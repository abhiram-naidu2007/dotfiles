use std::collections::HashMap;
use std::time::Instant;

use tiny_skia::{FilterQuality, Pixmap, PixmapPaint, Transform};

use crate::anim::{self, Spring, Tween};
use crate::canvas::{self, IRect};
use crate::config::home;
use crate::text::{Fonts, TextStyle};
use crate::services::{Msg, Waker};
use crate::theme::{Island, Theme, World, WorldId};

const CARD_W: f32 = 766.0;
const CARD_H: f32 = 360.0;
const SLOT: f32 = 330.0;
const DECODE_W: u32 = 620;

#[derive(Clone, Debug)]
pub struct Item {
    path: String,
    video: bool,
    thumb: String,
    name: String,
}

pub struct Walls {
    pub open: bool,
    world: WorldId,
    items: Vec<Item>,
    index: usize,
    pos: Spring,
    fade: Tween,
    current: String,
    cache: HashMap<String, Pixmap>,
    outline: Option<Pixmap>,
    hits: Vec<(IRect, WAct)>,
    dirty: bool,
    loading: bool,
    islands: [Island; 4],
    waker: Waker,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum WAct {
    Close,
    Select(usize),
    Apply,
    World(WorldId),
}

const ORDER: [WorldId; 4] = [WorldId::Meridian, WorldId::Sakuga, WorldId::Katha, WorldId::Toon];

fn wname(w: WorldId) -> &'static str {
    match w {
        WorldId::Meridian => "meridian",
        WorldId::Katha => "katha",
        WorldId::Sakuga => "sakuga",
        WorldId::Toon => "toon",
    }
}

fn title(w: WorldId) -> &'static str {
    match w {
        WorldId::Meridian => "Meridian",
        WorldId::Katha => "Katha",
        WorldId::Sakuga => "Sakuga",
        WorldId::Toon => "Toon",
    }
}

fn islands() -> [Island; 4] {
    let mut t = Theme::load();
    ORDER.map(|w| {
        t.world = World::get(w);
        Island::from(&t)
    })
}

fn slot(w: WorldId) -> usize {
    ORDER.iter().position(|x| *x == w).unwrap_or(0)
}

fn list(world: WorldId) -> Vec<Item> {
    let out = std::process::Command::new(home().join(".local/bin/rice")).args(["world-walls", wname(world)]).output().map(|o| String::from_utf8_lossy(&o.stdout).into_owned()).unwrap_or_default();
    out.lines()
        .filter_map(|l| {
            let p: Vec<&str> = l.split('|').collect();
            (p.len() >= 3).then(|| Item {
                path: p[0].to_owned(),
                video: p[1] == "video",
                thumb: p[2].to_owned(),
                name: std::path::Path::new(p[0]).file_stem().map(|s| s.to_string_lossy().replace(['-', '_'], " ")).unwrap_or_default(),
            })
        })
        .collect()
}

impl Walls {
    pub fn new(waker: Waker) -> Self {
        Self {
            open: false,
            world: WorldId::Meridian,
            items: Vec::new(),
            index: 0,
            pos: Spring::new(0.0, 0.38, 1.0),
            fade: Tween::fixed(0.0),
            current: String::new(),
            cache: HashMap::new(),
            outline: None,
            hits: Vec::new(),
            dirty: false,
            loading: false,
            islands: islands(),
            waker,
        }
    }

    pub fn show(&mut self, world: WorldId, now: Instant) {
        self.open = true;
        self.fade = Tween::fixed(0.0);
        self.fade.go(1.0, now, anim::FADE);
        self.islands = islands();
        self.load(world);
        if self.outline.is_none() {
            self.outline = crate::icons::load_scaled(&crate::config::assets().join("card-outline.png"), DECODE_W);
        }
    }

    pub fn hide(&mut self) {
        self.open = false;
        self.cache.clear();
        self.outline = None;
        self.items.clear();
    }

    fn load(&mut self, world: WorldId) {
        self.world = world;
        self.current = std::fs::read_to_string(home().join(format!(".local/state/rice/world-{}", wname(world)))).unwrap_or_default().trim().to_owned();
        self.items.clear();
        self.cache.clear();
        self.loading = true;
        self.dirty = true;
        let w = self.waker.clone();
        std::thread::spawn(move || w.send(Msg::WallItems(world, list(world))));
    }

