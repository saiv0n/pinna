// Battery time estimates from the recorded history: listening time left while draining,
// time to full while charging. Pure math so it can be tested without a headset.

/// The newest run of samples must be this fresh, and gaps inside it this short.
const GAP: i64 = 20 * 60;
/// Only the last two hours count, older discharge says little about the current use.
const WINDOW: i64 = 2 * 3600;

/// Minutes until empty (or full when `charging`) for one bud.
/// `samples` are (unix seconds, level 0..100 or -1) in time order.
pub fn minutes(samples: &[(i64, i16)], now: i64, charging: bool) -> Option<u32> {
    let &(last_t, last_v) = samples.iter().rev().find(|s| s.1 >= 0)?;
    if now - last_t > GAP {
        return None;
    }
    // walk back over the run that matches the current direction
    let mut run = vec![(last_t, last_v)];
    for &(t, v) in samples.iter().rev() {
        if v < 0 || t >= last_t {
            continue;
        }
        let (pt, pv) = *run.last()?;
        let wrong_way = if charging { v > pv } else { v < pv };
        if pt - t > GAP || last_t - t > WINDOW || wrong_way {
            break;
        }
        run.push((t, v));
    }
    let (min_n, min_change, lo, hi) = if charging { (3, 5.0, 25.0, 400.0) } else { (4, 3.0, 2.0, 80.0) };
    let first = *run.last()?;
    let change = (last_v - first.1).abs() as f64;
    if run.len() < min_n || last_t - first.0 < 10 * 60 || change < min_change {
        return None;
    }
    // least squares slope in percent per hour
    let n = run.len() as f64;
    let xs: Vec<f64> = run.iter().map(|s| (s.0 - last_t) as f64 / 3600.0).collect();
    let ys: Vec<f64> = run.iter().map(|s| s.1 as f64).collect();
    let (mx, my) = (xs.iter().sum::<f64>() / n, ys.iter().sum::<f64>() / n);
    let sxx: f64 = xs.iter().map(|x| (x - mx).powi(2)).sum();
    let sxy: f64 = xs.iter().zip(&ys).map(|(x, y)| (x - mx) * (y - my)).sum();
    if sxx == 0.0 {
        return None;
    }
    let rate = (sxy / sxx).abs();
    if !(lo..=hi).contains(&rate) {
        return None;
    }
    let left = if charging { 100.0 - last_v as f64 } else { last_v as f64 };
    let m = left / rate * 60.0;
    // five minute steps, the estimate is not more precise than that
    Some(((m / 5.0).round() * 5.0).max(5.0) as u32)
}

#[cfg(test)]
mod tests {
    use super::*;

    // every five minutes, like the history writer
    fn series(start: i16, step: f64, n: usize) -> Vec<(i64, i16)> {
        (0..n).map(|i| (i as i64 * 300, (start as f64 + step * i as f64).round() as i16)).collect()
    }

    #[test]
    fn drain() {
        // 100 to 80 over an hour: 20 %/h, 80% left means about four hours
        let s = series(100, -20.0 / 12.0, 13);
        assert_eq!(minutes(&s, 3600, false), Some(240));
    }

    #[test]
    fn real_history() {
        // left bud from the real battery.csv of 2026-11-23, 22:18 to 22:51
        let s: Vec<(i64, i16)> = [
            (0, 100), (300, 100), (600, 99), (900, 97), (1200, 95), (1500, 93), (1800, 91), (2100, 89), (2400, 87),
        ]
        .to_vec();
        let m = minutes(&s, 2400, false).unwrap();
        assert!((180..=280).contains(&m), "{m}");
    }

    #[test]
    fn charge() {
        let s = series(40, 5.0, 6);
        // 5 points per 5 min is 60 %/h; 35 left after 65 is 35 min
        assert_eq!(minutes(&s, 1500, true), Some(35));
    }

    #[test]
    fn needs_enough_data() {
        assert_eq!(minutes(&series(100, -1.0, 3), 600, false), None);
        // flat, no real discharge yet
        assert_eq!(minutes(&series(90, 0.0, 10), 2700, false), None);
        // stale: the buds were away for an hour
        assert_eq!(minutes(&series(100, -2.0, 10), 2700 + 3600, false), None);
    }

    #[test]
    fn only_the_latest_run() {
        // drained, then charged back up, now draining again: old discharge must not count
        let mut s = series(100, -2.0, 8);
        s.push((2400, 100));
        s.extend(series(100, -2.0, 6).into_iter().map(|(t, v)| (t + 2700, v)));
        let m = minutes(&s, 2700 + 1500, false).unwrap();
        // 2 points per 5 min is 24 %/h, 90 left is about 225 min; the flat point at the
        // top of the charge slows the fit a little
        assert!((220..=260).contains(&m), "{m}");
    }
}
