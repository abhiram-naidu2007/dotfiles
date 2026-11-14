use std::time::Instant;

use chrono::{Datelike, Local, NaiveDate};
use tiny_skia::{PixmapPaint, Transform};

use crate::canvas::{IRect, Rgba};
use crate::dot;
use crate::model::Model;
use crate::ui::{Act, Slider, Ui};

pub fn draw(page: &str, ui: &mut Ui, m: &mut Model, now: Instant) {
    match page {
        "wifi" => wifi(ui, m),
        "bt" => bt(ui, m),
        "audio" => audio(ui, m),
        "power" => power(ui, m),
        "cal" => calendar(ui, m),
        "notif" => notifications(ui, m),
        "clip" => clipboard(ui, m),
        "settings" => settings(ui, m),
        "battery" => battery(ui, m),
        "record" => record(ui, m),
        _ => main(ui, m, now),
    }
}

fn wifi_glyph(enabled: bool, ssid: &str, strength: i32) -> &'static str {
    if !enabled {
        "\u{f092e}"
    } else if ssid.is_empty() {
        "\u{f092b}"
    } else if strength > 66 {
        "\u{f0928}"
    } else if strength > 33 {
        "\u{f0925}"
    } else {
        "\u{f091f}"
    }
}

fn vol_glyph(level: f32, muted: bool) -> &'static str {
    if muted {
        "\u{f075f}"
    } else if level > 0.66 {
        "\u{f057e}"
    } else if level > 0.33 {
        "\u{f0580}"
    } else {
        "\u{f057f}"
    }
}

#[allow(clippy::too_many_arguments)]
fn tile(ui: &mut Ui, x: f32, y: f32, w: f32, glyph: &str, title: &str, sub: &str, on: bool, act: Act, toggle: Act) {
    let h = 60.0;
    let hot = ui.hit(IRect::new((x + 52.0) as i32, y as i32, (w - 52.0) as i32, h as i32), act);
    ui.card(x, y, w, h, false, hot);
    let th = ui.th;
    let thot = ui.hit(IRect::new((x + 8.0) as i32, (y + 10.0) as i32, 40, 40), toggle);
    let circ = if on { th.on } else if thot { th.fg.alpha(0.2) } else { th.fg.alpha(0.12) };
    ui.rect(x + 10.0, y + 12.0, 36.0, 36.0, 18.0, circ);
    ui.glyph_center(glyph, 16.0, x + 28.0, y + 30.0, if on { th.fg_on(th.on) } else { th.fg });
    let ts = ui.txt(ui.size - 3.0, 700);
    ui.text_max(title, &ts, x + 56.0, y + 22.0, th.fg, w - 64.0);
    let ss = ui.txt(ui.size - 5.0, 400);
    ui.text_max(sub, &ss, x + 56.0, y + 40.0, th.muted, w - 64.0);
}

