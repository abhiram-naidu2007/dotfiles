use std::process::{Child, Command, Stdio};
use std::time::{Duration, Instant};

use rustix::event::{PollFd, PollFlags, Timespec};
use x11rb::connection::Connection;
use x11rb::protocol::Event;

use crate::island::Ev;
use crate::ui::{Act, Slider};
use crate::config::{assets, home};
use crate::{audio, bar, clip, i3, icons, ipc, island, model, mpris, notify, services, stats, text, theme, watch, wifi, x11};

const FRAME: Duration = Duration::from_micros(6944);
const STATS_EVERY: Duration = Duration::from_secs(3);

const WORLDS: [&str; 4] = ["meridian", "sakuga", "katha", "toon"];
const IDLE: [&str; 9] = ["xset", "s", "600", "600", "+dpms", "dpms", "0", "0", "900"];

fn script(name: &str) -> String {
    assets().join("scripts").join(name).to_string_lossy().into_owned()
}

fn rice(args: &[&str]) {
    let bin = home().join(".local/bin/rice").to_string_lossy().into_owned();
    spawn(&[&[bin.as_str()], args].concat());
}

fn spawn(argv: &[&str]) {
    let _ = Command::new(argv[0]).args(&argv[1..]).stdin(Stdio::null()).stdout(Stdio::null()).stderr(Stdio::null()).spawn().map(|mut c| {
        std::thread::spawn(move || c.wait());
    });
}

fn run_out(argv: &[&str]) -> String {
    Command::new(argv[0]).args(&argv[1..]).stderr(Stdio::null()).output().map(|o| String::from_utf8_lossy(&o.stdout).into_owned()).unwrap_or_default()
}

fn sound(name: &str) {
    if !crate::config::SOUNDS.load(std::sync::atomic::Ordering::Relaxed) {
        return;
    }
    spawn(&["pw-play", &assets().join(format!("sounds/{name}.wav")).to_string_lossy()]);
}

fn rec_parse(out: &str) -> Option<model::Rec> {
    let p: Vec<&str> = out.trim().split('|').collect();
    let state = *p.first()?;
    if state != "rec" && state != "paused" {
        return None;
    }
    Some(model::Rec {
        start: p.get(2).and_then(|s| s.parse().ok()).unwrap_or(0),
        paused_total: p.get(3).and_then(|s| s.parse().ok()).unwrap_or(0),
        paused: state == "paused",
    })
}

struct App {
    disp: x11::Display,
    fonts: text::Fonts,
    icons: icons::Icons,
    bar: bar::Bar,
    bar_s: x11::Surface,
    isl: island::Island,
    isl_s: x11::Surface,
    m: model::Model,
    i3: i3::I3,
    hub: services::Hub,
    grabbed: bool,
    coffee: Option<Child>,
    sw: u16,
    last_frame: Instant,
    resumed: bool,
    worst: Duration,
    frames: u64,
    stats_log: bool,
    times: Vec<f32>,
    walls: crate::walls::Walls,
    walls_s: Option<x11::Surface>,
    menu: Option<(crate::menu::Menu, x11::Surface, bool)>,
    menu_x: i32,
    pointer: bool,
    low_warned: u8,
    launch_until: Option<Instant>,
}

impl App {
    fn waker(&self) -> services::Waker {
        self.hub.waker()
    }

    fn sync_i3(&mut self, now: Instant) {
        let (ws, focused) = self.i3.workspaces();
        self.bar.set_workspaces(ws, focused, now);
        let f = self.i3.focus();
        self.set_focus(&f, now);
    }

    fn set_focus(&mut self, f: &i3::Focus, now: Instant) {
        self.bar.set_focus(&f.title, &f.class, f.fullscreen);
        self.isl.set_hidden(f.fullscreen, now);
    }

    fn tick_clock(&mut self) {
        let t = chrono::Local::now();
        let fmt = match (self.m.cfg.clock24, self.m.cfg.seconds) {
            (true, false) => "%H:%M",
            (true, true) => "%H:%M:%S",
            (false, false) => "%-I:%M",
            (false, true) => "%-I:%M:%S",
        };
        self.m.clock = t.format(fmt).to_string();
        self.m.date = t.format("%A, %-d %B").to_string();
        self.isl.date = self.m.date.clone();
        self.isl.mark();
    }

    fn open(&mut self, page: &'static str, now: Instant) {
        self.m.power_arm.clear();
        match page {
            "wifi" => self.wifi_scan(),
            "audio" | "main" => self.m.bright = services::brightness(),
            "clip" => {
                self.m.clip_query.clear();
                self.clip_load();
            }
            "record" => self.rec_status(),
            "battery" => services::battery_details(self.waker()),
            _ => {}
        }
        if page == "main" {
            self.rec_status();
        }
        self.isl.open(page, now);
    }

    fn toast(&mut self, glyph: &str, label: &str, title: &str, ring: Option<f32>, ms: u64, now: Instant) {
        self.isl.show(island::Toast::plain(glyph, label, title, ring, now + Duration::from_millis(ms)), now);
    }

    fn follow_launch(&mut self, con_id: i64, now: Instant) {
        if !self.launch_until.is_some_and(|t| now < t) {
            return;
        }
        let Some((ws, class, title)) = self.i3.locate(con_id) else { return };
        if ws < 0 {
            return;
        }
        self.launch_until = None;
        let here = self.bar.focused;
        if ws != here {
            self.i3.command(&format!("[con_id={con_id}] focus"));
        }
        let app = if class.is_empty() { title } else { class.replace('-', " ") };
        let label = if ws != here { format!("Moved to workspace {ws}") } else { format!("Opened on workspace {ws}") };
        self.toast(&format!("{}", ws), &label, &app, None, 2600, now);
    }

    fn load_look(&mut self) {
        let t = theme::Theme::load();
        let (scene, live, mood) = theme::rice_look(&t.pal);
        self.m.scene = scene;
        self.m.live = live;
        self.m.mood = mood;
        let cur = std::fs::read_to_string(home().join(".local/state/rice/wallpaper")).unwrap_or_default().trim().to_owned();
        let world = self.m.world.clone();
        let w = self.waker();
        std::thread::spawn(move || {
            let out = run_out(&[&home().join(".local/bin/rice").to_string_lossy(), "world-walls", &world]);
            let state = std::fs::read_to_string(home().join(format!(".local/state/rice/world-{world}"))).unwrap_or_default().trim().to_owned();
            let want = if state.is_empty() { cur } else { state };
            let row = out.lines().map(|l| l.split('|').collect::<Vec<_>>()).find(|p| p.len() >= 3 && p[0] == want);
            if let Some(p) = row {
                let name = std::path::Path::new(p[0]).file_stem().map(|s| s.to_string_lossy().replace(['-', '_'], " ")).unwrap_or_default();
                w.send(services::Msg::Wall(name, p[1] == "video", p[2].to_owned()));
            }
        });
    }

