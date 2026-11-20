use std::io::{Read, Write};
use std::os::fd::{AsFd, BorrowedFd};
use std::os::unix::net::UnixStream;
use std::time::{Duration, Instant};

use serde_json::Value;

const MAGIC: &[u8; 6] = b"i3-ipc";
pub const RUN_COMMAND: u32 = 0;
pub const GET_WORKSPACES: u32 = 1;
pub const SUBSCRIBE: u32 = 2;
pub const GET_TREE: u32 = 4;
const EVENT_BIT: u32 = 0x8000_0000;
pub const EV_WORKSPACE: u32 = EVENT_BIT;
pub const EV_OUTPUT: u32 = EVENT_BIT | 1;
pub const EV_WINDOW: u32 = EVENT_BIT | 3;
pub const EV_SHUTDOWN: u32 = EVENT_BIT | 6;

#[derive(Clone, Debug, Default, PartialEq)]
pub struct Focus {
    pub title: String,
    pub class: String,
    pub fullscreen: bool,
    /// For the window page: X window id, geometry, floating and sticky state.
    pub window: i64,
    pub rect: (i64, i64, i64, i64),
    pub floating: bool,
    pub sticky: bool,
}

pub struct I3 {
    cmd: Option<UnixStream>,
    ev: Option<UnixStream>,
    buf: Vec<u8>,
    retry_at: Instant,
}

fn socket_path() -> Option<String> {
    let out = std::process::Command::new("i3").arg("--get-socketpath").output().ok()?;
    let s = String::from_utf8(out.stdout).ok()?.trim().to_owned();
    (!s.is_empty()).then_some(s)
}

fn frame(kind: u32, payload: &[u8]) -> Vec<u8> {
    let mut m = Vec::with_capacity(14 + payload.len());
    m.extend_from_slice(MAGIC);
    m.extend_from_slice(&(payload.len() as u32).to_le_bytes());
    m.extend_from_slice(&kind.to_le_bytes());
    m.extend_from_slice(payload);
    m
}

fn read_reply(s: &mut UnixStream) -> std::io::Result<(u32, Value)> {
    let mut head = [0u8; 14];
    s.read_exact(&mut head)?;
    if &head[..6] != MAGIC {
        return Err(std::io::Error::other("bad i3 magic"));
    }
    let len = u32::from_le_bytes(head[6..10].try_into().unwrap_or_default()) as usize;
    let kind = u32::from_le_bytes(head[10..14].try_into().unwrap_or_default());
    let mut body = vec![0u8; len];
    s.read_exact(&mut body)?;
    Ok((kind, serde_json::from_slice(&body).unwrap_or(Value::Null)))
}

impl I3 {
    pub fn new() -> Self {
        let mut i = Self { cmd: None, ev: None, buf: Vec::new(), retry_at: Instant::now() };
        i.connect();
        i
    }

    pub fn connected(&self) -> bool {
        self.ev.is_some()
    }

    pub fn connect(&mut self) -> bool {
        let Some(path) = socket_path() else {
            self.retry_at = Instant::now() + Duration::from_millis(500);
            return false;
        };
        let (Ok(mut cmd), Ok(mut ev)) = (UnixStream::connect(&path), UnixStream::connect(&path)) else {
            self.retry_at = Instant::now() + Duration::from_millis(500);
            return false;
        };
        let _ = cmd.set_read_timeout(Some(Duration::from_secs(2)));
        let sub = frame(SUBSCRIBE, br#"["workspace","window","output","shutdown"]"#);
        if ev.write_all(&sub).is_err() || read_reply(&mut ev).is_err() || ev.set_nonblocking(true).is_err() {
            self.retry_at = Instant::now() + Duration::from_millis(500);
            return false;
        }
        let _ = cmd.flush();
        self.cmd = Some(cmd);
        self.ev = Some(ev);
        self.buf.clear();
        true
    }

    pub fn retry_due(&self, now: Instant) -> Option<Instant> {
        (!self.connected()).then_some(self.retry_at.max(now))
    }

    pub fn fd(&self) -> Option<BorrowedFd<'_>> {
        self.ev.as_ref().map(|s| s.as_fd())
    }

    fn drop_conn(&mut self) {
        self.cmd = None;
        self.ev = None;
        self.retry_at = Instant::now() + Duration::from_millis(300);
    }

    pub fn request(&mut self, kind: u32, payload: &str) -> Option<Value> {
        let s = self.cmd.as_mut()?;
        let r = s.write_all(&frame(kind, payload.as_bytes())).and_then(|_| read_reply(s));
        match r {
            Ok((_, v)) => Some(v),
            Err(_) => {
                self.drop_conn();
                None
            }
        }
    }

    pub fn command(&mut self, cmd: &str) {
        let _ = self.request(RUN_COMMAND, cmd);
    }

