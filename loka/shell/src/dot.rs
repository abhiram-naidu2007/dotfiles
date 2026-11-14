use tiny_skia::{Pixmap, Transform};

use crate::canvas::{self, Rgba};

fn glyph(c: char) -> Option<[&'static str; 7]> {
    Some(match c {
        '0' => ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
        '1' => ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
        '2' => ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
        '3' => ["11111", "00010", "00100", "00010", "00001", "10001", "01110"],
        '4' => ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
        '5' => ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
        '6' => ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
        '7' => ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
        '8' => ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
        '9' => ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
        ':' => ["0", "0", "1", "0", "0", "1", "0"],
        '.' => ["0", "0", "0", "0", "0", "0", "1"],
        '-' => ["000", "000", "000", "111", "000", "000", "000"],
        '%' => ["11001", "11010", "00100", "00100", "00100", "01011", "10011"],
        '°' => ["111", "101", "111", "000", "000", "000", "000"],
        ' ' => ["00", "00", "00", "00", "00", "00", "00"],
        'A' | 'a' => ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
        'P' | 'p' => ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
        'M' | 'm' => ["10001", "11011", "10101", "10001", "10001", "10001", "10001"],
        _ => return None,
    })
}

pub fn pitch(size: f32) -> f32 {
    (size / 7.0).round().max(1.0)
}

pub fn metrics(size: f32) -> (f32, f32) {
    metrics_r(size, 0.22)
}

pub fn metrics_r(size: f32, ratio: f32) -> (f32, f32) {
    let p = pitch(size);
    let gap = if p >= 3.0 { (p * ratio).round() } else { 0.0 };
    (p - gap, gap)
}

fn cols(c: char) -> usize {
    glyph(c).map(|g| g[0].len()).unwrap_or(3)
}

pub fn char_width(c: char, size: f32) -> f32 {
    let p = pitch(size);
    cols(c) as f32 * p - metrics(size).1
}

pub fn width(text: &str, size: f32) -> f32 {
    let p = pitch(size);
    let n = text.chars().count();
    if n == 0 {
        return 0.0;
    }
    let total: usize = text.chars().map(cols).sum();
    total as f32 * p + (n - 1) as f32 * p - metrics(size).1
}

pub fn height(size: f32) -> f32 {
    7.0 * pitch(size) - metrics(size).1
}

pub fn draw(pm: &mut Pixmap, text: &str, size: f32, x: f32, y: f32, color: Rgba) {
    draw_clipped(pm, text, size, x, y, color, f32::MIN, f32::MAX);
}

pub fn draw_ratio(pm: &mut Pixmap, text: &str, size: f32, ratio: f32, x: f32, y: f32, color: Rgba) {
    draw_inner(pm, text, size, ratio, x, y, color, f32::MIN, f32::MAX);
}

#[allow(clippy::too_many_arguments)]
pub fn draw_clipped(pm: &mut Pixmap, text: &str, size: f32, x: f32, y: f32, color: Rgba, top: f32, bottom: f32) {
    draw_inner(pm, text, size, 0.22, x, y, color, top, bottom);
}

#[allow(clippy::too_many_arguments)]
fn draw_inner(pm: &mut Pixmap, text: &str, size: f32, ratio: f32, x: f32, y: f32, color: Rgba, top: f32, bottom: f32) {
    let p = pitch(size);
    let (dot, _) = metrics_r(size, ratio);
    let r = if dot >= 3.0 { dot * 0.3 } else { 0.0 };
    let (x, y) = (x.round(), y.round());
    let mut cx = x;
    let n = text.chars().count();
    for (i, ch) in text.chars().enumerate() {
        if let Some(g) = glyph(ch) {
            for (row, line) in g.iter().enumerate() {
                let py = y + row as f32 * p;
                if py < top || py + dot > bottom {
                    continue;
                }
                for (c, b) in line.bytes().enumerate() {
                    if b == b'1' {
                        canvas::fill_round(pm, cx + c as f32 * p, py, dot, dot, r, color, Transform::identity());
                    }
                }
            }
        }
        cx += cols(ch) as f32 * p;
        if i + 1 < n {
            cx += p;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn width_grows_with_text() {
        assert_eq!(width("", 14.0), 0.0);
        assert!(width("12:34", 14.0) > width("1:3", 14.0));
        assert_eq!(height(14.0), 14.0);
        assert_eq!(metrics(14.0), (2.0, 0.0));
    }
}