    fn peek_media(&mut self) {
        self.isl.media = self.m.media.as_ref().map(|md| {
            let extra = if md.playing { md.at.map(|a| a.elapsed().as_micros() as i64).unwrap_or(0) } else { 0 };
            let pos = if md.length_us > 0 { (md.position_us + extra) as f32 / md.length_us as f32 } else { 0.0 };
            (md.title.clone(), md.artist.clone(), pos)
        });
    }

    fn open_menu(&mut self, key: String, path: String, items: Vec<crate::tray::MenuItem>) {
        if items.is_empty() {
            crate::tray::act(crate::tray::Act::Menu(key, self.menu_x, self.bar_s.height as i32));
            return;
        }
        self.close_menu();
        let m = crate::menu::Menu::new(key, path, items);
        let h = m.height().ceil() as u16 + 2;
        let w = crate::menu::W as u16;
        let x = (self.menu_x - w as i32 / 2).clamp(6, self.sw as i32 - w as i32 - 6) as i16;
        if let Ok(s) = self.disp.create_surface(x, self.bar_s.height as i16 + 2, w, h, "loka-menu") {
            self.menu = Some((m, s, true));
            self.pointer = false;
        }
    }

    fn close_menu(&mut self) {
        if let Some((_, surf, _)) = self.menu.take() {
            self.disp.destroy(surf);
            self.disp.ungrab_pointer();
            self.pointer = false;
            self.disp.ungrab_keyboard();
            self.grabbed = false;
        }
    }

    fn menu_resize(&mut self) {
        if let Some((m, s, dirty)) = self.menu.as_mut() {
            let h = m.height().ceil() as u16 + 2;
            if h != s.height {
                let x = (self.menu_x - crate::menu::W as i32 / 2).clamp(6, self.sw as i32 - crate::menu::W as i32 - 6) as i16;
                if let Ok(ns) = self.disp.create_surface(x, self.bar_s.height as i16 + 2, crate::menu::W as u16, h, "loka-menu") {
                    let old = std::mem::replace(s, ns);
                    self.disp.destroy(old);
                    self.pointer = false;
                    self.grabbed = false;
                }
            }
            *dirty = true;
        }
    }

    fn menu_click(&mut self, x: f32, y: f32) {
        use crate::menu::Pick;
        let Some((m, s, _)) = self.menu.as_mut() else { return };
        if x < 0.0 || y < 0.0 || x > s.width as f32 || y > s.height as f32 {
            self.close_menu();
            return;
        }
        match m.pick(x, y) {
            Pick::Run(id) => {
                crate::tray::menu_event(m.key.clone(), m.path.clone(), id);
                self.close_menu();
            }
            Pick::Open(i) => {
                m.enter(i);
                self.menu_resize();
            }
            Pick::Back => {
                m.back();
                self.menu_resize();
            }
            Pick::None => {}
        }
    }

    fn open_walls(&mut self, now: Instant) {
        self.isl.close(now);
        if self.walls_s.is_none() {
            let (w, h) = self.disp.screen_size();
            self.walls_s = self.disp.create_surface(0, 0, w, h, "loka-walls").ok();
        }
        let wd = crate::walls::Walls::world_from_name(&self.m.world);
        self.walls.show(wd, now);
    }

    fn close_walls(&mut self) {
        self.walls.hide();
        if let Some(s) = self.walls_s.take() {
            self.disp.destroy(s);
        }
        if self.grabbed {
            self.disp.ungrab_keyboard();
            self.grabbed = false;
        }
    }

    fn walls_act(&mut self, a: crate::walls::WAct, now: Instant) {
        if let Some((world, path)) = self.walls.act(a, now) {
            rice(&["world", world, &path]);
        }
        if !self.walls.open {
            self.close_walls();
        }
    }

    fn walls_key(&mut self, ks: u32, now: Instant) {
        use crate::walls::WAct;
        match ks {
            0xff1b => self.walls_act(WAct::Close, now),
            0xff0d | 0xff8d => self.walls_act(WAct::Apply, now),
            0xff51 | 0x68 => self.walls.step(-1, now),
            0xff53 | 0x6c => self.walls.step(1, now),
            0xff52 | 0x6b | 0xfe20 => self.walls.world_step(-1, now),
            0xff54 | 0x6a | 0xff09 => self.walls.world_step(1, now),
            _ => {}
        }
    }

    fn wifi_scan(&mut self) {
        self.m.wifi_busy = true;
        let w = self.waker();
        std::thread::spawn(move || {
            w.send(services::Msg::Nets(wifi::list()));
            wifi::scan();
            std::thread::sleep(Duration::from_secs(4));
            w.send(services::Msg::Nets(wifi::list()));
        });
    }

    fn wifi_connect(&mut self, ssid: String, pw: Option<String>) {
        self.m.wifi_busy = true;
        let w = self.waker();
        std::thread::spawn(move || {
            let ok = wifi::connect(&ssid, pw.as_deref());
            w.send(services::Msg::WifiDone(ok, ssid));
        });
    }

    fn clip_load(&mut self) {
        let w = self.waker();
        std::thread::spawn(move || w.send(services::Msg::Clip(clip::list())));
    }

    fn rec_status(&mut self) {
        let w = self.waker();
        std::thread::spawn(move || w.send(services::Msg::Rec(rec_parse(&run_out(&[&script("record.sh"), "status"])))));
    }

    fn set_coffee(&mut self, on: bool) {
        if on && self.coffee.is_none() {
            self.coffee = Command::new("systemd-inhibit")
                .args(["--what=idle:sleep:handle-lid-switch", "--who=loka", "--why=Keep awake", "sleep", "infinity"])
                .stdin(Stdio::null())
                .stdout(Stdio::null())
                .stderr(Stdio::null())
                .spawn()
                .ok();
            spawn(&["xset", "s", "off", "-dpms"]);
        } else if !on {
            if let Some(mut c) = self.coffee.take() {
                let _ = c.kill();
                let _ = c.wait();
            }
            spawn(&IDLE);
        }
        self.m.coffee = self.coffee.is_some();
    }

