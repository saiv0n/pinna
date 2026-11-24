// Pausing MPRIS players on ear removal, ducking while you speak, and notifications.

use std::collections::HashMap;
use tokio::process::Command;
use zbus::Connection;
use zbus::Variant;

const MPRIS: &str = "org.mpris.MediaPlayer2.";
const PATH: &str = "/org/mpris/MediaPlayer2";
const PLAYER: &str = "org.mpris.MediaPlayer2.Player";

pub struct Media {
    conn: Connection,
    paused: Vec<String>,
    ducked_from: Option<f32>,
}

impl Media {
    pub fn new(conn: Connection) -> Media {
        Media { conn, paused: Vec::new(), ducked_from: None }
    }

    async fn players(&self) -> Vec<String> {
        let Ok(proxy) = zbus::fdo::DBusProxy::new(&self.conn).await else { return vec![] };
        let Ok(names) = proxy.list_names().await else { return vec![] };
        names.into_iter().map(|n| n.to_string()).filter(|n| n.starts_with(MPRIS)).collect()
    }

    async fn status(&self, name: &str) -> Option<String> {
        let p = zbus::Proxy::new(&self.conn, name.to_owned(), PATH, PLAYER).await.ok()?;
        p.get_property::<String>("PlaybackStatus").await.ok()
    }

    async fn call(&self, name: &str, method: &str) {
        if let Ok(p) = zbus::Proxy::new(&self.conn, name.to_owned(), PATH, PLAYER).await {
            let _ = p.call_method(method, &()).await;
        }
    }

    pub async fn pause_all(&mut self) {
        for n in self.players().await {
            if self.status(&n).await.as_deref() == Some("Playing") {
                self.call(&n, "Pause").await;
                if !self.paused.contains(&n) {
                    self.paused.push(n);
                }
            }
        }
    }

    pub async fn resume(&mut self) {
        for n in std::mem::take(&mut self.paused) {
            self.call(&n, "Play").await;
        }
    }

    /// Sends an MPRIS command to the playing player, or the first one.
    pub async fn player(&self, method: &str) {
        let all = self.players().await;
        let mut pick = all.first().cloned();
        for n in &all {
            if self.status(n).await.as_deref() == Some("Playing") {
                pick = Some(n.clone());
                break;
            }
        }
        if let Some(n) = pick {
            self.call(&n, method).await;
        }
    }

    pub fn forget(&mut self) {
        self.paused.clear();
    }

    async fn volume() -> Option<f32> {
        sink_volume().await
    }

    async fn set_volume(v: f32) {
        set_sink_volume(v).await;
    }

    /// level: speech level from the buds. 1-2 speaking, 3-7 in between, 8-9 normal.
    /// Volume comes back gradually in between so it does not jump.
    pub async fn speech(&mut self, level: u8, duck_to: u8) {
        if level >= 8 {
            if let Some(v) = self.ducked_from.take() {
                Self::set_volume(v).await;
            }
            return;
        }
        if self.ducked_from.is_none() {
            if level > 2 {
                return;
            }
            match Self::volume().await {
                Some(v) => self.ducked_from = Some(v),
                None => return,
            }
        }
        let Some(full) = self.ducked_from else { return };
        let low = duck_to as f32 / 100.0;
        let t = (level.saturating_sub(2) as f32 / 6.0).clamp(0.0, 1.0);
        Self::set_volume(full * (low + (1.0 - low) * t)).await;
    }

    pub async fn notify(&self, title: &str, body: &str, icon: &str) {
        let Ok(p) = zbus::Proxy::new(
            &self.conn,
            "org.freedesktop.Notifications",
            "/org/freedesktop/Notifications",
            "org.freedesktop.Notifications",
        )
        .await
        else {
            return;
        };
        let hints: HashMap<&str, Variant> = HashMap::new();
        let actions: Vec<&str> = vec![];
        let _ = p
            .call_method("Notify", &("Pinna", 0u32, icon, title, body, actions, hints, 5000i32))
            .await;
    }
}

include!(concat!(env!("OUT_DIR"), "/notify.rs"));