    pub fn set_items(&mut self, world: WorldId, items: Vec<Item>) {
        if !self.open || world != self.world {
            return;
        }
        self.items = items;
        self.loading = false;
        self.index = self.items.iter().position(|i| i.path == self.current).unwrap_or(0);
        self.pos.snap(self.index as f32);
        self.dirty = true;
    }

    pub fn needs_frame(&self, now: Instant) -> bool {
        self.open && (self.dirty || self.pos.running(now) || self.fade.running(now))
    }

    pub fn step(&mut self, d: i32, now: Instant) {
        if self.items.is_empty() {
            return;
        }
        let n = self.items.len() as i32;
        self.index = (self.index as i32 + d).clamp(0, n - 1) as usize;
        self.pos.set(self.index as f32, now);
        self.dirty = true;
    }

    pub fn world_step(&mut self, d: i32) {
        self.load(ORDER[(slot(self.world) as i32 + d).rem_euclid(4) as usize]);
    }

    fn warm_thumb(&mut self, i: usize) {
        let Some(key) = self.items.get(i).map(|it| &it.thumb) else { return };
        if self.cache.contains_key(key) {
            return;
        }
        if self.cache.len() > 9 {
            let near = &self.items[self.index.saturating_sub(3)..(self.index + 4).min(self.items.len())];
            self.cache.retain(|k, _| near.iter().any(|it| &it.thumb == k));
        }
        if let Some(p) = crate::icons::load_scaled(std::path::Path::new(key), DECODE_W) {
            self.cache.insert(key.clone(), p);
        }
    }

