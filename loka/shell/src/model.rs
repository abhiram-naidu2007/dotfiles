use std::time::Instant;

use crate::services::{Battery, Bt, Volume, Wifi};

#[derive(Clone, Debug, Default, PartialEq)]
pub struct Net {
    pub ssid: String,
    pub security: &'static str,
    pub strength: i32,
    pub known: bool,
    pub connected: bool,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct BtDev {
    pub path: String,
    pub name: String,
    pub icon: String,
    pub connected: bool,
    pub paired: bool,
    pub battery: i32,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct Dev {
    pub name: String,
    pub label: String,
    pub default: bool,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct Stream {
    pub index: u32,
    pub app: String,
    pub media: String,
    pub level: f32,
    pub muted: bool,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct Media {
    pub bus: String,
    pub title: String,
    pub artist: String,
    pub art: String,
    pub playing: bool,
    pub length_us: i64,
    pub position_us: i64,
    pub at: Option<Instant>,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Notif {
    pub id: u32,
    pub app: String,
    pub summary: String,
    pub body: String,
    pub icon: String,
    pub critical: bool,
    pub time: String,
    pub actions: Vec<(String, String)>,
}

#[derive(Clone, Debug, Default, PartialEq)]
pub struct BatDetails {
    pub capacity: f64,
    pub design: f64,
    pub rate: f64,
    pub to_empty: i64,
    pub to_full: i64,
    pub cycles: i32,
    pub history: Vec<(u32, f32)>,
}

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct Rec {
    pub start: i64,
    pub paused_total: i64,
    pub paused: bool,
}

impl Rec {
    pub fn elapsed(&self) -> i64 {
        (chrono::Utc::now().timestamp() - self.start - self.paused_total).max(0)
    }
}

#[derive(Default)]
pub struct Model {
    pub clock: String,
    pub date: String,
    pub battery: Option<Battery>,
    pub wifi: Option<Wifi>,
    pub nets: Vec<Net>,
    pub wifi_busy: bool,
    pub pw_for: Option<String>,
    pub pw_text: String,
    pub bt: Option<Bt>,
    pub bt_devs: Vec<BtDev>,
    pub bt_scanning: bool,
    pub vol: Option<Volume>,
    pub mic: Option<Volume>,
    pub sinks: Vec<Dev>,
    pub sources: Vec<Dev>,
    pub streams: Vec<Stream>,
    pub bright: f32,
    pub profile: String,
    pub coffee: bool,
    pub media: Option<Media>,
    pub art: Option<tiny_skia::Pixmap>,
    pub art_key: String,
    pub rec: Option<Rec>,
    pub rec_sys: bool,
    pub rec_mic: bool,
    pub rec_mic_dev: String,
    pub clip_query: String,
    pub clip_thumbs: std::collections::HashMap<u32, tiny_skia::Pixmap>,
    pub notifs: Vec<Notif>,
    pub dnd: bool,
    pub clip: Vec<crate::clip::Item>,
    pub cal_shift: i32,
    pub stats: [i32; 3],
    pub world: String,
    pub power_arm: String,
    pub batdet: Option<BatDetails>,
    pub tray: Vec<crate::tray::TrayItem>,
    pub cfg: crate::config::Config,
    pub scene: String,
    pub live: String,
    pub mood: String,
    pub wall_name: String,
    pub wall_video: bool,
    pub wall_thumb: Option<tiny_skia::Pixmap>,
}
