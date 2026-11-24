// The BLE "proximity pairing" advert AirPods send when the case lid opens.
// The plain part has battery in steps of 10; the encrypted 16 bytes give exact percentages once decrypted with the key from the buds.

use aes::Aes128;
use aes::cipher::{BlockCipherDecrypt, BlockCipherEncrypt, KeyInit};

#[derive(Debug, Clone, serde::Serialize)]
pub struct Advert {
    pub model: u16,
    pub left: Option<u8>,
    pub right: Option<u8>,
    #[serde(rename = "case")]
    pub case_: Option<u8>,
    pub left_charging: bool,
    pub right_charging: bool,
    pub case_charging: bool,
    pub lid_open: bool,
    pub left_in_ear: bool,
    pub right_in_ear: bool,
    pub color: u8,
}

pub fn parse(data: &[u8], enc_key: Option<&[u8; 16]>) -> Option<Advert> {
    if data.len() < 11 || data[0] != 0x07 || data[2] == 0x00 {
        return None;
    }
    let model = u16::from_be_bytes([data[3], data[4]]);
    let status = data[5];
    let pods = data[6];
    let fc = data[7];
    let primary_left = status & 0x20 != 0;
    let flipped = !primary_left;
    let nib = |n: u8| if n == 15 { None } else { Some((n * 10).min(100)) };
    let (ln, rn) = if flipped { (pods >> 4, pods & 0x0f) } else { (pods & 0x0f, pods >> 4) };
    let flags = fc >> 4;
    let this_in_case = status & 0x40 != 0;
    let xor = flipped ^ this_in_case;
    let mut a = Advert {
        model,
        left: nib(ln),
        right: nib(rn),
        case_: nib(fc & 0x0f),
        left_charging: if flipped { flags & 0x02 != 0 } else { flags & 0x01 != 0 },
        right_charging: if flipped { flags & 0x01 != 0 } else { flags & 0x02 != 0 },
        case_charging: flags & 0x04 != 0,
        // the lid bit only means something in the advert of a bud that sits in the case
        lid_open: this_in_case && (data[8] >> 3) & 1 == 0,
        left_in_ear: if xor { status & 0x08 != 0 } else { status & 0x02 != 0 },
        right_in_ear: if xor { status & 0x02 != 0 } else { status & 0x08 != 0 },
        color: data[9],
    };
    if let (Some(key), true) = (enc_key, data.len() >= 27) {
        let mut block = [0u8; 16];
        block.copy_from_slice(&data[data.len() - 16..]);
        let c = Aes128::new(key.into());
        c.decrypt_block((&mut block).into());
        let fmt = |b: u8| if b & 0x7f == 0x7f { None } else { Some(((b & 0x7f).min(100), b & 0x80 != 0)) };
        let (li, ri) = if primary_left { (1, 2) } else { (2, 1) };
        if let Some((l, c)) = fmt(block[li]) {
            a.left = Some(l);
            a.left_charging = c;
        }
        if let Some((r, c)) = fmt(block[ri]) {
            a.right = Some(r);
            a.right_charging = c;
        }
        if let Some((k, c)) = fmt(block[3]) {
            a.case_ = Some(k);
            a.case_charging = c;
        }
    }
    Some(a)
}

/// Checks with the IRK whether a random BLE address belongs to these buds (the ah function from the Bluetooth core spec).
pub fn rpa_matches(addr: [u8; 6], irk: &[u8; 16]) -> bool {
    // addr starts at the most significant byte; prand is the top 3 bytes, hash the low 3
    let prand = [addr[2], addr[1], addr[0]];
    let hash = [addr[5], addr[4], addr[3]];
    let mut key = *irk;
    key.reverse();
    let mut r = [0u8; 16];
    r[0..3].copy_from_slice(&prand);
    r.reverse();
    let c = Aes128::new((&key).into());
    c.encrypt_block((&mut r).into());
    r.reverse();
    r[0..3] == hash
}

/// AirPods 1 and 2 have no motion sensor; AirPods 3 send motion over RemoteHID, which we do not read yet.
pub fn has_head_sensor(id: u16) -> bool {
    !matches!(id, 0x2002 | 0x200f | 0x2013)
}

