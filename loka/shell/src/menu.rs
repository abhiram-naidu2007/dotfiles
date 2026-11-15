use tiny_skia::{Pixmap, Transform};

use crate::canvas::{self, IRect};
use crate::text::{Fonts, TextStyle};
use crate::theme::Island;
use crate::tray::MenuItem;

pub const W: f32 = 270.0;
const ROW: f32 = 34.0;
const SEP: f32 = 11.0;
const PAD: f32 = 7.0;

pub struct Menu {
    pub key: String,
    pub path: String,
    stack: Vec<Vec<MenuItem>>,
    hits: Vec<(IRect, Option<usize>)>,
    pub hover: Option<usize>,
}

pub enum Pick {
    Back,
    Run(i32),
    Open(usize),
    None,
}

impl Menu {
    pub fn new(key: String, path: String, items: Vec<MenuItem>) -> Self {
        Self { key, path, stack: vec![items], hits: Vec::new(), hover: None }
    }

    fn items(&self) -> &[MenuItem] {
        self.stack.last().map(|v| v.as_slice()).unwrap_or(&[])
    }

    pub fn height(&self) -> f32 {
        let back = if self.stack.len() > 1 { ROW } else { 0.0 };
        PAD * 2.0 + back + self.items().iter().map(|i| if i.separator { SEP } else { ROW }).sum::<f32>()
    }

    pub fn render(&mut self, pm: &mut Pixmap, fonts: &mut Fonts, th: &Island) -> IRect {
        let full = IRect::new(0, 0, pm.width() as i32, pm.height() as i32);
        canvas::clear(pm, full);
        let h = self.height();
        canvas::fill_round(pm, 0.5, 0.5, W - 1.0, h - 1.0, 14.0, th.bg, Transform::identity());
        canvas::stroke_round(pm, 0.5, 0.5, W - 1.0, h - 1.0, 14.0, 1.0, th.fg.alpha(0.14), Transform::identity());
        self.hits.clear();
        let st = TextStyle::new("JetBrainsMono Nerd Font", 12.5, 500);
        let gs = TextStyle::new("JetBrainsMono Nerd Font", 13.0, 400);
        let mut y = PAD;
        if self.stack.len() > 1 {
            let hot = self.hover == Some(usize::MAX);
            if hot {
                canvas::fill_round(pm, PAD, y, W - PAD * 2.0, ROW, 9.0, th.hover, Transform::identity());
            }
            fonts.draw(pm, "\u{f004d}", &gs, PAD + 10.0, y + ROW / 2.0, th.muted, None);
            fonts.draw(pm, "Back", &st, PAD + 32.0, y + ROW / 2.0, th.muted, None);
            self.hits.push((IRect::new(PAD as i32, y as i32, (W - PAD * 2.0) as i32, ROW as i32), Some(usize::MAX)));
            y += ROW;
        }
        let items = self.stack.last().map(|v| v.as_slice()).unwrap_or(&[]);
        for (i, it) in items.iter().enumerate() {
            if it.separator {
                canvas::fill_round(pm, PAD + 8.0, y + SEP / 2.0, W - PAD * 2.0 - 16.0, 1.0, 0.0, th.fg.alpha(0.12), Transform::identity());
                y += SEP;
                continue;
            }
            let hot = self.hover == Some(i) && it.enabled;
            if hot {
                canvas::fill_round(pm, PAD, y, W - PAD * 2.0, ROW, 9.0, th.hover, Transform::identity());
            }
            let c = if it.enabled { th.fg } else { th.muted };
            let mut tx = PAD + 12.0;
            if let Some(on) = it.toggle {
                fonts.draw(pm, if on { "\u{f0135}" } else { "\u{f0131}" }, &gs, tx, y + ROW / 2.0, if on { th.on } else { th.muted }, None);
                tx += 22.0;
            }
            fonts.draw_elided(pm, &it.label, &st, tx, y + ROW / 2.0, c, W - tx - 30.0);
            if !it.children.is_empty() {
                fonts.draw(pm, "\u{f0142}", &gs, W - PAD - 22.0, y + ROW / 2.0, th.muted, None);
            }
            self.hits.push((IRect::new(PAD as i32, y as i32, (W - PAD * 2.0) as i32, ROW as i32), Some(i)));
            y += ROW;
        }
        full
    }

    pub fn motion(&mut self, x: f32, y: f32) -> bool {
        let h = self.hits.iter().find(|(r, _)| r.contains(x, y)).and_then(|(_, i)| *i);
        let changed = h != self.hover;
        self.hover = h;
        changed
    }

    pub fn pick(&self, x: f32, y: f32) -> Pick {
        match self.hits.iter().find(|(r, _)| r.contains(x, y)).and_then(|(_, i)| *i) {
            Some(usize::MAX) => Pick::Back,
            Some(i) => {
                let it = &self.items()[i];
                if !it.enabled {
                    Pick::None
                } else if it.children.is_empty() {
                    Pick::Run(it.id)
                } else {
                    Pick::Open(i)
                }
            }
            None => Pick::None,
        }
    }

    pub fn enter(&mut self, i: usize) {
        if let Some(c) = self.items().get(i).map(|it| it.children.clone()) {
            self.stack.push(c);
            self.hover = None;
        }
    }

    pub fn back(&mut self) {
        if self.stack.len() > 1 {
            self.stack.pop();
            self.hover = None;
        }
    }
}
