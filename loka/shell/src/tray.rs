use std::collections::HashSet;
use std::sync::mpsc::{Receiver, Sender, channel};
use std::sync::{Arc, Mutex, OnceLock};
use std::time::Duration;

use tiny_skia::{FilterQuality, Pixmap, PixmapPaint, Transform};
use zbus::blocking::{Connection, MessageIterator, Proxy};
use zbus::object_server::SignalEmitter;

use crate::services::{Msg, Waker};

#[derive(Clone)]
pub struct TrayItem {
    pub key: String,
    pub id: String,
    pub icon: Option<Pixmap>,
}

impl std::fmt::Debug for TrayItem {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "TrayItem({})", self.key)
    }
}

impl PartialEq for TrayItem {
    fn eq(&self, o: &Self) -> bool {
        self.key == o.key && self.id == o.id && self.icon.as_ref().map(|p| p.data().len()) == o.icon.as_ref().map(|p| p.data().len())
            && self.icon.as_ref().map(|p| p.data()) == o.icon.as_ref().map(|p| p.data())
    }
}

pub enum Act {
    Activate(String, i32, i32),
    Secondary(String, i32, i32),
    Menu(String, i32, i32),
}

static CTL: OnceLock<Mutex<Sender<Act>>> = OnceLock::new();

pub fn act(a: Act) {
    if let Some(tx) = CTL.get().and_then(|m| m.lock().ok()) {
        let _ = tx.send(a);
    }
}

struct Watcher {
    items: Arc<Mutex<Vec<String>>>,
    changed: Sender<()>,
}

#[zbus::interface(name = "org.kde.StatusNotifierWatcher")]
impl Watcher {
    async fn register_status_notifier_item(
        &self,
        service: &str,
        #[zbus(header)] hdr: zbus::message::Header<'_>,
        #[zbus(signal_emitter)] em: SignalEmitter<'_>,
    ) {
        let sender = hdr.sender().map(|s| s.to_string()).unwrap_or_default();
        let key = if service.starts_with('/') {
            format!("{sender}{service}")
        } else if service.contains('/') {
            service.to_owned()
        } else {
            format!("{service}/StatusNotifierItem")
        };
        let added = {
            let mut v = self.items.lock().unwrap_or_else(|e| e.into_inner());
            if v.contains(&key) {
                false
            } else {
                v.push(key.clone());
                true
            }
        };
        if added {
            let _ = Self::status_notifier_item_registered(&em, &key).await;
            let _ = self.changed.send(());
        }
    }

    async fn register_status_notifier_host(&self, _service: &str) {}

    #[zbus(property)]
    async fn registered_status_notifier_items(&self) -> Vec<String> {
        self.items.lock().map(|v| v.clone()).unwrap_or_default()
    }

    #[zbus(property)]
    async fn is_status_notifier_host_registered(&self) -> bool {
        true
    }

    #[zbus(property)]
    async fn protocol_version(&self) -> i32 {
        0
    }