    fn act(&mut self, a: Act, now: Instant) {
        match a {
            Act::None | Act::Slider(_) => {}
            Act::Page(p) => {
                if self.isl.expanded {
                    self.m.power_arm.clear();
                    if p == "wifi" {
                        self.wifi_scan();
                    }
                    if p == "clip" {
                        self.clip_load();
                    }
                    if p == "battery" {
                        services::battery_details(self.waker());
                    }
                    self.isl.go(p, now);
                } else {
                    self.open(p, now);
                }
            }
            Act::Back => {
                self.m.pw_for = None;
                self.m.pw_text.clear();
                if self.isl.page == "main" {
                    self.isl.close(now);
                } else {
                    self.isl.go("main", now);
                }
            }
            Act::Close => self.isl.close(now),
            Act::Cmd(c) => {
                if c == "airplane" {
                    spawn(&["sh", "-c", "if rfkill -n -o SOFT list | grep -qv '^blocked$'; then rfkill block all; else rfkill unblock all; fi"]);
                } else if let Some(wn) = c.strip_prefix("world ") {
                    rice(&["world", wn]);
                } else if c == "worldwalls" {
                    self.open_walls(now);
                } else {
                    self.i3.command(&c);
                }
            }
            Act::Exec(argv) => {
                let v: Vec<&str> = argv.iter().map(|s| s.as_str()).collect();
                spawn(&v);
                self.isl.close(now);
            }
            Act::WifiToggle => {
                let on = self.m.wifi.as_ref().map(|w| w.enabled).unwrap_or(false);
                spawn(&["nmcli", "radio", "wifi", if on { "off" } else { "on" }]);
            }
            Act::WifiScan => self.wifi_scan(),
            Act::WifiPick(ssid) => {
                let net = self.m.nets.iter().find(|n| n.ssid == ssid).cloned();
                match net {
                    Some(n) if n.connected => drop(std::thread::spawn(wifi::disconnect)),
                    Some(n) if n.known || n.security == "open" => self.wifi_connect(ssid, None),
                    Some(_) => {
                        self.m.pw_for = Some(ssid);
                        self.m.pw_text.clear();
                    }
                    None => {}
                }
            }
            Act::WifiConnectTyped => {
                if let Some(ssid) = self.m.pw_for.take() {
                    let pw = std::mem::take(&mut self.m.pw_text);
                    if !pw.is_empty() {
                        self.wifi_connect(ssid, Some(pw));
                    }
                }
            }
            Act::WifiForget(ssid) => {
                let w = self.waker();
                std::thread::spawn(move || {
                    wifi::forget(&ssid);
                    w.send(services::Msg::WifiDone(true, String::new()));
                });
            }
            Act::BtToggle => services::bt_action("power", None),
            Act::BtScan => {
                self.m.bt_scanning = true;
                services::bt_action("scan", None);
            }
            Act::BtDevice(p) => services::bt_action("toggle", Some(p)),
            Act::Coffee => {
                let on = !self.m.coffee;
                self.set_coffee(on);
            }
            Act::Profile(p) => {
                services::set_profile(p);
                self.m.profile = p.to_owned();
            }
            Act::Media(w) => {
                if let Some(md) = &self.m.media {
                    mpris::control(md.bus.clone(), w);
                }
            }
            Act::Sink(n) => audio::control(audio::Ctl::DefaultSink(n)),
            Act::Source(n) => audio::control(audio::Ctl::DefaultSource(n)),
            Act::MuteOut => audio::control(audio::Ctl::ToggleMute),
            Act::MuteIn => audio::control(audio::Ctl::MicMute),
            Act::MuteStream(i) => audio::control(audio::Ctl::StreamMute(i)),
            Act::ClipCopy(id) => {
                std::thread::spawn(move || clip::copy(id));
                self.isl.close(now);
            }
            Act::ClipDelete(id) => {
                clip::delete(id);
                self.clip_load();
            }
            Act::ClipClear => {
                clip::wipe();
                self.m.clip.clear();
            }
            Act::NotifAction(id, key) => {
                notify::invoke(id, &key);
                self.m.notifs.retain(|n| n.id != id);
                self.isl.close(now);
            }
            Act::NotifDismiss(id) => {
                self.m.notifs.retain(|n| n.id != id);
                notify::closed(id, 2);
            }
            Act::NotifClear => {
                for n in std::mem::take(&mut self.m.notifs) {
                    notify::closed(n.id, 2);
                }
            }
            Act::Dnd => {
                self.m.dnd = !self.m.dnd;
                self.m.cfg.dnd = self.m.dnd;
                self.m.cfg.save();
            }
            Act::LiveToggle => rice(&["live", "toggle"]),
            Act::MoodToggle => rice(&["mode", "next"]),
            Act::Clock24 => {
                self.m.cfg.clock24 = !self.m.cfg.clock24;
                self.m.cfg.save();
                self.tick_clock();
            }
            Act::Seconds => {
                self.m.cfg.seconds = !self.m.cfg.seconds;
                self.m.cfg.save();
                self.tick_clock();
            }
            Act::Sounds => {
                self.m.cfg.sounds = !self.m.cfg.sounds;
                self.m.cfg.save();
            }
            Act::ToastSecs(n) => {
                self.m.cfg.toast_secs = n;
                self.m.cfg.save();
            }
            Act::TermOpacity(n) => {
                self.m.cfg.term_opacity = n;
                self.m.cfg.save();
                let d = home().join(".config/ghostty");
                let _ = std::fs::create_dir_all(&d);
                let _ = std::fs::write(d.join("opacity"), format!("background-opacity = {:.2}\n", n as f32 / 100.0));
                spawn(&["pkill", "-USR2", "-x", "ghostty"]);
            }
            Act::CalShift(d) => self.m.cal_shift = if d == 0 { 0 } else { self.m.cal_shift + d },
            Act::Power(id) => {
                let confirm = matches!(id, "logout" | "reboot" | "poweroff");
                if confirm && self.m.power_arm != id {
                    self.m.power_arm = id.to_owned();
                } else {
                    self.m.power_arm.clear();
                    self.isl.close(now);
                    match id {
                        "lock" => spawn(&[&home().join("dotfiles/lockscreen/lock.sh").to_string_lossy()]),
                        "suspend" => spawn(&["systemctl", "suspend"]),
                        "logout" => self.i3.command("exit"),
                        "reboot" => spawn(&["systemctl", "reboot"]),
                        "poweroff" => spawn(&["systemctl", "poweroff"]),
                        _ => {}
                    }
                }
            }
            Act::RecPause => self.rec_cmd(vec!["pause".into()]),
            Act::TrayOpen(key, x) => {
                let off = (self.sw as i32 - island::SURF_W as i32) / 2 + (island::SURF_W as i32 - 540) / 2;
                self.menu_x = off + x;
                self.isl.close(now);
                crate::tray::fetch_menu(key, self.waker());
            }
            Act::RecSys => self.m.rec_sys = !self.m.rec_sys,
            Act::RecMic => self.m.rec_mic = !self.m.rec_mic,
            Act::RecMicDev(d) => {
                self.m.rec_mic_dev = d;
                self.m.rec_mic = true;
            }
            Act::Record => {
                let active = self.m.rec.is_some();
                let dir = home().join("Videos").to_string_lossy().into_owned();
                if active {
                    self.rec_cmd(vec!["stop".into()]);
                } else {
                    self.rec_cmd(vec![
                        "start".into(),
                        "60".into(),
                        dir,
                        if self.m.rec_sys { "1".into() } else { "0".into() },
                        if self.m.rec_mic { "1".into() } else { "0".into() },
                        self.m.rec_mic_dev.clone(),
                        String::new(),
                    ]);
                }
            }
        }
        self.isl.mark();
    }

