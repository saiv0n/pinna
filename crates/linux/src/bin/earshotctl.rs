use clap::{Parser, Subcommand};
use futures::StreamExt;
use serde_json::Value;
use zbus::proxy;

#[proxy(
    interface = "dev.earshot.Daemon1",
    default_service = "dev.earshot.Daemon",
    default_path = "/dev/earshot/Daemon"
)]
trait Daemon {
    async fn state(&self) -> zbus::Result<String>;
    async fn set_mode(&self, mode: &str) -> zbus::Result<()>;
    async fn set_setting(&self, key: &str, value: &str) -> zbus::Result<()>;
    async fn set_pref(&self, key: &str, value: &str) -> zbus::Result<()>;
    async fn rename(&self, name: &str) -> zbus::Result<()>;
    async fn connect(&self) -> zbus::Result<()>;
    async fn disconnect(&self) -> zbus::Result<()>;
    async fn send_raw(&self, id: u8, d1: u8, d2: u8) -> zbus::Result<()>;
    #[zbus(signal)]
    fn state_changed(&self, json: &str) -> zbus::Result<()>;
}

/// AirPods'u komut satırından yönet.
#[derive(Parser)]
#[command(name = "earshotctl", version)]
struct Cli {
    #[command(subcommand)]
    cmd: Option<Cmd>,
}

#[derive(Subcommand)]
enum Cmd {
    /// Durumu göster (varsayılan)
    Status,
    /// Durumu JSON olarak yaz
    Json,
    /// Her değişiklikte bir satır JSON yaz
    Watch,
    /// Dinleme modu: off, anc, transparency, adaptive
    Mode { mode: String },
    /// ANC, uyarlanabilir ve şeffaf arasında sırayla geç
    Cycle,
    /// Kulaklık ayarı değiştir, ör. conversationAwareness on
    Set { key: String, value: String },
    /// Uygulama tercihi değiştir, ör. autoPause off
    Pref { key: String, value: String },
    /// Kulaklığın adını değiştir
    Rename { name: String },
    Connect,
    Disconnect,
    /// Ham kontrol komutu gönder (deneme için)
    Raw {
        #[arg(value_parser = hex_u8)]
        id: u8,
        #[arg(value_parser = hex_u8)]
        d1: u8,
        #[arg(value_parser = hex_u8, default_value = "0")]
        d2: u8,
    },
}

fn hex_u8(s: &str) -> Result<u8, String> {
    let s = s.trim_start_matches("0x");
    u8::from_str_radix(s, 16).map_err(|e| e.to_string())
}

fn bat(v: &Value) -> String {
    match v["level"].as_u64() {
        Some(l) => format!("%{l}{}", if v["charging"].as_bool() == Some(true) { " ⚡" } else { "" }),
        None => "—".into(),
    }
}

fn mode_tr(m: &str) -> &str {
    match m {
        "off" => "Kapalı",
        "anc" => "Gürültü Engelleme",
        "transparency" => "Şeffaf",
        "adaptive" => "Uyarlanabilir",
        _ => m,
    }
}

fn print_status(s: &Value) {
    let name = s["name"].as_str().unwrap_or("AirPods");
    if !s["connected"].as_bool().unwrap_or(false) {
        println!("{name}: bağlı değil");
        return;
    }
    println!("{name}  ({})", s["modelName"].as_str().unwrap_or(""));
    println!("  Sol {}   Sağ {}   Kutu {}", bat(&s["battery"]["left"]), bat(&s["battery"]["right"]), bat(&s["battery"]["case"]));
    if let Some(m) = s["mode"].as_str() {
        println!("  Mod: {}", mode_tr(m));
    }
    let ear = |p: &Value| match p.as_str() {
        Some("ear") => "kulakta",
        Some("out") => "dışarıda",
        Some("case") => "kutuda",
        _ => "?",
    };
    println!("  Sol {}, sağ {}", ear(&s["ear"]["left"]), ear(&s["ear"]["right"]));
}

#[tokio::main(flavor = "current_thread")]
async fn main() -> anyhow::Result<()> {
    let cli = Cli::parse();
    let conn = zbus::Connection::session().await?;
    let p = DaemonProxy::new(&conn).await?;
    match cli.cmd.unwrap_or(Cmd::Status) {
        Cmd::Status => print_status(&serde_json::from_str(&p.state().await?)?),
        Cmd::Json => println!("{}", p.state().await?),
        Cmd::Watch => {
            use std::io::Write;
            let mut st = p.receive_state_changed().await?;
            let mut out = std::io::stdout().lock();
            // okuyan taraf kapanınca sessizce çık
            if writeln!(out, "{}", p.state().await?).and_then(|_| out.flush()).is_err() {
                return Ok(());
            }
            while let Some(sig) = st.next().await {
                if writeln!(out, "{}", sig.args()?.json).and_then(|_| out.flush()).is_err() {
                    return Ok(());
                }
            }
        }
        Cmd::Mode { mode } => p.set_mode(&mode).await?,
        Cmd::Cycle => {
            let s: Value = serde_json::from_str(&p.state().await?)?;
            let next = match s["mode"].as_str() {
                Some("anc") => "adaptive",
                Some("adaptive") => "transparency",
                _ => "anc",
            };
            p.set_mode(next).await?;
            println!("{}", mode_tr(next));
        }
        Cmd::Set { key, value } => p.set_setting(&key, &value).await?,
        Cmd::Pref { key, value } => p.set_pref(&key, &value).await?,
        Cmd::Rename { name } => p.rename(&name).await?,
        Cmd::Connect => p.connect().await?,
        Cmd::Disconnect => p.disconnect().await?,
        Cmd::Raw { id, d1, d2 } => p.send_raw(id, d1, d2).await?,
    }
    Ok(())
}