pub fn model_name(id: u16) -> &'static str {
    match id {
        0x2002 => "AirPods",
        0x200f => "AirPods (2nd generation)",
        0x2013 => "AirPods (3rd generation)",
        0x200e => "AirPods Pro",
        0x2014 => "AirPods Pro 2",
        0x2024 => "AirPods Pro 2 (USB-C)",
        0x2027 => "AirPods Pro 3",
        0x2019 => "AirPods 4",
        0x201b => "AirPods 4 (ANC)",
        0x200a => "AirPods Max",
        0x201f => "AirPods Max (USB-C)",
        _ => "AirPods",
    }
}

/// Name from the part number the buds report in their info packet (like A3047), for
/// models whose product id is not in the table above. Part numbers from CAPod's model list.
pub fn model_from_part(part: &str) -> Option<&'static str> {
    const PARTS: &[(&[&str], &str)] = &[
        (&["A1523", "A1722"], "AirPods"),
        (&["A2031", "A2032"], "AirPods (2nd generation)"),
        (&["A2564", "A2565"], "AirPods (3rd generation)"),
        (&["A3050", "A3053", "A3054"], "AirPods 4"),
        (&["A3055", "A3056", "A3057"], "AirPods 4 (ANC)"),
        (&["A2083", "A2084"], "AirPods Pro"),
        (&["A2698", "A2699", "A2931"], "AirPods Pro 2"),
        (&["A3047", "A3048", "A3049"], "AirPods Pro 2 (USB-C)"),
        (&["A3063", "A3064", "A3065"], "AirPods Pro 3"),
        (&["A2096"], "AirPods Max"),
        (&["A3184"], "AirPods Max (USB-C)"),
        (&["A3454"], "AirPods Max 2"),
        (&["A2295"], "Beats Flex"),
        (&["A1796"], "Beats Solo3"),
        (&["A1881"], "Beats Solo Pro"),
        (&["A3140"], "Beats Solo 4"),
        (&["A3150", "A3151", "A3153"], "Beats Solo Buds"),
        (&["A1914"], "Beats Studio3"),
        (&["A2512", "A2513", "A2514"], "Beats Studio Buds"),
        (&["A2871", "A2872", "A2952"], "Beats Studio Buds +"),
        (&["A2924"], "Beats Studio Pro"),
        (&["A1763"], "BeatsX"),
        (&["A1747"], "Powerbeats3"),
        (&["A2015"], "Powerbeats"),
        (&["A2047", "A2048", "A2453", "A2454"], "Powerbeats Pro"),
        (&["A3157", "A3158", "A3159"], "Powerbeats Pro 2"),
        (&["A2576", "A2577", "A2578"], "Beats Fit Pro"),
    ];
    let p = part.trim();
    PARTS.iter().find(|(list, _)| list.contains(&p)).map(|(_, n)| *n)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn part_numbers() {
        // our AirPods Pro 2 (USB-C) report A3047
        assert_eq!(model_from_part("A3047"), Some("AirPods Pro 2 (USB-C)"));
        assert_eq!(model_from_part("A3454"), Some("AirPods Max 2"));
        assert_eq!(model_from_part("X0000"), None);
    }

    #[test]
    fn rpa_spec_vector() {
        // Bluetooth Core 5.x, Vol 3 Part H, D.7: irk ec0234a3..., prand 708194, hash 0dfbaa
        // the buds send the key little endian, so the spec value is reversed
        let mut irk = [
            0xec, 0x02, 0x34, 0xa3, 0x57, 0xc8, 0xad, 0x05, 0x34, 0x10, 0x10, 0xa6, 0x0a, 0x39, 0x7d, 0x9b,
        ];
        irk.reverse();
        assert!(rpa_matches([0x70, 0x81, 0x94, 0x0d, 0xfb, 0xaa], &irk));
        assert!(!rpa_matches([0x70, 0x81, 0x94, 0x0d, 0xfb, 0xab], &irk));
    }

    #[test]
    fn plain_advert() {
        // left primary, lid open, left 90%, right 80%, case 50% charging
        let d = [0x07, 0x19, 0x01, 0x20, 0x24, 0x75, 0x89, 0x45, 0x00, 0x00, 0x01];
        let a = parse(&d, None).unwrap();
        assert_eq!(a.model, 0x2024);
        assert_eq!(a.left, Some(90));
        assert_eq!(a.right, Some(80));
        assert_eq!(a.case_, Some(50));
        assert!(a.case_charging);
        assert!(a.lid_open);
    }
}