    fn rec_cmd(&mut self, args: Vec<String>) {
        let script = script("record.sh");
        let w = self.waker();
        std::thread::spawn(move || {
            let _ = Command::new(&script).args(&args).stdout(Stdio::null()).stderr(Stdio::null()).status();
            std::thread::sleep(Duration::from_millis(400));
            let out = run_out(&[&script, "status"]);
            w.send(services::Msg::Rec(rec_parse(&out)));
        });
        self.isl.mark();
    }

    fn slider(&mut self, s: Slider, v: f32, step: bool) {
        match s {
            Slider::Volume => {
                if step {
                    audio::control(audio::Ctl::Step(v));
                } else {
                    audio::control(audio::Ctl::Set(v));
                    if let Some(vol) = self.m.vol.as_mut() {
                        vol.level = v;
                        vol.muted = false;
                    }
                }
            }
            Slider::Mic => {
                let cur = self.m.mic.map(|m| m.level).unwrap_or(0.0);
                let t = if step { cur + v } else { v };
                audio::control(audio::Ctl::MicSet(t));
                if let Some(m) = self.m.mic.as_mut() {
                    m.level = t.clamp(0.0, 1.0);
                }
            }
            Slider::Bright => {
                let t = if step { self.m.bright + v } else { v }.clamp(0.01, 1.0);
                self.m.bright = t;
                services::set_brightness(t);
            }
            Slider::Stream(i) => {
                let cur = self.m.streams.iter().find(|x| x.index == i).map(|x| x.level).unwrap_or(0.0);
                let t = if step { cur + v } else { v }.clamp(0.0, 1.5);
                audio::control(audio::Ctl::StreamSet(i, t));
                if let Some(x) = self.m.streams.iter_mut().find(|x| x.index == i) {
                    x.level = t;
                }
            }
        }
        self.isl.mark();
    }

    fn toggle_page(&mut self, page: &'static str, now: Instant) {
        if page == "worldwalls" {
            self.open_walls(now);
        } else if self.isl.expanded && self.isl.page == page {
            self.isl.close(now);
        } else if self.isl.expanded {
            self.act(Act::Page(page), now);
        } else {
            self.open(page, now);
        }
    }

    fn ipc(&mut self, line: &str, now: Instant) {
        let (cmd, arg) = line.split_once(' ').unwrap_or((line, ""));
        let page = match cmd {
            "controls" => "main",
            "wifi" => "wifi",
            "bluetooth" => "bt",
            "audio" => "audio",
            "notifications" => "notif",
            "calendar" => "cal",
            "clipboard" => "clip",
            "powermenu" => "power",
            "settings" => "settings",
            "battery" => "battery",
            "record" => "record",
            "worlds" => "worldwalls",
            _ => "",
        };
        if !page.is_empty() {
            return self.toggle_page(page, now);
        }
        match cmd {
            "close" => self.isl.close(now),
            "dnd" => self.act(Act::Dnd, now),
            "recordToggle" => self.act(Act::Record, now),
            "worldNext" => {
                let cur = WORLDS.iter().position(|w| *w == self.m.world).unwrap_or(0);
                rice(&["world", WORLDS[(cur + 1) % WORLDS.len()]]);
            }
            "launched" => self.launch_until = Some(now + Duration::from_secs(12)),
            "shotCopied" => {
                let name = std::path::Path::new(arg).file_name().map(|n| n.to_string_lossy().into_owned()).unwrap_or_default();
                spawn(&["notify-send", "-a", "Screenshot", "-i", arg, "-h", "int:transient:1", "Screenshot", &format!("Copied to the clipboard · {name}")]);
                sound("screenshot");
            }
            "brightness" => {
                let v = arg.parse::<f32>().unwrap_or(0.0) / 100.0;
                self.m.bright = v;
                self.isl.show_osd("bright", v, false, now);
            }
            _ => {}
        }
        self.isl.mark();
    }

