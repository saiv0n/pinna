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
    async fn cycle_mode(&self) -> zbus::Result<String>;
    async fn show_card(&self) -> zbus::Result<()>;
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
    /// Stream lines for a Waybar custom module (return-type json)
    Waybar,
    /// Listening mode: off, anc, transparency, adaptive
    Mode { mode: String },
    /// Switch to the next of the modes picked for press and hold
    Cycle,
    /// Show the battery card
    Card,
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
    /// Check the setup: service, Bluetooth, PipeWire tools, tray
    Doctor,
    /// Print shell completions: bash, zsh or fish
    Completions { shell: clap_complete::Shell },
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
    if s["oneBattery"].as_bool() == Some(true) {
        println!("  Battery {}", bat(&s["battery"]["left"]));
    } else {
        println!("  Left {}   Right {}   Case {}", bat(&s["battery"]["left"]), bat(&s["battery"]["right"]), bat(&s["battery"]["case"]));
    }
    if let Some(m) = s["mode"].as_str() {
        println!("  Mode: {}", mode_name(m));
    }
    let ear = |p: &Value| match p.as_str() {
        Some("ear") => "in ear",
        Some("out") => "out",
        Some("case") => "in case",
        _ => "?",
    };
    if s["oneBattery"].as_bool() != Some(true) {
        println!("  Left {}, right {}", ear(&s["ear"]["left"]), ear(&s["ear"]["right"]));
    }
    let left = ["left", "right"].iter().filter_map(|k| s["estimate"][k].as_u64()).min();
    if let Some(m) = left {
        println!("  About {}h {:02}m of listening left", m / 60, m % 60);
    }
    if s["eq"]["enabled"].as_bool() == Some(true) {
        let b = |k: &str| s["eq"][k].as_i64().unwrap_or(50) - 50;
        println!("  EQ: bass {:+}, mids {:+}, treble {:+}", b("low"), b("mid"), b("high"));
    }
    if let Some(f) = s["firmware"].as_str().filter(|f| !f.is_empty()) {
        match s["version"].as_str().filter(|v| !v.is_empty()) {
            Some(v) => println!("  Firmware: {f} ({v})"),
            None => println!("  Firmware: {f}"),
        }
    }
}

async fn has_name(conn: &zbus::Connection, name: &str) -> bool {
    let Ok(dbus) = zbus::fdo::DBusProxy::new(conn).await else { return false };
    let Ok(n) = zbus::names::BusName::try_from(name) else { return false };
    dbus.name_has_owner(n).await.unwrap_or(false)
}

fn in_path(tool: &str) -> bool {
    std::env::var_os("PATH").is_some_and(|p| std::env::split_paths(&p).any(|d| d.join(tool).is_file()))
}

/// Walks through what Pinna needs and says what to do about anything missing.
async fn doctor(conn: &zbus::Connection) -> anyhow::Result<()> {
    let mut failed = false;
    let mut line = |level: &str, what: &str, hint: &str| {
        failed |= level == "fail";
        if hint.is_empty() {
            println!("{level:>4}  {what}");
        } else {
            println!("{level:>4}  {what}\n      {hint}");
        }
    };
    let name = std::env::var("PINNA_BUS").unwrap_or_else(|_| "dev.pinna.Daemon".into());
    let state: Option<Value> = if has_name(conn, &name).await {
        let p = DaemonProxy::builder(conn).destination(name.as_str()).build().await?;
        p.state().await.ok().and_then(|s| serde_json::from_str(&s).ok())
    } else {
        None
    };
    match &state {
        Some(_) => line("ok", "pinnad is running", ""),
        None => line("fail", "pinnad is not running", "systemctl --user enable --now pinnad.service"),
    }
    let system = zbus::Connection::system().await.ok();
    match &system {
        Some(c) if has_name(c, "org.bluez").await => line("ok", "BlueZ is running", ""),
        _ => line("fail", "BlueZ is not running", "start bluetooth.service, Pinna needs it for everything"),
    }
    if let Some(s) = &state {
        if s["adapter"].as_bool() == Some(true) {
            line("ok", "Bluetooth is on", "");
        } else {
            line("fail", "Bluetooth is off or there is no adapter", "turn it on in the system settings or with bluetoothctl power on");
        }
        let n = s["devices"].as_array().map_or(0, |d| d.len());
        if n == 0 {
            line("warn", "no paired AirPods or Beats", "pair them once from the system Bluetooth settings or with Start Pairing in the app");
        } else {
            line("ok", &format!("{n} paired headphones"), "");
        }
        if n > 0 && s["hasKeys"].as_bool() != Some(true) {
            line("warn", "no case keys yet", "connect the headphones once; the case battery and finder need the keys they send");
        }
    }
    for tool in ["pactl", "wpctl", "pw-cli"] {
        if in_path(tool) {
            line("ok", &format!("{tool} found"), "");
        } else {
            line("warn", &format!("{tool} not found"), "install the PipeWire tools; without them audio settings and volume features stay off");
        }
    }
    let main = std::fs::read_to_string("/etc/bluetooth/main.conf").unwrap_or_default();
    if main.lines().any(|l| l.trim_start().starts_with("DeviceID") && l.contains("bluetooth:004C")) {
        line("ok", "DeviceID is set to Apple", "");
    } else {
        line("info", "DeviceID is not set", "optional; some features want an Apple device, see This Computer > Bluetooth");
    }
    if std::path::Path::new("/usr/share/libmysofa/default.sofa").exists() {
        line("ok", "spatial audio filter found", "");
    } else {
        line("info", "no /usr/share/libmysofa/default.sofa", "only needed for spatial audio; install libmysofa");
    }
    if has_name(conn, "org.kde.StatusNotifierWatcher").await {
        line("ok", "a system tray is available", "");
    } else {
        line("info", "no system tray found", "the app still works; closing the window quits it");
    }
    if failed {
        anyhow::bail!("some checks failed");
    }
    Ok(())
}

