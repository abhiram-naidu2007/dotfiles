use std::os::fd::{AsFd, BorrowedFd, OwnedFd};
use std::sync::Arc;
use std::sync::mpsc::{Receiver, Sender, channel};
use std::time::Duration;

use rustix::event::{EventfdFlags, eventfd};
use zbus::blocking::{Connection, Proxy};

#[derive(Clone, Debug, PartialEq)]
pub struct Battery {
    pub present: bool,
    pub pct: i32,
    pub charging: bool,
    pub plugged: bool,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Wifi {
    pub enabled: bool,
    pub ssid: String,
    pub strength: i32,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Bt {
    pub powered: bool,
    pub connected: String,
    pub battery: i32,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Volume {
    pub level: f32,
    pub muted: bool,
}

#[derive(Clone, Debug)]
pub enum Msg {
    Battery(Battery),
    Wifi(Wifi),
    Bt(Bt),
    Volume(Volume),
    Audio(crate::audio::AudioState),
    Tray(Vec<crate::tray::TrayItem>),
    TrayMenu(String, String, Vec<crate::tray::MenuItem>),
    BtDevs(Vec<crate::model::BtDev>),
    Nets(Vec<crate::model::Net>),
    WifiDone(bool, String),
    Media(Option<crate::model::Media>),
    Profile(String),
    Notify(crate::model::Notif, i32),
    NotifClose(u32),
    Ipc(String),
    Rec(Option<crate::model::Rec>),
    Clip(Vec<(String, String)>),
    BatDetails(crate::model::BatDetails),
    Wall(String, bool, String),
    Resumed,
}

#[derive(Clone)]
pub struct Waker {
    fd: Arc<OwnedFd>,
    tx: Sender<Msg>,
}

impl Waker {
    pub fn send(&self, m: Msg) {
        if self.tx.send(m).is_ok() {
            let _ = rustix::io::write(&*self.fd, &1u64.to_ne_bytes());
        }
    }
}

pub struct Hub {
    fd: Arc<OwnedFd>,
    rx: Receiver<Msg>,
    tx: Sender<Msg>,
}

impl Hub {
    pub fn new() -> std::io::Result<Self> {
        let fd = Arc::new(eventfd(0, EventfdFlags::CLOEXEC | EventfdFlags::NONBLOCK)?);
        let (tx, rx) = channel();
        Ok(Self { fd, rx, tx })
    }

    pub fn waker(&self) -> Waker {
        Waker { fd: self.fd.clone(), tx: self.tx.clone() }
    }

    pub fn fd(&self) -> BorrowedFd<'_> {
        self.fd.as_fd()
    }

    pub fn drain(&self) -> Vec<Msg> {
        let mut b = [0u8; 8];
        let _ = rustix::io::read(&*self.fd, &mut b);
        self.rx.try_iter().collect()
    }
}

fn spawn_retrying(name: &str, w: Waker, f: fn(&Waker) -> zbus::Result<()>) {
    let _ = std::thread::Builder::new().name(name.into()).stack_size(256 * 1024).spawn(move || {
        loop {
            let _ = f(&w);
            std::thread::sleep(Duration::from_secs(2));
        }
    });
}

fn sleep_watch(w: &Waker) -> zbus::Result<()> {
    let conn = Connection::system()?;
    let login = plain(&conn, "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager")?;
    for m in login.receive_signal("PrepareForSleep")? {
        if let Ok(false) = m.body().deserialize::<bool>() {
            w.send(Msg::Resumed);
        }
    }
    Ok(())
}

fn battery_read(p: &Proxy) -> Battery {
    let pct: f64 = p.get_property("Percentage").unwrap_or(0.0);
    let state: u32 = p.get_property("State").unwrap_or(0);
    let present: bool = p.get_property("IsPresent").unwrap_or(false);
    let kind: u32 = p.get_property("Type").unwrap_or(0);
    Battery { present: present && kind == 2, pct: pct.round() as i32, charging: state == 1, plugged: matches!(state, 1 | 4 | 5) }
}

fn upower(w: &Waker) -> zbus::Result<()> {
    let conn = Connection::system()?;
    let path = "/org/freedesktop/UPower/devices/DisplayDevice";
    let dev: Proxy = zbus::blocking::proxy::Builder::new(&conn)
        .destination("org.freedesktop.UPower")?
        .path(path)?
        .interface("org.freedesktop.UPower.Device")?
        .cache_properties(zbus::proxy::CacheProperties::No)
        .build()?;
    let props = Proxy::new(&conn, "org.freedesktop.UPower", path, "org.freedesktop.DBus.Properties")?;
    let signals = props.receive_signal("PropertiesChanged")?;
    let mut last = battery_read(&dev);
    w.send(Msg::Battery(last.clone()));
    for _ in signals {
        let b = battery_read(&dev);
        if b != last {
            last = b.clone();
            w.send(Msg::Battery(b));
        }
    }
    Ok(())
}

fn plain(conn: &Connection, dest: &str, path: &str, iface: &str) -> zbus::Result<Proxy<'static>> {
    zbus::blocking::proxy::Builder::new(conn)
        .destination(dest.to_owned())?
        .path(path.to_owned())?
        .interface(iface.to_owned())?
        .cache_properties(zbus::proxy::CacheProperties::No)
        .build()
}

fn changes(conn: &Connection, sender: &str) -> zbus::Result<zbus::blocking::MessageIterator> {
    let rule = zbus::MatchRule::builder()
        .msg_type(zbus::message::Type::Signal)
        .sender(sender.to_owned())?
        .build();
    zbus::blocking::MessageIterator::for_match_rule(rule, conn, Some(64))
}

fn wifi_read(conn: &Connection) -> zbus::Result<Wifi> {
    let nm = plain(conn, "org.freedesktop.NetworkManager", "/org/freedesktop/NetworkManager", "org.freedesktop.NetworkManager")?;
    let enabled: bool = nm.get_property("WirelessEnabled").unwrap_or(false);
    let devices: Vec<zbus::zvariant::OwnedObjectPath> = nm.call("GetDevices", &()).unwrap_or_default();
    for d in devices {
        let dev = plain(conn, "org.freedesktop.NetworkManager", d.as_str(), "org.freedesktop.NetworkManager.Device")?;
        if dev.get_property::<u32>("DeviceType").unwrap_or(0) != 2 {
            continue;
        }
        let wl = plain(conn, "org.freedesktop.NetworkManager", d.as_str(), "org.freedesktop.NetworkManager.Device.Wireless")?;
        let ap: zbus::zvariant::OwnedObjectPath = wl.get_property("ActiveAccessPoint")?;
        if ap.as_str() == "/" {
            return Ok(Wifi { enabled, ssid: String::new(), strength: 0 });
        }
        let app = plain(conn, "org.freedesktop.NetworkManager", ap.as_str(), "org.freedesktop.NetworkManager.AccessPoint")?;
        let ssid: Vec<u8> = app.get_property("Ssid").unwrap_or_default();
        let strength: u8 = app.get_property("Strength").unwrap_or(0);
        return Ok(Wifi { enabled, ssid: String::from_utf8_lossy(&ssid).into_owned(), strength: strength as i32 });
    }
    Ok(Wifi { enabled, ssid: String::new(), strength: 0 })
}

fn wifi(w: &Waker) -> zbus::Result<()> {
    let conn = Connection::system()?;
    let events = changes(&conn, "org.freedesktop.NetworkManager")?;
    let mut last = wifi_read(&conn)?;
    w.send(Msg::Wifi(last.clone()));
    for _ in events {
        let now = wifi_read(&conn)?;
        if now != last {
            last = now.clone();
            w.send(Msg::Wifi(now));
        }
    }
    Ok(())
}

type Managed = std::collections::HashMap<
    zbus::zvariant::OwnedObjectPath,
    std::collections::HashMap<String, std::collections::HashMap<String, zbus::zvariant::OwnedValue>>,
>;

fn ov_str(v: Option<&zbus::zvariant::OwnedValue>) -> Option<String> {
    v.and_then(|v| v.try_clone().ok()).and_then(|v| String::try_from(v).ok())
}

fn bt_read(conn: &Connection) -> zbus::Result<(Bt, Vec<crate::model::BtDev>)> {
    let om = plain(conn, "org.bluez", "/", "org.freedesktop.DBus.ObjectManager")?;
    let objs: Managed = om.call("GetManagedObjects", &())?;
    let mut out = Bt { powered: false, connected: String::new(), battery: -1 };
    let mut devs = Vec::new();
    for (path, ifaces) in objs.iter() {
        if let Some(d) = ifaces.get("org.bluez.Device1") {
            let b = |k: &str| d.get(k).and_then(|v| bool::try_from(v).ok()).unwrap_or(false);
            let name = ov_str(d.get("Alias")).or_else(|| ov_str(d.get("Name"))).unwrap_or_default();
            devs.push(crate::model::BtDev {
                path: path.to_string(),
                name,
                icon: ov_str(d.get("Icon")).unwrap_or_default(),
                connected: b("Connected"),
                paired: b("Paired") || b("Bonded"),
                battery: ifaces.get("org.bluez.Battery1").and_then(|x| x.get("Percentage")).and_then(|v| u8::try_from(v).ok()).map(|v| v as i32).unwrap_or(-1),
            });
        }
    }
    let mac = |s: &str| s.len() == 17 && s.chars().filter(|c| *c == '-' || *c == ':').count() == 5;
    let mut seen = std::collections::HashSet::new();
    devs.retain(|d| {
        let known = d.connected || d.paired;
        if !known && (d.name.is_empty() || mac(&d.name)) {
            return false;
        }
        known || seen.insert(d.name.clone())
    });
    devs.sort_by_key(|a| (!a.connected, !a.paired, a.name.to_lowercase()));
    for ifaces in objs.values() {
        if let Some(a) = ifaces.get("org.bluez.Adapter1")
            && let Some(v) = a.get("Powered").and_then(|v| bool::try_from(v).ok()) {
                out.powered |= v;
            }
        if let Some(d) = ifaces.get("org.bluez.Device1") {
            let connected = d.get("Connected").and_then(|v| bool::try_from(v).ok()).unwrap_or(false);
            if connected && out.connected.is_empty() {
                let name = d.get("Alias").or_else(|| d.get("Name")).and_then(|v| String::try_from(v.try_clone().ok()?).ok());
                out.connected = name.unwrap_or_else(|| "Device".into());
                out.battery = ifaces
                    .get("org.bluez.Battery1")
                    .and_then(|b| b.get("Percentage"))
                    .and_then(|v| u8::try_from(v).ok())
                    .map(|v| v as i32)
                    .unwrap_or(-1);
            }
        }
    }
    Ok((out, devs))
}

fn bluetooth(w: &Waker) -> zbus::Result<()> {
    let conn = Connection::system()?;
    let events = changes(&conn, "org.bluez")?;
    let (mut last, mut ldevs) = bt_read(&conn).unwrap_or((Bt { powered: false, connected: String::new(), battery: -1 }, Vec::new()));
    w.send(Msg::Bt(last.clone()));
    w.send(Msg::BtDevs(ldevs.clone()));
    for _ in events {
        let (now, devs) = bt_read(&conn)?;
        if now != last {
            last = now.clone();
            w.send(Msg::Bt(now));
        }
        if devs != ldevs {
            ldevs = devs.clone();
            w.send(Msg::BtDevs(devs));
        }
    }
    Ok(())
}

pub fn bt_action(what: &'static str, path: Option<String>) {
    let _ = std::thread::Builder::new().stack_size(256 * 1024).spawn(move || -> zbus::Result<()> {
        let conn = Connection::system()?;
        let om = plain(&conn, "org.bluez", "/", "org.freedesktop.DBus.ObjectManager")?;
        let objs: Managed = om.call("GetManagedObjects", &())?;
        let adapter = objs.iter().find(|(_, i)| i.contains_key("org.bluez.Adapter1")).map(|(p, _)| p.to_string());
        match (what, path) {
            ("power", _) => {
                let a = adapter.ok_or_else(|| zbus::Error::Failure("no adapter".into()))?;
                let p = plain(&conn, "org.bluez", &a, "org.bluez.Adapter1")?;
                let on: bool = p.get_property("Powered").unwrap_or(false);
                if !on {
                    let _ = std::process::Command::new("rfkill").args(["unblock", "bluetooth"]).status();
                    std::thread::sleep(Duration::from_millis(300));
                }
                p.set_property("Powered", !on)?;
            }
            ("scan", _) => {
                let a = adapter.ok_or_else(|| zbus::Error::Failure("no adapter".into()))?;
                let p = plain(&conn, "org.bluez", &a, "org.bluez.Adapter1")?;
                let _: zbus::Result<()> = p.call("StartDiscovery", &());
                std::thread::sleep(Duration::from_secs(12));
                let _: zbus::Result<()> = p.call("StopDiscovery", &());
            }
            ("toggle", Some(dev)) => {
                let d = plain(&conn, "org.bluez", &dev, "org.bluez.Device1")?;
                let connected: bool = d.get_property("Connected").unwrap_or(false);
                let paired: bool = d.get_property("Paired").unwrap_or(false);
                if connected {
                    let _: zbus::Result<()> = d.call("Disconnect", &());
                } else {
                    let _ = d.set_property("Trusted", true);
                    if !paired {
                        let _: zbus::Result<()> = d.call("Pair", &());
                    }
                    let _: zbus::Result<()> = d.call("Connect", &());
                }
            }
            _ => {}
        }
        Ok(())
    });
}

fn profiles(w: &Waker) -> zbus::Result<()> {
    let conn = Connection::system()?;
    let p = plain(&conn, "net.hadess.PowerProfiles", "/net/hadess/PowerProfiles", "net.hadess.PowerProfiles")?;
    let events = changes(&conn, "net.hadess.PowerProfiles")?;
    let mut last: String = p.get_property("ActiveProfile").unwrap_or_default();
    w.send(Msg::Profile(last.clone()));
    for _ in events {
        let now: String = p.get_property("ActiveProfile").unwrap_or_default();
        if now != last {
            last = now.clone();
            w.send(Msg::Profile(now));
        }
    }
    Ok(())
}

pub fn set_profile(name: &'static str) {
    let _ = std::thread::Builder::new().stack_size(256 * 1024).spawn(move || -> zbus::Result<()> {
        let conn = Connection::system()?;
        let p = plain(&conn, "net.hadess.PowerProfiles", "/net/hadess/PowerProfiles", "net.hadess.PowerProfiles")?;
        p.set_property("ActiveProfile", name)?;
        Ok(())
    });
}

pub fn set_brightness(pct: f32) {
    let _ = std::thread::Builder::new().stack_size(256 * 1024).spawn(move || -> zbus::Result<()> {
        let Some((dev, max)) = backlight() else { return Ok(()) };
        let v = ((pct.clamp(0.01, 1.0)) * max as f32).round() as u32;
        let conn = Connection::system()?;
        let p = plain(&conn, "org.freedesktop.login1", "/org/freedesktop/login1/session/auto", "org.freedesktop.login1.Session")?;
        let _: zbus::Result<()> = p.call("SetBrightness", &("backlight", dev.as_str(), v));
        Ok(())
    });
}

pub fn backlight() -> Option<(String, u32)> {
    let d = std::fs::read_dir("/sys/class/backlight").ok()?.flatten().next()?;
    let max = std::fs::read_to_string(d.path().join("max_brightness")).ok()?.trim().parse().ok()?;
    Some((d.file_name().to_string_lossy().into_owned(), max))
}

pub fn brightness() -> f32 {
    let Some((dev, max)) = backlight() else { return 0.0 };
    std::fs::read_to_string(format!("/sys/class/backlight/{dev}/brightness"))
        .ok()
        .and_then(|s| s.trim().parse::<f32>().ok())
        .map(|v| v / max.max(1) as f32)
        .unwrap_or(0.0)
}

pub fn start(hub: &Hub) {
    spawn_retrying("loka-profiles", hub.waker(), profiles);
    crate::mpris::start(hub.waker());
    crate::notify::start(hub.waker());
    spawn_retrying("loka-upower", hub.waker(), upower);
    spawn_retrying("loka-sleep", hub.waker(), sleep_watch);
    spawn_retrying("loka-wifi", hub.waker(), wifi);
    spawn_retrying("loka-bt", hub.waker(), bluetooth);
    crate::audio::start(hub.waker());
    crate::tray::start(hub.waker());
}

pub fn battery_details(w: Waker) {
    let _ = std::thread::Builder::new().stack_size(256 * 1024).spawn(move || -> zbus::Result<()> {
        let conn = Connection::system()?;
        let up = plain(&conn, "org.freedesktop.UPower", "/org/freedesktop/UPower", "org.freedesktop.UPower")?;
        let devs: Vec<zbus::zvariant::OwnedObjectPath> = up.call("EnumerateDevices", &())?;
        let Some(path) = devs.iter().find(|p| p.as_str().contains("battery_BAT")).map(|p| p.to_string()) else { return Ok(()) };
        let d = plain(&conn, "org.freedesktop.UPower", &path, "org.freedesktop.UPower.Device")?;
        let history: Vec<(u32, f64, u32)> = d.call("GetHistory", &("charge", 86400u32, 96u32)).unwrap_or_default();
        let mut hist: Vec<(u32, f32)> = history.into_iter().filter(|h| h.1 > 0.0).map(|h| (h.0, h.1 as f32)).collect();
        hist.sort_by_key(|h| h.0);
        let det = crate::model::BatDetails {
            capacity: d.get_property("EnergyFull").unwrap_or(0.0),
            design: d.get_property("EnergyFullDesign").unwrap_or(0.0),
            rate: d.get_property("EnergyRate").unwrap_or(0.0),
            to_empty: d.get_property("TimeToEmpty").unwrap_or(0),
            to_full: d.get_property("TimeToFull").unwrap_or(0),
            cycles: d.get_property("ChargeCycles").unwrap_or(-1),
            history: hist,
        };
        w.send(Msg::BatDetails(det));
        Ok(())
    });
}
