use std::time::{Duration, Instant};

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Ease {
    Linear,
    InOutSine,
    OutCubic,
    OutQuint,
    OutExpo,
    OutBack(f32),
    OutElastic,
}

impl Ease {
    pub fn at(self, t: f32) -> f32 {
        let t = t.clamp(0.0, 1.0);
        match self {
            Ease::Linear => t,
            Ease::InOutSine => -((std::f32::consts::PI * t).cos() - 1.0) / 2.0,
            Ease::OutCubic => 1.0 - (1.0 - t).powi(3),
            Ease::OutQuint => 1.0 - (1.0 - t).powi(5),
            Ease::OutExpo => {
                if t >= 1.0 {
                    1.0
                } else {
                    1.0 - 2f32.powf(-10.0 * t)
                }
            }
            Ease::OutBack(s) => {
                let u = t - 1.0;
                1.0 + (s + 1.0) * u * u * u + s * u * u
            }
            Ease::OutElastic => {
                if t == 0.0 || t == 1.0 {
                    t
                } else {
                    let p = 0.3;
                    2f32.powf(-10.0 * t) * ((t - p / 4.0) * (2.0 * std::f32::consts::PI) / p).sin() + 1.0
                }
            }
        }
    }
}

/// One curve and one duration, chosen by what moves. Every animation in the shell picks
/// one of these, so the whole shell moves the same way. The curves slow down into the
/// target and never pass it; overshoot (OutBack, OutElastic) is kept for small touches.
#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Motion {
    pub dur: Duration,
    pub ease: Ease,
}

/// Colour, opacity, hover: things that change but do not travel.
pub const FADE: Motion = Motion { dur: Duration::from_millis(150), ease: Ease::OutCubic };
/// Short moves: a pill grows, a marker slides to the next workspace.
#[allow(dead_code)] // part of the set; nothing uses it yet
pub const STANDARD: Motion = Motion { dur: Duration::from_millis(250), ease: Ease::OutQuint };
/// Long moves across the screen: a panel slides away, a page changes.
pub const SLOW: Motion = Motion { dur: Duration::from_millis(400), ease: Ease::OutExpo };

#[derive(Clone, Copy, Debug)]
pub struct Tween {
    from: f32,
    to: f32,
    start: Instant,
    dur: Duration,
    ease: Ease,
}

impl Tween {
    pub fn fixed(v: f32) -> Self {
        Self { from: v, to: v, start: Instant::now(), dur: Duration::ZERO, ease: Ease::Linear }
    }


    pub fn set(&mut self, to: f32, now: Instant, dur: Duration, ease: Ease) {
        if (to - self.to).abs() < f32::EPSILON {
            return;
        }
        self.from = self.value(now);
        self.to = to;
        self.start = now;
        self.dur = dur;
        self.ease = ease;
    }

    /// Same as `set`, with one of the motion tokens.
    pub fn go(&mut self, to: f32, now: Instant, m: Motion) {
        self.set(to, now, m.dur, m.ease);
    }

    pub fn value(&self, now: Instant) -> f32 {
        if self.dur.is_zero() {
            return self.to;
        }
        let t = now.saturating_duration_since(self.start).as_secs_f32() / self.dur.as_secs_f32();
        if t >= 1.0 {
            self.to
        } else {
            self.from + (self.to - self.from) * self.ease.at(t)
        }
    }

    pub fn running(&self, now: Instant) -> bool {
        !self.dur.is_zero() && now.saturating_duration_since(self.start) < self.dur
    }
}

/// A damped spring, solved in closed form, so `value` needs no mutable state and no
/// fixed time step. A new target keeps the speed the value has at that instant: a panel
/// that is reopened while it closes turns round smoothly instead of stopping and
/// starting again, which a Tween cannot do.
#[derive(Clone, Copy, Debug)]
pub struct Spring {
    /// The target the value moves to.
    to: f32,
    /// Distance from the target and speed (units per second) at `start`.
    d0: f32,
    v0: f32,
    start: Instant,
    /// Angular frequency (rad/s) and damping ratio (1 = no overshoot).
    w: f32,
    zeta: f32,
    /// The value counts as settled when it is closer than this to the target.
    eps: f32,
}

impl Spring {
    /// `response`: seconds for one swing of the undamped spring, about the time the move
    /// takes. `zeta`: damping ratio. 1.0 settles without overshoot, 0.8 passes the target
    /// by about 1.5% and comes back.
    pub fn new(v: f32, response: f32, zeta: f32) -> Self {
        Self {
            to: v,
            d0: 0.0,
            v0: 0.0,
            start: Instant::now(),
            w: std::f32::consts::TAU / response.max(0.01),
            zeta: zeta.clamp(0.05, 1.0),
            eps: 1e-3,
        }
    }

    /// Distance from the target and speed, `t` seconds after `start`.
    fn state(&self, t: f32) -> (f32, f32) {
        let (w, z, d0, v0) = (self.w, self.zeta, self.d0, self.v0);
        if z >= 0.999 {
            let e = (-w * t).exp();
            let b = v0 + w * d0;
            ((d0 + b * t) * e, (v0 - w * t * b) * e)
        } else {
            let wd = w * (1.0 - z * z).sqrt();
            let e = (-z * w * t).exp();
            let b = (v0 + z * w * d0) / wd;
            let (s, c) = (wd * t).sin_cos();
            let d = e * (d0 * c + b * s);
            let v = e * ((b * wd - z * w * d0) * c - (d0 * wd + z * w * b) * s);
            (d, v)
        }
    }

