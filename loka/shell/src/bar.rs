use std::collections::HashMap;
use std::time::{Duration, Instant};

use tiny_skia::Pixmap;

use crate::anim::Tween;
use crate::canvas::{self, IRect, Rgba};
use crate::text::{Fonts, TextStyle};
use crate::theme::{Theme, WsStyle};

const ISLAND_HALF: f32 = 110.0;
const TOP: f32 = 8.0;
const EDGE: f32 = 8.0;
const GAP: f32 = 8.0;
const ICON_FONT: &str = "JetBrainsMono Nerd Font";

struct Colors {
    bg: Rgba,
    line: Rgba,
    line_hot: Rgba,
    text1: Rgba,
    text2: Rgba,
    on: Rgba,
    on2: Rgba,
    on_text: Rgba,
    warn: Rgba,
    crit: Rgba,
    ok: Rgba,
    red: Rgba,
    bryellow: Rgba,
    text3: Rgba,
    faint: Rgba,
    blue: Rgba,
    magenta: Rgba,
    cyan: Rgba,
}

impl Colors {
    fn from(t: &Theme) -> Self {
        let p = &t.pal;
        Self {
            bg: p.c("surface", "#141414").alpha(0.94),
            line: p.c("surface1", "#2a2a2a"),
            line_hot: p.c("surface2", "#4a4a4a"),
            text1: p.c("fg", "#ffffff"),
            text2: p.c("subtext", "#adadad"),
            on: p.c("accent", "#3b82f6"),
            on2: p.c("accent2", "#3b82f6"),
            on_text: p.c("crust", "#000000"),
            warn: p.c("warn", "#f2b544"),
            crit: p.c("crit", "#d71921"),
            ok: p.c("ok", "#4fd18b"),
            red: p.c("red", "#d71921"),
            bryellow: p.c("bryellow", "#f2b544"),
            text3: p.c("dim", "#707070"),
            faint: p.c("surface1", "#2a2a2a"),
            blue: p.c("blue", "#adadad"),
            magenta: p.c("magenta", "#adadad"),
            cyan: p.c("cyan", "#adadad"),
        }
    }
}

#[derive(Debug)]
pub enum Click {
    I3(String),
    Page(&'static str),
    TrayMenu(String, i32),
    Record,
}

#[derive(Clone, Copy, PartialEq, Eq, Hash, Debug)]
enum Hit {
    Launcher,
    Web,
    Workspace(i32),
    Stats,
    Battery,
    Wifi,
    Bluetooth,
    Volume,
    Tray(usize),
    Rec,
    Power,
}

enum Part {
    Glyph(&'static str, f32, Rgba),
    Text(String, TextStyle, Rgba, f32),
    Blocks(i32, Rgba, Rgba),
    Hearts(i32, Rgba, Rgba),
    Meter(i32, Rgba, Rgba),
    Lamp(i32, Rgba, Rgba),
    Icon(Pixmap),
}

impl Part {
    fn width(&self, fonts: &mut Fonts) -> f32 {
        match self {
            Part::Glyph(g, size, _) => fonts.measure(g, &TextStyle::new(ICON_FONT, *size, 400)),
            Part::Text(t, st, _, min_w) => fonts.measure(t, st).max(*min_w),
            Part::Blocks(..) => 10.0 * 4.0 + 9.0 * 2.0,
            Part::Hearts(..) => 5.0 * fonts.measure("\u{f02d1}", &TextStyle::new(ICON_FONT, 15.0, 400)) + 4.0,
            Part::Meter(..) => 62.0,
            Part::Lamp(..) => 26.0,
            Part::Icon(p) => p.width() as f32,
        }
    }

