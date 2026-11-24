// AAP packets, spoken over L2CAP PSM 0x1001.

pub const PSM: u16 = 0x1001;

pub const HANDSHAKE: &[u8] = &[0x00, 0x00, 0x04, 0x00, 0x01, 0x00, 0x02, 0x00, 0, 0, 0, 0, 0, 0, 0, 0];
// adaptive mode and conversation awareness during music do not turn on without this packet
pub const FEATURES: &[u8] = &[0x04, 0x00, 0x04, 0x00, 0x4d, 0x00, 0xd7, 0, 0, 0, 0, 0, 0, 0];
pub const NOTIFY: &[u8] = &[0x04, 0x00, 0x04, 0x00, 0x0f, 0x00, 0xff, 0xff, 0xff, 0xff, 0xff];
pub const REQUEST_KEYS: &[u8] = &[0x04, 0x00, 0x04, 0x00, 0x30, 0x00, 0x05, 0x00];

const HDR: [u8; 4] = [0x04, 0x00, 0x04, 0x00];

pub const HEAD_START: &[u8] = &[
    0x04, 0x00, 0x04, 0x00, 0x17, 0x00, 0x00, 0x00, 0x10, 0x00, 0x0F, 0x00, 0x08, 0x73, 0x42, 0x0B, 0x08, 0x10, 0x10,
    0x02, 0x1A, 0x05, 0x01, 0x40, 0x9C, 0x00, 0x00,
];
pub const HEAD_STOP: &[u8] = &[
    0x04, 0x00, 0x04, 0x00, 0x17, 0x00, 0x00, 0x00, 0x10, 0x00, 0x0F, 0x00, 0x08, 0x75, 0x42, 0x0B, 0x08, 0x10, 0x10,
    0x02, 0x1A, 0x05, 0x01, 0x00, 0x00, 0x00, 0x00,
];

// from LibrePods: makes the buds send their mic as 0x58 packets without leaving A2DP
pub const MIC_START: &[u8] = &[
    0x04, 0x00, 0x04, 0x00, 0x58, 0x00, 0x00, 0x00, 0x09, 0x00, 0x00, 0x01, 0x82, 0x00, 0x00, 0x00, 0x04, 0x96, 0x00,
];
pub const MIC_STOP: &[u8] = &[0x04, 0x00, 0x04, 0x00, 0x58, 0x00, 0x00, 0x00, 0x02, 0x00, 0x03, 0x01];
/// AAC-ELD config of the mic frames. It says 48 kHz but frames arrive at a 64 kHz rate.
pub const MIC_ASC: [u8; 4] = [0xF8, 0xE6, 0x30, 0x00];
pub const MIC_RATE: u32 = 64_000;

/// AAC-ELD frames in a 0x58 audio packet: a 22 byte header, then [time:u32][len:u8][frame] entries.
pub fn mic_frames(d: &[u8]) -> impl Iterator<Item = &[u8]> {
    let audio = d.len() > 22 && d[..4] == HDR && d[4..8] == [0x58, 0x00, 0x01, 0x00];
    let mut off = if audio { 22 } else { d.len() };
    std::iter::from_fn(move || {
        let len = *d.get(off + 4)? as usize;
        let f = d.get(off + 5..off + 5 + len)?;
        off += 5 + len;
        Some(f)
    })
}

pub mod cmd {
    pub const LISTENING_MODE: u8 = 0x0D;
    pub const PRESS_SPEED: u8 = 0x17;
    pub const HOLD_DURATION: u8 = 0x18;
    pub const HOLD_MODE: u8 = 0x16;
    pub const LISTENING_CYCLE: u8 = 0x1A;
    pub const ONE_BUD_ANC: u8 = 0x1B;
    pub const CHIME_VOLUME: u8 = 0x1F;
    pub const AUTO_CONNECT: u8 = 0x20;
    pub const VOLUME_SWIPE_INTERVAL: u8 = 0x23;
    pub const VOLUME_SWIPE: u8 = 0x25;
    pub const ADAPTIVE_VOLUME: u8 = 0x26;
    pub const CONVERSATION: u8 = 0x28;
    pub const HEARING_AID: u8 = 0x2C;
    pub const ADAPTIVE_STRENGTH: u8 = 0x2E;
    pub const HEARING_ASSIST: u8 = 0x33;
    pub const ALLOW_OFF: u8 = 0x34;
    pub const SLEEP_DETECTION: u8 = 0x35;
    /// bit mask: 2 double, 4 triple, 8 long press; marked presses are forwarded to us
    pub const STEM_CONFIG: u8 = 0x39;
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize, serde::Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Mode {
    Off,
    Anc,
    Transparency,
    Adaptive,
}

impl Mode {
    pub fn byte(self) -> u8 {
        match self {
            Mode::Off => 1,
            Mode::Anc => 2,
            Mode::Transparency => 3,
            Mode::Adaptive => 4,
        }
    }
    pub fn name(self) -> &'static str {
        match self {
            Mode::Off => "off",
            Mode::Anc => "anc",
            Mode::Transparency => "transparency",
            Mode::Adaptive => "adaptive",
        }
    }
    pub fn from_byte(b: u8) -> Option<Mode> {
        Some(match b {
            1 => Mode::Off,
            2 => Mode::Anc,
            3 => Mode::Transparency,
            4 => Mode::Adaptive,
            _ => return None,
        })
    }
    pub fn parse(s: &str) -> Option<Mode> {
        Some(match s {
            "off" | "kapali" => Mode::Off,
            "anc" | "nc" => Mode::Anc,
            "transparency" | "seffaf" | "t" => Mode::Transparency,
            "adaptive" | "uyarlanabilir" | "a" => Mode::Adaptive,
            _ => return None,
        })
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize)]
#[serde(rename_all = "lowercase")]
pub enum Pod {
    Ear,
    Out,
    Case,
    Unknown,
}