    #[zbus(signal)]
    async fn status_notifier_item_registered(em: &SignalEmitter<'_>, service: &str) -> zbus::Result<()>;

    #[zbus(signal)]
    async fn status_notifier_item_unregistered(em: &SignalEmitter<'_>, service: &str) -> zbus::Result<()>;

    #[zbus(signal)]
    async fn status_notifier_host_registered(em: &SignalEmitter<'_>) -> zbus::Result<()>;
}

fn split(key: &str) -> (String, String) {
    match key.find('/') {
        Some(i) => (key[..i].to_owned(), key[i..].to_owned()),
        None => (key.to_owned(), "/StatusNotifierItem".to_owned()),
    }
}

fn item_proxy<'a>(conn: &Connection, key: &str) -> zbus::Result<Proxy<'a>> {
    let (dest, path) = split(key);
    zbus::blocking::proxy::Builder::new(conn)
        .destination(dest)?
        .path(path)?
        .interface("org.kde.StatusNotifierItem")?
        .cache_properties(zbus::proxy::CacheProperties::No)
        .build()
}

fn pixmap_from_argb(list: &[(i32, i32, Vec<u8>)], size: u32) -> Option<Pixmap> {
    let mut best: Option<&(i32, i32, Vec<u8>)> = None;
    for p in list {
        let Some(b) = best else {
            best = Some(p);
            continue;
        };
        let ok_b = b.0 >= size as i32 && b.1 >= size as i32;
        let ok_p = p.0 >= size as i32 && p.1 >= size as i32;
        let smaller = p.0 < b.0 || p.1 < b.1;
        if (ok_b && ok_p && smaller) || (!ok_b && !smaller) {
            best = Some(p);
        }
    }
    let (w, h, data) = best?;
    if *w <= 0 || *h <= 0 || data.len() < (*w * *h * 4) as usize {
        return None;
    }
    let mut src = Pixmap::new(*w as u32, *h as u32)?;
    for (d, s) in src.data_mut().as_chunks_mut::<4>().0.iter_mut().zip(data.as_chunks::<4>().0.iter()) {
        let a = s[0] as u16;
        d[0] = (s[1] as u16 * a / 255) as u8;
        d[1] = (s[2] as u16 * a / 255) as u8;
        d[2] = (s[3] as u16 * a / 255) as u8;
        d[3] = s[0];
    }
    let mut out = Pixmap::new(size, size)?;
    let k = size as f32 / (*w).max(*h) as f32;
    let paint = PixmapPaint { quality: FilterQuality::Bicubic, ..PixmapPaint::default() };
    out.draw_pixmap(0, 0, src.as_ref(), &paint, Transform::from_scale(k, k), None);
    Some(out)
}

fn read_item(conn: &Connection, key: &str) -> Option<TrayItem> {
    let p = item_proxy(conn, key).ok()?;
    let id: String = p.get_property("Id").unwrap_or_default();
    let status: String = p.get_property("Status").unwrap_or_default();
    if status == "Passive" {
        return Some(TrayItem { key: key.to_owned(), id, icon: None });
    }
    let name: String = p.get_property("IconName").unwrap_or_default();
    let theme_path: String = p.get_property("IconThemePath").unwrap_or_default();
    let mut icon = None;
    if !name.is_empty() {
        icon = crate::icons::lookup(&name, &theme_path).and_then(|path| crate::icons::render_path(&path, 16));
    }
    if icon.is_none() {
        let px: Vec<(i32, i32, Vec<u8>)> = p.get_property("IconPixmap").unwrap_or_default();
        icon = pixmap_from_argb(&px, 16);
    }
    Some(TrayItem { key: key.to_owned(), id, icon })
}

fn snapshot(conn: &Connection, keys: &[String], w: &Waker, last: &mut Vec<TrayItem>) {
    let items: Vec<TrayItem> = keys.iter().filter_map(|k| read_item(conn, k)).collect();
    if &items != last {
        *last = items.clone();
        w.send(Msg::Tray(items));
    }
}

fn run(w: &Waker) -> zbus::Result<()> {
    let conn = Connection::session()?;
    let items: Arc<Mutex<Vec<String>>> = Arc::new(Mutex::new(Vec::new()));
    let (ch_tx, ch_rx) = channel::<()>();
    let dbus = zbus::blocking::fdo::DBusProxy::new(&conn)?;
    let own = dbus.request_name(
        zbus::names::WellKnownName::from_static_str("org.kde.StatusNotifierWatcher")?,
        zbus::fdo::RequestNameFlags::DoNotQueue.into(),
    );
    let is_watcher = matches!(own, Ok(zbus::fdo::RequestNameReply::PrimaryOwner));
    if is_watcher {
        conn.object_server().at("/StatusNotifierWatcher", Watcher { items: items.clone(), changed: ch_tx.clone() })?;
        if let Ok(names) = dbus.list_names() {
            let mut v = items.lock().unwrap_or_else(|e| e.into_inner());
            for n in names.iter().map(|n| n.to_string()).filter(|n| n.starts_with("org.kde.StatusNotifierItem-")) {
                let key = format!("{n}/StatusNotifierItem");
                if !v.contains(&key) {
                    v.push(key);
                }
            }
        }
    } else {
        let wp = Proxy::new(&conn, "org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher", "org.kde.StatusNotifierWatcher")?;
        let host = format!("org.kde.StatusNotifierHost-{}-1", std::process::id());
        let _ = dbus.request_name(zbus::names::WellKnownName::try_from(host.as_str())?, zbus::fdo::RequestNameFlags::DoNotQueue.into());
        let _: zbus::Result<()> = wp.call("RegisterStatusNotifierHost", &(host.as_str(),));
        let reg: Vec<String> = wp.get_property("RegisteredStatusNotifierItems").unwrap_or_default();
        *items.lock().unwrap_or_else(|e| e.into_inner()) = reg;
        let it = items.clone();
        let tx = ch_tx.clone();
        let c2 = conn.clone();
        std::thread::Builder::new().name("loka-tray-reg".into()).stack_size(256 * 1024).spawn(move || {
            let rule = zbus::MatchRule::builder()
                .msg_type(zbus::message::Type::Signal)
                .interface("org.kde.StatusNotifierWatcher")
                .map(|b| b.build());
            let Ok(rule) = rule else { return };
            let Ok(iter) = MessageIterator::for_match_rule(rule, &c2, Some(32)) else { return };
            for m in iter.flatten() {
                let hdr = m.header();
                let member = hdr.member().map(|m| m.to_string()).unwrap_or_default();
                let Ok(key) = m.body().deserialize::<String>() else { continue };
                let mut v = it.lock().unwrap_or_else(|e| e.into_inner());
                if member == "StatusNotifierItemRegistered" && !v.contains(&key) {
                    v.push(key);
                } else if member == "StatusNotifierItemUnregistered" {
                    v.retain(|k| k != &key);
                }
                drop(v);
                let _ = tx.send(());
            }
        }).ok();
    }

    {
        let tx = ch_tx.clone();
        let c2 = conn.clone();
        std::thread::Builder::new().name("loka-tray-sig".into()).stack_size(256 * 1024).spawn(move || {
            let Ok(rule) = zbus::MatchRule::builder()
                .msg_type(zbus::message::Type::Signal)
                .interface("org.kde.StatusNotifierItem")
                .map(|b| b.build())
            else {
                return;
            };
            let Ok(iter) = MessageIterator::for_match_rule(rule, &c2, Some(32)) else { return };
            for _ in iter.flatten() {
                let _ = tx.send(());
            }
        }).ok();
    }
    {
        let tx = ch_tx.clone();
        let c2 = conn.clone();
        let it = items.clone();
        std::thread::Builder::new().name("loka-tray-own".into()).stack_size(256 * 1024).spawn(move || {
            let Ok(p) = zbus::blocking::fdo::DBusProxy::new(&c2) else { return };
            let Ok(sig) = p.receive_name_owner_changed() else { return };
            for s in sig {
                let Ok(a) = s.args() else { continue };
                if a.new_owner().is_none() {
                    let gone = a.name().to_string();
                    let mut v = it.lock().unwrap_or_else(|e| e.into_inner());
                    let before = v.len();
                    v.retain(|k| split(k).0 != gone);
                    if v.len() != before {
                        drop(v);
                        let _ = tx.send(());
                    }
                }
            }
        }).ok();
    }

    let (act_tx, act_rx) = channel::<Act>();
    let _ = CTL.set(Mutex::new(act_tx));
    let c3 = conn.clone();
    std::thread::Builder::new().name("loka-tray-act".into()).stack_size(256 * 1024).spawn(move || actions(c3, act_rx)).ok();

    let mut last = Vec::new();
    let keys = items.lock().map(|v| v.clone()).unwrap_or_default();
    snapshot(&conn, &keys, w, &mut last);
    loop {
        if ch_rx.recv().is_err() {
            break;
        }
        std::thread::sleep(Duration::from_millis(120));
        while ch_rx.try_recv().is_ok() {}
        let keys = items.lock().map(|v| v.clone()).unwrap_or_default();
        let live: HashSet<String> = keys.iter().cloned().collect();
        last.retain(|i| live.contains(&i.key));
        snapshot(&conn, &keys, w, &mut last);
    }
    Ok(())
}

fn actions(conn: Connection, rx: Receiver<Act>) {
    for a in rx {
        let (key, method, x, y) = match a {
            Act::Activate(k, x, y) => (k, "Activate", x, y),
            Act::Secondary(k, x, y) => (k, "SecondaryActivate", x, y),
            Act::Menu(k, x, y) => (k, "ContextMenu", x, y),
        };
        if let Ok(p) = item_proxy(&conn, &key) {
            let _: zbus::Result<()> = p.call(method, &(x, y));
        }
    }
}

pub fn start(w: Waker) {
    let _ = std::thread::Builder::new().name("loka-tray".into()).stack_size(512 * 1024).spawn(move || {
        loop {
            let _ = run(&w);
            std::thread::sleep(Duration::from_secs(2));
        }
    });
}

#[derive(Clone, Debug, PartialEq)]
pub struct MenuItem {
    pub id: i32,
    pub label: String,
    pub enabled: bool,
    pub separator: bool,
    pub toggle: Option<bool>,
    pub children: Vec<MenuItem>,
}

fn walk(v: &zbus::zvariant::Value<'_>) -> Option<MenuItem> {
    use zbus::zvariant::Value;
    let v = if let Value::Value(inner) = v { inner.as_ref() } else { v };
    let Value::Structure(s) = v else { return None };
    let f = s.fields();
    let id = match f.first()? {
        Value::I32(i) => *i,
        _ => return None,
    };
    let mut label = String::new();
    let mut enabled = true;
    let mut visible = true;
    let mut separator = false;
    let mut toggle = None;
    if let Some(Value::Dict(d)) = f.get(1) {
        for (k, val) in d.iter() {
            let key = match k {
                Value::Str(s) => s.as_str().to_owned(),
                _ => continue,
            };
            let val = if let Value::Value(x) = val { x.as_ref() } else { val };
            match (key.as_str(), val) {
                ("label", Value::Str(s)) => label = s.as_str().replace('_', ""),
                ("enabled", Value::Bool(b)) => enabled = *b,
                ("visible", Value::Bool(b)) => visible = *b,
                ("type", Value::Str(s)) => separator = s.as_str() == "separator",
                ("toggle-state", Value::I32(i)) => toggle = Some(*i == 1),
                _ => {}
            }
        }
    }
    if !visible {
        return None;
    }
    let mut children = Vec::new();
    if let Some(Value::Array(a)) = f.get(2) {
        for c in a.iter() {
            if let Some(m) = walk(c) {
                children.push(m);
            }
        }
    }
    Some(MenuItem { id, label, enabled, separator, toggle, children })
}

pub fn fetch_menu(key: String, w: Waker) {
    let _ = std::thread::Builder::new().stack_size(512 * 1024).spawn(move || {
        if let Err(e) = fetch_menu_inner(&key, &w) {
            eprintln!("loka: tray menu {key}: {e}");
            w.send(Msg::TrayMenu(key, String::new(), Vec::new()));
        }
    });
}

fn fetch_menu_inner(key: &str, w: &Waker) -> zbus::Result<()> {
    {
        let conn = Connection::session()?;
        let p = item_proxy(&conn, key)?;
        let path: zbus::zvariant::OwnedObjectPath = p.get_property("Menu")?;
        let (dest, _) = split(key);
        let mp = zbus::blocking::proxy::Builder::<Proxy>::new(&conn)
            .destination(dest)?
            .path(path.to_string())?
            .interface("com.canonical.dbusmenu")?
            .cache_properties(zbus::proxy::CacheProperties::No)
            .build()?;
        let _: zbus::Result<bool> = mp.call("AboutToShow", &(0i32,));
        let props: Vec<&str> = vec![];
        type Layout = (i32, std::collections::HashMap<String, zbus::zvariant::OwnedValue>, Vec<zbus::zvariant::OwnedValue>);
        let (_, root): (u32, Layout) = mp.call("GetLayout", &(0i32, -1i32, props))?;
        let items: Vec<MenuItem> = root.2.iter().filter_map(|c| walk(c)).collect();
        if std::env::var_os("LOKA_DEBUG").is_some() {
            eprintln!("loka: menu {} children raw {} parsed {} first {:?}", key, root.2.len(), items.len(), root.2.first());
        }
        w.send(Msg::TrayMenu(key.to_owned(), path.to_string(), items));
        Ok(())
    }
}

pub fn menu_event(key: String, path: String, id: i32) {
    let _ = std::thread::Builder::new().stack_size(256 * 1024).spawn(move || -> zbus::Result<()> {
        let conn = Connection::session()?;
        let (dest, _) = split(&key);
        let mp = zbus::blocking::proxy::Builder::<Proxy>::new(&conn)
            .destination(dest)?
            .path(path)?
            .interface("com.canonical.dbusmenu")?
            .cache_properties(zbus::proxy::CacheProperties::No)
            .build()?;
        let ts = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs() as u32).unwrap_or(0);
        let _: zbus::Result<()> = mp.call("Event", &(id, "clicked", zbus::zvariant::Value::from(""), ts));
        Ok(())
    });
}
