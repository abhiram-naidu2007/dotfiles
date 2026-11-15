use std::collections::HashMap;
use std::path::PathBuf;

use crate::anim::Ease;
use crate::canvas::Rgba;
use crate::config::home;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum WorldId {
    Meridian,
    Katha,
    Sakuga,
    Toon,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum WsStyle {
    Dash,
    Akshara,
    Slash,
    Bubble,
}

#[derive(Clone, Debug)]
pub struct World {
    pub id: WorldId,
    pub display: &'static str,
    pub text: &'static str,
    pub text_weight: u16,
    pub tracking: f32,
    pub pill_h: f32,
    pub radius: f32,
    pub border: f32,
    pub skew: f32,
    pub lift: bool,
    pub lacquer: bool,
    pub dur_ms: u32,
    pub ease: Ease,
    pub labels: [&'static str; 3],
    pub workspace: WsStyle,
}

impl World {
    pub fn get(id: WorldId) -> Self {
        let (m, k, s, t) = (id == WorldId::Meridian, id == WorldId::Katha, id == WorldId::Sakuga, id == WorldId::Toon);
        World {
            id,
            display: if m { "JetBrainsMono Nerd Font" } else if k { "Ramaraja" } else if t { "Rounded Mplus 1c" } else { "Inter Tight" },
            text: if m { "JetBrainsMono Nerd Font" } else if k { "Anek Telugu" } else if t { "Rounded Mplus 1c" } else { "Inter Tight" },
            text_weight: if m { 500 } else if s || t { 700 } else { 600 },
            tracking: if m { 1.4 } else if s { 0.4 } else { 0.0 },
            pill_h: if t { 32.0 } else if s { 28.0 } else { 30.0 },
            radius: if m { 3.0 } else if s { 2.0 } else if t { 16.0 } else { 15.0 },
            border: if s { 0.0 } else if t { 2.0 } else { 1.0 },
            skew: if s { -0.28 } else { 0.0 },
            lift: t,
            lacquer: k,
            dur_ms: if m { 110 } else if k { 360 } else if s { 170 } else { 300 },
            ease: if m { Ease::Linear } else if k { Ease::InOutSine } else if s { Ease::OutBack(2.2) } else { Ease::OutElastic },
            labels: if m {
                ["SYS", "MEM", "GPU"]
            } else if s {
                ["CPU", "RAM", "GPU"]
            } else if t {
                ["\u{f04c5}", "\u{f035b}", "\u{f08ae}"]
            } else {
                ["\u{f035b}", "\u{f061a}", "\u{f08ae}"]
            },
            workspace: if m { WsStyle::Dash } else if k { WsStyle::Akshara } else if s { WsStyle::Slash } else { WsStyle::Bubble },
        }
    }

    pub fn labels_are_glyphs(&self) -> bool {
        matches!(self.id, WorldId::Katha | WorldId::Toon)
    }
}

#[derive(Clone, Debug)]
pub struct Palette {
    map: HashMap<String, String>,
}

impl Palette {
    pub fn raw(&self, key: &str) -> Option<&str> {
        self.map.get(key).map(String::as_str)
    }

    pub fn c(&self, key: &str, fallback: &str) -> Rgba {
        self.map
            .get(key)
            .and_then(|v| Rgba::hex(v))
            .or_else(|| Rgba::hex(fallback))
            .unwrap_or(Rgba::new(1.0, 1.0, 1.0, 1.0))
    }
}

#[derive(Clone, Debug)]
pub struct Theme {
    pub world: World,
    pub pal: Palette,
}

pub fn palette_path() -> PathBuf {
    home().join(".cache/theme/palette.json")
}

pub fn world_path() -> PathBuf {
    home().join(".local/state/rice/world")
}

impl Theme {
    pub fn load() -> Self {
        let map = std::fs::read_to_string(palette_path())
            .ok()
            .and_then(|s| serde_json::from_str::<HashMap<String, serde_json::Value>>(&s).ok())
            .map(|m| m.into_iter().filter_map(|(k, v)| v.as_str().map(|s| (k, s.to_owned()))).collect())
            .unwrap_or_default();
        let name = std::env::var("LOKA_WORLD").ok().unwrap_or_else(|| std::fs::read_to_string(world_path()).unwrap_or_default());
        let id = match name.trim() {
            "katha" => WorldId::Katha,
            "sakuga" => WorldId::Sakuga,
            "toon" => WorldId::Toon,
            _ => WorldId::Meridian,
        };
        Theme { world: World::get(id), pal: Palette { map } }
    }
}

pub fn rice_look(pal: &Palette) -> (String, String, String) {
    let st = home().join(".local/state/rice");
    let r = |f: &str| std::fs::read_to_string(st.join(f)).map(|s| s.trim().to_owned()).unwrap_or_default();
    let scene = r("scene");
    let live = r("live");
    let mood = pal.raw("mode").unwrap_or("night").to_owned();
    (if scene.is_empty() { "picture".into() } else { scene }, if live.is_empty() { "off".into() } else { live }, mood)
}

#[derive(Clone, Copy, Debug)]
pub struct Island {
    pub bg: Rgba,
    pub fg: Rgba,
    pub on: Rgba,
    pub crit: Rgba,
    pub muted: Rgba,
    pub line: Rgba,
    pub hover: Rgba,
}

impl Island {
    pub fn from(t: &Theme) -> Self {
        let h = |s: &str| Rgba::hex(s).unwrap_or(Rgba::new(1.0, 1.0, 1.0, 1.0));
        let (mut bg, mut fg, mut on, mut crit) = match t.world.id {
            WorldId::Meridian => (h("#000000"), h("#eceff4"), h("#eceff4"), h("#d71921")),
            WorldId::Sakuga => (h("#0a0b10"), h("#f4f6fa"), h("#e23a42"), h("#ff4d57")),
            WorldId::Katha => (h("#0e1440"), h("#f6ebd3"), h("#e8b04a"), h("#e2553f")),
            WorldId::Toon => (h("#2a2244"), h("#fff5e4"), h("#ffd45c"), h("#ff7a8a")),
        };
        let p = &t.pal;
        if p.raw("accent").is_some() {
            if p.raw("mode") == Some("paper") {
                bg = p.c("bg", "#e4e2dd");
                fg = p.c("fg", "#222222");
                on = fg;
                crit = p.c("red", "#aa3333");
            } else if t.world.id == WorldId::Sakuga {
                bg = p.c("crust", "#0a0b10");
                fg = p.c("fg", "#f4f6fa");
                on = p.c("accent", "#e23a42");
                crit = p.c("red", "#ff4d57");
            }
        }
        Island { bg, fg, on, crit, muted: fg.alpha(0.45), line: fg.alpha(0.10), hover: fg.alpha(0.10) }
    }

    pub fn fg_on(&self, c: Rgba) -> Rgba {
        if c.luma() > 0.6 { self.bg } else { Rgba::new(1.0, 1.0, 1.0, 1.0) }
    }
}