impl Pod {
    fn from_byte(b: u8) -> Pod {
        match b {
            0 => Pod::Ear,
            1 => Pod::Out,
            2 => Pod::Case,
            _ => Pod::Unknown,
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Component {
    Left,
    Right,
    Case,
}

#[derive(Debug, Clone)]
pub struct BatteryEntry {
    pub component: Component,
    pub level: u8,
    pub charging: bool,
    pub connected: bool,
}

#[derive(Debug, Clone, Default)]
pub struct DeviceInfo {
    pub name: String,
    pub model: String,
    pub serial: String,
    pub firmware: String,
    pub serial_left: String,
    pub serial_right: String,
}

#[derive(Debug, Clone)]
pub enum Packet {
    HandshakeAck,
    Battery(Vec<BatteryEntry>),
    /// primary and secondary bud
    Ear(Pod, Pod),
    Control { id: u8, data: [u8; 4] },
    Speaking(u8),
    Info(DeviceInfo),
    Keys { irk: [u8; 16], enc: [u8; 16] },
    /// three orientation and two acceleration values
    Head([i16; 5]),
    /// stem press: 5 single, 6 double, 7 triple, 8 long
    Stem { press: u8, left: bool },
    /// custom EQ, bands 0 to 100 with 50 flat
    Eq(Eq),
    Other(u16),
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, serde::Serialize)]
pub struct Eq {
    pub enabled: bool,
    pub low: u8,
    pub mid: u8,
    pub high: u8,
}

/// Format from MagicPodsCore; the buds send the same layout on connect.
pub fn eq(e: Eq) -> Vec<u8> {
    let mut p = HDR.to_vec();
    p.extend_from_slice(&[0x63, 0x00, 0x05, 0x00, 0x01, if e.enabled { 2 } else { 1 }]);
    p.extend_from_slice(&[e.low.min(100), e.mid.min(100), e.high.min(100)]);
    p
}

pub fn control(id: u8, data: [u8; 4]) -> Vec<u8> {
    let mut p = HDR.to_vec();
    p.extend_from_slice(&[0x09, 0x00, id]);
    p.extend_from_slice(&data);
    p
}

/// A name the buds accept: 1 to 32 bytes, no control characters.
pub fn valid_name(name: &str) -> bool {
    !name.is_empty() && name.len() <= 32 && !name.chars().any(char::is_control)
}

pub fn rename(name: &str) -> Vec<u8> {
    let bytes = name.as_bytes();
    let mut p = HDR.to_vec();
    p.extend_from_slice(&[0x1A, 0x00, 0x01, bytes.len() as u8, 0x00]);
    p.extend_from_slice(bytes);
    p
}

pub fn parse(d: &[u8]) -> Option<Packet> {
    if d.starts_with(&[0x01, 0x00, 0x04, 0x00]) {
        return Some(Packet::HandshakeAck);
    }
    if d.len() < 6 || d[..4] != HDR {
        return None;
    }
    let op = u16::from_le_bytes([d[4], d[5]]);
    let body = &d[6..];
    Some(match op {
        0x04 => {
            let n = *body.first()? as usize;
            let mut out = Vec::new();
            for i in 0..n {
                let e = body.get(1 + i * 5..1 + i * 5 + 5)?;
                let component = match e[0] {
                    0x04 => Component::Left,
                    0x02 => Component::Right,
                    0x08 => Component::Case,
                    _ => continue,
                };
                out.push(BatteryEntry {
                    component,
                    level: e[2],
                    charging: e[3] == 0x01,
                    // some firmware sends 127 for unknown, never show 127%
                    connected: e[3] != 0x04 && e[2] <= 100,
                });
            }
            Packet::Battery(out)
        }
        0x06 => Packet::Ear(Pod::from_byte(*body.first()?), Pod::from_byte(*body.get(1)?)),
        0x09 => {
            let id = *body.first()?;
            let mut data = [0u8; 4];
            for (i, b) in body.iter().skip(1).take(4).enumerate() {
                data[i] = *b;
            }
            Packet::Control { id, data }
        }
        0x4B => Packet::Speaking(*body.get(3)?),
        0x63 if body.len() >= 7 && body[..3] == [0x05, 0x00, 0x01] && body[4..7].iter().all(|b| *b <= 100) => {
            Packet::Eq(Eq { enabled: body[3] == 2, low: body[4], mid: body[5], high: body[6] })
        }
        0x19 => Packet::Stem { press: *body.first()?, left: *body.get(1)? == 0x01 },
        0x1D => Packet::Info(parse_info(body)),
        0x31 => parse_keys(body)?,
        0x17 if d.len() >= 55 => {
            let v = |o: usize| i16::from_le_bytes([d[o], d[o + 1]]);
            Packet::Head([v(43), v(45), v(47), v(51), v(53)])
        }
        other => Packet::Other(other),
    })
}

fn parse_info(body: &[u8]) -> DeviceInfo {
    // 4 unknown bytes first, then zero terminated strings
    let start = body.iter().position(|b| b.is_ascii_alphabetic()).unwrap_or(0);
    let s: Vec<String> = body[start..]
        .split(|b| *b == 0)
        .map(|x| String::from_utf8_lossy(x).into_owned())
        .collect();
    let get = |i: usize| s.get(i).cloned().unwrap_or_default();
    DeviceInfo {
        name: get(0),
        model: get(1),
        serial: get(3),
        firmware: get(4),
        serial_left: get(8),
        serial_right: get(9),
    }
}

fn parse_keys(body: &[u8]) -> Option<Packet> {
    // 02 [01 00 10 00 <irk 16>] [04 00 10 00 <enc 16>]
    let mut irk = None;
    let mut enc = None;
    let mut i = 1;
    while i + 4 <= body.len() {
        let t = body[i];
        let len = u16::from_be_bytes([body[i + 1], body[i + 2]]) as usize;
        let v = body.get(i + 4..i + 4 + len)?;
        if len == 16 {
            let mut k = [0u8; 16];
            k.copy_from_slice(v);
            match t {
                0x01 => irk = Some(k),
                0x04 => enc = Some(k),
                _ => {}
            }
        }
        i += 4 + len;
    }
    Some(Packet::Keys { irk: irk?, enc: enc? })
}

#[cfg(test)]
mod tests {
    use super::*;

    fn hex(s: &str) -> Vec<u8> {
        (0..s.len()).step_by(2).map(|i| u8::from_str_radix(&s[i..i + 2], 16).unwrap()).collect()
    }

    // packets captured from AirPods Pro 2 (USB-C) on 2026-11-23
    #[test]
    fn real_battery() {
        let Some(Packet::Battery(b)) = parse(&hex("0400040004000302015f020104016002010801000401")) else { panic!() };
        let get = |c: Component| b.iter().find(|e| e.component == c).cloned().unwrap();
        let (r, l, case) = (get(Component::Right), get(Component::Left), get(Component::Case));
        assert_eq!((r.level, r.charging, r.connected), (95, false, true));
        assert_eq!((l.level, l.charging, l.connected), (96, false, true));
        // case away from the buds reports level 0 and status 4
        assert!(!case.connected);
    }

    #[test]
    fn real_ear_speech_mode() {
        assert!(matches!(parse(&hex("0400040006000000")), Some(Packet::Ear(Pod::Ear, Pod::Ear))));
        assert!(matches!(parse(&hex("0400040006000001")), Some(Packet::Ear(Pod::Ear, Pod::Out))));
        assert!(matches!(parse(&hex("040004004b0002000108")), Some(Packet::Speaking(8))));
        let Some(Packet::Control { id, data }) = parse(&hex("0400040009000d03000000")) else { panic!() };
        assert_eq!((id, Mode::from_byte(data[0])), (cmd::LISTENING_MODE, Some(Mode::Transparency)));
    }

    #[test]
    fn real_unknown_packets_are_ignored() {
        for p in ["04000400550001010019", "0400040052000300020100", "040004004e000200000000000000", "040004000e0000000000000000", "04000400080002000100"] {
            assert!(matches!(parse(&hex(p)), Some(Packet::Other(_))), "{p}");
        }
    }

    #[test]
    fn battery_out_of_range() {
        let Some(Packet::Battery(b)) = parse(&hex("040004000400010201 7f0101".replace(' ', "").as_str())) else { panic!() };
        assert!(!b[0].connected);
    }

    #[test]
    fn custom_eq() {
        // sent by AirPods Pro 2 (USB-C) on connect: off, all bands flat
        let Some(Packet::Eq(e)) = parse(&hex("04000400630005000101323232")) else { panic!() };
        assert_eq!(e, Eq { enabled: false, low: 50, mid: 50, high: 50 });
        let on = Eq { enabled: true, low: 70, mid: 50, high: 30 };
        let Some(Packet::Eq(back)) = parse(&eq(on)) else { panic!() };
        assert_eq!(back, on);
        assert!(matches!(parse(&hex("04000400630005000101ff3232")), Some(Packet::Other(0x63))));
    }

    #[test]
    fn stem() {
        assert!(matches!(parse(&hex("0400040019000602")), Some(Packet::Stem { press: 6, left: false })));
        assert!(matches!(parse(&hex("0400040019000801")), Some(Packet::Stem { press: 8, left: true })));
    }

    #[test]
    fn battery() {
        let p = parse(&hex("04000400040003020161020104016402010801000401")).unwrap();
        let Packet::Battery(b) = p else { panic!() };
        assert_eq!(b.len(), 3);
        assert_eq!(b[0].component, Component::Right);
        assert_eq!(b[0].level, 97);
        assert_eq!(b[1].level, 100);
        assert!(!b[2].connected);
    }

    #[test]
    fn info() {
        let p = parse(&hex("040004001d0002db000400416972506f64732050726f004133303437004170706c6520496e632e00463358544e463252504b0039312e3334333130343630303430303030303030302e323900")).unwrap();
        let Packet::Info(i) = p else { panic!() };
        assert_eq!(i.name, "AirPods Pro");
        assert_eq!(i.model, "A3047");
    }

    #[test]
    fn head() {
        let mut d = vec![0u8; 60];
        d[..6].copy_from_slice(&[0x04, 0x00, 0x04, 0x00, 0x17, 0x00]);
        d[43..45].copy_from_slice(&(-120i16).to_le_bytes());
        let Packet::Head(h) = parse(&d).unwrap() else { panic!() };
        assert_eq!(h[0], -120);
        assert!(matches!(parse(HEAD_START), Some(Packet::Other(0x17))));
    }

    #[test]
    fn mic() {
        let mut d = vec![0x04, 0x00, 0x04, 0x00, 0x58, 0x00, 0x01, 0x00];
        d.resize(22, 0);
        d.extend([0x84, 3, 0, 0, 2, 0xAA, 0xBB, 0x38, 4, 0, 0, 1, 0xCC, 0x00]);
        let f: Vec<_> = mic_frames(&d).collect();
        assert_eq!(f, [&[0xAA, 0xBB][..], &[0xCC][..]]);
        assert_eq!(mic_frames(MIC_STOP).count(), 0);
        assert_eq!(mic_frames(&d[..24]).count(), 0);
    }

    // any bytes from the buds or the air must parse safely
    #[test]
    fn fuzz_parse() {
        let mut x: u64 = 0x9E37_79B9_7F4A_7C15;
        let mut next = || {
            x ^= x << 13;
            x ^= x >> 7;
            x ^= x << 17;
            x
        };
        let key = [7u8; 16];
        for i in 0..300_000 {
            let len = (next() % 96) as usize;
            let mut d: Vec<u8> = (0..len).map(|_| next() as u8).collect();
            // half of them get a valid header so deeper branches are reached too
            if i % 2 == 0 && d.len() >= 6 {
                d[..4].copy_from_slice(&HDR);
                d[4] = [0x04, 0x06, 0x09, 0x1D, 0x31, 0x4B, 0x17][(next() % 7) as usize];
                d[5] = 0;
            }
            let _ = parse(&d);
            if i % 5 == 0 && d.len() >= 8 {
                d[4..8].copy_from_slice(&[0x58, 0x00, 0x01, 0x00]);
            }
            let _ = mic_frames(&d).count();
            if i % 3 == 0 && !d.is_empty() {
                d[0] = 0x07;
            }
            let _ = crate::proximity::parse(&d, Some(&key));
            let _ = crate::proximity::parse(&d, None);
        }
    }

    #[test]
    fn names() {
        assert!(valid_name("AirPods"));
        assert!(!valid_name(""));
        assert!(!valid_name("a\nb"));
        assert!(!valid_name(&"x".repeat(33)));
    }

    #[test]
    fn control_roundtrip() {
        let p = control(cmd::LISTENING_MODE, [2, 0, 0, 0]);
        let Packet::Control { id, data } = parse(&p).unwrap() else { panic!() };
        assert_eq!((id, data[0]), (0x0D, 2));
    }
}