fn main(ui: &mut Ui, m: &mut Model, now: Instant) {
    let th = ui.th;
    let (x, w) = (ui.x, ui.w);
    let y0 = ui.y;
    let big = 26.0;
    dot::draw(ui.pm, &m.clock, big, x + 2.0, y0 + 4.0, th.fg);
    let cw = dot::width(&m.clock, big);
    let ds = ui.txt(ui.size - 3.0, 500);
    ui.text(&m.date, &ds, x + cw + 16.0, y0 + 12.0, th.fg);
    let ls = ui.txt(ui.size - 5.0, 400);
    let hot = ui.hit(IRect::new((x + cw + 12.0) as i32, (y0 + 20.0) as i32, 90, 18), Act::Page("cal"));
    ui.text("Calendar", &ls, x + cw + 16.0, y0 + 29.0, if hot { th.on } else { th.muted });
    let bx = x + w - 3.0 * 36.0;
    for (i, (g, act)) in [("\u{f009a}", Act::Page("notif")), ("\u{f014c}", Act::Page("clip")), ("\u{f0493}", Act::Page("settings"))].into_iter().enumerate() {
        let bxi = bx + i as f32 * 36.0;
        let hot = ui.hit(IRect::new(bxi as i32, (y0 + 4.0) as i32, 32, 32), act);
        ui.rect(bxi, y0 + 4.0, 32.0, 32.0, 16.0, if hot { th.hover } else { th.fg.alpha(0.06) });
        ui.glyph_center(g, 15.0, bxi + 16.0, y0 + 20.0, th.fg);
        if i == 0 && !m.notifs.is_empty() {
            ui.rect(bxi + 22.0, y0 + 4.0, 10.0, 10.0, 5.0, th.on);
        }
    }
    ui.y = y0 + 48.0;

    let half = (w - 10.0) / 2.0;
    let y = ui.y;
    let (wg, wt, ws, won) = match &m.wifi {
        Some(wf) => (
            wifi_glyph(wf.enabled, &wf.ssid, wf.strength),
            if wf.ssid.is_empty() { "Wi-Fi".to_owned() } else { wf.ssid.clone() },
            if !wf.enabled { "Off".to_owned() } else if wf.ssid.is_empty() { "Not connected".to_owned() } else { format!("{}%", wf.strength) },
            wf.enabled,
        ),
        None => ("\u{f092e}", "Wi-Fi".to_owned(), "Unavailable".to_owned(), false),
    };
    tile(ui, x, y, half, wg, &wt, &ws, won, Act::Page("wifi"), Act::WifiToggle);
    let (bg, bt_t, bt_s, bon) = match &m.bt {
        Some(b) => (
            if !b.powered { "\u{f00b2}" } else if b.connected.is_empty() { "\u{f00af}" } else { "\u{f00b1}" },
            if b.connected.is_empty() { "Bluetooth".to_owned() } else { b.connected.clone() },
            if !b.powered { "Off".to_owned() } else if b.connected.is_empty() { "No devices".to_owned() }
                else if b.battery >= 0 { format!("Connected · {}%", b.battery) } else { "Connected".to_owned() },
            b.powered,
        ),
        None => ("\u{f00b2}", "Bluetooth".to_owned(), "Unavailable".to_owned(), false),
    };
    tile(ui, x + half + 10.0, y, half, bg, &bt_t, &bt_s, bon, Act::Page("bt"), Act::BtToggle);
    ui.y = y + 70.0;

    let v = m.vol.unwrap_or(crate::services::Volume { level: 0.0, muted: false });
    let cy = ui.y;
    let vt = if v.muted { "Muted".to_owned() } else { format!("{}%", (v.level * 100.0).round() as i32) };
    ui.slider(vol_glyph(v.level, v.muted), Act::MuteOut, v.level, 1.0, Slider::Volume, &vt);
    ui.hit(IRect::new((x + w - 46.0) as i32, cy as i32, 46, 34), Act::Page("audio"));
    ui.slider("\u{f00df}", Act::None, m.bright, 1.0, Slider::Bright, &format!("{}%", (m.bright * 100.0).round() as i32));
    ui.space(4.0);

    if let Some(md) = m.media.clone() {
        let y = ui.y;
        let h = 78.0;
        ui.card(x, y, w, h, false, false);
        if let Some(art) = &m.art {
            ui.pm.draw_pixmap((x + 12.0) as i32, (y + 12.0) as i32, art.as_ref(), &PixmapPaint::default(), Transform::identity(), None);
        } else {
            ui.rect(x + 12.0, y + 12.0, 44.0, 44.0, 10.0, th.fg.alpha(0.08));
            ui.glyph_center("\u{f075a}", 18.0, x + 34.0, y + 34.0, th.muted);
        }
        let ts = ui.txt(ui.size - 3.0, 700);
        let ss = ui.txt(ui.size - 5.0, 400);
        let tw = w - 68.0 - 120.0;
        ui.text_max(&md.title, &ts, x + 66.0, y + 24.0, th.fg, tw);
        ui.text_max(&md.artist, &ss, x + 66.0, y + 42.0, th.muted, tw);
        let cx = x + w - 118.0;
        for (i, (g, a)) in [("\u{f04ae}", "prev"), (if md.playing { "\u{f03e4}" } else { "\u{f040a}" }, "play"), ("\u{f04ad}", "next")].into_iter().enumerate() {
            let bx = cx + i as f32 * 36.0;
            let hot = ui.hit(IRect::new(bx as i32, (y + 16.0) as i32, 32, 32), Act::Media(a));
            let main = a == "play";
            ui.rect(bx, y + 16.0, 32.0, 32.0, 16.0, if main { th.fg } else if hot { th.hover } else { Rgba::new(0.0, 0.0, 0.0, 0.0) });
            ui.glyph_center(g, 15.0, bx + 16.0, y + 32.0, if main { th.bg } else { th.fg });
        }
        let pos = if md.length_us > 0 {
            let extra = if md.playing { md.at.map(|a| a.elapsed().as_micros() as i64).unwrap_or(0) } else { 0 };
            ((md.position_us + extra) as f32 / md.length_us as f32).clamp(0.0, 1.0)
        } else {
            0.0
        };
        ui.rect(x + 66.0, y + 62.0, w - 82.0, 3.0, 1.5, th.fg.alpha(0.12));
        ui.rect(x + 66.0, y + 62.0, (w - 82.0) * pos, 3.0, 1.5, th.fg);
        ui.y = y + h + 8.0;
        let _ = now;
    }

    let y = ui.y;
    let rec_label = match m.rec {
        Some(r) => {
            let secs = r.elapsed();
            format!("{:02}:{:02}{}", secs / 60, secs % 60, if r.paused { "  paused" } else { "" })
        }
        None => "Record".to_owned(),
    };
    let hot = ui.hit(IRect::new(x as i32, y as i32, half as i32, 54), Act::Page("record"));
    ui.card(x, y, half, 54.0, m.rec.is_some(), hot);
    ui.rect(x + 14.0, y + 17.0, 20.0, 20.0, 10.0, if m.rec.is_some() { th.crit } else { th.fg.alpha(0.14) });
    ui.glyph_center(if m.rec.is_some() { "\u{f04db}" } else { "\u{f044a}" }, 11.0, x + 24.0, y + 27.0, th.fg);
    let rs = ui.txt(ui.size - 3.0, 600);
    ui.text(&rec_label, &rs, x + 44.0, y + 27.0, th.fg);

    let bx = x + half + 10.0;
    let hot = ui.hit(IRect::new(bx as i32, y as i32, half as i32, 54), Act::Page("battery"));
    ui.card(bx, y, half, 54.0, false, hot);
    if let Some(b) = &m.battery {
        let g = if b.charging { "\u{f0084}" } else {
            ["\u{f008e}", "\u{f007a}", "\u{f007b}", "\u{f007c}", "\u{f007d}", "\u{f007e}", "\u{f007f}", "\u{f0080}", "\u{f0081}", "\u{f0082}", "\u{f0079}"][(b.pct / 10).clamp(0, 10) as usize]
        };
        ui.glyph(g, 18.0, bx + 14.0, y + 27.0, if b.pct <= 20 && !b.charging { th.crit } else { th.fg });
        ui.text(&format!("{}%", b.pct), &rs, bx + 40.0, y + 20.0, th.fg);
        let ss = ui.txt(ui.size - 5.0, 400);
        ui.text(if b.charging { "Charging" } else if b.plugged { "Plugged in" } else { "On battery" }, &ss, bx + 40.0, y + 37.0, th.muted);
    } else {
        ui.glyph("\u{f0425}", 16.0, bx + 14.0, y + 27.0, th.fg);
        ui.text("Power", &rs, bx + 40.0, y + 27.0, th.fg);
    }
    ui.y = y + 64.0;

    let y = ui.y;
    let segw = (w - 20.0) / 3.0;
    for (i, (id, g, label)) in [("power-saver", "\u{f032a}", "Saver"), ("balanced", "\u{f0e2e}", "Balanced"), ("performance", "\u{f04c5}", "Fast")].into_iter().enumerate() {
        let sx = x + i as f32 * (segw + 10.0);
        ui.button(sx, y, segw, 36.0, g, label, m.profile == id, Act::Profile(id));
    }
    ui.y = y + 46.0;
    wall_card(ui, m);
    let items: Vec<crate::tray::TrayItem> = m.tray.iter().filter(|t| t.icon.is_some()).cloned().collect();
    if !items.is_empty() {
        let y = ui.y + 2.0;
        let ls = ui.txt(ui.size - 5.0, 700).tracking(1.0);
        ui.text("TRAY", &ls, x + 2.0, y + 16.0, th.muted);
        let mut bx = x + 52.0;
        for it in items {
            let hot = ui.hit(IRect::new(bx as i32, y as i32, 32, 32), Act::TrayOpen(it.key.clone(), (bx + 16.0) as i32));
            ui.rect(bx, y, 32.0, 32.0, 10.0, if hot { th.hover } else { th.fg.alpha(0.06) });
            if let Some(icon) = &it.icon {
                ui.pm.draw_pixmap((bx + 8.0) as i32, (y + 8.0) as i32, icon.as_ref(), &PixmapPaint::default(), Transform::identity(), None);
            }
            bx += 40.0;
        }
        ui.y = y + 40.0;
    }
}

