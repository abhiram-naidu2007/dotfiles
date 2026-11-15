use std::time::{Duration, Instant};

use tiny_skia::{FillRule, PathBuilder, Pixmap, Transform};

use crate::anim::{Ease, Tween};
use crate::canvas::{self, IRect};
use crate::dot;
use crate::model::Model;
use crate::text::Fonts;
use crate::theme::{Island as Pal, Theme};
use crate::ui::{Act, Hit, Slider, Ui};

pub const SURF_W: u16 = 600;
pub const SURF_H: u16 = 800;
const PANEL_W: f32 = 540.0;
const PILL_H: f32 = 38.0;
const FLARE: f32 = 12.0;
const PAD: f32 = 18.0;
const HOT_W: f32 = 160.0;

#[derive(Clone, Debug)]
pub struct Toast {
    pub glyph: String,
    pub label: String,
    pub title: String,
    pub body: String,
    pub ring: Option<f32>,
    pub notif: Option<u32>,
    pub action: Option<(String, String)>,
    pub default_action: bool,
    pub force: bool,
    pub until: Instant,
}

impl Toast {
    pub fn plain(glyph: &str, label: &str, title: &str, ring: Option<f32>, until: Instant) -> Self {
        Self {
            glyph: glyph.into(),
            label: label.into(),
            title: title.into(),
            body: String::new(),
            ring,
            notif: None,
            action: None,
            default_action: false,
            force: false,
            until,
        }
    }
}

pub enum Ev {
    Act(Act),
    Set(Slider, f32),
    Step(Slider, f32),
}

pub struct Island {
    pub pal: Pal,
    pub theme: Theme,
    pub expanded: bool,
    pub page: &'static str,
    w: Tween,
    h: Tween,
    fade: Tween,
    content: Pixmap,
    content_h: f32,
    content_dirty: bool,
    pub hits: Vec<Hit>,
    hover: u64,
    drag: Option<Hit>,
    dirty: bool,
    pub osd: Option<(&'static str, f32, bool, Instant)>,
    pub toast: Option<Toast>,
    clock: String,
    last_box: IRect,
    pub last_content_ms: f32,
    prev_clock: String,
    flip: Tween,
    pub peek: bool,
    armed: bool,
    enter_pt: Option<(f32, f32)>,
    rearm_at: Option<Instant>,
    pub date: String,
    pub media: Option<(String, String, f32)>,
    pub focus: Option<u64>,
    hidden: bool,
    stow: Tween,
}

fn ease() -> Ease {
    Ease::OutBack(1.15)
}

impl Island {
    pub fn new(theme: Theme) -> Self {
        let pal = Pal::from(&theme);
        Self {
            pal,
            theme,
            expanded: false,
            page: "main",
            w: Tween::fixed(96.0),
            h: Tween::fixed(PILL_H),
            fade: Tween::fixed(0.0),
            content: Pixmap::new(PANEL_W as u32, SURF_H as u32 - 40).expect("content buffer"),
            content_h: 0.0,
            content_dirty: true,
            hits: Vec::new(),
            hover: 0,
            drag: None,
            dirty: true,
            osd: None,
            toast: None,
            clock: String::new(),
            last_box: IRect::new(0, 0, SURF_W as i32, SURF_H as i32),
            last_content_ms: 0.0,
            prev_clock: String::new(),
            flip: Tween::fixed(1.0),
            peek: false,
            armed: true,
            enter_pt: None,
            rearm_at: None,
            date: String::new(),
            media: None,
            focus: None,
            hidden: false,
            stow: Tween::fixed(0.0),
        }
    }

    fn stowed(&self) -> bool {
        self.hidden && !self.expanded && !self.peek && self.osd.is_none() && self.toast.is_none()
    }

    pub fn set_hidden(&mut self, hidden: bool, now: Instant) {
        if self.hidden == hidden {
            return;
        }
        self.hidden = hidden;
        if hidden {
            self.toast = self.toast.take().filter(|t| t.force);
        }
        self.retarget(now);
    }

    pub fn set_theme(&mut self, t: Theme) {
        self.pal = Pal::from(&t);
        self.theme = t;
        self.content_dirty = true;
        self.dirty = true;
    }

