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

#[interface(name = "dev.pinna.Daemon1")]
impl Service {
    async fn state(&self) -> String {
        self.d.json().await
    }

    async fn set_mode(&self, mode: &str) -> fdo::Result<()> {
        self.d.set_mode(mode).await.map_err(err)
    }

    async fn set_setting(&self, key: &str, value: &str) -> fdo::Result<()> {
        self.d.set_setting(key, value).await.map_err(err)
    }

    async fn set_pref(&self, key: &str, value: &str) -> fdo::Result<()> {
        self.d.set_pref(key, value).await.map_err(err)
    }

    async fn rename(&self, name: &str) -> fdo::Result<()> {
        self.d.rename(name).await.map_err(err)
    }

    async fn connect(&self) -> fdo::Result<()> {
        self.d.connect().await.map_err(err)
    }

    async fn disconnect(&self) -> fdo::Result<()> {
        self.d.disconnect().await.map_err(err)
    }

    async fn send_raw(&self, id: u8, d1: u8, d2: u8) -> fdo::Result<()> {
        self.d.raw(id, d1, d2).await.map_err(err)
    }

    #[zbus(signal)]
    async fn state_changed(emitter: &SignalEmitter<'_>, json: &str) -> zbus::Result<()>;

    #[zbus(signal)]
    async fn case_opened(emitter: &SignalEmitter<'_>, json: &str) -> zbus::Result<()>;
}

/// Durum değişikliklerini D-Bus sinyaline çevirir; art arda gelenleri 60 ms içinde birleştirir.
pub async fn pump(conn: zbus::Connection, d: Daemon) -> zbus::Result<()> {
    let iface = conn.object_server().interface::<_, Service>(PATH).await?;
    let emitter = iface.signal_emitter();
    let mut rx = d.events.subscribe();
    loop {
        let ev = match rx.recv().await {
            Ok(e) => e,
            Err(tokio::sync::broadcast::error::RecvError::Lagged(_)) => Event::State,
            Err(_) => return Ok(()),
        };
        match ev {
            Event::State => {
                tokio::time::sleep(std::time::Duration::from_millis(60)).await;
                while let Ok(Event::State) = rx.try_recv() {}
                Service::state_changed(emitter, &d.json().await).await?;
            }
            Event::CaseOpened(a) => {
                let j = serde_json::to_string(&a).unwrap_or_default();
                Service::case_opened(emitter, &j).await?;
            }
        }
    }
}
