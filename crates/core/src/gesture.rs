//! Nod and shake from the head tracking stream.
//! A gesture is at least three swings back and forth of 7 degrees or more within two seconds,
//! on one axis clearly more than on the other. Looking down and up again is only two swings,
//! so it does not count.

use std::collections::VecDeque;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Gesture {
    Nod,
    Shake,
}

const WINDOW: f32 = 2.0;
const SWING: f32 = 7.0;
const QUIET: f32 = 2.0;

#[derive(Default)]
pub struct Detector {
    samples: VecDeque<(f32, f32, f32)>,
    quiet_until: f32,
}

/// Yaw and pitch in degrees from the raw head packet values, as the head view computes them.
pub fn angles(v: [i16; 5]) -> (f32, f32) {
    let (a, b) = (v[1] as f32, v[2] as f32);
    ((a - b) / 2.0 / 32000.0 * 180.0, (a + b) / 2.0 / 32000.0 * 180.0)
}

/// How many times the signal turns around after moving at least `min` degrees.
fn swings(v: impl Iterator<Item = f32>, min: f32) -> (u32, f32) {
    let mut count = 0;
    let (mut lo, mut hi) = (f32::MAX, f32::MIN);
    let mut ext: Option<f32> = None;
    let mut dir = 0i8;
    for x in v {
        lo = lo.min(x);
        hi = hi.max(x);
        let Some(e) = ext else {
            ext = Some(x);
            continue;
        };
        match dir {
            0 if (x - e).abs() >= min => {
                dir = if x > e { 1 } else { -1 };
                count = 1;
                ext = Some(x);
            }
            0 => {}
            1 if x > e => ext = Some(x),
            -1 if x < e => ext = Some(x),
            d if (x - e).abs() >= min => {
                dir = -d;
                count += 1;
                ext = Some(x);
            }
            _ => {}
        }
    }
    (count, if hi > lo { hi - lo } else { 0.0 })
}

impl Detector {
    /// Feed one sample, `t` in seconds.
    pub fn feed(&mut self, t: f32, yaw: f32, pitch: f32) -> Option<Gesture> {
        // the rest of a gesture that already fired must not fire it again
        if t < self.quiet_until {
            return None;
        }
        self.samples.push_back((t, yaw, pitch));
        while self.samples.front().is_some_and(|s| t - s.0 > WINDOW) {
            self.samples.pop_front();
        }
        let (ys, yr) = swings(self.samples.iter().map(|s| s.1), SWING);
        let (ps, pr) = swings(self.samples.iter().map(|s| s.2), SWING);
        let g = if ys >= 3 && yr > pr * 1.5 {
            Gesture::Shake
        } else if ps >= 3 && pr > yr * 1.5 {
            Gesture::Nod
        } else {
            return None;
        };
        self.samples.clear();
        self.quiet_until = t + QUIET;
        Some(g)
    }

    pub fn reset(&mut self) {
        self.samples.clear();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    // 15 samples a second, like the buds send
    fn run(d: &mut Detector, secs: f32, f: impl Fn(f32) -> (f32, f32)) -> Vec<Gesture> {
        (0..(secs * 15.0) as usize)
            .filter_map(|i| {
                let t = i as f32 / 15.0;
                let (y, p) = f(t);
                d.feed(t, y, p)
            })
            .collect()
    }

    #[test]
    fn shake_and_nod() {
        let wave = |t: f32| (t * 2.0 * std::f32::consts::PI * 2.0).sin();
        assert_eq!(run(&mut Detector::default(), 1.5, |t| (15.0 * wave(t), 2.0 * wave(t))), vec![Gesture::Shake]);
        assert_eq!(run(&mut Detector::default(), 1.5, |t| (3.0 * wave(t), 12.0 * wave(t))), vec![Gesture::Nod]);
    }

    #[test]
    fn ordinary_movement_is_not_a_gesture() {
        // looking down at the keyboard and back up
        assert!(run(&mut Detector::default(), 3.0, |t| (0.0, if t < 1.0 { -20.0 * t } else { -20.0 + 20.0 * (t - 1.0).min(1.0) })).is_empty());
        // turning to look at a second screen
        assert!(run(&mut Detector::default(), 3.0, |t| (40.0 * (t / 3.0), 0.0)).is_empty());
        // small jitter while sitting still
        assert!(run(&mut Detector::default(), 3.0, |t| (2.0 * (t * 20.0).sin(), 2.0 * (t * 17.0).cos())).is_empty());
        // a diagonal swing is not clear enough either way
        let wave = |t: f32| (t * 2.0 * std::f32::consts::PI * 2.0).sin();
        assert!(run(&mut Detector::default(), 1.5, |t| (12.0 * wave(t), 12.0 * wave(t))).is_empty());
    }

    #[test]
    fn one_gesture_per_movement() {
        let wave = |t: f32| (t * 2.0 * std::f32::consts::PI * 2.0).sin();
        assert_eq!(run(&mut Detector::default(), 2.5, |t| (15.0 * wave(t), 0.0)).len(), 1);
        // a long nod, then stillness: still one
        assert_eq!(run(&mut Detector::default(), 5.0, |t| (0.0, if t < 1.5 { 12.0 * wave(t) } else { 0.0 })).len(), 1);
    }
}