    pub fn mark(&mut self) {
        self.content_dirty = true;
        self.dirty = true;
    }

    pub fn animating(&self, now: Instant) -> bool {
        self.w.running(now) || self.h.running(now) || self.fade.running(now) || self.flip.running(now) || self.stow.running(now)
    }

    pub fn needs_frame(&self, now: Instant) -> bool {
        self.dirty || self.animating(now)
    }

    pub fn next_wake(&self, now: Instant) -> Option<Instant> {
        let mut t: Option<Instant> = None;
        if let Some((_, _, _, at)) = self.osd {
            t = Some(at);
        }
        if let Some(to) = &self.toast {
            t = Some(t.map_or(to.until, |x| x.min(to.until)));
        }
        if let Some(at) = self.rearm_at {
            t = Some(t.map_or(at, |x| x.min(at)));
        }
        t.map(|x| x.max(now))
    }

    pub fn tick(&mut self, now: Instant, clock: &str) {
        if self.rearm_at.is_some_and(|t| now >= t) {
            self.rearm_at = None;
            self.armed = true;
        }
        if let Some((_, _, _, at)) = self.osd
            && now >= at {
                self.osd = None;
                self.retarget(now);
            }
        if let Some(Toast { until: at, .. }) = &self.toast
            && now >= *at {
                self.toast = None;
                self.retarget(now);
            }
        if clock != self.clock {
            if !self.clock.is_empty() {
                self.prev_clock = std::mem::take(&mut self.clock);
                self.flip = Tween::fixed(0.0);
                self.flip.set(1.0, now, Duration::from_millis(420), Ease::OutBack(1.4));
            }
            self.clock = clock.to_owned();
            self.retarget(now);
            self.dirty = true;
        }
    }

    fn collapsed_size(&self) -> (f32, f32) {
        if self.peek && self.osd.is_none() && self.toast.is_none() {
            return (420.0, 72.0);
        }
        if self.osd.is_some() {
            return (300.0, PILL_H);
        }
        if let Some(to) = &self.toast {
            let n = to.title.chars().count().max(to.body.chars().count()).max(to.label.chars().count()).min(56) as f32;
            let extra = if to.action.is_some() { 96.0 } else if to.ring.is_some() { 48.0 } else { 0.0 };
            return ((n * 7.6 + 96.0 + extra).clamp(240.0, 500.0), 56.0);
        }
        (dot::width(&self.clock, 14.0) + 36.0, PILL_H)
    }

    fn retarget(&mut self, now: Instant) {
        let d = Duration::from_millis(300);
        if self.expanded {
            self.w.set(PANEL_W, now, d, ease());
            self.h.set((self.content_h + PAD * 2.0).min(SURF_H as f32 - 2.0), now, d, ease());
            self.fade.set(1.0, now, Duration::from_millis(180), Ease::OutCubic);
        } else {
            let (w, h) = self.collapsed_size();
            self.w.set(w, now, d, ease());
            self.h.set(h, now, d, ease());
            self.fade.set(0.0, now, Duration::from_millis(120), Ease::OutCubic);
        }
        let stow = if self.stowed() { 1.0 } else { 0.0 };
        self.stow.set(stow, now, Duration::from_millis(260), Ease::OutCubic);
        self.dirty = true;
    }

    pub fn open(&mut self, page: &'static str, now: Instant) {
        self.peek = false;
        self.focus = None;
        if self.expanded && self.page == page {
            self.close(now);
            return;
        }
        self.page = page;
        self.expanded = true;
        self.content_dirty = true;
        self.retarget(now);
    }

    pub fn go(&mut self, page: &'static str, now: Instant) {
        self.focus = None;
        self.page = page;
        self.content_dirty = true;
        self.retarget(now);
    }

    pub fn close(&mut self, now: Instant) {
        if self.expanded {
            self.expanded = false;
            self.drag = None;
            self.retarget(now);
        }
    }

    pub fn show_osd(&mut self, kind: &'static str, v: f32, muted: bool, now: Instant) {
        if self.expanded {
            return;
        }
        self.osd = Some((kind, v, muted, now + Duration::from_millis(1400)));
        self.retarget(now);
    }

