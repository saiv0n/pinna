// A pretend pair of AirPods for working on pinnad and the app without a headset.
// It answers the handshake with packets shaped like real AirPods Pro 2 (USB-C) captures,
// echoes settings back like the buds do, and drains the battery so estimates have data.
// Start it with PINNA_FAKE=1, or PINNA_FAKE=pro3, max, airpods4 or airpods2 for the controls and
// battery layout those models report (from LibrePods and CAPod captures); use PINNA_BUS and XDG_CONFIG_HOME / XDG_STATE_HOME to keep
// it away from the real service and its files.

use pinna_core::aap;
use std::time::Duration;
use tokio::net::UnixDatagram;

pub const ADDRESS: &str = "00:00:00:00:00:01";

fn pkt(op: u8, body: &[u8]) -> Vec<u8> {
    let mut p = vec![0x04, 0x00, 0x04, 0x00, op, 0x00];
    p.extend_from_slice(body);
    p
}

pub struct Profile {
    pub name: &'static str,
    pub model_name: &'static str,
    pub product: u16,
    part: &'static str,
    firmware: &'static str,
    /// one battery for the whole headset, no case
    single: bool,
    eq: bool,
    /// the controls these buds report right after connecting
    controls: &'static [(u8, [u8; 4])],
}

const PRO2: Profile = Profile {
    name: "Fake AirPods Pro",
    model_name: "AirPods Pro 2 (USB-C)",
    product: 0x2024,
    part: "A3047",
    firmware: "8A358",
    single: false,
    eq: true,
    controls: &[
        (0x0D, [2, 0, 0, 0]), (0x17, [0, 0, 0, 0]), (0x18, [0, 0, 0, 0]), (0x1B, [2, 0, 0, 0]), (0x1F, [80, 80, 0, 0]),
        (0x23, [0, 0, 0, 0]), (0x24, [0, 3, 0, 0]), (0x25, [1, 0, 0, 0]), (0x26, [2, 0, 0, 0]), (0x28, [1, 0, 0, 0]),
        (0x2E, [50, 0, 0, 0]), (0x33, [2, 0, 0, 0]), (0x35, [2, 0, 0, 0]),
    ],
};

const PROFILES: &[(&str, Profile)] = &[
    ("pro2", PRO2),
    ("pro3", Profile {
        name: "Fake AirPods Pro 3",
        model_name: "AirPods Pro 3",
        product: 0x2027,
        part: "A3064",
        firmware: "81.2675000075000000.6503",
        single: false,
        eq: false,
        controls: &[
            (0x0D, [2, 0, 0, 0]), (0x17, [0, 0, 0, 0]), (0x18, [0, 0, 0, 0]), (0x1B, [2, 0, 0, 0]), (0x1F, [80, 80, 0, 0]),
            (0x23, [0, 0, 0, 0]), (0x24, [0, 3, 0, 0]), (0x25, [1, 0, 0, 0]), (0x26, [2, 0, 0, 0]), (0x28, [2, 0, 0, 0]),
            (0x2E, [50, 0, 0, 0]), (0x3B, [1, 0, 0, 0]),
        ],
    }),
    ("max", Profile {
        name: "Fake AirPods Max",
        model_name: "AirPods Max",
        product: 0x200A,
        part: "A2096",
        firmware: "65.1868046005000000.109",
        single: true,
        eq: false,
        controls: &[
            (0x0D, [2, 0, 0, 0]), (0x17, [0, 0, 0, 0]), (0x18, [0, 0, 0, 0]), (0x1B, [2, 0, 0, 0]), (0x1F, [80, 80, 0, 0]),
            (0x24, [0, 3, 0, 0]), (0x26, [2, 0, 0, 0]), (0x28, [1, 0, 0, 0]), (0x34, [2, 0, 0, 0]),
        ],
    }),
    // no listening modes, no adaptive, no head sensor
    ("airpods2", Profile {
        name: "Fake AirPods",
        model_name: "AirPods (2nd generation)",
        product: 0x200f,
        part: "A2032",
        firmware: "6F8",
        single: false,
        eq: false,
        controls: &[(0x17, [0, 0, 0, 0]), (0x18, [0, 0, 0, 0])],
    }),
    // AirPods 4 (ANC): no volume swipe, no case speaker setting, no noise cancellation with one bud
    ("airpods4", Profile {
        name: "Fake AirPods 4",
        model_name: "AirPods 4 (ANC)",
        product: 0x201B,
        part: "A3056",
        firmware: "8A356",
        single: false,
        eq: false,
        controls: &[(0x0D, [2, 0, 0, 0]), (0x17, [0, 0, 0, 0]), (0x18, [0, 0, 0, 0]), (0x26, [2, 0, 0, 0]), (0x28, [1, 0, 0, 0]), (0x2E, [50, 0, 0, 0])],
    }),
];

pub fn profile() -> &'static Profile {
    let want = std::env::var("PINNA_FAKE").unwrap_or_default();
    PROFILES.iter().find(|(k, _)| *k == want).map_or(&PRO2, |(_, p)| p)
}