    fn at(&self, now: Instant) -> (f32, f32) {
        self.state(now.saturating_duration_since(self.start).as_secs_f32())
    }

    pub fn set(&mut self, to: f32, now: Instant) {
        if (to - self.to).abs() < f32::EPSILON {
            return;
        }
        let (d, v) = if self.running(now) { self.at(now) } else { (0.0, 0.0) };
        self.set_from(self.to + d, v, to, now);
    }

    /// Like `set`, with a new response and damping from now on. The motion so far keeps
    /// its position and speed, so a spring can close faster than it opened.
    pub fn set_with(&mut self, to: f32, now: Instant, response: f32, zeta: f32) {
        if (to - self.to).abs() < f32::EPSILON {
            return;
        }
        let (d, v) = if self.running(now) { self.at(now) } else { (0.0, 0.0) };
        let x = self.to + d;
        self.w = std::f32::consts::TAU / response.max(0.01);
        self.zeta = zeta.clamp(0.05, 1.0);
        self.set_from(x, v, to, now);
    }

    fn set_from(&mut self, x: f32, v: f32, to: f32, now: Instant) {
        self.d0 = x - to;
        self.v0 = v;
        self.to = to;
        self.start = now;
        // settle at 1/500 of the distance travelled, never finer than a thousandth
        self.eps = (self.d0.abs() * 0.002).max(1e-3);
    }

    /// Jump to `v` with no motion.
    pub fn snap(&mut self, v: f32) {
        self.to = v;
        self.d0 = 0.0;
        self.v0 = 0.0;
    }

    pub fn value(&self, now: Instant) -> f32 {
        if !self.running(now) {
            return self.to;
        }
        self.to + self.at(now).0
    }

    pub fn running(&self, now: Instant) -> bool {
        if self.d0 == 0.0 && self.v0 == 0.0 {
            return false;
        }
        let (d, v) = self.at(now);
        d.abs() > self.eps || v.abs() > self.eps * self.w
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn eases_hit_endpoints() {
        for e in [Ease::Linear, Ease::InOutSine, Ease::OutCubic, Ease::OutQuint, Ease::OutExpo, Ease::OutBack(1.7), Ease::OutElastic] {
            assert!((e.at(0.0)).abs() < 1e-4, "{e:?} at 0");
            assert!((e.at(1.0) - 1.0).abs() < 1e-4, "{e:?} at 1");
        }
    }

    #[test]
    fn out_back_overshoots() {
        let peak = (0..100).map(|i| Ease::OutBack(2.2).at(i as f32 / 100.0)).fold(0.0f32, f32::max);
        assert!(peak > 1.0);
    }

    #[test]
    fn tween_reaches_target() {
        let t0 = Instant::now();
        let mut t = Tween::fixed(0.0);
        t.set(10.0, t0, Duration::from_millis(100), Ease::Linear);
        assert!((t.value(t0 + Duration::from_millis(50)) - 5.0).abs() < 0.01);
        assert_eq!(t.value(t0 + Duration::from_millis(200)), 10.0);
        assert!(!t.running(t0 + Duration::from_millis(200)));
    }

    #[test]
    fn tokens_never_overshoot() {
        for m in [FADE, STANDARD, SLOW] {
            let mut prev = 0.0;
            for i in 0..=200 {
                let v = m.ease.at(i as f32 / 200.0);
                assert!(v <= 1.0 + 1e-6 && v >= prev - 1e-6, "{m:?} at {i}");
                prev = v;
            }
        }
    }

    #[test]
    fn spring_settles_on_target() {
        let t0 = Instant::now();
        for zeta in [0.7, 0.85, 1.0] {
            let mut s = Spring::new(0.0, 0.4, zeta);
            s.set(300.0, t0);
            assert!(s.running(t0 + Duration::from_millis(50)));
            let mid = s.value(t0 + Duration::from_millis(100));
            assert!(mid > 0.0 && mid < 300.0, "zeta {zeta}: {mid}");
            let end = t0 + Duration::from_secs(2);
            assert!(!s.running(end), "zeta {zeta} still running");
            assert_eq!(s.value(end), 300.0);
        }
    }

    #[test]
    fn spring_starts_where_it_is() {
        let t0 = Instant::now();
        let mut s = Spring::new(0.0, 0.4, 0.85);
        s.set(100.0, t0);
        let t1 = t0 + Duration::from_millis(120);
        let here = s.value(t1);
        s.set(0.0, t1);
        assert!((s.value(t1) - here).abs() < 1e-3);
        // still moving towards 100 for a moment: the speed is kept, not dropped
        assert!(s.value(t1 + Duration::from_millis(8)) > here);
    }

    #[test]
    fn critical_spring_never_overshoots() {
        let t0 = Instant::now();
        let mut s = Spring::new(0.0, 0.4, 1.0);
        s.set(50.0, t0);
        for i in 0..200 {
            assert!(s.value(t0 + Duration::from_millis(i * 5)) <= 50.0 + 1e-3);
        }
    }

    #[test]
    fn set_with_keeps_position() {
        let t0 = Instant::now();
        let mut s = Spring::new(0.0, 0.4, 0.85);
        s.set(100.0, t0);
        let t1 = t0 + Duration::from_millis(100);
        let here = s.value(t1);
        s.set_with(0.0, t1, 0.25, 1.0);
        assert!((s.value(t1) - here).abs() < 1e-3);
        assert!(!s.running(t1 + Duration::from_secs(1)));
    }
}
