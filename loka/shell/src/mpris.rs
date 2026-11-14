use std::collections::HashMap;
use std::sync::mpsc::channel;
use std::time::{Duration, Instant};

use zbus::blocking::{Connection, MessageIterator, Proxy};
use zbus::zvariant::OwnedValue;

use crate::model::Media;
use crate::services::{Msg, Waker};

const PATH: &str = "/org/mpris/MediaPlayer2";
const IFACE: &str = "org.mpris.MediaPlayer2.Player";

fn player<'a>(conn: &Connection, bus: &str) -> zbus::Result<Proxy<'a>> {
    zbus::blocking::proxy::Builder::new(conn)
        .destination(bus.to_owned())?
        .path(PATH)?
        .interface(IFACE)?
        .cache_properties(zbus::proxy::CacheProperties::No)
        .build()
}

fn s(v: Option<&OwnedValue>) -> String {
    let Some(v) = v.and_then(|v| v.try_clone().ok()) else { return String::new() };
    if let Ok(x) = String::try_from(v.try_clone().unwrap_or_else(|_| OwnedValue::from(0u8))) {
        return x;
    }
    if let Ok(list) = <Vec<String>>::try_from(v) {
        return list.join(", ");
    }
    String::new()
}

fn read(conn: &Connection, bus: &str) -> Option<Media> {
    let p = player(conn, bus).ok()?;
    let status: String = p.get_property("PlaybackStatus").unwrap_or_default();
    let meta: HashMap<String, OwnedValue> = p.get_property("Metadata").unwrap_or_default();
    let title = s(meta.get("xesam:title"));
    if title.trim().is_empty() {
        return None;
    }
    let length = meta.get("mpris:length").and_then(|v| i64::try_from(v).ok().or_else(|| u64::try_from(v).ok().map(|x| x as i64))).unwrap_or(0);
    let position: i64 = p.get_property("Position").unwrap_or(0);
    Some(Media {
        bus: bus.to_owned(),
        title,
        artist: s(meta.get("xesam:artist")),
        art: s(meta.get("mpris:artUrl")),
        playing: status == "Playing",
        length_us: length,
        position_us: position,
        at: Some(Instant::now()),
    })
}

fn pick(conn: &Connection) -> Option<Media> {
    let dbus = zbus::blocking::fdo::DBusProxy::new(conn).ok()?;
    let names = dbus.list_names().ok()?;
    let mut any = None;
    for n in names.iter().map(|n| n.to_string()).filter(|n| n.starts_with("org.mpris.MediaPlayer2.")) {
        if let Some(m) = read(conn, &n) {
            if m.playing {
                return Some(m);
            }
            any.get_or_insert(m);
        }
    }
    any
}

fn same(a: &Option<Media>, b: &Option<Media>) -> bool {
    match (a, b) {
        (Some(x), Some(y)) => x.bus == y.bus && x.title == y.title && x.artist == y.artist && x.art == y.art && x.playing == y.playing && x.length_us == y.length_us && (x.position_us - y.position_us).abs() < 3_000_000,
        (None, None) => true,
        _ => false,
    }
}

fn run(w: &Waker) -> zbus::Result<()> {
    let conn = Connection::session()?;
    let (tx, rx) = channel::<()>();
    {
        let c = conn.clone();
        let tx = tx.clone();
        std::thread::Builder::new().name("loka-mpris-sig".into()).stack_size(256 * 1024).spawn(move || {
            let Ok(rule) = zbus::MatchRule::builder().msg_type(zbus::message::Type::Signal).path(PATH).map(|b| b.build()) else { return };
            let Ok(it) = MessageIterator::for_match_rule(rule, &c, Some(32)) else { return };
            for _ in it {
                let _ = tx.send(());
            }
        }).ok();
    }
    {
        let c = conn.clone();
        let tx = tx.clone();
        std::thread::Builder::new().name("loka-mpris-own".into()).stack_size(256 * 1024).spawn(move || {
            let Ok(p) = zbus::blocking::fdo::DBusProxy::new(&c) else { return };
            let Ok(sig) = p.receive_name_owner_changed() else { return };
            for s in sig {
                if s.args().map(|a| a.name().starts_with("org.mpris.")).unwrap_or(false) {
                    let _ = tx.send(());
                }
            }
        }).ok();
    }
    let mut last = pick(&conn);
    w.send(Msg::Media(last.clone()));
    loop {
        if rx.recv_timeout(Duration::from_secs(5)).is_ok() {
            std::thread::sleep(Duration::from_millis(80));
            while rx.try_recv().is_ok() {}
        }
        let now = pick(&conn);
        if !same(&now, &last) {
            last = now.clone();
            w.send(Msg::Media(now));
        }
    }
}

pub fn control(bus: String, what: &'static str) {
    let _ = std::thread::Builder::new().stack_size(256 * 1024).spawn(move || -> zbus::Result<()> {
        let conn = Connection::session()?;
        let p = player(&conn, &bus)?;
        let m = match what {
            "prev" => "Previous",
            "next" => "Next",
            _ => "PlayPause",
        };
        let _: zbus::Result<()> = p.call(m, &());
        Ok(())
    });
}

pub fn start(w: Waker) {
    let _ = std::thread::Builder::new().name("loka-mpris".into()).stack_size(512 * 1024).spawn(move || {
        loop {
            let _ = run(&w);
            std::thread::sleep(Duration::from_secs(2));
        }
    });
}