    fn draw(&self, pm: &mut Pixmap, fonts: &mut Fonts, x: f32, cy: f32) {
        let id = tiny_skia::Transform::identity();
        match self {
            Part::Glyph(g, size, c) => {
                fonts.draw(pm, g, &TextStyle::new(ICON_FONT, *size, 400), x, cy, *c, None);
            }
            Part::Text(t, st, c, min_w) => {
                let w = fonts.measure(t, st);
                fonts.draw(pm, t, st, x + (min_w - w).max(0.0), cy, *c, None);
            }
            Part::Blocks(pct, c, faint) => {
                let lit = (*pct as f32 / 10.0).ceil() as i32;
                for i in 0..10 {
                    let bx = x + i as f32 * 6.0;
                    canvas::fill_round(pm, bx, cy - 5.5, 4.0, 11.0, 0.0, if i < lit { *c } else { *faint }, id);
                }
            }
            Part::Hearts(pct, c, dim) => {
                let st = TextStyle::new(ICON_FONT, 15.0, 400);
                let hw = fonts.measure("\u{f02d1}", &st);
                for i in 0..5 {
                    let fill = (*pct as f32 / 20.0 - i as f32).clamp(0.0, 1.0);
                    let g = if fill >= 0.75 { "\u{f02d1}" } else if fill >= 0.25 { "\u{f06de}" } else { "\u{f02d5}" };
                    fonts.draw(pm, g, &st, x + i as f32 * (hw + 1.0), cy, if fill >= 0.25 { *c } else { *dim }, None);
                }
            }
            Part::Meter(pct, c, faint) => {
                canvas::fill_round(pm, x, cy - 4.0, 62.0, 8.0, 4.0, *faint, id);
                let w = (62.0 * *pct as f32 / 100.0).max(4.0);
                canvas::fill_round(pm, x, cy - 4.0, w, 8.0, 4.0, *c, id);
            }
            Part::Icon(p) => {
                pm.draw_pixmap(x as i32, (cy - p.height() as f32 / 2.0) as i32, p.as_ref(), &tiny_skia::PixmapPaint::default(), id, None);
            }
            Part::Lamp(pct, flame, on) => {
                let base_y = cy - 11.0;
                let lvl = 0.45 + 0.55 * *pct as f32 / 100.0;
                let st = TextStyle::new(ICON_FONT, 15.0 * lvl, 400);
                let fw = fonts.measure("\u{f0238}", &st);
                fonts.draw(pm, "\u{f0238}", &st, x + 13.0 - fw / 2.0, base_y + 13.0 - 15.0 * lvl * 0.65, *flame, None);
                canvas::fill_round(pm, x + 1.0, base_y + 12.0, 24.0, 8.0, 4.0, *on, id);
                canvas::fill_round(pm, x + 1.0, base_y + 12.0, 24.0, 3.0, 0.0, *on, id);
                canvas::fill_round(pm, x + 20.0, base_y + 11.0, 6.0, 4.0, 2.0, on.darker(1.25), id);
            }
        }
    }
}

struct Spec {
    fill: Rgba,
    border: f32,
    pad: f32,
    spacing: f32,
    parts: Vec<Part>,
    hits: Vec<(Hit, Option<usize>)>,
}

pub struct Bar {
    theme: Theme,
    col: Colors,
    width: f32,
    workspaces: Vec<i32>,
    pub focused: i32,
    ws_w: HashMap<i32, Tween>,
    stats: [i32; 3],
    title: String,
    class: String,
    hidden: bool,
    battery: Option<(i32, bool)>,
    wifi: Option<crate::services::Wifi>,
    bt: Option<crate::services::Bt>,
    vol: Option<crate::services::Volume>,
    tray: Vec<crate::tray::TrayItem>,
    open_page: Option<&'static str>,
    rec: Option<(i64, bool)>,
    hover: Option<Hit>,
    hits: Vec<(IRect, Hit)>,
    pills: Vec<IRect>,
    dirty: bool,
}

impl Bar {
    pub fn new(width: u16, theme: Theme) -> Self {
        let col = Colors::from(&theme);
        Self {
            theme,
            col,
            width: width as f32,
            workspaces: Vec::new(),
            focused: -1,
            ws_w: HashMap::new(),
            stats: [-1, -1, -1],
            title: String::new(),
            class: String::new(),
            hidden: false,
            battery: None,
            wifi: None,
            bt: None,
            vol: None,
            tray: Vec::new(),
            open_page: None,
            rec: None,
            hover: None,
            hits: Vec::new(),
            pills: Vec::new(),
            dirty: true,
        }
    }

    pub fn height(&self) -> u16 {
        (TOP + self.theme.world.pill_h + 6.0).ceil() as u16
    }

    pub fn input_rects(&self) -> &[IRect] {
        &self.pills
    }

    fn dur(&self) -> Duration {
        Duration::from_millis(self.theme.world.dur_ms as u64)
    }

