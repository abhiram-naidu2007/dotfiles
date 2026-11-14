use std::io::{BufRead, BufReader, Write};
use std::os::unix::net::{UnixListener, UnixStream};
use std::path::PathBuf;

use crate::services::{Msg, Waker};

pub fn path() -> PathBuf {
    let dir = std::env::var_os("XDG_RUNTIME_DIR").map(PathBuf::from).unwrap_or_else(|| PathBuf::from("/tmp"));
    let display = std::env::var("DISPLAY").unwrap_or_default().replace([':', '.'], "");
    dir.join(format!("loka-{display}.sock"))
}

pub fn send(msg: &str) -> std::io::Result<String> {
    let mut s = UnixStream::connect(path())?;
    s.write_all(msg.as_bytes())?;
    s.write_all(b"\n")?;
    s.shutdown(std::net::Shutdown::Write)?;
    let mut out = String::new();
    BufReader::new(s).read_line(&mut out)?;
    Ok(out)
}

pub fn serve(w: Waker) -> std::io::Result<()> {
    let p = path();
    if UnixStream::connect(&p).is_ok() {
        return Err(std::io::Error::other("another loka is running on this display"));
    }
    let _ = std::fs::remove_file(&p);
    let listener = UnixListener::bind(&p)?;
    std::thread::Builder::new().name("loka-ipc".into()).stack_size(256 * 1024).spawn(move || {
        for conn in listener.incoming().flatten() {
            let mut r = BufReader::new(&conn);
            let mut line = String::new();
            if r.read_line(&mut line).is_ok() {
                let l = line.trim().to_owned();
                if !l.is_empty() {
                    w.send(Msg::Ipc(l));
                }
                let _ = (&conn).write_all(b"ok\n");
            }
        }
    })?;
    Ok(())
}
