// AAP (Apple Accessory Protocol) paketleri. L2CAP PSM 0x1001 üzerinden konuşulur.
// Paket düzeni LibrePods ekibinin tersine mühendislik notlarına dayanıyor.

pub const PSM: u16 = 0x1001;

pub const HANDSHAKE: &[u8] = &[0x00, 0x00, 0x04, 0x00, 0x01, 0x00, 0x02, 0x00, 0, 0, 0, 0, 0, 0, 0, 0];
// adaptif mod ve müzik çalarken konuşma algılama bu paket olmadan açılmıyor
pub const FEATURES: &[u8] = &[0x04, 0x00, 0x04, 0x00, 0x4d, 0x00, 0xd7, 0, 0, 0, 0, 0, 0, 0];
pub const NOTIFY: &[u8] = &[0x04, 0x00, 0x04, 0x00, 0x0f, 0x00, 0xff, 0xff, 0xff, 0xff, 0xff];
pub const REQUEST_KEYS: &[u8] = &[0x04, 0x00, 0x04, 0x00, 0x30, 0x00, 0x05, 0x00];

const HDR: [u8; 4] = [0x04, 0x00, 0x04, 0x00];

// baş takibi akışını başlatıp durduran paketler, LibrePods notlarından
pub const HEAD_START: &[u8] = &[
    0x04, 0x00, 0x04, 0x00, 0x17, 0x00, 0x00, 0x00, 0x10, 0x00, 0x10, 0x00, 0x08, 0xA1, 0x02, 0x42, 0x0B, 0x08, 0x0E,
    0x10, 0x02, 0x1A, 0x05, 0x01, 0x40, 0x9C, 0x00, 0x00,
];
pub const HEAD_STOP: &[u8] = &[
    0x04, 0x00, 0x04, 0x00, 0x17, 0x00, 0x00, 0x00, 0x10, 0x00, 0x11, 0x00, 0x08, 0x7E, 0x10, 0x02, 0x42, 0x0B, 0x08,
    0x4E, 0x10, 0x02, 0x1A, 0x05, 0x01, 0x00, 0x00, 0x00, 0x00,
];

pub mod cmd {
    pub const MIC_MODE: u8 = 0x01;
    pub const EAR_DETECTION: u8 = 0x0A;
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
    /// birincil ve ikincil kulaklık
    Ear(Pod, Pod),
    Control { id: u8, data: [u8; 4] },
    Speaking(u8),
    Info(DeviceInfo),
    Keys { irk: [u8; 16], enc: [u8; 16] },
    /// üç yönelim ve iki ivme değeri
    Head([i16; 5]),
    Other(u16),
}

pub fn control(id: u8, data: [u8; 4]) -> Vec<u8> {
    let mut p = HDR.to_vec();
    p.extend_from_slice(&[0x09, 0x00, id]);
    p.extend_from_slice(&data);
    p
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
                    connected: e[3] != 0x04,
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
    // başta 4 baytlık bilinmeyen alan var, sonra sıfırla biten metinler
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
    fn control_roundtrip() {
        let p = control(cmd::LISTENING_MODE, [2, 0, 0, 0]);
        let Packet::Control { id, data } = parse(&p).unwrap() else { panic!() };
        assert_eq!((id, data[0]), (0x0D, 2));
    }
}