    pub fn show_toast(&mut self, title: &str, body: &str, secs: u64, now: Instant) {
        let mut t = Toast::plain("\u{f009a}", "", title, None, now + Duration::from_secs(secs));
        t.body = body.into();
        t.force = true;
        self.show(t, now);
    }

    pub fn show(&mut self, t: Toast, now: Instant) {
        if self.hidden && !t.force {
            return;
        }
        if self.expanded && t.notif.is_none() {
            self.close(now);
        } else if self.expanded {
            return;
        }
        self.peek = false;
        self.toast = Some(t);
        self.retarget(now);
    }

    fn panel_rect(&self, now: Instant) -> (f32, f32, f32) {
        let w = self.w.value(now);
        let h = self.h.value(now);
        ((SURF_W as f32 - w) / 2.0, w, h)
    }

    pub fn input_rects(&self, now: Instant) -> Vec<IRect> {
        let (x, w, h) = self.panel_rect(now);
        if self.expanded {
            vec![IRect::new(0, 0, SURF_W as i32, SURF_H as i32)]
        } else if self.stowed() {
            let hw = w.max(HOT_W);
            vec![IRect::new(((SURF_W as f32 - hw) / 2.0) as i32, 0, hw.ceil() as i32, 1)]
        } else {
            vec![IRect::new(x as i32, 0, w.ceil() as i32, h.ceil() as i32)]
        }
    }

    fn draw_shape(&self, pm: &mut Pixmap, x: f32, w: f32, h: f32, full_h: f32) {
        let r = if self.expanded || full_h > PILL_H + 4.0 { 26.0f32.min(h / 2.0) } else { (h / 2.0).min(18.0) };
        let mut pb = PathBuilder::new();
        pb.move_to(x - FLARE, 0.0);
        pb.quad_to(x, 0.0, x, FLARE.min(h));
        pb.line_to(x, h - r);
        pb.cubic_to(x, h - r * 0.45, x + r * 0.45, h, x + r, h);
        pb.line_to(x + w - r, h);
        pb.cubic_to(x + w - r * 0.45, h, x + w, h - r * 0.45, x + w, h - r);
        pb.line_to(x + w, FLARE.min(h));
        pb.quad_to(x + w, 0.0, x + w + FLARE, 0.0);
        pb.close();
        if let Some(p) = pb.finish() {
            pm.fill_path(&p, &canvas::paint(self.pal.bg), FillRule::Winding, Transform::identity(), None);
        }
    }

    fn render_content(&mut self, fonts: &mut Fonts, m: &Model, now: Instant) {
        let (cw, ch) = (self.content.width() as i32, self.content.height() as i32);
        canvas::clear(&mut self.content, IRect::new(0, 0, cw, ch));
        let mut ui = Ui {
            pm: &mut self.content,
            fonts,
            th: self.pal,
            font: "JetBrainsMono Nerd Font",
            size: 15.0,
            x: PAD,
            w: PANEL_W - PAD * 2.0,
            y: 0.0,
            hits: Vec::new(),
            hover: self.hover,
            alpha: 1.0,
        };
        crate::pages::draw(self.page, &mut ui, m, now);
        self.content_h = ui.y;
        self.hits = ui.hits;
        self.content_dirty = false;
    }