fn wifi(ui: &mut Ui, m: &mut Model) {
    ui.header("Wi-Fi networks", Some(("\u{f0450}", Act::WifiScan)));
    let th = ui.th;
    let (x, w) = (ui.x, ui.w);
    let enabled = m.wifi.as_ref().map(|w| w.enabled).unwrap_or(false);
    ui.toggle("Wi-Fi", "\u{f05a9}", enabled, Act::WifiToggle);
    let y = ui.y;
    let bw = (w - 20.0) / 3.0;
    ui.button(x, y, bw, 34.0, "\u{f001d}", "Airplane", !enabled && m.bt.as_ref().map(|b| !b.powered).unwrap_or(true), Act::Cmd("airplane".into()));
    ui.button(x + bw + 10.0, y, bw, 34.0, "\u{f0415}", "Hidden…", false, Act::Exec(vec!["nm-connection-editor".into(), "--create".into(), "--type=802-11-wireless".into()]));
    ui.button(x + 2.0 * (bw + 10.0), y, bw, 34.0, "\u{f0493}", "Settings…", false, Act::Exec(vec!["nm-connection-editor".into()]));
    ui.y = y + 44.0;
    if let Some((ssid, _)) = m.pw_for.clone() {
        let y = ui.y;
        let h = 44.0;
        ui.card(x, y, w, h, true, false);
        ui.glyph("\u{f033e}", 14.0, x + 12.0, y + h / 2.0, th.muted);
        let st = ui.txt(ui.size - 3.0, 500);
        if m.pw_text.is_empty() {
            ui.text_max(&format!("Password for {ssid}"), &st, x + 36.0, y + h / 2.0, th.muted, w - 90.0);
        } else {
            let dots: String = "•".repeat(m.pw_text.chars().count());
            ui.text_max(&dots, &st, x + 36.0, y + h / 2.0, th.fg, w - 90.0);
        }
        let hot = ui.hit(IRect::new((x + w - 44.0) as i32, (y + 6.0) as i32, 36, 32), Act::WifiConnectTyped);
        ui.rect(x + w - 44.0, y + 6.0, 36.0, 32.0, 10.0, if m.pw_text.is_empty() { th.fg.alpha(0.1) } else if hot { th.fg } else { th.on });
        ui.glyph_center("\u{f0054}", 13.0, x + w - 26.0, y + 22.0, th.fg_on(th.on));
        ui.y = y + h + 8.0;
    }
    if m.wifi_busy && m.nets.is_empty() {
        ui.note("Scanning…");
    }
    let nets = m.nets.clone();
    for n in nets.iter().take(14) {
        let sec = match n.security.as_str() {
            "open" => "Open",
            "eap" => "Enterprise",
            _ => "Secured",
        };
        let sub = format!("{sec} · {}%{}", n.strength, if n.known { " · saved" } else { "" });
        let start_y = ui.y;
        let right = if n.connected { "\u{f012c}" } else if n.known { "    " } else { "" };
        ui.row(wifi_glyph(true, "x", n.strength), &n.ssid, &sub, right, n.connected, Act::WifiPick(n.ssid.clone()));
        if n.known && !n.connected {
            let rh = ui.y - start_y - 2.0;
            let fx = x + w - 36.0;
            let hot = ui.hit(IRect::new(fx as i32, (start_y + rh / 2.0 - 14.0) as i32, 28, 28), Act::WifiForget(n.ssid.clone()));
            ui.glyph_center("\u{f0156}", 13.0, fx + 14.0, start_y + rh / 2.0, if hot { th.crit } else { th.muted });
        }
    }
}

