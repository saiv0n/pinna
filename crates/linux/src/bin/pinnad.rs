use pinna_linux::daemon::Daemon;
use pinna_linux::service::{self, Service};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();
    let conn = zbus::Connection::session().await?;
    let d = Daemon::new(conn.clone()).await?;
    conn.object_server().at(service::PATH, Service { d: d.clone() }).await?;
    conn.request_name(service::NAME).await?;
    tokio::spawn(service::pump(conn.clone(), d.clone()));
    let b = d.clone();
    tokio::spawn(async move {
        if let Err(e) = pinna_linux::battery::run(b).await {
            log::warn!("could not register with the system battery indicator: {e}");
        }
    });
    log::info!("pinnad ready");
    d.run().await
}
