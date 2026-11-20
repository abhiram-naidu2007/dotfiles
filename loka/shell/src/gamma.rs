//! Night light: warm the screen through the RandR CRTC gamma ramps, so no extra program
//! (redshift, xsct) has to run. Strength follows a daily window with 30 min fades.

use std::sync::atomic::{AtomicU32, Ordering};

use x11rb::connection::Connection;
use x11rb::protocol::randr::ConnectionExt as _;

/// Last strength sent, in thousandths, so a minute tick with no change costs nothing.
static LAST: AtomicU32 = AtomicU32::new(u32::MAX);

/// RGB gains of a black body at `k` kelvin, relative to 6500 K (Tanner Helland's fit).
pub fn kelvin(k: u32) -> (f32, f32, f32) {
    let t = k.clamp(1000, 6500) as f32 / 100.0;
    let r = 1.0;
    let g = (0.390_081_58 * t.ln() - 0.631_841_4).clamp(0.0, 1.0);
    let b = if t <= 19.0 { 0.0 } else { (0.543_206_8 * (t - 10.0).ln() - 1.196_254_1).clamp(0.0, 1.0) };
    (r, g, b)
}

/// How strong the night light is at `minute` of the day (0..1440) for a window from
/// `from` to `to` o'clock; the window may pass midnight. 30 min fades at both ends.
pub fn strength(minute: u32, from: u8, to: u8) -> f32 {
    let (a, b) = (from as i32 * 60, to as i32 * 60);
    let m = minute as i32;
    let ramp = 30.0;
    // minutes since the window opened, and until it closes, wrapping at midnight
    let since = (m - a).rem_euclid(1440) as f32;
    let len = (b - a).rem_euclid(1440) as f32;
    if since >= len {
        // outside: fading out during the 30 min after the end
        let after = since - len;
        return (1.0 - after / ramp).clamp(0.0, 1.0) * if after < ramp { 1.0 } else { 0.0 };
    }
    // inside: fading in during the first 30 min
    (since / ramp).clamp(0.0, 1.0)
}

/// Set every CRTC to `s` (0 = neutral) of the `k` kelvin tint. Runs on its own thread
/// and its own X connection; failures are ignored (a missing RandR leaves the screen as is).
pub fn apply(s: f32, k: u32) {
    let key = (s.clamp(0.0, 1.0) * 1000.0).round() as u32;
    let prev = LAST.swap(key, Ordering::Relaxed);
    // never touched yet and asked for neutral: leave any existing calibration alone
    if prev == key || (prev == u32::MAX && key == 0) {
        return;
    }
    std::thread::spawn(move || {
        let _ = set(key as f32 / 1000.0, k);
    });
}

fn set(s: f32, k: u32) -> Result<(), Box<dyn std::error::Error>> {
    let (conn, screen) = x11rb::connect(None)?;
    let root = conn.setup().roots[screen].root;
    let res = conn.randr_get_screen_resources_current(root)?.reply()?;
    let (kr, kg, kb) = kelvin(k);
    let gain = |c: f32| 1.0 + (c - 1.0) * s;
    let (gr, gg, gb) = (gain(kr), gain(kg), gain(kb));
    for crtc in res.crtcs {
        let n = conn.randr_get_crtc_gamma_size(crtc)?.reply()?.size as usize;
        if n < 2 {
            continue;
        }
        let ramp = |g: f32| -> Vec<u16> { (0..n).map(|i| ((i as f32 / (n - 1) as f32) * g * 65535.0).round() as u16).collect() };
        conn.randr_set_crtc_gamma(crtc, &ramp(gr), &ramp(gg), &ramp(gb))?;
    }
    conn.flush()?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn window_and_fades() {
        // 20:00 to 07:00
        assert_eq!(strength(12 * 60, 20, 7), 0.0);
        assert_eq!(strength(20 * 60, 20, 7), 0.0);
        assert!((strength(20 * 60 + 15, 20, 7) - 0.5).abs() < 1e-3);
        assert_eq!(strength(23 * 60, 20, 7), 1.0);
        assert_eq!(strength(3 * 60, 20, 7), 1.0);
        assert!((strength(7 * 60 + 15, 20, 7) - 0.5).abs() < 1e-3);
        assert_eq!(strength(8 * 60, 20, 7), 0.0);
    }

    #[test]
    fn warm_is_red_heavy() {
        let (r, g, b) = kelvin(3400);
        assert!(r >= g && g > b && b > 0.3);
        let (_, g, b) = kelvin(6500);
        assert!(g > 0.95 && b > 0.95);
    }
}