fn bt(ui: &mut Ui, m: &mut Model) {
    ui.header("Bluetooth", Some(("\u{f0450}", Act::BtScan)));
    let (x, w) = (ui.x, ui.w);
    let on = m.bt.as_ref().map(|b| b.powered).unwrap_or(false);
    ui.toggle("Bluetooth", "\u{f00af}", on, Act::BtToggle);
    if on {
        let devs = m.bt_devs.clone();
        if devs.is_empty() {
            ui.note(if m.bt_scanning { "Scanning for devices…" } else { "No devices. Press refresh to scan." });
        }
        for d in devs.iter().take(12) {
            let g = match d.icon.as_str() {
                "audio-headset" | "audio-headphones" => "\u{f186f}",
                "input-mouse" => "\u{f037d}",
                "input-keyboard" => "\u{f030c}",
                "audio-speakers" | "audio-speaker" => "\u{f04c3}",
                "phone" => "\u{f011c}",
                "watch" => "\u{f0596}",
                _ => "\u{f00af}",
            };
            let sub = if d.connected { "Connected".to_owned() } else if d.paired { "Paired".to_owned() } else { "Available".to_owned() }
                + &if d.battery >= 0 { format!(" · {}%", d.battery) } else { String::new() };
            ui.row(g, &d.name, &sub, if d.connected { "\u{f012c}" } else { "" }, d.connected, Act::BtDevice(d.path.clone()));
        }
    }
    let y = ui.y + 4.0;
    let bw = (w - 20.0) / 3.0;
    ui.button(x, y, bw, 34.0, "\u{f0552}", "Send files…", false, Act::Exec(vec!["blueman-sendto".into()]));
    ui.button(x + bw + 10.0, y, bw, 34.0, "\u{f00af}", "Adapter…", false, Act::Exec(vec!["blueman-adapters".into()]));
    ui.button(x + 2.0 * (bw + 10.0), y, bw, 34.0, "\u{f0493}", "Settings…", false, Act::Exec(vec!["blueman-manager".into()]));
    ui.y = y + 44.0;
}

fn audio(ui: &mut Ui, m: &mut Model) {
    ui.header("Sound", Some(("\u{f0493}", Act::Exec(vec!["pavucontrol".into()]))));
    ui.label("Output");
    let v = m.vol.unwrap_or(crate::services::Volume { level: 0.0, muted: false });
    ui.slider(vol_glyph(v.level, v.muted), Act::MuteOut, v.level, 1.0, Slider::Volume, &if v.muted { "Muted".into() } else { format!("{}%", (v.level * 100.0).round() as i32) });
    if m.sinks.len() > 1 {
        for d in m.sinks.clone() {
            ui.row("\u{f04c3}", &d.label, "", if d.default { "\u{f012c}" } else { "" }, d.default, Act::Sink(d.name.clone()));
        }
    }
    ui.label("Input");
    let mic = m.mic.unwrap_or(crate::services::Volume { level: 0.0, muted: false });
    ui.slider(if mic.muted { "\u{f036d}" } else { "\u{f036c}" }, Act::MuteIn, mic.level, 1.0, Slider::Mic, &if mic.muted { "Muted".into() } else { format!("{}%", (mic.level * 100.0).round() as i32) });
    if m.sources.len() > 1 {
        for d in m.sources.clone() {
            ui.row("\u{f036c}", &d.label, "", if d.default { "\u{f012c}" } else { "" }, d.default, Act::Source(d.name.clone()));
        }
    }
    if !m.streams.is_empty() {
        ui.label("Applications");
        for s in m.streams.clone() {
            let th = ui.th;
            let ts = ui.txt(ui.size - 4.0, 700);
            let title = if s.media.is_empty() || s.media == "Playback" { s.app.clone() } else { format!("{}  ·  {}", s.app, s.media) };
            let cy = ui.y + 8.0;
            let (x, w) = (ui.x, ui.w);
            ui.text_max(&title, &ts, x + 36.0, cy, th.fg, w - 100.0);
            ui.y += 16.0;
            ui.slider(vol_glyph(s.level, s.muted), Act::MuteStream(s.index), s.level, 1.5, Slider::Stream(s.index), &if s.muted { "Muted".into() } else { format!("{}%", (s.level * 100.0).round() as i32) });
        }
    }
}

