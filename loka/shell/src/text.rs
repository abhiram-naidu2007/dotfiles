use std::collections::HashMap;
use std::path::PathBuf;

use cosmic_text::{Attrs, Buffer, Family, FeatureTag, FontFeatures, FontSystem, Metrics, Shaping, Style, SwashCache, SwashContent, Weight, fontdb};
use tiny_skia::Pixmap;

use crate::canvas::{self, Rgba};

#[derive(Clone, Debug, PartialEq, Eq, Hash)]
pub struct TextStyle {
    pub family: String,
    pub size_tenths: u32,
    pub weight: u16,
    pub italic: bool,
    pub tracking_cpx: i32,
    pub tnum: bool,
}

impl TextStyle {
    pub fn new(family: &str, size: f32, weight: u16) -> Self {
        Self { family: family.to_owned(), size_tenths: (size * 10.0).round() as u32, weight, italic: false, tracking_cpx: 0, tnum: false }
    }

    pub fn tracking(mut self, px: f32) -> Self {
        self.tracking_cpx = (px * 100.0).round() as i32;
        self
    }

    pub fn tnum(mut self, on: bool) -> Self {
        self.tnum = on;
        self
    }

    pub fn italic(mut self, on: bool) -> Self {
        self.italic = on;
        self
    }

    pub fn size(&self) -> f32 {
        self.size_tenths as f32 / 10.0
    }
}

pub struct Shaped {
    buf: Buffer,
    pub width: f32,
    pub height: f32,
}

pub struct Fonts {
    sys: FontSystem,
    cache: SwashCache,
    shaped: HashMap<(String, TextStyle), Shaped>,
}

fn font_files() -> Vec<PathBuf> {
    let home = std::env::var_os("HOME").map(PathBuf::from).unwrap_or_default();
    let user = home.join(".local/share/fonts");
    let mut v = vec![
        user.join("JetBrainsMonoNerdFont-Regular.ttf"),
        user.join("JetBrainsMonoNerdFont-Medium.ttf"),
        user.join("JetBrainsMonoNerdFont-Bold.ttf"),
        user.join("loka/InterTight[wght].ttf"),
        user.join("loka/telugu/AnekTelugu[wdth,wght].ttf"),
        user.join("loka/telugu/Ramaraja-Regular.ttf"),
        user.join("loka/MPLUSRounded1c-Bold.ttf"),
        user.join("loka/MPLUSRounded1c-Medium.ttf"),
        PathBuf::from("/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf"),
    ];
    for f in ["InterDisplay-Regular.otf", "InterDisplay-Medium.otf", "InterDisplay-SemiBold.otf", "InterDisplay-Bold.otf"] {
        v.push(PathBuf::from("/usr/share/fonts/opentype/inter").join(f));
    }
    v
}

impl Fonts {
    pub fn new() -> Self {
        let mut db = fontdb::Database::new();
        for f in font_files() {
            if f.exists() {
                let _ = db.load_font_file(&f);
            }
        }
        let sys = FontSystem::new_with_locale_and_db("en-US".into(), db);
        Self { sys, cache: SwashCache::new(), shaped: HashMap::new() }
    }

    fn shape(&mut self, text: &str, st: &TextStyle) -> &Shaped {
        let key = (text.to_owned(), st.clone());
        if !self.shaped.contains_key(&key) {
            if self.shaped.len() > 1024 {
                self.shaped.clear();
            }
            let size = st.size();
            let mut buf = Buffer::new(&mut self.sys, Metrics::new(size, (size * 1.3).ceil()));
            let mut features = FontFeatures::new();
            if st.tnum {
                features.enable(FeatureTag::new(b"tnum"));
            }
            let attrs = Attrs::new()
                .family(Family::Name(&st.family))
                .weight(Weight(st.weight))
                .style(if st.italic { Style::Italic } else { Style::Normal })
                .letter_spacing(st.tracking_cpx as f32 / 100.0 / size)
                .font_features(features);
            buf.set_size(None, None);
            buf.set_text(text, &attrs, Shaping::Advanced, None);
            buf.shape_until_scroll(&mut self.sys, false);
            let mut width: f32 = 0.0;
            let mut height: f32 = size * 1.3;
            for run in buf.layout_runs() {
                width = width.max(run.line_w);
                height = run.line_height;
            }
            self.shaped.insert(key.clone(), Shaped { buf, width, height });
        }
        &self.shaped[&key]
    }

    pub fn measure(&mut self, text: &str, st: &TextStyle) -> f32 {
        self.shape(text, st).width
    }

    #[allow(clippy::too_many_arguments)]
    pub fn draw(&mut self, pm: &mut Pixmap, text: &str, st: &TextStyle, x: f32, center_y: f32, color: Rgba, max_w: Option<f32>) -> f32 {
        let key = (text.to_owned(), st.clone());
        self.shape(text, st);
        let Fonts { sys, cache, shaped } = self;
        let s = &shaped[&key];
        let top = (center_y - s.height / 2.0).round();
        let limit = max_w.map(|m| x + m);
        for run in s.buf.layout_runs() {
            for g in run.glyphs.iter() {
                if let Some(l) = limit
                    && x + g.x + g.w > l {
                        return s.width.min(max_w.unwrap_or(f32::MAX));
                    }
                let phys = g.physical((x, top), 1.0);
                let Some(img) = cache.get_image(sys, phys.cache_key) else { continue };
                let gx = phys.x + img.placement.left;
                let gy = run.line_y as i32 + phys.y - img.placement.top;
                let (w, h) = (img.placement.width as i32, img.placement.height as i32);
                match img.content {
                    SwashContent::Mask => canvas::blend_mask(pm, gx, gy, w, h, &img.data, color),
                    SwashContent::Color => canvas::blend_rgba(pm, gx, gy, w, h, &img.data, color.a),
                    SwashContent::SubpixelMask => {}
                }
            }
        }
        s.width
    }

    #[allow(clippy::too_many_arguments)]
    pub fn draw_elided(&mut self, pm: &mut Pixmap, text: &str, st: &TextStyle, x: f32, center_y: f32, color: Rgba, max_w: f32) -> f32 {
        let full = self.measure(text, st);
        if full <= max_w + 0.5 {
            return self.draw(pm, text, st, x, center_y, color, None);
        }
        let ell = "…";
        let room = (max_w - self.measure(ell, st)).max(0.0);
        let key = (text.to_owned(), st.clone());
        let mut cut = 0usize;
        if let Some(sh) = self.shaped.get(&key) {
            for run in sh.buf.layout_runs() {
                for g in run.glyphs.iter() {
                    if g.x + g.w <= room {
                        cut = cut.max(g.end);
                    }
                }
            }
        }
        let mut t = text.get(..cut).unwrap_or("").trim_end().to_owned();
        t.push_str(ell);
        self.draw(pm, &t, st, x, center_y, color, None)
    }
}