/// One line per state change, built from the full state; nothing is printed when the line
/// would repeat. Ends quietly when the reader goes away.
async fn follow(p: &DaemonProxy<'_>, line: impl Fn(&Value) -> Option<String>) -> anyhow::Result<()> {
    use std::io::Write;
    let mut st = p.receive_state_changed().await?;
    let mut out = std::io::stdout().lock();
    let mut full: Value = serde_json::from_str(&p.state().await?)?;
    let mut last = None;
    loop {
        if let Some(l) = line(&full).filter(|l| last.as_ref() != Some(l)) {
            if writeln!(out, "{l}").and_then(|_| out.flush()).is_err() {
                return Ok(());
            }
            last = Some(l);
        }
        // the service only sends changed fields
        let Some(sig) = st.next().await else { return Ok(()) };
        if let (Value::Object(m), Ok(Value::Object(d))) = (&mut full, serde_json::from_str(sig.args()?.json)) {
            m.extend(d);
        }
    }
}

/// Waybar custom module output: the lower bud in the bar, details in the tooltip.
fn waybar(s: &Value) -> Value {
    let name = s["name"].as_str().filter(|n| !n.is_empty()).unwrap_or("AirPods");
    if !s["connected"].as_bool().unwrap_or(false) {
        return serde_json::json!({ "text": "", "tooltip": format!("{name}: not connected"), "class": "disconnected" });
    }
    let b = &s["battery"];
    let low = ["left", "right"].iter().filter_map(|k| b[k]["level"].as_u64()).min();
    let mode = s["mode"].as_str().unwrap_or("");
    let mut class = vec!["connected".to_string()];
    if !mode.is_empty() {
        class.push(mode.to_string());
    }
    if low.is_some_and(|l| l <= 20) {
        class.push("low".into());
    }
    if ["left", "right"].iter().any(|k| b[k]["charging"].as_bool() == Some(true)) {
        class.push("charging".into());
    }
    let levels = if s["oneBattery"].as_bool() == Some(true) {
        format!("Battery {}", bat(&b["left"]))
    } else {
        format!("Left {}   Right {}   Case {}", bat(&b["left"]), bat(&b["right"]), bat(&b["case"]))
    };
    let mut tip = format!("{name}\n{levels}");
    if !mode.is_empty() {
        tip += &format!("\n{}", mode_name(mode));
    }
    serde_json::json!({
        "text": low.map(|l| format!("{l}%")).unwrap_or_default(),
        "alt": mode,
        "tooltip": tip,
        "class": class,
        "percentage": low.unwrap_or(0),
    })
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
    if let Some(Cmd::Completions { shell }) = cli.cmd {
        use clap::CommandFactory;
        clap_complete::generate(shell, &mut Cli::command(), "pinnactl", &mut std::io::stdout());
        return Ok(());
    }
    let conn = zbus::Connection::session().await?;
    if let Some(Cmd::Doctor) = cli.cmd {
        return doctor(&conn).await;
    }
    let mut b = DaemonProxy::builder(&conn);
    // PINNA_BUS talks to a test daemon instead of the real one
    if let Ok(name) = std::env::var("PINNA_BUS") {
        b = b.destination(name);
    }
    let p = b.build().await?;
    match cli.cmd.unwrap_or(Cmd::Status) {
        Cmd::Status => print_status(&serde_json::from_str(&p.state().await?)?),
        Cmd::Json => println!("{}", p.state().await?),
        Cmd::Watch => follow(&p, |v| Some(v.to_string())).await?,
        Cmd::Waybar => follow(&p, |v| Some(waybar(v).to_string())).await?,
        Cmd::Mode { mode } => p.set_mode(&mode).await?,
        Cmd::Cycle => println!("{}", mode_name(&p.cycle_mode().await?)),
        Cmd::Card => p.show_card().await?,
        Cmd::Set { key, value } => p.set_setting(&key, &value).await?,
        Cmd::Pref { key, value } => p.set_pref(&key, &value).await?,
        Cmd::Rename { name } => p.rename(&name).await?,
        Cmd::Audio { key, value } => p.set_audio(&key, &value).await?,
        Cmd::Connect => p.connect().await?,
        Cmd::Disconnect => p.disconnect().await?,
        Cmd::Completions { .. } | Cmd::Doctor => {}
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn waybar_lines() {
        let off = waybar(&serde_json::json!({ "name": "Pods", "connected": false }));
        assert_eq!(off["class"], "disconnected");
        assert_eq!(off["text"], "");
        let on = waybar(&serde_json::json!({
            "name": "Pods", "connected": true, "mode": "anc",
            "battery": { "left": { "level": 15, "charging": false }, "right": { "level": 40, "charging": true }, "case": { "level": null } }
        }));
        assert_eq!(on["text"], "15%");
        assert_eq!(on["percentage"], 15);
        assert_eq!(on["class"], serde_json::json!(["connected", "anc", "low", "charging"]));
        assert!(on["tooltip"].as_str().unwrap().contains("Noise Cancellation"));
        let max = waybar(&serde_json::json!({
            "connected": true, "oneBattery": true, "battery": { "left": { "level": 70 } }
        }));
        assert!(max["tooltip"].as_str().unwrap().contains("Battery 70%"));
    }
}
