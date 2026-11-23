// Son 24 saatin pil kayıtları. Satır başına: unix zamanı, sol, sağ, kutu (-1 bilinmiyor).

use pinna_core::state::Battery;
use std::io::Write;
use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};

const DAY: u64 = 24 * 3600;

fn path() -> PathBuf {
    dirs::state_dir().unwrap_or_else(|| PathBuf::from(".")).join("pinna").join("battery.csv")
}

fn now() -> u64 {
    SystemTime::now().duration_since(UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0)
}

fn lvl(c: Option<u8>) -> i16 {
    c.map(i16::from).unwrap_or(-1)
}

#[derive(Default)]
pub struct History {
    last: Option<(u64, [i16; 3])>,
    lines: usize,
}

impl History {

    pub fn record(&mut self, b: &Battery) {
        let v = [lvl(b.left.level), lvl(b.right.level), lvl(b.case_.level)];
        if v == [-1, -1, -1] {
            return;
        }
        let t = now();
        // değer aynıysa beş dakikada bir yaz, grafik boş kalmasın ama dosya şişmesin
        if let Some((lt, lv)) = self.last
            && (lv == v && t - lt < 300 || t - lt < 30)
        {
            return;
        }
        self.last = Some((t, v));
        let p = path();
        if let Some(d) = p.parent() {
            let _ = std::fs::create_dir_all(d);
        }
        if let Ok(mut f) = std::fs::OpenOptions::new().create(true).append(true).open(&p) {
            let _ = writeln!(f, "{t},{},{},{}", v[0], v[1], v[2]);
        }
        self.lines += 1;
        if self.lines > 500 {
            self.lines = 0;
            let keep: Vec<String> = read().into_iter().map(|r| format!("{},{},{},{}", r[0], r[1], r[2], r[3])).collect();
            let _ = std::fs::write(&p, keep.join("\n") + "\n");
        }
    }
}

pub fn read() -> Vec<[i64; 4]> {
    let from = now().saturating_sub(DAY) as i64;
    std::fs::read_to_string(path())
        .unwrap_or_default()
        .lines()
        .filter_map(|l| {
            let mut it = l.split(',').map(|x| x.trim().parse::<i64>().ok());
            Some([it.next()??, it.next()??, it.next()??, it.next()??])
        })
        .filter(|r| r[0] >= from)
        .collect()
}