    fn apply(&mut self, msg: services::Msg, now: Instant) {
        use services::Msg;
        match msg {
            Msg::Battery(b) => {
                if let Some(prev) = self.m.battery.clone()
                    && b.plugged && !prev.plugged {
                        self.toast("\u{f0084}", "Charging", &format!("{}%", b.pct), Some(b.pct as f32 / 100.0), 2300, now);
                        sound("charge");
                    }
                if b.present {
                    if b.plugged || b.pct > 20 {
                        self.low_warned = 0;
                    } else if b.pct <= 5 && self.low_warned < 2 {
                        self.low_warned = 2;
                        spawn(&["notify-send", "-u", "critical", "-a", "Battery", "-i", "battery-caution", &format!("Battery {}%", b.pct), "Plug in now. The laptop shuts down at 2% and unsaved work is lost."]);
                    } else if b.pct <= 15 && self.low_warned < 1 {
                        self.low_warned = 1;
                        let mut t = island::Toast::plain("\u{f0083}", "Low battery", &format!("{}% left · plug in soon", b.pct), Some(b.pct as f32 / 100.0), now + Duration::from_millis(3500));
                        t.force = true;
                        self.isl.show(t, now);
                        sound("disconnect");
                    }
                }
                self.m.battery = b.present.then_some(b.clone());
                self.bar.apply(Msg::Battery(b));
            }
            Msg::Wifi(w) => {
                if let Some(prev) = self.m.wifi.clone() {
                    if !w.ssid.is_empty() && w.ssid != prev.ssid {
                        self.toast("\u{f0928}", "Connected", &w.ssid, Some(w.strength as f32 / 100.0), 2500, now);
                        sound("connect");
                        let ssid = w.ssid.clone();
                        std::thread::spawn(move || {
                            std::thread::sleep(Duration::from_millis(2500));
                            let _ = Command::new(script("captive.sh")).arg(ssid).stdout(Stdio::null()).stderr(Stdio::null()).status();
                        });
                    } else if w.ssid.is_empty() && !prev.ssid.is_empty() && w.enabled {
                        self.toast("\u{f092b}", "Disconnected", &prev.ssid, None, 2500, now);
                        sound("disconnect");
                    }
                }
                self.m.wifi = Some(w.clone());
                self.bar.apply(Msg::Wifi(w));
            }
            Msg::Bt(b) => {
                if let Some(prev) = self.m.bt.clone() {
                    if !b.connected.is_empty() && b.connected != prev.connected {
                        let ring = (b.battery >= 0).then(|| b.battery as f32 / 100.0);
                        self.toast("\u{f00b1}", "Connected", &b.connected, ring, 2500, now);
                        sound("connect");
                    } else if b.connected.is_empty() && !prev.connected.is_empty() {
                        self.toast("\u{f00af}", "Disconnected", &prev.connected, None, 2500, now);
                        sound("disconnect");
                    }
                }
                self.m.bt = Some(b.clone());
                self.bar.apply(Msg::Bt(b));
            }
            Msg::BtDevs(d) => {
                self.m.bt_devs = d;
                self.m.bt_scanning = false;
            }
            Msg::Audio(a) => {
                if let (Some(o), Some(prev)) = (a.out, self.m.vol) {
                    let moved = (o.level - prev.level).abs() > 0.004 || o.muted != prev.muted;
                    if moved && !self.isl.expanded {
                        self.isl.show_osd("vol", o.level, o.muted, now);
                    }
                }
                self.m.vol = a.out;
                self.m.mic = a.mic;
                self.m.sinks = a.sinks;
                self.m.sources = a.sources;
                self.m.streams = a.streams;
                if let Some(v) = a.out {
                    self.bar.apply(Msg::Volume(v));
                }
            }
            Msg::Volume(v) => self.bar.apply(Msg::Volume(v)),
            Msg::Tray(t) => {
                self.m.tray = t.clone();
                self.bar.apply(Msg::Tray(t));
            }
            Msg::TrayMenu(k, p, items) => self.open_menu(k, p, items),
            Msg::Nets(n) => {
                self.m.nets = n;
                self.m.wifi_busy = false;
            }
            Msg::WifiDone(ok, ssid) => {
                self.m.wifi_busy = false;
                if !ok && !ssid.is_empty() {
                    self.isl.show_toast("Wi-Fi", &format!("Could not connect to {ssid}"), 4, now);
                }
                self.wifi_scan();
            }
            Msg::Media(md) => {
                let art = md.as_ref().map(|m| m.art.clone()).unwrap_or_default();
                if art != self.m.art_key {
                    self.m.art_key = art.clone();
                    self.m.art = None;
                    if !art.is_empty() {
                        let w = self.waker();
                        std::thread::spawn(move || {
                            let path = run_out(&["loka-art", &art, "44", "10"]);
                            w.send(Msg::Art(art, path.trim().to_owned()));
                        });
                    }
                }
                self.m.media = md;
                self.peek_media();
            }
            Msg::Art(key, path) => {
                if key == self.m.art_key {
                    self.m.art = icons::render_path(std::path::Path::new(&path), 44);
                }
            }
            Msg::Profile(p) => self.m.profile = p,
            Msg::Notify(n, timeout) => {
                if let Some(i) = self.m.notifs.iter().position(|x| x.id == n.id) {
                    self.m.notifs[i] = n.clone();
                } else {
                    self.m.notifs.push(n.clone());
                }
                if self.m.notifs.len() > 50 {
                    self.m.notifs.remove(0);
                }
                if !self.m.dnd || n.critical {
                    let secs = if n.critical { 10 } else if timeout > 0 { (timeout as u64 / 1000).clamp(2, 10) } else { self.m.cfg.toast_secs };
                    let action = n.actions.iter().find(|(k, _)| k != "default").cloned();
                    let has_default = n.actions.iter().any(|(k, _)| k == "default");
                    self.isl.show(island::Toast {
                        glyph: if n.critical { "\u{f0026}".into() } else { "\u{f009a}".into() },
                        label: String::new(),
                        title: n.summary.clone(),
                        body: n.body.clone(),
                        ring: None,
                        notif: Some(n.id),
                        action,
                        default_action: has_default,
                        force: n.critical,
                        until: now + Duration::from_secs(if n.actions.is_empty() { secs } else { secs.max(8) }),
                    }, now);
                }
            }
            Msg::NotifClose(id) => self.m.notifs.retain(|n| n.id != id),
            Msg::Ipc(l) => self.ipc(&l, now),
            Msg::Rec(r) => self.m.rec = r,
            Msg::Resumed => {
                self.resumed = true;
                self.rec_status();
            }
            Msg::Clip(c) => {
                self.m.clip_thumbs.retain(|id, _| c.iter().any(|i| i.id == *id));
                for i in c.iter().take(20) {
                    if let Some(path) = &i.image
                        && !self.m.clip_thumbs.contains_key(&i.id)
                        && let Some(p) = icons::load_scaled(path, 64)
                    {
                        self.m.clip_thumbs.insert(i.id, p);
                    }
                }
                self.m.clip = c;
            }
            Msg::BatDetails(d) => self.m.batdet = Some(d),
            Msg::Wall(name, video, thumb) => {
                self.m.wall_name = name;
                self.m.wall_video = video;
                self.m.wall_thumb = icons::load_scaled(std::path::Path::new(&thumb), 224);
            }
        }
        self.isl.mark();
    }