    pub fn read_events(&mut self) -> Vec<(u32, Value)> {
        let mut out = Vec::new();
        let Some(s) = self.ev.as_mut() else { return out };
        let mut tmp = [0u8; 16384];
        loop {
            match s.read(&mut tmp) {
                Ok(0) => {
                    self.drop_conn();
                    out.push((EV_SHUTDOWN, Value::Null));
                    return out;
                }
                Ok(n) => self.buf.extend_from_slice(&tmp[..n]),
                Err(e) if e.kind() == std::io::ErrorKind::WouldBlock => break,
                Err(e) if e.kind() == std::io::ErrorKind::Interrupted => continue,
                Err(_) => {
                    self.drop_conn();
                    out.push((EV_SHUTDOWN, Value::Null));
                    return out;
                }
            }
        }
        while self.buf.len() >= 14 {
            if &self.buf[..6] != MAGIC {
                self.drop_conn();
                out.push((EV_SHUTDOWN, Value::Null));
                return out;
            }
            let len = u32::from_le_bytes(self.buf[6..10].try_into().unwrap_or_default()) as usize;
            if self.buf.len() < 14 + len {
                break;
            }
            let kind = u32::from_le_bytes(self.buf[10..14].try_into().unwrap_or_default());
            let v = serde_json::from_slice(&self.buf[14..14 + len]).unwrap_or(Value::Null);
            self.buf.drain(..14 + len);
            out.push((kind, v));
        }
        out
    }

    pub fn workspaces(&mut self) -> (Vec<i32>, i32) {
        let Some(Value::Array(a)) = self.request(GET_WORKSPACES, "") else { return (Vec::new(), -1) };
        let num = |w: &Value| w["num"].as_i64().unwrap_or(-1) as i32;
        let mut nums: Vec<i32> = a.iter().map(num).collect();
        nums.sort_unstable();
        (nums, a.iter().find(|w| w["focused"].as_bool() == Some(true)).map_or(-1, num))
    }

    pub fn focus(&mut self) -> Focus {
        let Some(tree) = self.request(GET_TREE, "") else { return Focus::default() };
        let mut stack = vec![&tree];
        while let Some(n) = stack.pop() {
            if n["focused"].as_bool() == Some(true) {
                return focus_of(n);
            }
            for k in ["nodes", "floating_nodes"] {
                if let Some(a) = n[k].as_array() {
                    stack.extend(a.iter());
                }
            }
        }
        Focus::default()
    }

    pub fn locate(&mut self, con_id: i64) -> Option<(i32, String, String)> {
        let tree = self.request(GET_TREE, "")?;
        fn walk(n: &Value, ws: Option<i32>, id: i64) -> Option<(i32, String, String)> {
            let ws = if n["type"].as_str() == Some("workspace") { n["num"].as_i64().map(|x| x as i32) } else { ws };
            if n["id"].as_i64() == Some(id) {
                return Some((
                    ws.unwrap_or(-1),
                    n["window_properties"]["class"].as_str().unwrap_or_default().to_owned(),
                    n["name"].as_str().unwrap_or_default().to_owned(),
                ));
            }
            for k in ["nodes", "floating_nodes"] {
                if let Some(a) = n[k].as_array() {
                    for c in a {
                        if let Some(r) = walk(c, ws, id) {
                            return Some(r);
                        }
                    }
                }
            }
            None
        }
        walk(&tree, None, con_id)
    }
}

pub fn focus_of(n: &Value) -> Focus {
    if n["window"].is_null() {
        return Focus::default();
    }
    Focus {
        title: n["name"].as_str().unwrap_or_default().to_owned(),
        class: n["window_properties"]["class"].as_str().unwrap_or_default().to_owned(),
        fullscreen: n["fullscreen_mode"].as_i64().unwrap_or(0) > 0,
        window: n["window"].as_i64().unwrap_or(0),
        rect: (
            n["rect"]["x"].as_i64().unwrap_or(0),
            n["rect"]["y"].as_i64().unwrap_or(0),
            n["rect"]["width"].as_i64().unwrap_or(0),
            n["rect"]["height"].as_i64().unwrap_or(0),
        ),
        floating: n["floating"].as_str().is_some_and(|s| s.ends_with("_on")),
        sticky: n["sticky"].as_bool().unwrap_or(false),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn frames_are_little_endian() {
        let f = frame(GET_TREE, b"x");
        assert_eq!(&f[..6], b"i3-ipc");
        assert_eq!(u32::from_le_bytes(f[6..10].try_into().unwrap()), 1);
        assert_eq!(u32::from_le_bytes(f[10..14].try_into().unwrap()), GET_TREE);
        assert_eq!(f[14], b'x');
    }

    #[test]
    fn focus_reads_container() {
        let v: Value = serde_json::from_str(r#"{"window":5,"name":"t","fullscreen_mode":1,"window_properties":{"class":"Thunar"}}"#).unwrap();
        let f = focus_of(&v);
        assert_eq!((f.title.as_str(), f.class.as_str(), f.fullscreen), ("t", "Thunar", true));
        assert_eq!(focus_of(&serde_json::json!({"window": null})), Focus::default());
    }
}
