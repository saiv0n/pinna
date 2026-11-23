// PipeWire tarafı: pactl'in JSON çıktısıyla kulaklığın kartını ve çıkışını bulur.

use pinna_core::state::Audio;
use serde_json::Value;
use tokio::process::Command;

async fn pactl(args: &[&str]) -> Option<String> {
    let out = Command::new("pactl").args(args).output().await.ok()?;
    out.status.success().then(|| String::from_utf8_lossy(&out.stdout).into_owned())
}

async fn list(kind: &str) -> Vec<Value> {
    let Some(s) = pactl(&["-f", "json", "list", kind]).await else { return vec![] };
    serde_json::from_str::<Value>(&s).ok().and_then(|v| v.as_array().cloned()).unwrap_or_default()
}

fn prop<'a>(v: &'a Value, key: &str) -> &'a str {
    v["properties"][key].as_str().unwrap_or("")
}

fn ours(v: &Value, addr: &str) -> bool {
    prop(v, "api.bluez5.address").eq_ignore_ascii_case(addr)
}

pub struct Target {
    pub card: String,
    pub sink: Option<String>,
    profiles: Vec<String>,
}

pub async fn find(addr: &str) -> Option<(Target, Audio)> {
    let card = list("cards").await.into_iter().find(|c| ours(c, addr))?;
    let active = card["active_profile"].as_str().unwrap_or("off").to_string();
    let profiles = card["profiles"]
        .as_object()
        .map(|m| {
            m.iter()
                .filter(|(_, p)| p["available"].as_bool().unwrap_or(true))
                .map(|(k, _)| k.clone())
                .collect()
        })
        .unwrap_or_default();
    let sink = list("sinks").await.into_iter().find(|s| ours(s, addr));
    let default = pactl(&["get-default-sink"]).await.unwrap_or_default();
    let mut a = Audio { profile: kind(&active).into(), ..Default::default() };
    let mut name = None;
    if let Some(s) = &sink {
        let n = s["name"].as_str().unwrap_or("").to_string();
        a.available = true;
        a.is_default = default.trim() == n;
        a.muted = s["mute"].as_bool().unwrap_or(false);
        a.volume = s["volume"]
            .as_object()
            .and_then(|m| m.values().next())
            .and_then(|c| c["value_percent"].as_str())
            .and_then(|p| p.trim_end_matches('%').trim().parse::<u32>().ok())
            .unwrap_or(0)
            .min(150) as u8;
        name = Some(n);
    }
    Some((Target { card: card["name"].as_str().unwrap_or("").into(), sink: name, profiles }, a))
}

fn kind(profile: &str) -> &'static str {
    if profile.starts_with("a2dp") {
        "a2dp"
    } else if profile.starts_with("headset") {
        "hfp"
    } else {
        "off"
    }
}

impl Target {
    pub async fn set_profile(&self, want: &str) -> bool {
        // aynı türden birden çok profil olabilir (aac, msbc); ilki yeter
        let Some(p) = self.profiles.iter().filter(|p| kind(p) == want).max_by_key(|p| p.len()) else { return false };
        pactl(&["set-card-profile", &self.card, p]).await.is_some()
    }

    pub async fn set_volume(&self, v: u8) -> bool {
        let Some(s) = &self.sink else { return false };
        pactl(&["set-sink-volume", s, &format!("{}%", v.min(100))]).await.is_some()
    }

    pub async fn make_default(&self) -> bool {
        let Some(s) = &self.sink else { return false };
        pactl(&["set-default-sink", s]).await.is_some()
    }
}