fn info(p: &Profile) -> Vec<u8> {
    let fields = [
        p.name, p.part, "Apple Inc.", "FAKESERIAL01", p.firmware, p.firmware, "1.0.0",
        "com.apple.accessory.updater.app.71", if p.single { "0" } else { "FAKELEFT0001" }, if p.single { "0" } else { "FAKERIGHT001" },
    ];
    let mut body = vec![0x02, 0xe2, 0x00, 0x04];
    for f in fields {
        body.extend_from_slice(f.as_bytes());
        body.push(0);
    }
    pkt(0x1d, &body)
}

fn battery(p: &Profile, left: u8, right: u8, case: Option<u8>) -> Vec<u8> {
    if p.single {
        return pkt(0x04, &[0x01, 0x01, 0x01, left, 0x02, 0x01]);
    }
    let mut b = vec![0x03];
    b.extend_from_slice(&[0x02, 0x01, right, 0x02, 0x01]);
    b.extend_from_slice(&[0x04, 0x01, left, 0x02, 0x01]);
    match case {
        Some(c) => b.extend_from_slice(&[0x08, 0x01, c, 0x02, 0x01]),
        None => b.extend_from_slice(&[0x08, 0x01, 0x00, 0x04, 0x01]),
    }
    pkt(0x04, &b)
}

/// A head tracking packet with these angles, laid out like the real 0x17 stream.
fn head(yaw: f32, pitch: f32) -> Vec<u8> {
    let mut p = vec![0u8; 55];
    p[..6].copy_from_slice(&[0x04, 0x00, 0x04, 0x00, 0x17, 0x00]);
    let a = ((pitch + yaw) * 32000.0 / 180.0) as i16;
    let b = ((pitch - yaw) * 32000.0 / 180.0) as i16;
    p[45..47].copy_from_slice(&a.to_le_bytes());
    p[47..49].copy_from_slice(&b.to_le_bytes());
    p
}

/// Every eight seconds: still, a nod, still, a shake.
fn head_at(t: f32) -> (f32, f32) {
    let t = t % 8.0;
    let w = (t * 2.0 * std::f32::consts::PI * 2.0).sin();
    match t {
        t if (1.0..2.5).contains(&t) => (0.0, 12.0 * w),
        t if (4.5..6.0).contains(&t) => (15.0 * w, 0.0),
        _ => (0.0, 0.0),
    }
}

/// Runs the pretend buds on one end of a datagram pair.
pub async fn headset(sock: UnixDatagram) {
    let prof = profile();
    let mut buf = vec![0u8; 2048];
    let (mut left, mut right) = (100u8, 98u8);
    let mut tick = tokio::time::interval(Duration::from_secs(20));
    let mut up = false;
    let mut ticks = 0u32;
    let mut stream: Option<std::time::Instant> = None;
    let mut frame = tokio::time::interval(Duration::from_millis(66));
    loop {
        tokio::select! {
            r = sock.recv(&mut buf) => {
                let Ok(n) = r else { return };
                let d = buf[..n].to_vec();
                if d.starts_with(&[0x00, 0x00, 0x04, 0x00, 0x01]) {
                    let _ = sock.send(&[0x01, 0x00, 0x04, 0x00]).await;
                    up = true;
                    let mut list = vec![info(prof), battery(prof, left, right, Some(30)), pkt(0x06, &[0x00, 0x00])];
                    list.extend(prof.controls.iter().map(|(id, v)| aap::control(*id, *v)));
                    if prof.eq {
                        list.push(aap::eq(aap::Eq { enabled: false, low: 50, mid: 50, high: 50 }));
                    }
                    for p in list {
                        let _ = sock.send(&p).await;
                    }
                } else if d.len() > 7 && d[4] == 0x09 && d[6] == aap::cmd::STEM_CONFIG {
                    // once presses are forwarded, act out a double press on the left stem
                    if d[7] & 0x02 != 0 {
                        let _ = sock.send(&pkt(0x19, &[0x06, 0x01])).await;
                    }
                } else if d == aap::HEAD_START {
                    stream = Some(std::time::Instant::now());
                } else if d == aap::HEAD_STOP {
                    stream = None;
                } else if d.len() > 6 && (d[4] == 0x09 || d[4] == 0x63) {
                    // the buds confirm a setting by sending it back
                    let _ = sock.send(&d).await;
                }
            }
            _ = frame.tick(), if stream.is_some() => {
                let (yaw, pitch) = head_at(stream.map_or(0.0, |s| s.elapsed().as_secs_f32()));
                let _ = sock.send(&head(yaw, pitch)).await;
            }
            _ = tick.tick(), if up => {
                // 1% every 100 s, faster than real use so estimates show up within minutes
                ticks += 1;
                if ticks.is_multiple_of(5) {
                    left = left.saturating_sub(1);
                    right = right.saturating_sub(1);
                    let _ = sock.send(&battery(prof, left, right, Some(30))).await;
                }
            }
        }
    }
}
