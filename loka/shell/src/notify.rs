use std::collections::HashMap;
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::OnceLock;
use std::time::Duration;

use zbus::blocking::Connection;
use zbus::object_server::SignalEmitter;
use zbus::zvariant::OwnedValue;

use crate::model::Notif;
use crate::services::{Msg, Waker};

static NEXT: AtomicU32 = AtomicU32::new(1);
static CONN: OnceLock<Connection> = OnceLock::new();

struct Server {
    w: Waker,
}

#[zbus::interface(name = "org.freedesktop.Notifications")]
impl Server {
    async fn get_capabilities(&self) -> Vec<String> {
        vec!["body".into(), "actions".into(), "persistence".into()]
    }

    #[allow(clippy::too_many_arguments)]
    async fn notify(
        &self,
        app_name: String,
        replaces_id: u32,
        _app_icon: String,
        summary: String,
        body: String,
        actions: Vec<String>,
        hints: HashMap<String, OwnedValue>,
        expire_timeout: i32,
    ) -> u32 {
        let id = if replaces_id > 0 { replaces_id } else { NEXT.fetch_add(1, Ordering::Relaxed) };
        if app_name == "osd" || summary.contains("Some required themes are missing") {
            return id;
        }
        let urgency = hints.get("urgency").and_then(|v| u8::try_from(v).ok()).unwrap_or(1);
        let n = Notif {
            id,
            app: if app_name.is_empty() { "Notification".into() } else { app_name },
            summary,
            body: strip_markup(&body),
            critical: urgency >= 2,
            time: chrono::Local::now().format("%H:%M").to_string(),
            stamp: chrono::Local::now().timestamp(),
            actions: actions.chunks(2).filter(|c| c.len() == 2).map(|c| (c[0].clone(), c[1].clone())).collect(),
        };
        self.w.send(Msg::Notify(n, expire_timeout));
        id
    }

    async fn close_notification(&self, id: u32, #[zbus(signal_emitter)] em: SignalEmitter<'_>) {
        self.w.send(Msg::NotifClose(id));
        let _ = Self::notification_closed(&em, id, 3).await;
    }

    async fn get_server_information(&self) -> (String, String, String, String) {
        ("loka".into(), "loka".into(), env!("CARGO_PKG_VERSION").into(), "1.2".into())
    }

    #[zbus(signal)]
    async fn notification_closed(em: &SignalEmitter<'_>, id: u32, reason: u32) -> zbus::Result<()>;

    #[zbus(signal)]
    async fn action_invoked(em: &SignalEmitter<'_>, id: u32, action_key: &str) -> zbus::Result<()>;
}

fn strip_markup(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    let mut tag = false;
    for c in s.chars() {
        match c {
            '<' => tag = true,
            '>' if tag => tag = false,
            _ if !tag => out.push(c),
            _ => {}
        }
    }
    out.replace("&amp;", "&").replace("&lt;", "<").replace("&gt;", ">").replace("&quot;", "\"").replace("&#39;", "'")
}

fn emit<B: serde::Serialize + zbus::zvariant::DynamicType>(member: &str, body: &B) {
    if let Some(c) = CONN.get() {
        let _ = c.emit_signal(None::<&str>, "/org/freedesktop/Notifications", "org.freedesktop.Notifications", member, body);
    }
}

pub fn invoke(id: u32, key: &str) {
    emit("ActionInvoked", &(id, key));
    closed(id, 2);
}

fn history_path() -> std::path::PathBuf {
    let base = std::env::var_os("XDG_STATE_HOME").map(std::path::PathBuf::from)
        .unwrap_or_else(|| std::path::PathBuf::from(std::env::var_os("HOME").unwrap_or_default()).join(".local/state"));
    base.join("loka/notifications.json")
}

/// Keep the history across restarts (newest 50).
pub fn save(list: &[Notif]) {
    let p = history_path();
    let _ = std::fs::create_dir_all(p.parent().unwrap_or(&p));
    let start = list.len().saturating_sub(50);
    if let Ok(s) = serde_json::to_string(&list[start..]) {
        let tmp = p.with_extension("tmp");
        if std::fs::write(&tmp, s).is_ok() {
            let _ = std::fs::rename(tmp, p);
        }
    }
}

/// History from the last run. The apps that sent these are gone, so actions are dropped,
/// and ids move to a high range where they cannot clash with the ids this run hands out.
pub fn load() -> Vec<Notif> {
    let Ok(s) = std::fs::read_to_string(history_path()) else { return Vec::new() };
    let mut v: Vec<Notif> = serde_json::from_str(&s).unwrap_or_default();
    for (i, n) in v.iter_mut().enumerate() {
        n.id = 0x8000_0000 + i as u32;
        n.actions.clear();
    }
    v
}

pub fn closed(id: u32, reason: u32) {
    emit("NotificationClosed", &(id, reason));
}

fn run(w: &Waker) -> zbus::Result<()> {
    let conn = Connection::session()?;
    conn.object_server().at("/org/freedesktop/Notifications", Server { w: w.clone() })?;
    let dbus = zbus::blocking::fdo::DBusProxy::new(&conn)?;
    let flags = zbus::fdo::RequestNameFlags::DoNotQueue;
    loop {
        let r = dbus.request_name(zbus::names::WellKnownName::from_static_str("org.freedesktop.Notifications")?, flags.into());
        if matches!(r, Ok(zbus::fdo::RequestNameReply::PrimaryOwner) | Ok(zbus::fdo::RequestNameReply::AlreadyOwner)) {
            break;
        }
        std::thread::sleep(Duration::from_secs(3));
    }
    let _ = CONN.set(conn);
    loop {
        std::thread::park();
    }
}

pub fn start(w: Waker) {
    let _ = std::thread::Builder::new().name("loka-notify".into()).stack_size(512 * 1024).spawn(move || {
        loop {
            let _ = run(&w);
            std::thread::sleep(Duration::from_secs(2));
        }
    });
}

#[cfg(test)]
mod tests {
    use super::strip_markup;

    #[test]
    fn markup_is_stripped() {
        assert_eq!(strip_markup("<b>Hi</b> &amp; <i>bye</i>"), "Hi & bye");
        assert_eq!(strip_markup("a &lt; b"), "a < b");
    }
}
