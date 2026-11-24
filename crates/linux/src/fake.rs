// A pretend pair of AirPods for working on pinnad and the app without a headset.
// It answers the handshake with packets shaped like real AirPods Pro 2 (USB-C) captures,
// echoes settings back like the buds do, and drains the battery so estimates have data.
// Start it with PINNA_FAKE=1; use PINNA_BUS and XDG_CONFIG_HOME / XDG_STATE_HOME to keep
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

fn info() -> Vec<u8> {
    let fields = [
        "Fake AirPods Pro", "A3047", "Apple Inc.", "FAKESERIAL01", "8A358", "8A358", "1.0.0",
        "com.apple.accessory.updater.app.71", "FAKELEFT0001", "FAKERIGHT001",
    ];
    let mut body = vec![0x02, 0xe2, 0x00, 0x04];
    for f in fields {
        body.extend_from_slice(f.as_bytes());
        body.push(0);
    }
    pkt(0x1d, &body)
}

fn battery(left: u8, right: u8, case: Option<u8>) -> Vec<u8> {
    let mut b = vec![0x03];
    b.extend_from_slice(&[0x02, 0x01, right, 0x02, 0x01]);
    b.extend_from_slice(&[0x04, 0x01, left, 0x02, 0x01]);
    match case {
        Some(c) => b.extend_from_slice(&[0x08, 0x01, c, 0x02, 0x01]),
        None => b.extend_from_slice(&[0x08, 0x01, 0x00, 0x04, 0x01]),
    }
    pkt(0x04, &b)
}

/// Runs the pretend buds on one end of a datagram pair.
pub async fn headset(sock: UnixDatagram) {
    let mut buf = vec![0u8; 2048];
    let (mut left, mut right) = (100u8, 98u8);
    let mut tick = tokio::time::interval(Duration::from_secs(20));
    let mut up = false;
    let mut ticks = 0u32;
    loop {
        tokio::select! {
            r = sock.recv(&mut buf) => {
                let Ok(n) = r else { return };
                let d = buf[..n].to_vec();
                if d.starts_with(&[0x00, 0x00, 0x04, 0x00, 0x01]) {
                    let _ = sock.send(&[0x01, 0x00, 0x04, 0x00]).await;
                    up = true;
                    for p in [
                        info(),
                        battery(left, right, None),
                        pkt(0x06, &[0x00, 0x00]),
                        aap::control(aap::cmd::LISTENING_MODE, [0x02, 0, 0, 0]),
                        aap::control(aap::cmd::CONVERSATION, [0x01, 0, 0, 0]),
                        aap::control(aap::cmd::ADAPTIVE_STRENGTH, [50, 0, 0, 0]),
                        aap::control(aap::cmd::CHIME_VOLUME, [80, 80, 0, 0]),
                        aap::eq(aap::Eq { enabled: false, low: 50, mid: 50, high: 50 }),
                    ] {
                        let _ = sock.send(&p).await;
                    }
                } else if d.len() > 6 && (d[4] == 0x09 || d[4] == 0x63) {
                    // the buds confirm a setting by sending it back
                    let _ = sock.send(&d).await;
                }
            }
            _ = tick.tick(), if up => {
                // 1% every 100 s, faster than real use so estimates show up within minutes
                ticks += 1;
                if ticks.is_multiple_of(5) {
                    left = left.saturating_sub(1);
                    right = right.saturating_sub(1);
                    let _ = sock.send(&battery(left, right, None)).await;
                }
            }
        }
    }
}
