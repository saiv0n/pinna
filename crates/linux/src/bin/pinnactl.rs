use clap::{Parser, Subcommand};
use futures::StreamExt;
use serde_json::Value;
use zbus::proxy;

#[proxy(
    interface = "dev.pinna.Daemon1",
    default_service = "dev.pinna.Daemon",
    default_path = "/dev/pinna/Daemon"
)]
trait Daemon {
    async fn state(&self) -> zbus::Result<String>;
    async fn set_mode(&self, mode: &str) -> zbus::Result<()>;
    async fn set_setting(&self, key: &str, value: &str) -> zbus::Result<()>;
    async fn set_pref(&self, key: &str, value: &str) -> zbus::Result<()>;
    async fn rename(&self, name: &str) -> zbus::Result<()>;
    async fn connect(&self) -> zbus::Result<()>;
    async fn disconnect(&self) -> zbus::Result<()>;
    async fn set_audio(&self, key: &str, value: &str) -> zbus::Result<()>;
    #[zbus(signal)]
    fn state_changed(&self, json: &str) -> zbus::Result<()>;
}

/// AirPods'u komut satırından yönet.
#[derive(Parser)]
#[command(name = "pinnactl", version)]
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
    /// Ses ayarı: profile a2dp|hfp, volume 0-100, default true
    Audio { key: String, value: String },
    /// Son kullanılan kulaklığa bağlan
    Connect,
    /// Bağlantıyı kes
    Disconnect,
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
async fn main() {
    if let Err(e) = run(Cli::parse()).await {
        // servis "tür: açıklama" yolluyor, kullanıcıya sadece açıklama lazım
        let raw = e.root_cause().to_string();
        let msg = if raw.contains("ServiceUnknown") {
            "Pinna servisi çalışmıyor, systemctl --user start pinnad ile başlat.".to_string()
        } else if let Some(rest) = raw.strip_prefix("org.freedesktop.DBus.Error.").and_then(|r| r.split_once(": ")) {
            rest.1.split_once(": ").map_or(rest.1, |(_, t)| t).to_string()
        } else {
            raw
        };
        eprintln!("pinnactl: {msg}");
        std::process::exit(1);
    }
}

async fn run(cli: Cli) -> anyhow::Result<()> {
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
            let mut full: Value = serde_json::from_str(&p.state().await?)?;
            if writeln!(out, "{full}").and_then(|_| out.flush()).is_err() {
                return Ok(());
            }
            // servis sadece değişen alanları yolluyor, satır başına yine tam durum yazılsın
            while let Some(sig) = st.next().await {
                if let (Value::Object(m), Ok(Value::Object(d))) = (&mut full, serde_json::from_str(sig.args()?.json)) {
                    m.extend(d);
                }
                if writeln!(out, "{full}").and_then(|_| out.flush()).is_err() {
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
        Cmd::Audio { key, value } => p.set_audio(&key, &value).await?,
        Cmd::Connect => p.connect().await?,
        Cmd::Disconnect => p.disconnect().await?,
    }
    Ok(())
}