    fn ws_target(&self, id: i32) -> f32 {
        let here = id == self.focused;
        match self.theme.world.workspace {
            WsStyle::Akshara => if here { 22.0 } else { 6.0 },
            WsStyle::Bubble => if here { 14.0 } else { 8.0 },
            WsStyle::Slash => if here { 22.0 } else { 7.0 },
            WsStyle::Dash => if here { 18.0 } else { 5.0 },
        }
    }

    pub fn set_focused(&mut self, id: i32, now: Instant) {
        if self.focused == id {
            return;
        }
        self.focused = id;
        let (dur, ease) = (self.dur(), self.theme.world.ease);
        for w in self.workspaces.clone() {
            let t = self.ws_target(w);
            self.ws_w.entry(w).or_insert_with(|| Tween::fixed(t)).set(t, now, dur, ease);
        }
        self.dirty = true;
    }

    pub fn set_workspaces(&mut self, list: Vec<i32>, focused: i32, now: Instant) {
        if list == self.workspaces && focused == self.focused {
            return;
        }
        self.ws_w.retain(|k, _| list.contains(k));
        self.workspaces = list;
        let prev = self.focused;
        self.focused = -2;
        if prev == -1 {
            self.focused = focused;
            self.ws_w.clear();
        } else {
            self.set_focused(focused, now);
        }
        self.dirty = true;
    }

    pub fn set_focus(&mut self, title: &str, class: &str, fullscreen: bool) {
        if self.title != title || self.class != class || self.hidden != fullscreen {
            self.title = title.to_owned();
            self.class = class.to_owned();
            self.hidden = fullscreen;
            self.dirty = true;
        }
    }

    fn set_service<T: PartialEq>(slot: &mut Option<T>, v: T, dirty: &mut bool) {
        if slot.as_ref() != Some(&v) {
            *slot = Some(v);
            *dirty = true;
        }
    }

    pub fn apply(&mut self, m: crate::services::Msg) {
        use crate::services::Msg;
        match m {
            Msg::Battery(b) => self.set_battery(b.present.then_some((b.pct, b.charging))),
            Msg::Wifi(w) => Self::set_service(&mut self.wifi, w, &mut self.dirty),
            Msg::Bt(b) => Self::set_service(&mut self.bt, b, &mut self.dirty),
            Msg::Volume(v) => Self::set_service(&mut self.vol, v, &mut self.dirty),
            Msg::Tray(t)
                if t != self.tray => {
                    self.tray = t;
                    self.dirty = true;
                }
            _ => {}
        }
    }

    fn set_battery(&mut self, b: Option<(i32, bool)>) {
        if b != self.battery {
            self.battery = b;
            self.dirty = true;
        }
    }

    pub fn set_rec(&mut self, r: Option<(i64, bool)>) {
        if r != self.rec {
            self.rec = r;
            self.dirty = true;
        }
    }