/// Notifications follow the language picked in the app, else the session locale.
fn language() -> String {
    let conf = dirs::config_dir().map(|d| d.join("pinna").join("Pinna.conf"));
    let picked = conf
        .and_then(|p| std::fs::read_to_string(p).ok())
        .and_then(|s| s.lines().find_map(|l| l.strip_prefix("language=").map(|v| v.trim().to_string())))
        .filter(|v| !v.is_empty());
    picked
        .or_else(|| ["LC_ALL", "LC_MESSAGES", "LANG"].iter().find_map(|k| std::env::var(k).ok().filter(|v| !v.is_empty())))
        .unwrap_or_default()
}

/// English text in, the same text in the user's language out, from app/i18n.
pub fn t(en: &'static str) -> &'static str {
    lookup(&language(), en)
}

fn lookup(lang: &str, en: &'static str) -> &'static str {
    // "pt_BR.UTF-8" tries pt_BR, then pt
    let full = lang.split('.').next().unwrap_or("");
    let short = full.split(['_', '-']).next().unwrap_or("");
    [full, short]
        .iter()
        .filter(|l| !l.is_empty())
        .find_map(|l| NOTIFY.iter().find(|(code, _)| code == l))
        .and_then(|(_, table)| table.iter().find(|(src, _)| *src == en))
        .map_or(en, |(_, tr)| tr)
}

#[cfg(test)]
mod lang_tests {
    #[test]
    fn falls_back_to_english() {
        assert_eq!(super::lookup("tr_TR.UTF-8", "Case"), "Kutu");
        assert_eq!(super::lookup("tr", "Microphone muted"), "Mikrofon kapalı");
        assert_eq!(super::lookup("xx_YY", "Case"), "Case");
        assert_eq!(super::lookup("", "Case"), "Case");
    }
}

// wpctl first; the Flatpak runtime only has pactl

async fn run(cmd: &str, args: &[&str]) -> Option<String> {
    // decimals and "yes" must not come out translated
    let out = Command::new(cmd).args(args).env("LC_ALL", "C").output().await.ok()?;
    out.status.success().then(|| String::from_utf8_lossy(&out.stdout).into_owned())
}

/// "Volume: front-left: 39321 /  60% / -13.31 dB, ..." -> 0.6
fn pactl_percent(s: &str) -> Option<f32> {
    let p = s.split('%').next()?.rsplit(' ').next()?.trim();
    p.parse::<f32>().ok().map(|v| v / 100.0)
}

pub async fn sink_volume() -> Option<f32> {
    if let Some(s) = run("wpctl", &["get-volume", "@DEFAULT_AUDIO_SINK@"]).await {
        return s.split_whitespace().nth(1)?.parse().ok();
    }
    pactl_percent(&run("pactl", &["get-sink-volume", "@DEFAULT_SINK@"]).await?)
}

pub async fn set_sink_volume(v: f32) {
    let v = v.clamp(0.0, 1.0);
    if run("wpctl", &["set-volume", "@DEFAULT_AUDIO_SINK@", &format!("{v:.2}")]).await.is_none() {
        let _ = run("pactl", &["set-sink-volume", "@DEFAULT_SINK@", &format!("{}%", (v * 100.0).round())]).await;
    }
}

/// One volume step up or down, never above 100%.
pub async fn step_volume(up: bool) {
    if let Some(v) = sink_volume().await {
        set_sink_volume(v + if up { 0.05 } else { -0.05 }).await;
    }
}

/// Toggles the default mic; returns whether it is muted now.
pub async fn toggle_mic() -> bool {
    if run("wpctl", &["set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]).await.is_some() {
        return run("wpctl", &["get-volume", "@DEFAULT_AUDIO_SOURCE@"]).await.is_some_and(|s| s.contains("MUTED"));
    }
    let _ = run("pactl", &["set-source-mute", "@DEFAULT_SOURCE@", "toggle"]).await;
    run("pactl", &["get-source-mute", "@DEFAULT_SOURCE@"]).await.is_some_and(|s| s.contains("yes"))
}

#[cfg(test)]
mod volume_tests {
    #[test]
    fn pactl_output() {
        let s = "Volume: front-left: 39321 /  60% / -13.31 dB,   front-right: 39321 /  60% / -13.31 dB\n        balance 0.00\n";
        assert_eq!(super::pactl_percent(s), Some(0.6));
        assert_eq!(super::pactl_percent("Volume: mono: 65536 / 100% / 0.00 dB"), Some(1.0));
        assert_eq!(super::pactl_percent("nothing"), None);
    }
}
