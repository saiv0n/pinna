// Registers with BlueZ as a battery provider so UPower, GNOME, KDE and bars
// show the AirPods battery in their own indicators.

use crate::daemon::{Daemon, Event};
use log::{debug, info};
use zbus::interface;
use zbus::OwnedObjectPath;

const ROOT: &str = "/dev/pinna/battery";

struct Provider {
    percentage: u8,
    device: OwnedObjectPath,
}

#[interface(name = "org.bluez.BatteryProvider1")]
impl Provider {
    #[zbus(property)]
    fn percentage(&self) -> u8 {
        self.percentage
    }
    #[zbus(property)]
    fn device(&self) -> OwnedObjectPath {
        self.device.clone()
    }
    #[zbus(property)]
    fn source(&self) -> String {
        "Pinna".into()
    }
}

/// Headphone battery: the lower bud, since the system shows one number.
fn level(v: &serde_json::Value) -> Option<u8> {
    let b = &v["battery"];
    ["left", "right"].iter().filter_map(|k| b[k]["level"].as_u64()).min().map(|n| n.min(100) as u8)
}

pub async fn run(d: Daemon) -> anyhow::Result<()> {
    let conn = zbus::Connection::system().await?;
    let server = conn.object_server();
    server.at(ROOT, zbus::fdo::ObjectManager).await?;
    let adapter = format!("/org/bluez/{}", d.adapter_name());
    let mgr = zbus::Proxy::new(&conn, "org.bluez", adapter.as_str(), "org.bluez.BatteryProviderManager1").await?;
    mgr.call_method("RegisterBatteryProvider", &(zbus::ObjectPath::try_from(ROOT)?,)).await?;
    info!("battery provider registered");
    let mut rx = d.events.subscribe();
    let mut shown: Option<(String, u8)> = None;
    loop {
        match rx.recv().await {
            Ok(Event::State) | Err(tokio::sync::broadcast::error::RecvError::Lagged(_)) => {}
            Ok(_) => continue,
            Err(_) => return Ok(()),
        }
        let v = d.value().await;
        let want = match (v["connected"].as_bool(), v["address"].as_str(), level(&v)) {
            (Some(true), Some(a), Some(p)) => Some((a.replace(':', "_"), p)),
            _ => None,
        };
        if want == shown {
            continue;
        }
        let path = |a: &str| format!("{ROOT}/dev_{a}");
        match (&shown, &want) {
            (Some((a, _)), Some((b, p))) if a == b => {
                let r = server.interface::<_, Provider>(path(b).as_str()).await?;
                r.get_mut().await.percentage = *p;
                r.get().await.percentage_changed(r.signal_emitter()).await?;
            }
            _ => {
                if let Some((a, _)) = &shown {
                    server.remove::<Provider, _>(path(a).as_str()).await?;
                }
                if let Some((a, p)) = &want {
                    let device = OwnedObjectPath::try_from(format!("{adapter}/dev_{a}"))?;
                    server.at(path(a).as_str(), Provider { percentage: *p, device }).await?;
                }
            }
        }
        debug!("system battery: {want:?}");
        shown = want;
    }
}
