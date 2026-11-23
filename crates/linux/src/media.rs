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
        let out = Command::new("wpctl").args(["get-volume", "@DEFAULT_AUDIO_SINK@"]).output().await.ok()?;
        let s = String::from_utf8_lossy(&out.stdout);
        s.split_whitespace().nth(1)?.parse().ok()
    }

    async fn set_volume(v: f32) {
        let _ = Command::new("wpctl")
            .args(["set-volume", "@DEFAULT_AUDIO_SINK@", &format!("{v:.2}")])
            .status()
            .await;
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

/// Notifications follow the language picked in the app, else the session locale.
pub fn turkish() -> bool {
    let conf = dirs::config_dir().map(|d| d.join("pinna").join("Pinna.conf"));
    let picked = conf
        .and_then(|p| std::fs::read_to_string(p).ok())
        .and_then(|s| s.lines().find_map(|l| l.strip_prefix("language=").map(|v| v.trim().to_string())))
        .filter(|v| !v.is_empty());
    let lang = picked.or_else(|| ["LC_ALL", "LC_MESSAGES", "LANG"].iter().find_map(|k| std::env::var(k).ok().filter(|v| !v.is_empty())));
    lang.is_some_and(|l| l.starts_with("tr"))
}

pub fn t<'a>(en: &'a str, tr: &'a str) -> &'a str {
    if turkish() { tr } else { en }
}
