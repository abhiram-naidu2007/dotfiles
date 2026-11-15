use std::path::PathBuf;
use std::sync::atomic::{AtomicBool, Ordering};

use serde::{Deserialize, Serialize};

pub static SOUNDS: AtomicBool = AtomicBool::new(true);

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
#[serde(default)]
pub struct Config {
    pub clock24: bool,
    pub seconds: bool,
    pub sounds: bool,
    pub toast_secs: u64,
    pub dnd: bool,
    pub term_opacity: u8,
}

impl Default for Config {
    fn default() -> Self {
        Self { clock24: true, seconds: false, sounds: true, toast_secs: 5, dnd: false, term_opacity: 90 }
    }
}

pub fn home() -> PathBuf {
    PathBuf::from(std::env::var_os("HOME").unwrap_or_default())
}

pub fn assets() -> PathBuf {
    home().join("dotfiles/loka")
}

fn path() -> PathBuf {
    home().join(".config/loka/shell.json")
}

impl Config {
    pub fn load() -> Self {
        let c: Config = std::fs::read_to_string(path()).ok().and_then(|s| serde_json::from_str(&s).ok()).unwrap_or_default();
        SOUNDS.store(c.sounds, Ordering::Relaxed);
        c
    }

    pub fn save(&self) {
        SOUNDS.store(self.sounds, Ordering::Relaxed);
        let p = path();
        if let Some(d) = p.parent() {
            let _ = std::fs::create_dir_all(d);
        }
        if let Ok(s) = serde_json::to_string_pretty(self) {
            let tmp = p.with_extension("json.tmp");
            if std::fs::write(&tmp, s).is_ok() {
                let _ = std::fs::rename(tmp, p);
            }
        }
    }
}