    pub fn render(&mut self, pm: &mut Pixmap, fonts: &mut Fonts, m: &Model, now: Instant) -> IRect {
        if self.content_dirty && self.expanded {
            let before = self.content_h;
            let t0 = Instant::now();
            self.render_content(fonts, m, now);
            self.last_content_ms = t0.elapsed().as_secs_f32() * 1000.0;
            if (before - self.content_h).abs() > 0.5 {
                self.retarget(now);
            }
        }
        let (x, w, full_h) = self.panel_rect(now);
        let lift = self.stow.value(now).clamp(0.0, 1.0) * (full_h + 2.0);
        let h = (full_h - lift).max(0.0);
        let bx = IRect::new((x - FLARE - 2.0).floor() as i32, 0, (w + FLARE * 2.0 + 4.0).ceil() as i32, (h + 2.0).ceil() as i32);
        let l = self.last_box;
        let x0 = bx.x.min(l.x);
        let x1 = (bx.x + bx.w).max(l.x + l.w);
        let full = IRect::new(x0, 0, x1 - x0, bx.h.max(l.h)).clip(pm.width() as i32, pm.height() as i32);
        self.last_box = bx;
        canvas::clear(pm, full);
        if h > 0.5 {
            self.draw_shape(pm, x, w, h, full_h);
        }
        let fade = self.fade.value(now);
        if fade > 0.01 && (self.expanded || self.fade.running(now)) {
            let vis = (h - PAD).max(0.0) as u32;
            if vis > 0 {
                let rows = vis.min(self.content_h.ceil() as u32 + 2);
                let ox = (x + (w - PANEL_W) / 2.0) as i32;
                canvas::blit_clip(pm, &self.content, ox, PAD as i32, rows, fade, (x + 8.0) as i32, (x + w - 8.0) as i32);
                if let Some(k) = self.focus
                    && let Some(hit) = self.hits.iter().find(|h| h.key == k)
                {
                    let r = hit.rect;
                    let (fx, fy) = (ox as f32 + r.x as f32 - 3.0, PAD + r.y as f32 - 3.0);
                    if fy + r.h as f32 + 6.0 < h {
                        canvas::stroke_round(pm, fx, fy, r.w as f32 + 6.0, r.h as f32 + 6.0, 13.0, 2.0, self.pal.on.alpha(fade), Transform::identity());
                    }
                }
            }
        }
        if !self.expanded && fade < 0.5 && h > 0.5 {
            self.draw_collapsed(pm, fonts, x, w, full_h, -lift, now);
        }
        self.dirty = false;
        full
    }