    fn right_specs(&self) -> Vec<Spec> {
        let wd = &self.theme.world;
        let c = &self.col;
        let mut out = Vec::new();
        if let Some((secs, paused)) = self.rec {
            let t = format!("{:02}:{:02}", secs / 60, secs % 60);
            let parts = vec![
                Part::Glyph(if paused { "\u{f03e4}" } else { "\u{f044a}" }, 13.0, c.crit),
                Part::Text(t, self.txt(13.0, wd.text_weight).tnum(true), c.text1, 0.0),
            ];
            out.push(Spec { fill: c.bg, border: wd.border, pad: self.pad(), spacing: 7.0, parts, hits: vec![(Hit::Rec, None)] });
        }
        let hidden = ["nm-applet", "blueman", "networkmanager", "xfce4-clipman"];
        let mut tparts = Vec::new();
        let mut thits = Vec::new();
        for (i, it) in self.tray.iter().enumerate() {
            let id = it.id.to_lowercase();
            if hidden.iter().any(|h| id.contains(h)) {
                continue;
            }
            if let Some(icon) = &it.icon {
                thits.push((Hit::Tray(i), Some(tparts.len())));
                tparts.push(Part::Icon(icon.clone()));
            }
        }
        if !tparts.is_empty() {
            out.push(Spec { fill: c.bg, border: wd.border, pad: self.pad(), spacing: 10.0, parts: tparts, hits: thits });
        }
        if self.stats[0] >= 0 {
            let glyphs = wd.labels_are_glyphs();
            let lst = self.txt(11.0, 700);
            let vst = self.txt(13.0, wd.text_weight).tnum(true);
            let tints = [c.blue, c.magenta, c.cyan];
            let mut parts = Vec::new();
            for (i, (&v, tint)) in self.stats.iter().zip(tints).enumerate() {
                if v < 0 {
                    continue;
                }
                let lc = if v >= 90 { c.crit } else if v >= 70 { c.warn } else { tint };
                if glyphs {
                    parts.push(Part::Glyph(wd.labels[i], 14.0, lc));
                } else {
                    parts.push(Part::Text(wd.labels[i].to_owned(), lst, lc, 0.0));
                }
                parts.push(Part::Text(v.to_string(), vst, if v >= 90 { c.crit } else { c.text1 }, 20.0));
            }
            out.push(Spec { fill: c.bg, border: wd.border, pad: 12.0, spacing: 0.0, parts: interleave(parts), hits: vec![(Hit::Stats, None)] });
        }
        if let Some(wf) = &self.wifi {
            let g = if !wf.enabled { "\u{f092e}" } else if wf.ssid.is_empty() { "\u{f092b}" }
                else if wf.strength > 66 { "\u{f0928}" } else if wf.strength > 33 { "\u{f0925}" } else { "\u{f091f}" };
            let gc = if !wf.enabled || wf.ssid.is_empty() { c.crit } else { c.text1 };
            out.push(Spec { fill: c.bg, border: wd.border, pad: self.pad(), spacing: 8.0, parts: vec![Part::Glyph(g, 15.0, gc)], hits: vec![(Hit::Wifi, None)] });
        }
        if let Some(b) = &self.bt {
            let conn = !b.connected.is_empty();
            let g = if !b.powered { "\u{f00b2}" } else if conn { "\u{f00b1}" } else { "\u{f00af}" };
            let mut parts = vec![Part::Glyph(g, 15.0, if conn { c.text1 } else { c.text3 })];
            if b.battery > 0 {
                parts.push(Part::Text(format!("{}%", b.battery), self.txt(12.0, wd.text_weight).tnum(true), c.text2, 0.0));
            }
            out.push(Spec { fill: c.bg, border: wd.border, pad: self.pad(), spacing: 8.0, parts, hits: vec![(Hit::Bluetooth, None)] });
        }
        if let Some(v) = self.vol {
            let g = if v.muted { "\u{f075f}" } else if v.level > 0.66 { "\u{f057e}" } else if v.level > 0.33 { "\u{f0580}" } else { "\u{f057f}" };
            let t = if v.muted { "MUTE".to_owned() } else { format!("{}", (v.level * 100.0).round() as i32) };
            let parts = vec![
                Part::Glyph(g, 15.0, c.text2),
                Part::Text(t, self.txt(13.0, wd.text_weight).tnum(true), if v.muted { c.crit } else { c.text1 }, 28.0),
            ];
            out.push(Spec { fill: c.bg, border: wd.border, pad: self.pad(), spacing: 7.0, parts, hits: vec![(Hit::Volume, None)] });
        }
        if let Some((pct, charging)) = self.battery {
            let hp = if charging { c.ok } else if pct <= 20 { c.crit } else if pct <= 50 { c.warn } else { c.ok };
            let mut parts = Vec::new();
            if wd.id != crate::theme::WorldId::Katha {
                parts.push(Part::Text("HP".into(), self.txt(11.0, 700), c.text2, 0.0));
            }
            parts.push(match wd.id {
                crate::theme::WorldId::Meridian => Part::Blocks(pct, hp, c.faint),
                crate::theme::WorldId::Toon => Part::Hearts(pct, if pct <= 20 { c.crit } else { c.red }, c.text3),
                crate::theme::WorldId::Katha => Part::Lamp(pct, if charging { c.on } else if pct <= 20 { c.crit } else { c.bryellow }, c.on),
                crate::theme::WorldId::Sakuga => Part::Meter(pct, hp, c.faint),
            });
            let tc = if pct <= 20 && !charging { c.crit } else { c.text1 };
            parts.push(Part::Text(format!("{pct}%{}", if charging { " +" } else { "" }), self.txt(13.0, wd.text_weight).tnum(true), tc, 0.0));
            out.push(Spec { fill: c.bg, border: wd.border, pad: self.pad(), spacing: 8.0, parts, hits: vec![(Hit::Battery, None)] });
        }
        out.push(Spec { fill: c.on, border: 0.0, pad: 9.0, spacing: 0.0, parts: vec![Part::Glyph("\u{f0425}", 15.0, c.on_text)], hits: vec![(Hit::Power, None)] });
        out
    }

