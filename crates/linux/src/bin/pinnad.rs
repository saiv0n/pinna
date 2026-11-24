use pinna_linux::daemon::Daemon;
use pinna_linux::service::{self, Service};

#[tokio::main]
async fn main() -> anyhow::Result<()> {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info")).init();
    let conn = zbus::Connection::session().await?;
    let d = Daemon::new(conn.clone()).await?;
    conn.object_server().at(service::PATH, Service { d: d.clone() }).await?;
    // PINNA_BUS lets a test daemon run next to the real one
    let name = std::env::var("PINNA_BUS").unwrap_or_else(|_| service::NAME.into());
    conn.request_name(name.as_str()).await?;
    tokio::spawn(service::pump(conn.clone(), d.clone()));
    if std::env::var_os("PINNA_FAKE").is_some() {
        log::info!("pinnad ready with fake airpods on {name}");
        return d.run_fake().await;
    }
    let b = d.clone();
    tokio::spawn(async move {
        loop {
            match pinna_linux::battery::run(b.clone()).await {
                Err(e) if e.to_string() == "adapter changed" => tokio::time::sleep(std::time::Duration::from_secs(2)).await,
                Err(e) => break log::warn!("could not register with the system battery indicator: {e}"),
                Ok(()) => break,
            }
        }
    });
    log::info!("pinnad ready");
    d.run().await
}