fn power(ui: &mut Ui, m: &mut Model) {
    ui.header("Power", None);
    let (x, w) = (ui.x, ui.w);
    let items: [(&str, &str, &'static str); 5] = [
        ("\u{f033e}", "Lock", "lock"),
        ("\u{f0904}", "Sleep", "suspend"),
        ("\u{f0343}", "Log out", "logout"),
        ("\u{f0709}", "Restart", "reboot"),
        ("\u{f0425}", "Shut down", "poweroff"),
    ];
    let bw = (w - 4.0 * 8.0) / 5.0;
    let y = ui.y;
    for (i, (g, label, id)) in items.into_iter().enumerate() {
        let bx = x + i as f32 * (bw + 8.0);
        let hot = ui.hit(IRect::new(bx as i32, y as i32, bw as i32, 84), Act::Power(id));
        let armed = m.power_arm == id;
        ui.card(bx, y, bw, 84.0, armed, hot);
        let th = ui.th;
        ui.glyph_center(g, 22.0, bx + bw / 2.0, y + 32.0, if armed { th.crit } else { th.fg });
        let st = ui.txt(ui.size - 5.0, 500);
        ui.text_center(if armed { "Again" } else { label }, &st, bx + bw / 2.0, y + 62.0, th.fg);
    }
    ui.y = y + 94.0;
    ui.note("Log out, restart and shut down ask for a second click.");
}

fn calendar(ui: &mut Ui, m: &mut Model) {
    let today = Local::now().date_naive();
    let mut y0 = today.year();
    let mut mo = today.month() as i32 + m.cal_shift;
    while mo < 1 {
        mo += 12;
        y0 -= 1;
    }
    while mo > 12 {
        mo -= 12;
        y0 += 1;
    }
    let first = NaiveDate::from_ymd_opt(y0, mo as u32, 1).unwrap_or(today);
    let title = format!("{} {}", first.format("%B"), y0);
    ui.header(&title, Some(("\u{f0142}", Act::CalShift(1))));
    let th = ui.th;
    let (x, w) = (ui.x, ui.w);
    let hot = ui.hit(IRect::new((x + w - 64.0) as i32, (ui.y - 40.0) as i32, 30, 30), Act::CalShift(-1));
    ui.glyph_center("\u{f0141}", 14.0, x + w - 49.0, ui.y - 25.0, if hot { th.on } else { th.fg });
    let cw = w / 7.0;
    let hs = ui.txt(ui.size - 5.0, 700);
    for (i, d) in ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"].iter().enumerate() {
        ui.text_center(d, &hs, x + cw * (i as f32 + 0.5), ui.y + 8.0, th.muted);
    }
    ui.y += 24.0;
    let lead = first.weekday().num_days_from_monday() as i32;
    let days = {
        let next = if mo == 12 { NaiveDate::from_ymd_opt(y0 + 1, 1, 1) } else { NaiveDate::from_ymd_opt(y0, mo as u32 + 1, 1) };
        next.map(|n| (n - first).num_days() as i32).unwrap_or(30)
    };
    let ds = ui.txt(ui.size - 3.0, 500);
    let rows = (lead + days + 6) / 7;
    for r in 0..rows {
        for c in 0..7 {
            let d = r * 7 + c - lead + 1;
            if d < 1 || d > days {
                continue;
            }
            let cx = x + cw * (c as f32 + 0.5);
            let cy = ui.y + r as f32 * 36.0 + 16.0;
            let is_today = m.cal_shift == 0 && d == today.day() as i32;
            if is_today {
                ui.rect(cx - 16.0, cy - 16.0, 32.0, 32.0, 16.0, th.on);
            }
            ui.text_center(&d.to_string(), &ds, cx, cy, if is_today { th.fg_on(th.on) } else if c >= 5 { th.muted } else { th.fg });
        }
    }
    ui.y += rows as f32 * 36.0 + 6.0;
    if m.cal_shift != 0 {
        let y = ui.y;
        ui.button(x, y, w, 32.0, "\u{f00f0}", "Today", false, Act::CalShift(0));
        ui.y = y + 40.0;
    }
}

fn notifications(ui: &mut Ui, m: &mut Model) {
    ui.header("Notifications", Some(("\u{f0b89}", Act::NotifClear)));
    ui.toggle("Do not disturb", "\u{f009b}", m.dnd, Act::Dnd);
    if m.notifs.is_empty() {
        ui.note("Nothing new.");
        return;
    }
    let th = ui.th;
    for n in m.notifs.clone().iter().rev().take(10) {
        let (x, w) = (ui.x, ui.w);
        let y = ui.y;
        let body_lines = if n.body.is_empty() { 0.0 } else { 1.0 };
        let h = 46.0 + body_lines * 18.0 + if n.actions.iter().any(|(k, _)| k != "default") { 4.0 } else { 0.0 };
        ui.card(x, y, w, h, n.critical, false);
        let as_ = ui.txt(ui.size - 6.0, 700).tracking(0.6);
        ui.text_max(&n.app.to_uppercase(), &as_, x + 12.0, y + 14.0, th.muted, w - 110.0);
        let ts = ui.txt(ui.size - 6.0, 400);
        ui.text_right(&n.time, &ts, x + w - 40.0, y + 14.0, th.muted);
        let hot = ui.hit(IRect::new((x + w - 34.0) as i32, (y + 2.0) as i32, 28, 24), Act::NotifDismiss(n.id));
        ui.glyph_center("\u{f0156}", 12.0, x + w - 20.0, y + 14.0, if hot { th.crit } else { th.muted });
        let ss = ui.txt(ui.size - 3.0, 700);
        ui.text_max(&n.summary, &ss, x + 12.0, y + 33.0, th.fg, w - 24.0);
        if !n.body.is_empty() {
            let bs = ui.txt(ui.size - 4.0, 400);
            ui.text_max(&n.body.replace('\n', " "), &bs, x + 12.0, y + 52.0, th.muted, w - 24.0);
        }
        let acts: Vec<(String, String)> = n.actions.iter().filter(|(k, _)| k != "default").cloned().collect();
        if !acts.is_empty() {
            let by = y + h - 2.0;
            let bw = ((w - 24.0) - 8.0 * (acts.len() as f32 - 1.0)) / acts.len() as f32;
            for (i, (k, label)) in acts.iter().enumerate() {
                ui.button(x + 12.0 + i as f32 * (bw + 8.0), by, bw, 30.0, "", label, false, Act::NotifAction(n.id, k.clone()));
            }
            ui.y = by + 30.0 + 10.0;
        } else {
            ui.y = y + h + 8.0;
        }
    }
}

