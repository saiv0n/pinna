use crate::daemon::{Daemon, Event};
use zbus::object_server::SignalEmitter;
use zbus::{fdo, interface};

pub const NAME: &str = "dev.pinna.Daemon";
pub const PATH: &str = "/dev/pinna/Daemon";

pub struct Service {
    pub d: Daemon,
}

fn err(e: anyhow::Error) -> fdo::Error {
    fdo::Error::Failed(format!("{e:#}"))
}

/// D-Bus'tan gelen her metin için üst sınır; asıl doğrulama daemon tarafında.
fn short(s: &str) -> fdo::Result<&str> {
    if s.len() > 64 || s.chars().any(char::is_control) {
        return Err(fdo::Error::InvalidArgs("invalid: Değer çok uzun ya da geçersiz.".into()));
    }
    Ok(s)
}

#[interface(name = "dev.pinna.Daemon1")]
impl Service {
    async fn power_on(&self) -> fdo::Result<()> {
        self.d.power_on().await.map_err(err)
    }

    async fn state(&self) -> String {
        self.d.json().await
    }

    async fn set_mode(&self, mode: &str) -> fdo::Result<()> {
        self.d.set_mode(short(mode)?).await.map_err(err)
    }

    async fn set_setting(&self, key: &str, value: &str) -> fdo::Result<()> {
        self.d.set_setting(short(key)?, short(value)?).await.map_err(err)
    }

    async fn set_pref(&self, key: &str, value: &str) -> fdo::Result<()> {
        self.d.set_pref(short(key)?, short(value)?).await.map_err(err)
    }

    async fn rename(&self, name: &str) -> fdo::Result<()> {
        self.d.rename(short(name)?).await.map_err(err)
    }

    async fn connect(&self) -> fdo::Result<()> {
        self.d.connect().await.map_err(err)
    }

    async fn disconnect(&self) -> fdo::Result<()> {
        self.d.disconnect().await.map_err(err)
    }

    async fn select(&self, address: &str) -> fdo::Result<()> {
        self.d.select(short(address)?).await.map_err(err)
    }

    async fn forget(&self, address: &str) -> fdo::Result<()> {
        self.d.forget(short(address)?).await.map_err(err)
    }

    async fn discover(&self, on: bool) -> fdo::Result<()> {
        self.d.discover(on).await.map_err(err)
    }

    async fn pair(&self, address: &str) -> fdo::Result<()> {
        self.d.pair(short(address)?).await.map_err(err)
    }

    async fn set_audio(&self, key: &str, value: &str) -> fdo::Result<()> {
        self.d.set_audio(short(key)?, short(value)?).await.map_err(err)
    }

    async fn head_tracking(&self, on: bool) -> fdo::Result<()> {
        self.d.head_tracking(on).await.map_err(err)
    }

    /// Son 24 saatin pil kayıtları: [[unix, sol, sağ, kutu], ...]
    async fn battery_history(&self) -> String {
        serde_json::to_string(&crate::history::read()).unwrap_or_default()
    }

    #[zbus(signal)]
    async fn state_changed(emitter: &SignalEmitter<'_>, json: &str) -> zbus::Result<()>;

    #[zbus(signal)]
    async fn head(emitter: &SignalEmitter<'_>, values: &[i16]) -> zbus::Result<()>;

    #[zbus(signal)]
    async fn case_opened(emitter: &SignalEmitter<'_>, json: &str) -> zbus::Result<()>;
}

/// Durum değişikliklerini D-Bus sinyaline çevirir. Beklemeden gönderir, kuyrukta biriken değişiklikleri
/// birleştirir ve sinyalde yalnızca değişen üst düzey alanlar gider; istemci elindeki duruma katar.
pub async fn pump(conn: zbus::Connection, d: Daemon) -> zbus::Result<()> {
    let iface = conn.object_server().interface::<_, Service>(PATH).await?;
    let emitter = iface.signal_emitter();
    let mut rx = d.events.subscribe();
    let mut last_head = std::time::Instant::now();
    let mut held = None;
    let mut last = serde_json::Map::new();
    loop {
        let ev = match held.take() {
            Some(e) => e,
            None => match rx.recv().await {
                Ok(e) => e,
                Err(tokio::sync::broadcast::error::RecvError::Lagged(_)) => Event::State,
                Err(_) => return Ok(()),
            },
        };
        match ev {
            Event::State => {
                tokio::task::yield_now().await;
                // araya giren başka bir olayı kaybetme
                while let Ok(e) = rx.try_recv() {
                    if !matches!(e, Event::State) {
                        held = Some(e);
                        break;
                    }
                }
                let serde_json::Value::Object(now) = d.value().await else { continue };
                let diff: serde_json::Map<_, _> =
                    now.iter().filter(|(k, v)| last.get(*k) != Some(v)).map(|(k, v)| (k.clone(), v.clone())).collect();
                last = now;
                if !diff.is_empty() {
                    Service::state_changed(emitter, &serde_json::Value::Object(diff).to_string()).await?;
                }
            }
            Event::Head(v) => {
                // kulaklık saniyede yüzlerce paket yolluyor, arayüze 30 Hz yeter
                if last_head.elapsed().as_millis() >= 33 {
                    last_head = std::time::Instant::now();
                    Service::head(emitter, &v).await?;
                }
            }
            Event::CaseOpened(a) => {
                let j = serde_json::to_string(&a).unwrap_or_default();
                Service::case_opened(emitter, &j).await?;
            }
        }
    }
}