    pub fn set_open_page(&mut self, p: Option<&'static str>) {
        if p != self.open_page {
            self.open_page = p;
            self.dirty = true;
        }
    }

    fn pad(&self) -> f32 {
        if self.theme.world.id == crate::theme::WorldId::Toon { 14.0 } else { 12.0 }
    }

    pub fn set_stats(&mut self, v: [i32; 3]) {
        if v != self.stats {
            self.stats = v;
            self.dirty = true;
        }
    }

    pub fn set_theme(&mut self, theme: Theme) {
        self.col = Colors::from(&theme);
        self.theme = theme;
        self.ws_w.clear();
        self.dirty = true;
    }

    fn shown_title(&self) -> String {
        let t = self.title.trim();
        let cls = self.class.to_lowercase();
        for sep in [" - ", " — ", " – "] {
            if let Some(i) = t.rfind(sep) {
                let tail = t[i + sep.len()..].to_lowercase();
                let tail_word = tail.split_whitespace().next().unwrap_or("");
                if !cls.is_empty() && !tail_word.is_empty() && (cls.contains(tail_word) || tail.contains(&cls)) {
                    return t[..i].to_owned();
                }
            }
        }
        t.to_owned()
    }

    pub fn animating(&self, now: Instant) -> bool {
        self.ws_w.values().any(|t| t.running(now))
    }

    pub fn needs_frame(&self, now: Instant) -> bool {
        self.dirty || self.animating(now)
    }

    fn txt(&self, size: f32, weight: u16) -> TextStyle {
        let w = &self.theme.world;
        TextStyle::new(w.text, size, weight)
            .italic(w.id == crate::theme::WorldId::Sakuga && weight >= 700)
            .tracking(w.tracking)
    }

    fn pill(&self, pm: &mut Pixmap, x: f32, w: f32, fill: Rgba, border: f32, hot: bool) {
        let wd = &self.theme.world;
        let h = wd.pill_h;
        let r = wd.radius.min(h / 2.0);
        let t = canvas::skew_about(wd.skew, TOP + h / 2.0);
        if wd.lift {
            canvas::fill_round(pm, x, TOP + 3.0, w, h, wd.radius, fill.darker(1.9), t);
        }
        canvas::fill_round(pm, x, TOP, w, h, r, fill, t);
        canvas::stroke_round(pm, x, TOP, w, h, r, border, if hot { self.col.line_hot } else { self.col.line }, t);
        if wd.lacquer {
            for i in 0..3 {
                let y = TOP + 6.0 + i as f32 * 8.0;
                canvas::fill_round(pm, x + r * 0.6, y, w - r * 1.2, 1.0, 0.0, self.col.on.alpha(0.22), t);
            }
        }
        if wd.lift {
            canvas::fill_round(pm, x + r * 0.6, TOP + 4.0, w - r * 1.2, 4.0, 2.0, Rgba::new(1.0, 1.0, 1.0, 0.14), t);
        }
    }

    fn pad_extra(&self) -> f32 {
        if self.theme.world.id == crate::theme::WorldId::Sakuga { 12.0 } else { 0.0 }
    }

