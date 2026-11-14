use tiny_skia::{Pixmap, Transform};

use crate::canvas::{self, IRect, Rgba};
use crate::text::{Fonts, TextStyle};
use crate::theme::Island;

pub const ICON: &str = "JetBrainsMono Nerd Font";

#[derive(Clone, Debug, PartialEq)]
pub enum Act {
    None,
    Page(&'static str),
    Back,
    Close,
    Cmd(String),
    Exec(Vec<String>),
    WifiToggle,
    WifiScan,
    WifiPick(String),
    WifiConnectTyped,
    WifiForget(String),
    BtToggle,
    BtScan,
    BtDevice(String),
    Coffee,
    Profile(&'static str),
    Media(&'static str),
    Sink(String),
    Source(String),
    MuteOut,
    MuteIn,
    MuteStream(u32),
    Slider(Slider),
    ClipCopy(String),
    ClipDelete(String),
    ClipClear,
    NotifDismiss(u32),
    NotifAction(u32, String),
    NotifClear,
    Dnd,
    CalShift(i32),
    Power(&'static str),
    Record,
    RecPause,
    RecSys,
    RecMic,
    RecMicDev(String),
    TrayOpen(String, i32),
    LiveToggle,
    MoodToggle,
    Clock24,
    Seconds,
    Sounds,
    ToastSecs(u64),
    TermOpacity(u8),
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Slider {
    Volume,
    Mic,
    Bright,
    Stream(u32),
}

#[derive(Clone, Debug)]
pub struct Hit {
    pub rect: IRect,
    pub act: Act,
    pub key: u64,
    pub track: Option<(f32, f32, f32)>,
}

pub struct Ui<'a> {
    pub pm: &'a mut Pixmap,
    pub fonts: &'a mut Fonts,
    pub th: Island,
    pub font: String,
    pub size: f32,
    pub x: f32,
    pub w: f32,
    pub y: f32,
    pub hits: Vec<Hit>,
    pub hover: u64,
    pub alpha: f32,
}

pub fn key_of(a: &Act) -> u64 {
    use std::hash::{Hash, Hasher};
    let mut h = std::collections::hash_map::DefaultHasher::new();
    format!("{a:?}").hash(&mut h);
    h.finish()
}

impl<'a> Ui<'a> {
    pub fn txt(&self, size: f32, weight: u16) -> TextStyle {
        TextStyle::new(&self.font, size, weight)
    }

    pub fn icon_style(size: f32) -> TextStyle {
        TextStyle::new(ICON, size, 400)
    }

    fn c(&self, c: Rgba) -> Rgba {
        c.alpha(self.alpha)
    }

    pub fn hit(&mut self, r: IRect, act: Act) -> bool {
        let key = key_of(&act);
        let hot = key == self.hover && act != Act::None;
        if act != Act::None {
            self.hits.push(Hit { rect: r, act, key, track: None });
        }
        hot
    }

    pub fn rect(&mut self, x: f32, y: f32, w: f32, h: f32, r: f32, fill: Rgba) {
        let f = self.c(fill);
        canvas::fill_round(self.pm, x, y, w, h, r, f, Transform::identity());
    }

    pub fn stroke(&mut self, x: f32, y: f32, w: f32, h: f32, r: f32, c: Rgba) {
        let f = self.c(c);
        canvas::stroke_round(self.pm, x, y, w, h, r, 1.0, f, Transform::identity());
    }

    pub fn text(&mut self, s: &str, st: &TextStyle, x: f32, cy: f32, c: Rgba) -> f32 {
        let col = self.c(c);
        self.fonts.draw(self.pm, s, st, x, cy, col, None)
    }

    pub fn text_max(&mut self, s: &str, st: &TextStyle, x: f32, cy: f32, c: Rgba, max: f32) -> f32 {
        let col = self.c(c);
        self.fonts.draw_elided(self.pm, s, st, x, cy, col, max)
    }

    pub fn text_right(&mut self, s: &str, st: &TextStyle, right: f32, cy: f32, c: Rgba) -> f32 {
        let w = self.fonts.measure(s, st);
        self.text(s, st, right - w, cy, c);
        w
    }

    pub fn text_center(&mut self, s: &str, st: &TextStyle, cx: f32, cy: f32, c: Rgba) {
        let w = self.fonts.measure(s, st);
        self.text(s, st, cx - w / 2.0, cy, c);
    }

    pub fn glyph(&mut self, g: &str, size: f32, x: f32, cy: f32, c: Rgba) -> f32 {
        let st = Self::icon_style(size);
        self.text(g, &st, x, cy, c)
    }

    pub fn glyph_center(&mut self, g: &str, size: f32, cx: f32, cy: f32, c: Rgba) {
        let st = Self::icon_style(size);
        self.text_center(g, &st, cx, cy, c);
    }

    pub fn measure(&mut self, s: &str, st: &TextStyle) -> f32 {
        self.fonts.measure(s, st)
    }

    pub fn space(&mut self, h: f32) {
        self.y += h;
    }

    pub fn label(&mut self, s: &str) {
        let st = self.txt(self.size - 4.0, 700).tracking(1.0);
        let up = s.to_uppercase();
        let cy = self.y + 8.0;
        let m = self.th.muted;
        self.text(&up, &st, self.x + 2.0, cy, m);
        self.y += 20.0;
    }

    pub fn header(&mut self, title: &str, right: Option<(&'static str, Act)>) {
        let h = 30.0;
        let cy = self.y + h / 2.0;
        let back = IRect::new(self.x as i32, self.y as i32, 30, 30);
        let hot = self.hit(back, Act::Back);
        let (fg, hv) = (self.th.fg, self.th.hover);
        if hot {
            self.rect(self.x, self.y, 30.0, 30.0, 15.0, hv);
        }
        self.glyph_center("\u{f004d}", 14.0, self.x + 15.0, cy, fg);
        let st = self.txt(self.size - 2.0, 700);
        self.text(title, &st, self.x + 40.0, cy, fg);
        if let Some((g, act)) = right {
            let rx = self.x + self.w - 30.0;
            let hot = self.hit(IRect::new(rx as i32, self.y as i32, 30, 30), act);
            if hot {
                self.rect(rx, self.y, 30.0, 30.0, 15.0, hv);
            }
            self.glyph_center(g, 14.0, rx + 15.0, cy, fg);
        }
        self.y += h + 10.0;
    }

    pub fn card(&mut self, x: f32, y: f32, w: f32, h: f32, active: bool, hot: bool) {
        let th = self.th;
        let fill = if active { th.on.alpha(0.18) } else if hot { th.fg.alpha(0.10) } else { th.fg.alpha(0.055) };
        self.rect(x, y, w, h, 14.0, fill);
        self.stroke(x, y, w, h, 14.0, if active { th.on.alpha(0.45) } else { th.line });
    }

    pub fn row(&mut self, glyph: &str, title: &str, sub: &str, right: &str, active: bool, act: Act) {
        let h = if sub.is_empty() { 40.0 } else { 48.0 };
        let (x, y, w) = (self.x, self.y, self.w);
        let hot = self.hit(IRect::new(x as i32, y as i32, w as i32, h as i32), act);
        let th = self.th;
        if active || hot {
            self.rect(x, y, w, h, 12.0, if active { th.on.alpha(0.14) } else { th.hover });
        }
        let cy = y + h / 2.0;
        self.glyph(glyph, 15.0, x + 12.0, cy, if active { th.on } else { th.fg });
        let tst = self.txt(self.size - 3.0, if active { 700 } else { 500 });
        let rw = if right.is_empty() { 0.0 } else { self.measure(right, &Self::icon_style(13.0)) + 12.0 };
        if sub.is_empty() {
            self.text_max(title, &tst, x + 40.0, cy, th.fg, w - 52.0 - rw);
        } else {
            self.text_max(title, &tst, x + 40.0, cy - 8.0, th.fg, w - 52.0 - rw);
            let sst = self.txt(self.size - 5.0, 400);
            self.text_max(sub, &sst, x + 40.0, cy + 9.0, th.muted, w - 52.0 - rw);
        }
        if !right.is_empty() {
            let st = Self::icon_style(13.0);
            self.text_right(right, &st, x + w - 12.0, cy, if active { th.on } else { th.muted });
        }
        self.y += h + 2.0;
    }

    pub fn slider(&mut self, glyph: &str, glyph_act: Act, value: f32, max: f32, which: Slider, right: &str) {
        let h = 34.0;
        let (x, y, w) = (self.x, self.y, self.w);
        let cy = y + h / 2.0;
        let th = self.th;
        self.hit(IRect::new(x as i32, y as i32, 30, h as i32), glyph_act);
        self.glyph_center(glyph, 16.0, x + 14.0, cy, th.fg);
        let rw = if right.is_empty() { 0.0 } else { 46.0 };
        let tx = x + 36.0;
        let tw = w - 36.0 - rw - 6.0;
        let pos = (value / max).clamp(0.0, 1.0);
        self.rect(tx, cy - 3.0, tw, 6.0, 3.0, th.fg.alpha(0.12));
        self.rect(tx, cy - 3.0, (tw * pos).max(6.0), 6.0, 3.0, th.on);
        if max > 1.0 {
            self.rect(tx + tw / max - 1.0, cy - 6.0, 2.0, 12.0, 0.0, th.fg.alpha(0.35));
        }
        let kx = tx + tw * pos;
        self.rect(kx - 8.0, cy - 8.0, 16.0, 16.0, 8.0, Rgba::new(1.0, 1.0, 1.0, 1.0));
        self.stroke(kx - 8.0, cy - 8.0, 16.0, 16.0, 8.0, th.bg);
        let act = Act::Slider(which);
        let key = key_of(&act);
        self.hits.push(Hit { rect: IRect::new((tx - 8.0) as i32, y as i32, (tw + 16.0) as i32, h as i32), act, key, track: Some((tx, tw, max)) });
        if !right.is_empty() {
            let st = self.txt(self.size - 3.0, 400);
            self.text_right(right, &st, x + w, cy, th.muted);
        }
        self.y += h + 4.0;
    }

    #[allow(clippy::too_many_arguments)]
    pub fn button(&mut self, x: f32, y: f32, w: f32, h: f32, glyph: &str, label: &str, on: bool, act: Act) {
        let hot = self.hit(IRect::new(x as i32, y as i32, w as i32, h as i32), act);
        self.card(x, y, w, h, on, hot);
        let th = self.th;
        let st = self.txt(self.size - 4.0, 500);
        let gw = if glyph.is_empty() { 0.0 } else { self.measure(glyph, &Self::icon_style(13.0)) + 6.0 };
        let lw = self.measure(label, &st);
        let sx = x + (w - gw - lw) / 2.0;
        let cy = y + h / 2.0;
        if !glyph.is_empty() {
            self.glyph(glyph, 13.0, sx, cy, if on { th.on } else { th.fg });
        }
        self.text(label, &st, sx + gw, cy, th.fg);
    }

    pub fn toggle(&mut self, label: &str, glyph: &str, on: bool, act: Act) {
        let h = 40.0;
        let (x, y, w) = (self.x, self.y, self.w);
        let hot = self.hit(IRect::new(x as i32, y as i32, w as i32, h as i32), act);
        self.card(x, y, w, h, false, hot);
        let th = self.th;
        let cy = y + h / 2.0;
        self.glyph(glyph, 15.0, x + 12.0, cy, th.fg);
        let st = self.txt(self.size - 3.0, 500);
        self.text(label, &st, x + 40.0, cy, th.fg);
        let sx = x + w - 52.0;
        self.rect(sx, cy - 11.0, 40.0, 22.0, 11.0, if on { th.on } else { th.fg.alpha(0.16) });
        let kx = if on { sx + 20.0 } else { sx + 2.0 };
        self.rect(kx, cy - 9.0, 18.0, 18.0, 9.0, if on { th.fg_on(th.on) } else { th.fg.alpha(0.7) });
        self.y += h + 6.0;
    }

    pub fn note(&mut self, s: &str) {
        let st = self.txt(self.size - 4.0, 400);
        let th = self.th;
        let cy = self.y + 10.0;
        self.text_max(s, &st, self.x + 4.0, cy, th.muted, self.w - 8.0);
        self.y += 22.0;
    }
}