    fn key(&mut self, keycode: u8, state: u16, now: Instant) {
        let ks = self.disp.keysym(keycode, state);
        if std::env::var_os("LOKA_DEBUG").is_some() {
            eprintln!("loka: key {keycode} state {state} keysym {ks:#x} page {} grabbed {}", self.isl.page, self.grabbed);
        }
        if self.menu.is_some() {
            if ks == 0xff1b {
                self.close_menu();
            }
            return;
        }
        if self.walls.open {
            self.walls_key(ks, now);
            return;
        }
        match ks {
            0xff1b => {
                if self.m.pw_for.is_some() {
                    self.m.pw_for = None;
                    self.m.pw_text.clear();
                } else if self.isl.page != "main" {
                    self.isl.go("main", now);
                } else {
                    self.isl.close(now);
                }
            }
            0xff0d | 0xff8d => {
                if self.m.pw_for.is_some() {
                    self.act(Act::WifiConnectTyped, now);
                } else if let Some(h) = self.isl.focused() {
                    self.act(h.act, now);
                } else if self.isl.page == "clip" {
                    let q = self.m.clip_query.to_lowercase();
                    if let Some(id) = self.m.clip.iter().find(|i| q.is_empty() || i.text.to_lowercase().contains(&q)).map(|i| i.id) {
                        self.act(Act::ClipCopy(id), now);
                    }
                }
            }
            0xff08 => {
                if self.isl.page == "clip" {
                    self.m.clip_query.pop();
                } else {
                    self.m.pw_text.pop();
                }
            }
            0xff55 if self.isl.page == "cal" => self.m.cal_shift -= 1,
            0xff56 if self.isl.page == "cal" => self.m.cal_shift += 1,
            0xff09 | 0xff54 => self.isl.move_focus(1),
            0xfe20 | 0xff52 => self.isl.move_focus(-1),
            0xff51 | 0xff53 => {
                let d = if ks == 0xff53 { 1.0 } else { -1.0 };
                match self.isl.focused() {
                    Some(h) => match h.act {
                        Act::Slider(sl) => self.slider(sl, 0.05 * d, true),
                        _ => self.isl.move_focus(d as i32),
                    },
                    None if self.isl.page == "cal" => self.m.cal_shift += d as i32,
                    None => self.isl.move_focus(d as i32),
                }
            }
            0x20 if self.isl.page != "clip" && self.m.pw_for.is_none() => {
                if let Some(h) = self.isl.focused() {
                    self.act(h.act, now);
                }
            }
            _ => {
                if state & 0x4 == 0
                    && let Some(c) = x11::keysym_char(ks)
                {
                    if self.m.pw_for.is_some() {
                        self.m.pw_text.push(c);
                    } else if self.isl.page == "clip" {
                        self.m.clip_query.push(c);
                    }
                }
            }
        }
        self.isl.mark();
    }

    fn frame(&mut self, now: Instant) -> x11::Result<()> {
        let t0 = Instant::now();
        let mut drew = false;
        self.bar.set_open_page(if self.isl.expanded { Some(self.isl.page) } else { None });
        if self.bar.needs_frame(now) {
            let d = self.bar.render(&mut self.bar_s.pixmap, &mut self.fonts, &mut self.icons, now);
            self.disp.present(&mut self.bar_s, d)?;
            self.disp.set_input_region(&self.bar_s, self.bar.input_rects())?;
            drew = true;
        }
        if self.isl.needs_frame(now) {
            self.isl.last_content_ms = 0.0;
            let ta = Instant::now();
            let d = self.isl.render(&mut self.isl_s.pixmap, &mut self.fonts, &mut self.m, now);
            let tb = Instant::now();
            self.disp.present(&mut self.isl_s, d)?;
            self.disp.set_input_region(&self.isl_s, &self.isl.input_rects(now))?;
            let tc = Instant::now();
            drew = true;
            if self.stats_log && (tc - ta).as_secs_f32() > 0.007 {
                eprintln!(
                    "loka: slow island frame page={} content {:.2} draw {:.2} present {:.2} ms",
                    self.isl.page,
                    self.isl.last_content_ms,
                    (tb - ta).as_secs_f32() * 1000.0 - self.isl.last_content_ms,
                    (tc - tb).as_secs_f32() * 1000.0
                );
            }
        }
        let th = self.isl.pal;
        if let Some((m, s, dirty)) = self.menu.as_mut()
            && *dirty {
                let d = m.render(&mut s.pixmap, &mut self.fonts, &th);
                self.disp.present(s, d)?;
                *dirty = false;
                drew = true;
            }
        if self.walls.needs_frame(now) {
            if let Some(ws) = self.walls_s.as_mut() {
                let d = self.walls.render(&mut ws.pixmap, &mut self.fonts, now);
                self.disp.present(ws, d)?;
            }
            drew = true;
        }
        if drew {
            let dt = t0.elapsed();
            self.worst = self.worst.max(dt);
            self.frames += 1;
            self.last_frame = now;
            if self.stats_log {
                self.times.push(dt.as_secs_f32() * 1000.0);
                if self.times.len() >= 120 {
                    let mut t = std::mem::take(&mut self.times);
                    t.sort_by(|a, b| a.total_cmp(b));
                    let p = |q: f32| t[((t.len() - 1) as f32 * q) as usize];
                    eprintln!("loka: frames {} p50 {:.2} p99 {:.2} max {:.2} ms", self.frames, p(0.5), p(0.99), t[t.len() - 1]);
                }
            }
        }
        Ok(())
    }

    fn ensure_grabs(&mut self) {
        if let Some((_, s, _)) = &self.menu {
            if !self.pointer {
                self.pointer = self.disp.grab_pointer(s);
                if std::env::var_os("LOKA_DEBUG").is_some() {
                    eprintln!("loka: menu pointer grab {}", self.pointer);
                }
            }
            if !self.grabbed {
                self.grabbed = self.disp.grab_keyboard(s);
                if std::env::var_os("LOKA_DEBUG").is_some() {
                    eprintln!("loka: menu keyboard grab {}", self.grabbed);
                }
            }
        } else if self.walls.open {
            if !self.grabbed
                && let Some(ws) = &self.walls_s {
                    self.grabbed = self.disp.grab_keyboard(ws);
                }
        } else if self.isl.expanded {
            if !self.grabbed {
                self.grabbed = self.disp.grab_keyboard(&self.isl_s);
            }
            if !self.pointer {
                self.pointer = self.disp.grab_pointer(&self.isl_s);
            }
        } else {
            if self.grabbed {
                self.disp.ungrab_keyboard();
                self.grabbed = false;
            }
            if self.pointer {
                self.disp.ungrab_pointer();
                self.pointer = false;
            }
        }
    }
}