    pub fn render(&mut self, pm: &mut Pixmap, fonts: &mut Fonts, icons: &mut crate::icons::Icons, now: Instant) -> IRect {
        let full = IRect::new(0, 0, pm.width() as i32, pm.height() as i32);
        canvas::clear(pm, full);
        self.hits.clear();
        self.pills.clear();
        if self.hidden {
            self.dirty = false;
            return full;
        }
        let h = self.theme.world.pill_h;
        let cy = TOP + h / 2.0;
        let mut x = EDGE;

        let g1 = "\u{f041d}";
        let g2 = "\u{f059f}";
        let gs = TextStyle::new(ICON_FONT, 16.0, 400);
        let (w1, w2) = (fonts.measure(g1, &gs), fonts.measure(g2, &gs));
        let lw = 10.0 * 2.0 + w1 + 12.0 + w2 + self.pad_extra();
        self.pill(pm, x, lw, self.col.on, 0.0, false);
        let gx = x + (lw - (w1 + 12.0 + w2)) / 2.0;
        fonts.draw(pm, g1, &gs, gx, cy, self.col.on_text, None);
        fonts.draw(pm, g2, &gs, gx + w1 + 12.0, cy, self.col.on_text, None);
        self.hits.push((IRect::new((gx - 8.0) as i32, TOP as i32, (w1 + 14.0) as i32, h as i32), Hit::Launcher));
        self.hits.push((IRect::new((gx + w1 + 6.0) as i32, TOP as i32, (w2 + 14.0) as i32, h as i32), Hit::Web));
        self.pills.push(IRect::new(x as i32, TOP as i32, lw.ceil() as i32, h as i32));
        x += lw + GAP;

        let widths: Vec<f32> = self
            .workspaces
            .iter()
            .map(|id| self.ws_w.get(id).map(|t| t.value(now)).unwrap_or_else(|| self.ws_target(*id)))
            .collect();
        let inner: f32 = widths.iter().sum::<f32>() + 9.0 * (self.workspaces.len().saturating_sub(1)) as f32;
        let ww = inner + 26.0 + self.pad_extra();
        let hot = matches!(self.hover, Some(Hit::Workspace(_)));
        self.pill(pm, x, ww, self.col.bg, self.theme.world.border, hot);
        let mut dx = x + (ww - inner) / 2.0;
        for (id, w) in self.workspaces.iter().zip(widths.iter()) {
            let here = *id == self.focused;
            let hovered = self.hover == Some(Hit::Workspace(*id));
            let opacity = if here { 1.0 } else if hovered { 0.85 } else { 0.5 };
            let c = if here { self.col.on } else { self.col.text2 }.alpha(opacity);
            match self.theme.world.workspace {
                WsStyle::Dash => {
                    let dh = if here { 4.0 } else { 5.0 };
                    canvas::fill_round(pm, dx, cy - dh / 2.0, *w, dh, 0.0, c, tiny_skia::Transform::identity());
                }
                WsStyle::Bubble => {
                    canvas::fill_round(pm, dx, cy - w / 2.0, *w, *w, w / 2.0, c, tiny_skia::Transform::identity());
                }
                WsStyle::Slash => {
                    let t = canvas::skew_about(-0.9, cy);
                    canvas::fill_round(pm, dx, cy - 3.0, *w, 6.0, 0.0, c, t);
                }
                WsStyle::Akshara => {
                    if here {
                        let st = TextStyle::new(self.theme.world.display, 22.0, 400);
                        let aw = fonts.measure("అ", &st);
                        fonts.draw(pm, "అ", &st, dx + (w - aw) / 2.0, cy, c, None);
                    } else {
                        canvas::fill_round(pm, dx, cy - 3.0, *w, 6.0, 3.0, c, tiny_skia::Transform::identity());
                    }
                }
            }
            self.hits.push((IRect::new((dx - 4.0) as i32, TOP as i32, (w + 8.0) as i32, h as i32), Hit::Workspace(*id)));
            dx += w + 9.0;
        }
        self.pills.push(IRect::new(x as i32, TOP as i32, ww.ceil() as i32, h as i32));
        x += ww + GAP;

        let shown = self.shown_title();
        if !shown.is_empty() && self.width / 2.0 - ISLAND_HALF - GAP - x > 120.0 {
            let gst = TextStyle::new(ICON_FONT, 14.0, 400);
            let glyph = "\u{f05af}";
            let icon = if self.class.is_empty() { None } else { icons.for_class(&self.class, 16) };
            let gw = if icon.is_some() { 16.0 } else { fonts.measure(glyph, &gst) };
            let tst = TextStyle::new(self.theme.world.text, 13.0, 500).tracking(self.theme.world.tracking);
            let cap = (self.width / 2.0 - ISLAND_HALF - GAP - x - 34.0 - gw).min(360.0);
            let tw = fonts.measure(&shown, &tst).min(cap.max(0.0));
            let bw = 13.0 + gw + 8.0 + tw + 13.0;
            let wd = &self.theme.world;
            let tr = canvas::skew_about(wd.skew, TOP + h / 2.0);
            canvas::fill_round(pm, x, TOP, bw, h, wd.radius.min(h / 2.0), self.col.bg.alpha(0.78), tr);
            if let Some(ic) = icon {
                pm.draw_pixmap((x + 13.0) as i32, (cy - 8.0) as i32, ic.as_ref(), &tiny_skia::PixmapPaint::default(), tiny_skia::Transform::identity(), None);
            } else {
                fonts.draw(pm, glyph, &gst, x + 13.0, cy, self.col.on2, None);
            }
            fonts.draw_elided(pm, &shown, &tst, x + 13.0 + gw + 8.0, cy, self.col.text1, tw);
        }

        let mut specs = self.right_specs();
        let open = self.open_page;
        let (on, on_text) = (self.col.on, self.col.on_text);
        for sp in specs.iter_mut() {
            let page = sp.hits.first().map(|(h, _)| match h {
                Hit::Wifi => "wifi",
                Hit::Bluetooth => "bt",
                Hit::Volume => "audio",
                Hit::Battery => "main",
                Hit::Power => "power",
                Hit::Rec => "record",
                _ => "",
            });
            if page.is_some() && page == open && !page.unwrap_or("").is_empty() {
                sp.fill = on;
                sp.border = 0.0;
                for p in sp.parts.iter_mut() {
                    match p {
                        Part::Glyph(_, _, c) | Part::Text(_, _, c, _) => *c = on_text,
                        _ => {}
                    }
                }
            }
        }
        let mut widths = Vec::with_capacity(specs.len());
        for sp in &specs {
            let inner: f32 = sp.parts.iter().map(|p| p.width(fonts)).sum::<f32>()
                + sp.spacing * sp.parts.len().saturating_sub(1) as f32;
            widths.push((inner, inner + sp.pad * 2.0 + self.pad_extra()));
        }
        let room = self.width / 2.0 - ISLAND_HALF - GAP - EDGE;
        let sum = |w: &[(f32, f32)]| w.iter().map(|w| w.1).sum::<f32>() + GAP * w.len().saturating_sub(1) as f32;
        for drop in [Hit::Stats, Hit::Tray(0), Hit::Bluetooth, Hit::Wifi, Hit::Volume] {
            if sum(&widths) <= room {
                break;
            }
            if let Some(i) = specs.iter().position(|sp| sp.hits.iter().any(|(k, _)| std::mem::discriminant(k) == std::mem::discriminant(&drop))) {
                specs.remove(i);
                widths.remove(i);
            }
        }
        let total: f32 = sum(&widths);
        let mut rx = self.width - EDGE - total;
        for (sp, (inner, w)) in specs.into_iter().zip(widths) {
            let hot = self.hover.map(|hh| sp.hits.iter().any(|(k, _)| *k == hh)).unwrap_or(false);
            self.pill(pm, rx, w, sp.fill, sp.border, hot);
            let mut px = rx + (w - inner) / 2.0;
            for (i, part) in sp.parts.iter().enumerate() {
                let pw = part.width(fonts);
                part.draw(pm, fonts, px, cy);
                if let Some((k, _)) = sp.hits.iter().find(|(_, idx)| *idx == Some(i)) {
                    self.hits.push((IRect::new((px - 8.0) as i32, TOP as i32, (pw + 16.0) as i32, h as i32), *k));
                }
                px += pw + sp.spacing;
            }
            if let Some((k, _)) = sp.hits.iter().find(|(_, idx)| idx.is_none()) {
                self.hits.push((IRect::new(rx as i32, TOP as i32, w as i32, h as i32), *k));
            }
            self.pills.push(IRect::new(rx as i32, TOP as i32, w.ceil() as i32, h as i32));
            rx += w + GAP;
        }

        self.dirty = false;
        full
    }