    #[allow(clippy::too_many_arguments)]
    fn draw_collapsed(&self, pm: &mut Pixmap, fonts: &mut Fonts, x: f32, w: f32, h: f32, oy: f32, now: Instant) {
        let p = self.pal;
        let cy = oy + h / 2.0;
        if let Some((kind, v, muted, _)) = self.osd {
            let g = match kind {
                "bright" => "\u{f00df}",
                "mic" => if muted { "\u{f036d}" } else { "\u{f036c}" },
                _ => if muted { "\u{f075f}" } else if v > 0.66 { "\u{f057e}" } else if v > 0.33 { "\u{f0580}" } else { "\u{f057f}" },
            };
            let st = crate::text::TextStyle::new(crate::ui::ICON, 15.0, 400);
            fonts.draw(pm, g, &st, x + 18.0, cy, p.fg, None);
            let tx = x + 46.0;
            let tw = w - 46.0 - 58.0;
            if tw > 10.0 {
                canvas::fill_round(pm, tx, cy - 3.0, tw, 6.0, 3.0, p.fg.alpha(0.16), Transform::identity());
                canvas::fill_round(pm, tx, cy - 3.0, (tw * v.clamp(0.0, 1.0)).max(6.0), 6.0, 3.0, if muted { p.muted } else { p.fg }, Transform::identity());
            }
            let t = if muted { "MUTE".to_owned() } else { format!("{}%", (v * 100.0).round() as i32) };
            let ts = crate::text::TextStyle::new("JetBrainsMono Nerd Font", 12.0, 500).tnum(true);
            let tw2 = fonts.measure(&t, &ts);
            fonts.draw(pm, &t, &ts, x + w - 16.0 - tw2, cy, p.muted, None);
            return;
        }
        if let Some(to) = &self.toast {
            let ts = crate::text::TextStyle::new("JetBrainsMono Nerd Font", 13.0, 700);
            let bs = crate::text::TextStyle::new("JetBrainsMono Nerd Font", 11.5, 400);
            let st = crate::text::TextStyle::new(crate::ui::ICON, 16.0, 400);
            canvas::fill_round(pm, x + 12.0, cy - 16.0, 32.0, 32.0, 16.0, p.fg.alpha(0.10), Transform::identity());
            let gw = fonts.measure(&to.glyph, &st);
            fonts.draw(pm, &to.glyph, &st, x + 28.0 - gw / 2.0, cy, p.fg, None);
            let right_w = if to.action.is_some() { 96.0 } else if to.ring.is_some() { 44.0 } else { 0.0 };
            let tw = w - 66.0 - right_w - 14.0;
            if !to.label.is_empty() {
                fonts.draw_elided(pm, &to.label, &bs, x + 54.0, cy - 9.0, p.muted, tw);
                fonts.draw_elided(pm, &to.title, &ts, x + 54.0, cy + 8.0, p.fg, tw);
            } else {
                fonts.draw_elided(pm, &to.title, &ts, x + 54.0, cy - 8.0, p.fg, tw);
                fonts.draw_elided(pm, &to.body.replace('\n', " "), &bs, x + 54.0, cy + 9.0, p.muted, tw);
            }
            if let Some((_, label)) = &to.action {
                let bx = x + w - 16.0 - 86.0;
                canvas::fill_round(pm, bx, cy - 14.0, 86.0, 28.0, 14.0, p.fg, Transform::identity());
                let lw = fonts.measure(label, &bs);
                fonts.draw_elided(pm, label, &bs, bx + (86.0 - lw.min(76.0)) / 2.0, cy, p.bg, 76.0);
            } else if let Some(v) = to.ring {
                let rcx = x + w - 34.0;
                ring(pm, rcx, cy, 13.0, v, p.fg);
            }
            return;
        }
        if self.peek && w > 300.0 {
            let a = ((w - 300.0) / 120.0).clamp(0.0, 1.0);
            let big = 24.0;
            dot::draw_ratio(pm, &self.clock, big, 0.1, (x + 24.0).round(), (cy - 18.0).round(), p.fg.alpha(a));
            let ds = crate::text::TextStyle::new("JetBrainsMono Nerd Font", 12.0, 400);
            fonts.draw(pm, &self.date, &ds, x + 24.0, cy + 17.0, p.muted.alpha(a), None);
            if let Some((t, ar, pos)) = &self.media {
                let right = x + w - 24.0;
                let cw = 200.0f32.min(w - 180.0);
                let ts = crate::text::TextStyle::new("JetBrainsMono Nerd Font", 12.5, 600);
                let as_ = crate::text::TextStyle::new("JetBrainsMono Nerd Font", 11.0, 400);
                let tw = fonts.measure(t, &ts).min(cw);
                fonts.draw_elided(pm, t, &ts, right - tw, cy - 13.0, p.fg.alpha(a), cw);
                let aw = fonts.measure(ar, &as_).min(cw);
                fonts.draw_elided(pm, ar, &as_, right - aw, cy + 3.0, p.muted.alpha(a), cw);
                canvas::fill_round(pm, right - 120.0, cy + 15.0, 120.0, 3.0, 1.5, p.fg.alpha(0.15 * a), Transform::identity());
                canvas::fill_round(pm, right - 120.0, cy + 15.0, 120.0 * pos.clamp(0.0, 1.0), 3.0, 1.5, p.fg.alpha(a), Transform::identity());
            }
            return;
        }
        let size = 14.0;
        let tw = dot::width(&self.clock, size);
        if w > tw + 8.0 {
            let x0 = (x + (w - tw) / 2.0).round();
            let y0 = (cy - dot::height(size) / 2.0).round();
            let t = self.flip.value(now);
            if t >= 1.0 || self.prev_clock.chars().count() != self.clock.chars().count() {
                dot::draw(pm, &self.clock, size, x0, y0, p.fg);
            } else {
                let lift = dot::height(size) + 6.0;
                let mut cx = x0;
                let (mut ab, mut bb) = ([0u8; 4], [0u8; 4]);
                for (a, b) in self.prev_clock.chars().zip(self.clock.chars()) {
                    let s = &*b.encode_utf8(&mut bb);
                    let cw = dot::char_width(b, size);
                    if a == b {
                        dot::draw(pm, s, size, cx, y0, p.fg);
                    } else {
                        dot::draw_clipped(pm, a.encode_utf8(&mut ab), size, cx, y0 - t * lift, p.fg.alpha((1.0 - t).clamp(0.0, 1.0)), y0 - 1.0, y0 + dot::height(size) + 1.0);
                        dot::draw_clipped(pm, s, size, cx, y0 + (1.0 - t) * lift, p.fg.alpha(t.clamp(0.0, 1.0)), y0 - 1.0, y0 + dot::height(size) + 1.0);
                    }
                    cx += cw + dot::pitch(size);
                }
            }
        }
    }