fn clipboard(ui: &mut Ui, m: &mut Model) {
    ui.header("Clipboard", Some(("\u{f0b89}", Act::ClipClear)));
    let th = ui.th;
    let (x, w) = (ui.x, ui.w);
    let y = ui.y;
    ui.card(x, y, w, 38.0, !m.clip_query.is_empty(), false);
    ui.glyph("\u{f0349}", 14.0, x + 12.0, y + 19.0, th.muted);
    let st = ui.txt(ui.size - 3.0, 500);
    if m.clip_query.is_empty() {
        ui.text("Type to search", &st, x + 38.0, y + 19.0, th.muted);
    } else {
        ui.text_max(&m.clip_query, &st, x + 38.0, y + 19.0, th.fg, w - 50.0);
    }
    ui.y = y + 46.0;
    let q = m.clip_query.to_lowercase();
    let items: Vec<(String, String)> = m.clip.iter().filter(|(_, t)| q.is_empty() || t.to_lowercase().contains(&q)).take(12).cloned().collect();
    if items.is_empty() {
        ui.note(if m.clip.is_empty() { "Clipboard history is empty." } else { "Nothing found." });
        return;
    }
    for (id, text) in items {
        let start = ui.y;
        let image = text.starts_with("[[ binary");
        if image {
            let path = text.split("]] ").nth(1).unwrap_or("").to_owned();
            let h = 60.0;
            let hot = ui.hit(IRect::new(x as i32, start as i32, w as i32, h as i32), Act::ClipCopy(id.clone()));
            if hot {
                ui.rect(x, start, w, h, 12.0, th.hover);
            }
            if let Some(t) = m.clip_thumbs.get(&path) {
                let ty = start + (h - t.height().min(52) as f32) / 2.0;
                ui.pm.draw_pixmap((x + 10.0) as i32, ty as i32, t.as_ref(), &PixmapPaint::default(), Transform::identity(), None);
            } else {
                ui.glyph("\u{f02e9}", 18.0, x + 14.0, start + h / 2.0, th.fg);
            }
            let dims = text.split_whitespace().find(|p| p.contains('x') && p.chars().next().is_some_and(|c| c.is_ascii_digit())).unwrap_or("").to_owned();
            let ts = ui.txt(ui.size - 3.0, 600);
            ui.text("Image", &ts, x + 86.0, start + h / 2.0 - 8.0, th.fg);
            let ss = ui.txt(ui.size - 5.0, 400);
            ui.text(&dims, &ss, x + 86.0, start + h / 2.0 + 9.0, th.muted);
            ui.y = start + h + 2.0;
        } else {
            let clean = text.split_whitespace().collect::<Vec<_>>().join(" ");
            ui.row("\u{f0192}", &clean, "", "    ", false, Act::ClipCopy(id.clone()));
        }
        let rh = ui.y - start - 2.0;
        let hot = ui.hit(IRect::new((x + w - 36.0) as i32, (start + rh / 2.0 - 14.0) as i32, 28, 28), Act::ClipDelete(id.clone()));
        ui.glyph_center("\u{f0156}", 12.0, x + w - 22.0, start + rh / 2.0, if hot { th.crit } else { th.muted });
    }
}

fn record(ui: &mut Ui, m: &mut Model) {
    ui.header("Screen recording", Some(("\u{f024b}", Act::Exec(vec!["xdg-open".into(), format!("{}/Videos", std::env::var("HOME").unwrap_or_default())]))));
    let th = ui.th;
    let (x, w) = (ui.x, ui.w);
    let y = ui.y;
    let (label, sub) = match m.rec {
        Some(r) => {
            let s = r.elapsed();
            (format!("{:02}:{:02}", s / 60, s % 60), if r.paused { "Paused" } else { "Recording" })
        }
        None => ("00:00".to_owned(), "Ready to record"),
    };
    ui.rect(x + 2.0, y + 8.0, 14.0, 14.0, 7.0, if m.rec.is_some_and(|r| !r.paused) { th.crit } else { th.fg.alpha(0.2) });
    dot::draw(ui.pm, &label, 26.0, x + 26.0, y + 2.0, th.fg);
    let ss = ui.txt(ui.size - 3.0, 500);
    ui.text(sub, &ss, x + 26.0 + dot::width(&label, 26.0) + 16.0, y + 14.0, th.muted);
    ui.y = y + 44.0;
    if m.rec.is_none() {
        ui.toggle("System audio", "\u{f057e}", m.rec_sys, Act::RecSys);
        ui.toggle("Microphone", "\u{f036c}", m.rec_mic, Act::RecMic);
        if m.rec_mic && m.sources.len() > 1 {
            for d in m.sources.clone() {
                let on = if m.rec_mic_dev.is_empty() { d.default } else { m.rec_mic_dev == d.name };
                ui.row("\u{f036c}", &d.label, "", if on { "\u{f012c}" } else { "" }, on, Act::RecMicDev(d.name.clone()));
            }
        }
        let y = ui.y + 4.0;
        ui.button(x, y, w, 40.0, "\u{f044a}", "Start recording", true, Act::Record);
        ui.y = y + 50.0;
        ui.note("Saves to ~/Videos · whole screen at 60 fps");
    } else {
        let y = ui.y + 4.0;
        let bw = (w - 10.0) / 2.0;
        let paused = m.rec.is_some_and(|r| r.paused);
        ui.button(x, y, bw, 40.0, if paused { "\u{f040a}" } else { "\u{f03e4}" }, if paused { "Resume" } else { "Pause" }, false, Act::RecPause);
        ui.button(x + bw + 10.0, y, bw, 40.0, "\u{f04db}", "Finish", true, Act::Record);
        ui.y = y + 50.0;
    }
}