    fn hit(&self, x: f32, y: f32) -> Option<Hit> {
        self.hits.iter().find(|(r, _)| r.contains(x, y)).map(|(_, h)| *h)
    }

    pub fn motion(&mut self, x: f32, y: f32) {
        let h = self.hit(x, y);
        if h != self.hover {
            self.hover = h;
            self.dirty = true;
        }
    }

    pub fn leave(&mut self) {
        if self.hover.is_some() {
            self.hover = None;
            self.dirty = true;
        }
    }

    pub fn click(&mut self, x: f32, y: f32, button: u8, now: Instant) -> Option<Click> {
        let exec = |cmd: &str| Some(Click::I3(format!("exec --no-startup-id {cmd}")));
        match (self.hit(x, y), button) {
            (Some(Hit::Workspace(id)), 1) => {
                self.set_focused(id, now);
                Some(Click::I3(format!("workspace number {id}")))
            }
            (Some(Hit::Workspace(_)), 4 | 5) => {
                let i = self.workspaces.iter().position(|w| *w == self.focused)?;
                let n = if button == 5 { (i + 1).min(self.workspaces.len() - 1) } else { i.saturating_sub(1) };
                let id = self.workspaces[n];
                self.set_focused(id, now);
                Some(Click::I3(format!("workspace number {id}")))
            }
            (Some(Hit::Volume), 4) => {
                crate::audio::control(crate::audio::Ctl::Step(0.05));
                None
            }
            (Some(Hit::Volume), 5) => {
                crate::audio::control(crate::audio::Ctl::Step(-0.05));
                None
            }
            (Some(Hit::Volume), 2) => {
                crate::audio::control(crate::audio::Ctl::ToggleMute);
                None
            }
            (Some(Hit::Volume), 3) => exec("pavucontrol"),
            (Some(Hit::Volume), 1) => Some(Click::Page("audio")),
            (Some(Hit::Wifi), 3) => exec("nm-connection-editor"),
            (Some(Hit::Wifi), 1) => Some(Click::Page("wifi")),
            (Some(Hit::Bluetooth), 1) => Some(Click::Page("bt")),
            (Some(Hit::Bluetooth), 3) => exec("blueman-manager"),
            (Some(Hit::Tray(i)), b) => {
                let it = self.tray.get(i)?;
                let (xi, yi) = (x as i32, (TOP + self.theme.world.pill_h + 6.0) as i32);
                if b == 1 && it.id.to_lowercase().contains("zapfast") {
                    return exec("~/.local/bin/loka-zapfast");
                }
                if b == 3 {
                    return Some(Click::TrayMenu(it.key.clone(), xi));
                }
                let a = match b {
                    1 => crate::tray::Act::Activate(it.key.clone(), xi, yi),
                    _ => crate::tray::Act::Secondary(it.key.clone(), xi, yi),
                };
                crate::tray::act(a);
                None
            }
            (Some(Hit::Power), 1 | 3) => Some(Click::Page("power")),
            (Some(Hit::Rec), 1) => Some(Click::Page("record")),
            (Some(Hit::Rec), 3) => Some(Click::Record),
            (Some(Hit::Stats | Hit::Battery), 1) => Some(Click::Page("main")),
            (Some(Hit::Battery), 3) => exec("~/.config/i3/scripts/settings.sh"),
            (Some(Hit::Launcher), 1) => exec("~/.config/rofi/scripts/launcher.sh apps"),
            (Some(Hit::Web), 1) => exec("~/.config/rofi/scripts/launcher.sh web"),
            _ => None,
        }
    }