    pub fn motion(&mut self, x: f32, y: f32, now: Instant) -> Option<Ev> {
        if !self.expanded {
            if self.peek || self.toast.is_some() || self.osd.is_some() {
                return None;
            }
            let start = *self.enter_pt.get_or_insert((x, y));
            if !self.armed && (x - start.0).abs() + (y - start.1).abs() >= 12.0 {
                self.armed = true;
            }
            if self.armed {
                self.peek = true;
                self.rearm_at = None;
                self.retarget(now);
            }
            return None;
        }
        let (px, _, _) = self.panel_rect(now);
        let ox = px + (self.w.value(now) - PANEL_W) / 2.0;
        let (lx, ly) = (x - ox, y - PAD);
        if let Some(d) = &self.drag
            && let (Act::Slider(s), Some((tx, tw, max))) = (&d.act, d.track) {
                let v = ((lx - tx) / tw).clamp(0.0, 1.0) * max;
                return Some(Ev::Set(*s, v));
            }
        let key = self.hits.iter().rev().find(|h| h.rect.contains(lx, ly)).map(|h| h.key).unwrap_or(0);
        if key != self.hover {
            self.hover = key;
            self.mark();
        }
        None
    }

    pub fn leave_at(&mut self, now: Instant) {
        self.enter_pt = None;
        if self.peek {
            self.peek = false;
            self.armed = false;
            self.rearm_at = Some(now + Duration::from_millis(450));
            self.retarget(now);
        }
        self.leave();
    }

    pub fn leave(&mut self) {
        if self.hover != 0 {
            self.hover = 0;
            self.mark();
        }
    }

    pub fn press(&mut self, x: f32, y: f32, button: u8, now: Instant) -> Option<Ev> {
        let (px, w, h) = self.panel_rect(now);
        if !self.expanded {
            if x >= px && x <= px + w && y <= h && button == 1 {
                if let Some(to) = self.toast.take() {
                    self.retarget(now);
                    if let (Some(id), Some((key, _))) = (to.notif, &to.action)
                        && x >= px + w - 110.0 {
                            return Some(Ev::Act(Act::NotifAction(id, key.clone())));
                        }
                    if let (Some(id), true) = (to.notif, to.default_action) {
                        return Some(Ev::Act(Act::NotifAction(id, "default".into())));
                    }
                    return Some(Ev::Act(if to.notif.is_some() { Act::Page("notif") } else { Act::None }));
                }
                return Some(Ev::Act(Act::Page("main")));
            }
            return None;
        }
        if x < px || x > px + w || y > h {
            return Some(Ev::Act(Act::Close));
        }
        let ox = px + (w - PANEL_W) / 2.0;
        let (lx, ly) = (x - ox, y - PAD);
        let hit = self.hits.iter().rev().find(|h| h.rect.contains(lx, ly))?.clone();
        if button == 4 || button == 5 {
            if let Act::Slider(s) = hit.act {
                return Some(Ev::Step(s, if button == 4 { 0.05 } else { -0.05 }));
            }
            return None;
        }
        if let (Act::Slider(s), Some((tx, tw, max))) = (&hit.act, hit.track) {
            let v = ((lx - tx) / tw).clamp(0.0, 1.0) * max;
            let s = *s;
            self.drag = Some(hit);
            return Some(Ev::Set(s, v));
        }
        Some(Ev::Act(hit.act))
    }

    pub fn warm(&mut self, fonts: &mut Fonts, m: &Model, now: Instant) {
        let keep = (self.page, self.content_h, std::mem::take(&mut self.hits));
        for p in ["main", "wifi", "bt", "audio", "power", "cal", "notif", "clip", "settings", "battery", "record"] {
            self.page = p;
            self.render_content(fonts, m, now);
        }
        self.page = keep.0;
        self.content_h = keep.1;
        self.hits = keep.2;
        self.content_dirty = true;
        let st = crate::text::TextStyle::new("JetBrainsMono Nerd Font", 13.0, 700);
        let _ = fonts.measure("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789", &st);
    }

