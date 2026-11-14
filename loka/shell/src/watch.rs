use std::collections::HashMap;
use std::os::fd::{AsFd, BorrowedFd, OwnedFd};
use std::path::Path;

use rustix::fs::inotify::{self, CreateFlags, WatchFlags};

pub const THEME: u8 = 1;
pub const REC: u8 = 2;

pub struct Watch {
    fd: OwnedFd,
    tags: HashMap<i32, (u8, &'static [&'static str])>,
}

impl Watch {
    pub fn new(dirs: &[(&Path, u8, &'static [&'static str])]) -> std::io::Result<Self> {
        let fd = inotify::init(CreateFlags::CLOEXEC | CreateFlags::NONBLOCK)?;
        let mut tags = HashMap::new();
        for (d, tag, names) in dirs {
            let _ = std::fs::create_dir_all(d);
            if let Ok(wd) = inotify::add_watch(
                &fd,
                *d,
                WatchFlags::CLOSE_WRITE | WatchFlags::MOVED_TO | WatchFlags::CREATE | WatchFlags::DELETE,
            ) {
                tags.insert(wd, (*tag, *names));
            }
        }
        Ok(Self { fd, tags })
    }

    pub fn fd(&self) -> BorrowedFd<'_> {
        self.fd.as_fd()
    }

    pub fn drain(&self) -> u8 {
        let mut buf = [0u8; 4096];
        let mut hit = 0u8;
        while let Ok(n) = rustix::io::read(&self.fd, &mut buf) {
            if n == 0 {
                break;
            }
            let mut off = 0;
            while off + 16 <= n {
                let wd = i32::from_ne_bytes(buf[off..off + 4].try_into().unwrap_or_default());
                let len = u32::from_ne_bytes(buf[off + 12..off + 16].try_into().unwrap_or_default()) as usize;
                let end = (off + 16 + len).min(n);
                let name = std::str::from_utf8(&buf[off + 16..end]).unwrap_or("").trim_end_matches('\0');
                if let Some((tag, names)) = self.tags.get(&wd)
                    && (names.is_empty() || names.iter().any(|p| name.starts_with(p))) {
                        hit |= tag;
                    }
                off = end;
            }
        }
        hit
    }
}