fn settings(ui: &mut Ui, m: &mut Model) {
    ui.header("Settings", None);
    let (x, w) = (ui.x, ui.w);
    ui.label("World");
    let y = ui.y;
    let bw = (w - 30.0) / 4.0;
    for (i, (id, name)) in [("meridian", "Meridian"), ("katha", "Katha"), ("sakuga", "Sakuga"), ("toon", "Toon")].into_iter().enumerate() {
        ui.button(x + i as f32 * (bw + 10.0), y, bw, 36.0, "", name, m.world == id, Act::Cmd(format!("world {id}")));
    }
    ui.y = y + 46.0;
    ui.label("Wallpaper");
    let y = ui.y;
    let bw2 = (w - 20.0) / 3.0;
    ui.button(x, y, bw2, 36.0, "\u{f02e9}", "Wallpapers…", false, Act::Cmd("worldwalls".into()));
    ui.button(x + bw2 + 10.0, y, bw2, 36.0, "\u{f040a}", "Live on/off", false, Act::Exec(vec!["rice".into(), "live".into(), "toggle".into()]));
    ui.button(x + 2.0 * (bw2 + 10.0), y, bw2, 36.0, "\u{f03d8}", "Night / paper", false, Act::Exec(vec!["rice".into(), "mode".into(), "next".into()]));
    ui.y = y + 46.0;
    ui.label("Apps");
    let y = ui.y;
    let keys = format!("{}/dotfiles/i3/.config/i3/config", std::env::var("HOME").unwrap_or_default());
    for (i, (g, l, argv)) in [
        ("\u{f0379}", "Displays", vec!["arandr".to_owned()]),
        ("\u{f057e}", "Sound", vec!["pavucontrol".to_owned()]),
        ("\u{f05a9}", "Network", vec!["nm-connection-editor".to_owned()]),
        ("\u{f030c}", "Keys", vec!["ghostty".to_owned(), "-e".to_owned(), "nvim".to_owned(), keys.clone()]),
    ].into_iter().enumerate() {
        ui.button(x + i as f32 * (bw + 10.0), y, bw, 36.0, g, l, false, Act::Exec(argv));
    }
    ui.y = y + 46.0;
    ui.label("Terminal");
    let y = ui.y;
    let st = ui.txt(ui.size - 4.0, 500);
    let th = ui.th;
    ui.text("Background opacity", &st, x + 4.0, y + 18.0, th.muted);
    let ow = (w - 150.0 - 20.0) / 3.0;
    for (i, n) in [80u8, 90, 100].into_iter().enumerate() {
        ui.button(x + 150.0 + i as f32 * (ow + 10.0), y, ow, 34.0, "", &format!("{n}%"), m.cfg.term_opacity == n, Act::TermOpacity(n));
    }
    ui.y = y + 44.0;
    ui.label("Clock");
    ui.toggle("24-hour clock", "\u{f0954}", m.cfg.clock24, Act::Clock24);
    ui.toggle("Show seconds", "\u{f051f}", m.cfg.seconds, Act::Seconds);
    ui.label("Notifications");
    ui.toggle("Do not disturb", "\u{f009b}", m.dnd, Act::Dnd);
    let y = ui.y;
    let st = ui.txt(ui.size - 4.0, 500);
    let th = ui.th;
    ui.text("Show toasts for", &st, x + 4.0, y + 18.0, th.muted);
    let bw = (w - 150.0 - 20.0) / 3.0;
    for (i, n) in [3u64, 5, 8].into_iter().enumerate() {
        ui.button(x + 150.0 + i as f32 * (bw + 10.0), y, bw, 34.0, "", &format!("{n} s"), m.cfg.toast_secs == n, Act::ToastSecs(n));
    }
    ui.y = y + 44.0;
    ui.label("System");
    ui.toggle("Sound effects", "\u{f057e}", m.cfg.sounds, Act::Sounds);
    ui.toggle("Coffee mode", "\u{f0176}", m.coffee, Act::Coffee);
}

fn dur(secs: i64) -> String {
    let m = (secs / 60).max(0);
    if m >= 60 { format!("{}h {:02}m", m / 60, m % 60) } else { format!("{m} min") }
}

