use tiny_skia::{Color, FillRule, Paint, Path, PathBuilder, Pixmap, Rect, Stroke, Transform};

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct IRect {
    pub x: i32,
    pub y: i32,
    pub w: i32,
    pub h: i32,
}

impl IRect {
    pub const fn new(x: i32, y: i32, w: i32, h: i32) -> Self {
        Self { x, y, w, h }
    }

    pub fn clip(self, width: i32, height: i32) -> Self {
        let x0 = self.x.clamp(0, width);
        let y0 = self.y.clamp(0, height);
        let x1 = (self.x + self.w).clamp(0, width);
        let y1 = (self.y + self.h).clamp(0, height);
        Self { x: x0, y: y0, w: x1 - x0, h: y1 - y0 }
    }

    pub fn contains(self, px: f32, py: f32) -> bool {
        px >= self.x as f32 && py >= self.y as f32 && px < (self.x + self.w) as f32 && py < (self.y + self.h) as f32
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Rgba {
    pub r: f32,
    pub g: f32,
    pub b: f32,
    pub a: f32,
}

impl Rgba {
    pub const fn new(r: f32, g: f32, b: f32, a: f32) -> Self {
        Self { r, g, b, a }
    }

    pub fn hex(s: &str) -> Option<Self> {
        let s = s.trim().trim_start_matches('#');
        let v = |i: usize| u8::from_str_radix(s.get(i..i + 2)?, 16).ok().map(|x| x as f32 / 255.0);
        match s.len() {
            6 => Some(Self::new(v(0)?, v(2)?, v(4)?, 1.0)),
            8 => Some(Self::new(v(2)?, v(4)?, v(6)?, v(0)?)),
            _ => None,
        }
    }

    pub fn alpha(self, a: f32) -> Self {
        Self { a: self.a * a, ..self }
    }

    /// Blend towards `o` by `t` (0 = self, 1 = o), in premultiplied alpha so a fade from
    /// transparent keeps the hue of `o` instead of passing through black.
    pub fn mix(self, o: Self, t: f32) -> Self {
        let t = t.clamp(0.0, 1.0);
        let a = self.a + (o.a - self.a) * t;
        if a <= 0.0 {
            return Self { a: 0.0, ..o };
        }
        let ch = |x: f32, y: f32| (x * self.a + (y * o.a - x * self.a) * t) / a;
        Self { r: ch(self.r, o.r), g: ch(self.g, o.g), b: ch(self.b, o.b), a }
    }

    pub fn darker(self, f: f32) -> Self {
        Self { r: self.r / f, g: self.g / f, b: self.b / f, a: self.a }
    }


    pub fn luma(self) -> f32 {
        0.2126 * self.r + 0.7152 * self.g + 0.0722 * self.b
    }

    fn sk(self) -> Color {
        Color::from_rgba(self.r.clamp(0.0, 1.0), self.g.clamp(0.0, 1.0), self.b.clamp(0.0, 1.0), self.a.clamp(0.0, 1.0))
            .unwrap_or(Color::TRANSPARENT)
    }
}

pub fn paint(c: Rgba) -> Paint<'static> {
    let mut p = Paint::default();
    p.set_color(c.sk());
    p.anti_alias = true;
    p
}

pub fn rounded(x: f32, y: f32, w: f32, h: f32, r: f32) -> Option<Path> {
    let r = r.min(w / 2.0).min(h / 2.0).max(0.0);
    if r <= 0.01 {
        return Some(PathBuilder::from_rect(Rect::from_xywh(x, y, w, h)?));
    }
    let k = 0.552_284_8 * r;
    let mut pb = PathBuilder::new();
    pb.move_to(x + r, y);
    pb.line_to(x + w - r, y);
    pb.cubic_to(x + w - r + k, y, x + w, y + r - k, x + w, y + r);
    pb.line_to(x + w, y + h - r);
    pb.cubic_to(x + w, y + h - r + k, x + w - r + k, y + h, x + w - r, y + h);
    pb.line_to(x + r, y + h);
    pb.cubic_to(x + r - k, y + h, x, y + h - r + k, x, y + h - r);
    pb.line_to(x, y + r);
    pb.cubic_to(x, y + r - k, x + r - k, y, x + r, y);
    pb.close();
    pb.finish()
}

pub fn skew_about(skew: f32, cy: f32) -> Transform {
    if skew == 0.0 {
        Transform::identity()
    } else {
        Transform::from_row(1.0, 0.0, skew, 1.0, -skew * cy, 0.0)
    }
}

#[allow(clippy::too_many_arguments)]
pub fn fill_round(pm: &mut Pixmap, x: f32, y: f32, w: f32, h: f32, r: f32, c: Rgba, t: Transform) {
    if c.a <= 0.0 {
        return;
    }
    if let Some(p) = rounded(x, y, w, h, r) {
        pm.fill_path(&p, &paint(c), FillRule::Winding, t, None);
    }
}

#[allow(clippy::too_many_arguments)]
pub fn stroke_round(pm: &mut Pixmap, x: f32, y: f32, w: f32, h: f32, r: f32, width: f32, c: Rgba, t: Transform) {
    if width <= 0.0 || c.a <= 0.0 {
        return;
    }
    let half = width / 2.0;
    if let Some(p) = rounded(x + half, y + half, w - width, h - width, (r - half).max(0.0)) {
        let s = Stroke { width, ..Stroke::default() };
        pm.stroke_path(&p, &paint(c), &s, t, None);
    }
}

pub fn clear(pm: &mut Pixmap, r: IRect) {
    let w = pm.width() as i32;
    let r = r.clip(w, pm.height() as i32);
    let data = pm.data_mut();
    for row in r.y..r.y + r.h {
        let a = (row * w + r.x) as usize * 4;
        data[a..a + r.w as usize * 4].fill(0);
    }
}

pub fn blend_mask(pm: &mut Pixmap, x0: i32, y0: i32, w: i32, h: i32, mask: &[u8], c: Rgba) {
    let pw = pm.width() as i32;
    let ph = pm.height() as i32;
    let (cr, cg, cb, ca) = (c.r * 255.0, c.g * 255.0, c.b * 255.0, c.a);
    let data = pm.data_mut();
    for j in 0..h {
        let y = y0 + j;
        if y < 0 || y >= ph {
            continue;
        }
        for i in 0..w {
            let x = x0 + i;
            if x < 0 || x >= pw {
                continue;
            }
            let m = mask[(j * w + i) as usize] as f32 / 255.0 * ca;
            if m <= 0.0 {
                continue;
            }
            let o = ((y * pw + x) * 4) as usize;
            let inv = 1.0 - m;
            data[o] = (cr * m + data[o] as f32 * inv) as u8;
            data[o + 1] = (cg * m + data[o + 1] as f32 * inv) as u8;
            data[o + 2] = (cb * m + data[o + 2] as f32 * inv) as u8;
            data[o + 3] = (255.0 * m + data[o + 3] as f32 * inv) as u8;
        }
    }
}

pub fn blend_rgba(pm: &mut Pixmap, x0: i32, y0: i32, w: i32, h: i32, rgba: &[u8], opacity: f32) {
    let pw = pm.width() as i32;
    let ph = pm.height() as i32;
    let data = pm.data_mut();
    for j in 0..h {
        let y = y0 + j;
        if y < 0 || y >= ph {
            continue;
        }
        for i in 0..w {
            let x = x0 + i;
            if x < 0 || x >= pw {
                continue;
            }
            let s = ((j * w + i) * 4) as usize;
            let a = rgba[s + 3] as f32 / 255.0 * opacity;
            if a <= 0.0 {
                continue;
            }
            let o = ((y * pw + x) * 4) as usize;
            let inv = 1.0 - a;
            for k in 0..3 {
                data[o + k] = (rgba[s + k] as f32 * a + data[o + k] as f32 * inv) as u8;
            }
            data[o + 3] = (255.0 * a + data[o + 3] as f32 * inv) as u8;
        }
    }
}

#[allow(clippy::too_many_arguments)]
pub fn blit_clip(dst: &mut Pixmap, src: &Pixmap, dx: i32, dy: i32, rows: u32, opacity: f32, clip_x0: i32, clip_x1: i32) {
    blit_clip_from(dst, src, dx, dy, 0, rows, opacity, clip_x0, clip_x1);
}

/// Like `blit_clip`, starting `sy` rows down in `src` (a scrolled view).
#[allow(clippy::too_many_arguments)]
pub fn blit_clip_from(dst: &mut Pixmap, src: &Pixmap, dx: i32, dy: i32, sy: i32, rows: u32, opacity: f32, clip_x0: i32, clip_x1: i32) {
    let (dw, dh) = (dst.width() as i32, dst.height() as i32);
    let sw = src.width() as i32;
    let sy = sy.clamp(0, src.height() as i32);
    let rows = (rows as i32).min(src.height() as i32 - sy);
    let x0 = dx.max(0).max(clip_x0);
    let x1 = (dx + sw).min(dw).min(clip_x1);
    if x1 <= x0 {
        return;
    }
    let sx0 = (x0 - dx) as usize;
    let n = (x1 - x0) as usize;
    let op = (opacity.clamp(0.0, 1.0) * 256.0) as u32;
    let solid = op >= 256;
    let s = src.data();
    let d = dst.data_mut();
    for j in 0..rows {
        let y = dy + j;
        if y < 0 || y >= dh {
            continue;
        }
        let so = ((j + sy) as usize * sw as usize + sx0) * 4;
        let doff = (y as usize * dw as usize + x0 as usize) * 4;
        let srow = &s[so..so + n * 4];
        let drow = &mut d[doff..doff + n * 4];
        for (dp, sp) in drow.as_chunks_mut::<4>().0.iter_mut().zip(srow.as_chunks::<4>().0.iter()) {
            let a = sp[3];
            if a == 0 {
                continue;
            }
            if solid && a == 255 {
                dp.copy_from_slice(sp);
                continue;
            }
            let sa = if solid { a as u32 } else { (a as u32 * op) >> 8 };
            let inv = 255 - sa;
            for k in 0..3 {
                let sc = if solid { sp[k] as u32 } else { (sp[k] as u32 * op) >> 8 };
                dp[k] = (sc + (dp[k] as u32 * inv + 127) / 255).min(255) as u8;
            }
            dp[3] = (sa + (dp[3] as u32 * inv + 127) / 255).min(255) as u8;
        }
    }
}
