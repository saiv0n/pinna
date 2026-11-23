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

/// Control AirPods from the command line.
#[derive(Parser)]
#[command(name = "pinnactl", version)]
struct Cli {
    #[command(subcommand)]
    cmd: Option<Cmd>,
}

#[derive(Subcommand)]
enum Cmd {
    /// Show status (default)
    Status,
    /// Print status as JSON
    Json,
    /// Print one JSON line on every change
    Watch,
    /// Listening mode: off, anc, transparency, adaptive
    Mode { mode: String },
    /// Cycle through ANC, adaptive and transparency
    Cycle,
    /// Change a headphone setting, e.g. conversationAwareness on
    Set { key: String, value: String },
    /// Change an app preference, e.g. autoPause off
    Pref { key: String, value: String },
    /// Rename the headphones
    Rename { name: String },
    /// Audio setting: profile a2dp|hfp, volume 0-100, default true
    Audio { key: String, value: String },
    /// Connect the last used headphones
    Connect,
    /// Disconnect
    Disconnect,
}

fn bat(v: &Value) -> String {
    match v["level"].as_u64() {
        Some(l) => format!("{l}%{}", if v["charging"].as_bool() == Some(true) { " ⚡" } else { "" }),
        None => "—".into(),
    }
}

fn mode_name(m: &str) -> &str {
    match m {
        "off" => "Off",
        "anc" => "Noise Cancellation",
        "transparency" => "Transparency",
        "adaptive" => "Adaptive",
        _ => m,
    }
}

fn print_status(s: &Value) {
    let name = s["name"].as_str().unwrap_or("AirPods");
    if !s["connected"].as_bool().unwrap_or(false) {
        println!("{name}: not connected");
        return;
    }
    println!("{name}  ({})", s["modelName"].as_str().unwrap_or(""));
    println!("  Left {}   Right {}   Case {}", bat(&s["battery"]["left"]), bat(&s["battery"]["right"]), bat(&s["battery"]["case"]));
    if let Some(m) = s["mode"].as_str() {
        println!("  Mode: {}", mode_name(m));
    }
    let ear = |p: &Value| match p.as_str() {
        Some("ear") => "in ear",
        Some("out") => "out",
        Some("case") => "in case",
        _ => "?",
    };
    println!("  Left {}, right {}", ear(&s["ear"]["left"]), ear(&s["ear"]["right"]));
}

#[tokio::main(flavor = "current_thread")]
async fn main() {
    if let Err(e) = run(Cli::parse()).await {
        // the service sends "code: message", people only need the message
        let raw = e.root_cause().to_string();
        let msg = if raw.contains("ServiceUnknown") {
            "The Pinna service is not running, start it with systemctl --user start pinnad.".to_string()
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
            // exit quietly when the reader goes away
            let mut full: Value = serde_json::from_str(&p.state().await?)?;
            if writeln!(out, "{full}").and_then(|_| out.flush()).is_err() {
                return Ok(());
            }
            // the service only sends changed fields, still print the full state per line
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
            println!("{}", mode_name(next));
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