fn battery(ui: &mut Ui, m: &mut Model) {
    ui.header("Battery", Some(("\u{f0425}", Act::Page("power"))));
    let th = ui.th;
    let (x, w) = (ui.x, ui.w);
    let Some(b) = m.battery.clone() else {
        ui.note("No battery found.");
        return;
    };
    let d = m.batdet.clone().unwrap_or_default();
    let y = ui.y;
    let big = 30.0;
    let pct = format!("{}%", b.pct);
    dot::draw(ui.pm, &pct, big, x + 4.0, y + 2.0, th.fg);
    let status = if b.charging {
        if d.to_full > 0 { format!("Charging · full in {}", dur(d.to_full)) } else { "Charging".into() }
    } else if b.plugged {
        "Plugged in".into()
    } else if d.to_empty > 0 {
        format!("On battery · {} left", dur(d.to_empty))
    } else {
        "On battery".into()
    };
    let ss = ui.txt(ui.size - 3.0, 500);
    ui.text(&status, &ss, x + dot::width(&pct, big) + 18.0, y + 16.0, th.fg);
    ui.y = y + 48.0;
    let y = ui.y;
    let cw = (w - 20.0) / 3.0;
    let health = if d.design > 0.0 { (d.capacity / d.design * 100.0).round() as i32 } else { -1 };
    let stats = [
        ("Capacity", if d.capacity > 0.0 { format!("{:.1} Wh", d.capacity) } else { "—".into() }),
        ("Health", if health >= 0 { format!("{health}%") } else { "—".into() }),
        (if b.charging { "Charge rate" } else { "Draw" }, if d.rate > 0.05 { format!("{:.1} W", d.rate) } else { "—".into() }),
    ];
    for (i, (label, val)) in stats.iter().enumerate() {
        let cx = x + i as f32 * (cw + 10.0);
        ui.card(cx, y, cw, 58.0, false, false);
        let ls = ui.txt(ui.size - 6.0, 600).tracking(0.6);
        ui.text(&label.to_uppercase(), &ls, cx + 12.0, y + 17.0, th.muted);
        let vs = ui.txt(ui.size - 1.0, 700);
        ui.text(val, &vs, cx + 12.0, y + 39.0, if *label == "Health" && (0..50).contains(&health) { th.crit } else { th.fg });
    }
    ui.y = y + 68.0;
    ui.label("Last 24 hours");
    let y = ui.y;
    let gh = 110.0;
    ui.card(x, y, w, gh, false, false);
    let (gx, gy, gw, gh2) = (x + 12.0, y + 12.0, w - 24.0, gh - 24.0);
    for frac in [0.0f32, 0.5, 1.0] {
        ui.rect(gx, gy + gh2 * (1.0 - frac), gw, 1.0, 0.0, th.fg.alpha(0.07));
    }
    if d.history.len() >= 2 {
        let t1 = d.history.last().map(|h| h.0).unwrap_or(0) as f32;
        let t0 = t1 - 86400.0;
        let mut pb = tiny_skia::PathBuilder::new();
        let mut first = true;
        for (t, v) in d.history.iter().filter(|h| h.0 as f32 >= t0) {
            let px = gx + (*t as f32 - t0) / 86400.0 * gw;
            let py = gy + gh2 * (1.0 - v / 100.0);
            if first {
                pb.move_to(px, py);
                first = false;
            } else {
                pb.line_to(px, py);
            }
        }
        if let Some(path) = pb.finish() {
            let st = tiny_skia::Stroke { width: 2.0, line_join: tiny_skia::LineJoin::Round, ..tiny_skia::Stroke::default() };
            ui.pm.stroke_path(&path, &crate::canvas::paint(th.on), &st, tiny_skia::Transform::identity(), None);
        }
    } else {
        let ns = ui.txt(ui.size - 4.0, 400);
        ui.text("No history yet.", &ns, gx, gy + gh2 / 2.0, th.muted);
    }
    ui.y = y + gh + 10.0;
    let y = ui.y;
    let segw = (w - 20.0) / 3.0;
    for (i, (id, g, label)) in [("power-saver", "\u{f032a}", "Saver"), ("balanced", "\u{f0e2e}", "Balanced"), ("performance", "\u{f04c5}", "Fast")].into_iter().enumerate() {
        ui.button(x + i as f32 * (segw + 10.0), y, segw, 36.0, g, label, m.profile == id, Act::Profile(id));
    }
    ui.y = y + 46.0;
    if d.cycles > 0 {
        ui.note(&format!("{} charge cycles.", d.cycles));
    }
}

fn wall_card(ui: &mut Ui, m: &mut Model) {
    let th = ui.th;
    let (x, w) = (ui.x, ui.w);
    let y = ui.y;
    let h = 76.0;
    let hot = ui.hit(IRect::new(x as i32, y as i32, 140, h as i32), Act::Cmd("worldwalls".into()));
    ui.card(x, y, w, h, false, false);
    let (tx, ty, tw, tht) = (x + 10.0, y + 10.0, 112.0, 56.0);
    if let Some(t) = &m.wall_thumb {
        let k = tw / t.width() as f32;
        let paint = PixmapPaint { quality: tiny_skia::FilterQuality::Bilinear, ..PixmapPaint::default() };
        let oy = ty + (tht - t.height() as f32 * k) / 2.0;
        ui.pm.draw_pixmap(0, 0, t.as_ref(), &paint, Transform::from_row(k, 0.0, 0.0, k, tx, oy), None);
    } else {
        ui.rect(tx, ty, tw, tht, 8.0, th.fg.alpha(0.08));
    }
    if hot {
        ui.rect(tx, ty, tw, tht, 8.0, th.fg.alpha(0.12));
    }
    let moving = m.scene != "picture" && (m.live == "on" || m.live == "always");
    let world = { let mut c = m.world.chars(); c.next().map(|f| f.to_uppercase().collect::<String>() + c.as_str()).unwrap_or_default() };
    let ls = ui.txt(ui.size - 6.0, 700).tracking(0.8);
    ui.text(&world.to_uppercase(), &ls, x + 134.0, y + 22.0, th.muted);
    let ns = ui.txt(ui.size - 3.0, 700);
    ui.text_max(&m.wall_name, &ns, x + 134.0, y + 41.0, th.fg, w - 134.0 - 150.0);
    let ss = ui.txt(ui.size - 5.0, 400);
    let sub = if m.scene == "picture" { "Still picture" } else if moving { "Live" } else { "Live paused" };
    ui.text(sub, &ss, x + 134.0, y + 58.0, if moving { th.on } else { th.muted });
    let bw = 40.0;
    let bx = x + w - 3.0 * (bw + 8.0) - 2.0;
    let by = y + (h - bw) / 2.0;
    let can_live = m.wall_video || m.scene != "picture";
    let paper = m.mood == "paper";
    let btns: [(&str, bool, Act, bool); 3] = [
        (if moving { "\u{f03e4}" } else { "\u{f040a}" }, moving, Act::LiveToggle, can_live),
        (if paper { "\u{f00ba}" } else { "\u{f0594}" }, paper, Act::MoodToggle, true),
        ("\u{f02e9}", false, Act::Cmd("worldwalls".into()), true),
    ];
    for (i, (g, on, act, enabled)) in btns.into_iter().enumerate() {
        let cx = bx + i as f32 * (bw + 8.0);
        let hot = enabled && ui.hit(IRect::new(cx as i32, by as i32, bw as i32, bw as i32), act);
        let fill = if on { th.on } else if hot { th.hover } else { th.fg.alpha(0.07) };
        ui.rect(cx, by, bw, bw, 12.0, fill);
        ui.glyph_center(g, 16.0, cx + bw / 2.0, by + bw / 2.0, if on { th.fg_on(th.on) } else if enabled { th.fg } else { th.muted });
    }
    ui.y = y + h + 8.0;
}
