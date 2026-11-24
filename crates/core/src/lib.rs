// Platform independent part: packets, BLE adverts, the settings table, persistent config.
// Future Windows and Android layers will use it too.
pub mod aap;
pub mod proximity;
pub mod estimate;
pub mod gesture;
pub mod state;

#[cfg(test)]
mod robustness {
    // the buds and anything advertising nearby send these bytes; no input may panic
    fn lcg(seed: &mut u64) -> u8 {
        *seed = seed.wrapping_mul(6364136223846793005).wrapping_add(1442695040888963407);
        (*seed >> 33) as u8
    }

    #[test]
    fn parsers_survive_random_input() {
        let mut seed = 7u64;
        let key = [0x11u8; 16];
        for i in 0..200_000 {
            let len = (lcg(&mut seed) as usize) % 80;
            let mut d: Vec<u8> = (0..len).map(|_| lcg(&mut seed)).collect();
            // half the time look like a real AAP header so the deeper branches run
            if i % 2 == 0 && d.len() >= 6 {
                d[..4].copy_from_slice(&[0x04, 0x00, 0x04, 0x00]);
                d[4] = [0x04, 0x06, 0x09, 0x17, 0x19, 0x1d, 0x31, 0x4b, 0x63][i % 9];
                d[5] = 0;
            }
            let _ = crate::aap::parse(&d);
            if !d.is_empty() {
                d[0] = 0x07;
            }
            let _ = crate::proximity::parse(&d, Some(&key));
            let _ = crate::proximity::parse(&d, None);
        }
    }
}