    fn focusable(&self) -> Vec<&Hit> {
        let mut v: Vec<&Hit> = Vec::new();
        for h in self.hits.iter() {
            if !matches!(h.act, Act::None) && !v.iter().any(|x| x.key == h.key) {
                v.push(h);
            }
        }
        v.sort_by_key(|a| (a.rect.y / 8, a.rect.x));
        v
    }

    pub fn move_focus(&mut self, d: i32) {
        let list = self.focusable();
        if list.is_empty() {
            return;
        }
        let n = list.len() as i32;
        let i = self.focus.and_then(|k| list.iter().position(|h| h.key == k)).map(|i| i as i32);
        let next = match i {
            Some(i) => (i + d).rem_euclid(n),
            None => if d > 0 { 0 } else { n - 1 },
        };
        self.focus = Some(list[next as usize].key);
        self.dirty = true;
    }

    pub fn focused(&self) -> Option<Hit> {
        let k = self.focus?;
        self.hits.iter().find(|h| h.key == k).cloned()
    }

    pub fn release(&mut self) {
        self.drag = None;
    }
}

fn ring(pm: &mut Pixmap, cx: f32, cy: f32, r: f32, v: f32, c: crate::canvas::Rgba) {
    let track = tiny_skia::PathBuilder::from_circle(cx, cy, r);
    let stroke = tiny_skia::Stroke { width: 3.0, line_cap: tiny_skia::LineCap::Round, ..tiny_skia::Stroke::default() };
    if let Some(t) = track {
        pm.stroke_path(&t, &canvas::paint(c.alpha(0.18)), &stroke, Transform::identity(), None);
    }
    let v = v.clamp(0.0, 1.0);
    if v <= 0.0 {
        return;
    }
    let mut pb = PathBuilder::new();
    let steps = (64.0 * v).ceil() as i32;
    for i in 0..=steps {
        let a = -std::f32::consts::FRAC_PI_2 + std::f32::consts::TAU * v * i as f32 / steps as f32;
        let (px, py) = (cx + r * a.cos(), cy + r * a.sin());
        if i == 0 {
            pb.move_to(px, py);
        } else {
            pb.line_to(px, py);
        }
    }
    if let Some(path) = pb.finish() {
        pm.stroke_path(&path, &canvas::paint(c), &stroke, Transform::identity(), None);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn island() -> (Island, Instant) {
        (Island::new(Theme::load()), Instant::now())
    }

    #[test]
    fn fullscreen_stows_to_a_top_strip() {
        let (mut i, now) = island();
        assert!(i.input_rects(now)[0].h > 1);
        i.set_hidden(true, now);
        let r = i.input_rects(now)[0];
        assert_eq!((r.y, r.h), (0, 1));
        assert!(r.w >= HOT_W as i32);
        assert_eq!(i.stow.value(now + Duration::from_secs(1)), 1.0);
        i.set_hidden(false, now);
        assert!(i.input_rects(now)[0].h > 1);
        assert_eq!(i.stow.value(now + Duration::from_secs(1)), 0.0);
    }

    #[test]
    fn fullscreen_drops_plain_toasts_and_keeps_forced_ones() {
        let (mut i, now) = island();
        i.show(Toast::plain("g", "Connected", "net", None, now + Duration::from_secs(2)), now);
        i.set_hidden(true, now);
        assert!(i.toast.is_none());
        i.show(Toast::plain("g", "Connected", "net", None, now + Duration::from_secs(2)), now);
        assert!(i.toast.is_none() && i.stowed());
        let mut t = Toast::plain("g", "Low battery", "9%", None, now + Duration::from_secs(2));
        t.force = true;
        i.show(t, now);
        assert!(i.toast.is_some() && !i.stowed());
        i.tick(now + Duration::from_secs(3), "");
        assert!(i.toast.is_none() && i.stowed());
    }

    #[test]
    fn pointer_and_keyboard_reveal_while_fullscreen() {
        let (mut i, now) = island();
        i.set_hidden(true, now);
        i.motion(300.0, 0.0, now);
        assert!(i.peek && !i.stowed());
        i.leave_at(now);
        assert!(i.stowed());
        i.open("main", now);
        assert!(i.expanded && !i.stowed());
        i.close(now);
        assert!(i.stowed());
        i.show_osd("vol", 0.5, false, now);
        assert!(!i.stowed());
    }
}