    pub fn resize(&mut self, width: u16) {
        self.width = width as f32;
        self.dirty = true;
    }

    pub fn mark_dirty(&mut self) {
        self.dirty = true;
    }
}

fn interleave(parts: Vec<Part>) -> Vec<Part> {
    let mut out = Vec::with_capacity(parts.len() * 2);
    let n = parts.len();
    for (i, p) in parts.into_iter().enumerate() {
        out.push(p);
        if i + 1 < n {
            out.push(Part::Text(String::new(), TextStyle::new(ICON_FONT, 11.0, 400), Rgba::new(0.0, 0.0, 0.0, 0.0), if i % 2 == 0 { 5.0 } else { 12.0 }));
        }
    }
    out
}

#[cfg(test)]
mod tests {
    use super::*;

    fn bar_with(title: &str, class: &str) -> Bar {
        let mut b = Bar::new(1920, crate::theme::Theme::load());
        b.set_focus(title, class, false);
        b
    }

    #[test]
    fn title_drops_app_suffix() {
        assert_eq!(bar_with("Remember the Titans | Movy - Thorium", "Thorium-browser").shown_title(), "Remember the Titans | Movy");
        assert_eq!(bar_with("tmp - Thunar", "Thunar").shown_title(), "tmp");
        assert_eq!(bar_with("notes - draft", "Mousepad").shown_title(), "notes - draft");
    }
}
