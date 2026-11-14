use std::time::{Duration, Instant};

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Ease {
    Linear,
    InOutSine,
    OutCubic,
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

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn eases_hit_endpoints() {
        for e in [Ease::Linear, Ease::InOutSine, Ease::OutCubic, Ease::OutBack(1.7), Ease::OutElastic] {
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
}