    pub fn render(&mut self, pm: &mut Pixmap, fonts: &mut Fonts, now: Instant) -> IRect {
        let (w, h) = (pm.width() as f32, pm.height() as f32);
        let full = IRect::new(0, 0, w as i32, h as i32);
        canvas::clear(pm, full);
        self.hits.clear();
        let th = self.islands[slot(self.world)];
        let fade = self.fade.value(now);
        canvas::fill_round(pm, 0.0, 0.0, w, h, 0.0, th.bg.alpha(0.55 * fade), Transform::identity());
        self.hits.push((full, WAct::Close));

        let disp = World::get(self.world).display;
        let tab_st = TextStyle::new(if self.world == WorldId::Katha { "Ramaraja" } else { disp }, 17.0, 600);
        let mut widths = Vec::new();
        for wd in ORDER {
            widths.push(fonts.measure(title(wd), &tab_st) + 36.0);
        }
        let total: f32 = widths.iter().sum::<f32>() + 8.0 * 3.0;
        let mut tx = (w - total) / 2.0;
        let ty = h / 2.0 - 290.0;
        for (i, wd) in ORDER.into_iter().enumerate() {
            let p = self.islands[i];
            let on = wd == self.world;
            let tw = widths[i];
            canvas::fill_round(pm, tx, ty, tw, 40.0, 20.0, if on { p.on } else { p.bg.alpha(0.85) }.alpha(fade), Transform::identity());
            if !on {
                canvas::stroke_round(pm, tx, ty, tw, 40.0, 20.0, 1.0, p.fg.alpha(0.18 * fade), Transform::identity());
            }
            let st = TextStyle::new(World::get(wd).display, 17.0, if on { 600 } else { 500 });
            let lw = fonts.measure(title(wd), &st);
            fonts.draw(pm, title(wd), &st, tx + (tw - lw) / 2.0, ty + 20.0, if on { p.bg } else { p.fg }.alpha(fade), None);
            self.hits.push((IRect::new(tx as i32, ty as i32, tw as i32, 40), WAct::World(wd)));
            tx += tw + 8.0;
        }

        let cy = h / 2.0 + 20.0;
        let pos = self.pos.value(now);
        let mut order: Vec<usize> = (0..self.items.len()).filter(|i| (*i as f32 - pos).abs() < 4.5).collect();
        order.sort_by(|a, b| (*b as f32 - pos).abs().total_cmp(&(*a as f32 - pos).abs()));
        for &i in &order {
            self.warm_thumb(i);
        }
        for i in order {
            let d = i as f32 - pos;
            let ad = d.abs();
            let sc = if ad <= 1.0 { 0.56 + 0.44 * (1.0 - ad).powf(1.35) } else { 0.56 * 0.86f32.powf(ad - 1.0) };
            let op = (1.15 - 0.34 * ad).clamp(0.0, 1.0) * fade;
            let cx = w / 2.0 + d * SLOT;
            let cw = CARD_W * sc;
            let chh = CARD_H * sc;
            let x0 = cx - cw / 2.0;
            let y0 = cy - chh / 2.0;
            let video = self.items[i].video;
            let is_cur = self.items[i].path == self.current;
            if let Some(t) = self.cache.get(&self.items[i].thumb) {
                let k = cw / t.width() as f32;
                let paint = PixmapPaint { opacity: op, quality: FilterQuality::Bilinear, ..PixmapPaint::default() };
                pm.draw_pixmap(0, 0, t.as_ref(), &paint, Transform::from_row(k, 0.0, 0.0, k, x0, y0), None);
            }
            if ad < 0.5
                && let Some(o) = &self.outline {
                    let k = cw / o.width() as f32;
                    let paint = PixmapPaint { opacity: 0.9 * fade, quality: FilterQuality::Bilinear, ..PixmapPaint::default() };
                    pm.draw_pixmap(0, 0, o.as_ref(), &paint, Transform::from_row(k, 0.0, 0.0, k, x0, y0), None);
                }
            let bst = TextStyle::new("JetBrainsMono Nerd Font", 11.0 * sc.max(0.7), 700).tracking(1.2);
            if video {
                let lw = fonts.measure("LIVE", &bst) + 16.0;
                let bx = x0 + cw - lw - 30.0 * sc;
                canvas::fill_round(pm, bx, y0 + 16.0 * sc, lw, 22.0, 11.0, th.on.alpha(op), Transform::identity());
                fonts.draw(pm, "LIVE", &bst, bx + 8.0, y0 + 16.0 * sc + 11.0, th.bg.alpha(op), None);
            }
            if is_cur {
                let lw = fonts.measure("NOW", &bst) + 16.0;
                let bx = x0 + 150.0 * sc;
                canvas::fill_round(pm, bx, y0 + 16.0 * sc, lw, 22.0, 11.0, th.bg.alpha(0.85 * op), Transform::identity());
                fonts.draw(pm, "NOW", &bst, bx + 8.0, y0 + 16.0 * sc + 11.0, th.fg.alpha(op), None);
            }
            let act = if ad < 0.5 { WAct::Apply } else { WAct::Select(i) };
            self.hits.push((IRect::new(x0 as i32, y0 as i32, cw as i32, chh as i32), act));
        }

        let name = match self.items.get(self.index) {
            Some(i) => i.name.clone(),
            None if self.loading => "Loading…".to_owned(),
            None => format!("No wallpapers in ~/dotfiles/wallpaper/{}", wname(self.world)),
        };
        let nst = TextStyle::new(disp, 20.0, 600);
        let nw = fonts.measure(&name, &nst);
        fonts.draw(pm, &name, &nst, (w - nw) / 2.0, h / 2.0 + 262.0, th.fg.alpha(fade), None);
        let hint = "←→ wallpaper    ↑↓ / Tab world    Enter set    Esc close";
        let hst = TextStyle::new("JetBrainsMono Nerd Font", 12.0, 400);
        let hw = fonts.measure(hint, &hst);
        fonts.draw(pm, hint, &hst, (w - hw) / 2.0, h / 2.0 + 290.0, th.fg.alpha(0.6 * fade), None);
        self.dirty = false;
        full
    }

    pub fn press(&self, x: f32, y: f32) -> Option<WAct> {
        self.hits.iter().rev().find(|(r, _)| r.contains(x, y)).map(|(_, a)| *a)
    }

    pub fn act(&mut self, a: WAct, now: Instant) -> Option<(&'static str, String)> {
        match a {
            WAct::Close => {
                self.hide();
                None
            }
            WAct::Select(i) => {
                let d = i as i32 - self.index as i32;
                self.step(d, now);
                None
            }
            WAct::Apply => {
                let pick = self.items.get(self.index).map(|it| (wname(self.world), it.path.clone()));
                self.hide();
                pick
            }
            WAct::World(wd) => {
                self.load(wd);
                None
            }
        }
    }

    pub fn world_from_name(n: &str) -> WorldId {
        match n {
            "katha" => WorldId::Katha,
            "sakuga" => WorldId::Sakuga,
            "toon" => WorldId::Toon,
            _ => WorldId::Meridian,
        }
    }
}