pub fn run() -> x11::Result<()> {
    let disp = x11::Display::connect()?;
    let (sw, _) = disp.screen_size();
    let th = theme::Theme::load();
    let bar = bar::Bar::new(sw, th.clone());
    let bar_s = disp.create_surface(0, 0, sw, bar.height(), "loka")?;
    let isl_s = disp.create_surface(((sw - island::SURF_W) / 2) as i16, 0, island::SURF_W, island::SURF_H, "loka-island")?;
    disp.watch_clipboard(&isl_s)?;
    let _ = disp.watch_screen();
    let hub = services::Hub::new()?;
    ipc::serve(hub.waker())?;
    services::start(&hub);
    let cfg = crate::config::Config::load();
    let m = model::Model {
        rec_sys: true,
        dnd: cfg.dnd,
        cfg,
        world: std::fs::read_to_string(theme::world_path()).unwrap_or_default().trim().to_owned(),
        bright: services::brightness(),
        ..Default::default()
    };
    let mut app = App {
        disp,
        fonts: text::Fonts::new(),
        icons: icons::Icons::new(),
        bar,
        bar_s,
        isl: island::Island::new(th),
        isl_s,
        m,
        i3: i3::I3::new(),
        hub,
        grabbed: false,
        coffee: None,
        sw,
        last_frame: Instant::now() - FRAME,
        resumed: false,
        worst: Duration::ZERO,
        frames: 0,
        stats_log: std::env::var_os("LOKA_STATS").is_some(),
        times: Vec::new(),
        walls: crate::walls::Walls::new(),
        walls_s: None,
        menu: None,
        menu_x: 0,
        pointer: false,
        low_warned: 0,
        launch_until: None,
    };
    spawn(&IDLE);
    let mut stats = stats::Stats::new();
    let run = std::env::var_os("XDG_RUNTIME_DIR").map(std::path::PathBuf::from).unwrap_or_else(|| std::path::PathBuf::from("/tmp"));
    let watch = watch::Watch::new(&[
        (&home().join(".cache/theme"), watch::THEME, &[]),
        (&home().join(".local/state/rice"), watch::THEME, &[]),
        (&run, watch::REC, &["rice-rec"]),
        (&run.join("loka"), watch::REC, &["record.state"]),
    ])?;
    app.rec_status();
    let start = Instant::now();
    app.load_look();
    app.sync_i3(start);
    app.tick_clock();
    stats.sample();
    let mut next_stats = start + STATS_EVERY;
    let mut next_clock = start + Duration::from_secs(60 - chrono::Local::now().timestamp() as u64 % 60);
    let mut next_live = start + Duration::from_secs(1);
    let mut warm_at = Some(start + Duration::from_secs(2));

    loop {
        let now = Instant::now();
        if app.resumed {
            app.resumed = false;
            next_stats = now;
            next_clock = now;
        }
        if now >= next_stats {
            stats.sample();
            app.m.stats = [stats.cpu, stats.mem, stats.igpu];
            app.bar.set_stats(app.m.stats);
            next_stats = now + STATS_EVERY;
        }
        if now >= next_clock {
            app.tick_clock();
            let step = if app.m.cfg.seconds { 1 } else { 60 };
            let ms = chrono::Local::now().timestamp_subsec_millis() as u64;
            let into = (chrono::Local::now().timestamp() as u64 % step) * 1000 + ms;
            next_clock = now + Duration::from_millis(step * 1000 - into.min(step * 1000 - 1));
        }
        let playing = app.m.media.as_ref().map(|m| m.playing).unwrap_or(false);
        let live = (app.isl.expanded && (app.m.rec.is_some() || playing)) || (app.isl.peek && playing);
        if live && now >= next_live {
            app.peek_media();
            app.isl.mark();
            next_live = now + Duration::from_secs(1);
        }
        if warm_at.is_some_and(|t| now >= t) && !app.isl.expanded {
            warm_at = None;
            app.isl.warm(&mut app.fonts, &mut app.m, now);
        }
        let clock = app.m.clock.clone();
        app.isl.tick(now, &clock);
        if let Some(at) = app.i3.retry_due(now)
            && now >= at && app.i3.connect() {
                app.sync_i3(now);
            }
        let menu_dirty = app.menu.as_ref().map(|m| m.2).unwrap_or(false);
        if (menu_dirty || app.bar.needs_frame(now) || app.isl.needs_frame(now) || app.walls.needs_frame(now)) && now.duration_since(app.last_frame) >= FRAME {
            app.frame(now)?;
        }

        let now = Instant::now();
        let mut deadline = next_stats.min(next_clock);
        if let Some(t) = warm_at {
            deadline = deadline.min(t);
        }
        if live {
            deadline = deadline.min(next_live);
        }
        if app.bar.needs_frame(now) || app.isl.needs_frame(now) || app.walls.needs_frame(now) {
            deadline = deadline.min(app.last_frame + FRAME);
        }
        if let Some(at) = app.i3.retry_due(now) {
            deadline = deadline.min(at);
        }
        if let Some(at) = app.isl.next_wake(now) {
            deadline = deadline.min(at);
        }
        if app.m.rec.is_some_and(|r| !r.paused) {
            let ms = 1000 - chrono::Utc::now().timestamp_subsec_millis().min(999) as u64;
            deadline = deadline.min(now + Duration::from_millis(ms + 5));
        }
        let wait = deadline.saturating_duration_since(now);
        let ts = Timespec { tv_sec: wait.as_secs() as i64, tv_nsec: wait.subsec_nanos() as i64 };
        let (w_ready, i_ready, h_ready) = {
            let xfd = std::os::fd::AsFd::as_fd(app.disp.conn.stream());
            let wfd = watch.fd();
            let hfd = app.hub.fd();
            let ifd = app.i3.fd();
            let mut fds = vec![PollFd::new(&xfd, PollFlags::IN), PollFd::new(&wfd, PollFlags::IN), PollFd::new(&hfd, PollFlags::IN)];
            if let Some(f) = ifd.as_ref() {
                fds.push(PollFd::new(f, PollFlags::IN));
            }
            match rustix::event::poll(&mut fds, Some(&ts)) {
                Ok(_) | Err(rustix::io::Errno::INTR) => {}
                Err(e) => return Err(e.into()),
            }
            let r = |i: usize| fds.get(i).map(|f| !f.revents().is_empty()).unwrap_or(false);
            (r(1), r(3), r(2))
        };
        let now = Instant::now();
        app.bar.set_rec(app.m.rec.map(|r| (r.elapsed(), r.paused)));
        if h_ready {
            for m in app.hub.drain() {
                app.apply(m, now);
            }
        }
        let changed = if w_ready { watch.drain() } else { 0 };
        if changed & watch::REC != 0 {
            app.rec_status();
        }
        if changed & watch::THEME != 0 {
            let t = theme::Theme::load();
            app.m.world = std::fs::read_to_string(theme::world_path()).unwrap_or_default().trim().to_owned();
            app.bar.set_theme(t.clone());
            app.isl.set_theme(t);
            app.load_look();
            let h = app.bar.height();
            if h != app.bar_s.height {
                let ns = app.disp.create_surface(0, 0, app.sw, h, "loka")?;
                let old = std::mem::replace(&mut app.bar_s, ns);
                app.disp.destroy(old);
            }
        }
        if i_ready {
            let mut resync = false;
            for (kind, v) in app.i3.read_events() {
                match kind {
                    i3::EV_WINDOW => {
                        let change = v["change"].as_str().unwrap_or_default();
                        let c = &v["container"];
                        if matches!(change, "new" | "urgent") && (change == "new" || c["urgent"].as_bool() == Some(true))
                            && let Some(id) = c["id"].as_i64() {
                                app.follow_launch(id, now);
                            }
                        if c["focused"].as_bool() == Some(true) && matches!(change, "focus" | "title" | "new" | "fullscreen_mode") {
                            app.set_focus(&i3::focus_of(c), now);
                        } else if change == "close" || change == "fullscreen_mode" {
                            resync = true;
                        }
                    }
                    i3::EV_WORKSPACE | i3::EV_OUTPUT => resync = true,
                    _ => {}
                }
            }
            if resync && app.i3.connected() {
                app.sync_i3(now);
            }
        }
        while let Some(ev) = app.disp.next_event()? {
            let now = Instant::now();
            let bw = app.bar_s.win;
            let iw = app.isl_s.win;
            match ev {
                Event::Expose(e) => {
                    if e.window == bw {
                        app.bar.mark_dirty();
                    } else {
                        app.isl.mark();
                    }
                }
                Event::MotionNotify(e) if app.menu.as_ref().map(|m| m.1.win) == Some(e.event) => {
                    if let Some((m, _, dirty)) = app.menu.as_mut()
                        && m.motion(e.event_x as f32, e.event_y as f32) {
                            *dirty = true;
                        }
                }
                Event::ButtonPress(e) if app.menu.as_ref().map(|m| m.1.win) == Some(e.event) => {
                    app.menu_click(e.event_x as f32, e.event_y as f32);
                }
                Event::MotionNotify(e) if e.event == bw => app.bar.motion(e.event_x as f32, e.event_y as f32),
                Event::MotionNotify(e) if e.event == iw => {
                    if let Some(Ev::Set(s, v)) = app.isl.motion(e.event_x as f32, e.event_y as f32, now) {
                        app.slider(s, v, false);
                    }
                }
                Event::LeaveNotify(e) => {
                    if e.event == bw {
                        app.bar.leave();
                    } else if e.event == iw {
                        app.isl.leave_at(now);
                    }
                }
                Event::ButtonPress(e) if e.event == bw => {
                    let r = app.bar.click(e.event_x as f32, e.event_y as f32, e.detail, now);
                    if std::env::var_os("LOKA_DEBUG").is_some() {
                        eprintln!("loka: bar click {} {} b{} -> {:?}", e.event_x, e.event_y, e.detail, r);
                    }
                    match r {
                        Some(bar::Click::I3(cmd)) => app.i3.command(&cmd),
                        Some(bar::Click::Page(p)) => app.toggle_page(p, now),
                        Some(bar::Click::Record) => app.act(Act::Record, now),
                        Some(bar::Click::TrayMenu(key, x)) => {
                            app.menu_x = x;
                            crate::tray::fetch_menu(key, app.hub.waker());
                        }
                        None => {}
                    }
                }
                Event::ButtonPress(e) if e.event == iw => match app.isl.press(e.event_x as f32, e.event_y as f32, e.detail, now) {
                    Some(Ev::Act(a)) => app.act(a, now),
                    Some(Ev::Set(s, v)) => app.slider(s, v, false),
                    Some(Ev::Step(s, d)) => app.slider(s, d, true),
                    None => {}
                },
                Event::ButtonRelease(e) if e.event == iw => app.isl.release(),
                Event::ButtonPress(e) if app.walls_s.as_ref().map(|s| s.win) == Some(e.event) => match e.detail {
                    4 => app.walls.step(-1, now),
                    5 => app.walls.step(1, now),
                    1 => {
                        if let Some(a) = app.walls.press(e.event_x as f32, e.event_y as f32) {
                            app.walls_act(a, now);
                        }
                    }
                    _ => {}
                },
                Event::KeyPress(e) => app.key(e.detail, u16::from(e.state), now),
                Event::MappingNotify(_) => app.disp.reload_keymap(),
                Event::RandrScreenChangeNotify(_) => {
                    let (w, _) = app.disp.current_size();
                    if w != app.sw && w > 0 {
                        app.sw = w;
                        app.bar.resize(w);
                        let h = app.bar.height();
                        if let Ok(ns) = app.disp.create_surface(0, 0, w, h, "loka") {
                            let old = std::mem::replace(&mut app.bar_s, ns);
                            app.disp.destroy(old);
                        }
                        app.disp.move_window(&app.isl_s, ((w.saturating_sub(island::SURF_W)) / 2) as i16, 0);
                        app.isl.mark();
                    }
                }
                Event::XfixesSelectionNotify(_) => drop(std::thread::spawn(clip::store)),
                _ => {}
            }
        }
        app.ensure_grabs();
        app.disp.conn.flush()?;
    }
}

#[cfg(test)]
mod tests {
    use super::rec_parse;

    #[test]
    fn record_status_parses() {
        assert_eq!(rec_parse("idle\n"), None);
        assert_eq!(rec_parse("rec|123|1794681318|4|/x.mp4\n").map(|r| (r.start, r.paused_total, r.paused)), Some((1794681318, 4, false)));
        assert_eq!(rec_parse("paused|123|10|2|/x.mp4\n").map(|r| r.paused), Some(true));
    }
}
