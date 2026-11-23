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
    addr: String,
    pub sink: Option<String>,
    profiles: Vec<(String, u64)>,
}

pub async fn find(addr: &str) -> Option<(Target, Audio)> {
    let card = list("cards").await.into_iter().find(|c| ours(c, addr))?;
    let active = card["active_profile"].as_str().unwrap_or("off").to_string();
    let profiles = card["profiles"]
        .as_object()
        .map(|m| {
            m.iter()
                .filter(|(_, p)| p["available"].as_bool().unwrap_or(true))
                .map(|(k, p)| (k.clone(), p["priority"].as_u64().unwrap_or(0)))
                .collect()
        })
        .unwrap_or_default();
    let sink = list("sinks").await.into_iter().find(|s| ours(s, addr));
    let default = pactl(&["get-default-sink"]).await.unwrap_or_default();
    let desc = card["profiles"][&active]["description"].as_str().unwrap_or("");
    let codec = desc.split("codec ").nth(1).map(|c| c.trim_end_matches(')').to_string()).unwrap_or_default();
    let mut a = Audio { profile: kind(&active).into(), codec, ..Default::default() };
    let mut name = None;
    if let Some(s) = &sink {
        let n = s["name"].as_str().unwrap_or("").to_string();
        a.available = true;
        a.is_default = default.trim() == n || default.trim() == crate::spatial::NODE;
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
    let card = card["name"].as_str().unwrap_or("").into();
    Some((Target { card, addr: addr.into(), sink: name, profiles }, a))
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
        // aynı türden birden çok kodek var; PipeWire'ın en yüksek önceliği verdiği en iyisi (AAC, LC3)
        let Some((p, _)) = self.profiles.iter().filter(|(p, _)| kind(p) == want).max_by_key(|(_, prio)| *prio) else {
            return false;
        };
        if pactl(&["set-card-profile", &self.card, p]).await.is_none() {
            return false;
        }
        // mikrofonu seçince uygulamalar da onu kullansın, bırakınca dahili mikrofona dön
        let src = pactl(&["get-default-source"]).await.unwrap_or_default();
        if want == "hfp" {
            tokio::time::sleep(std::time::Duration::from_millis(500)).await;
            if let Some(s) = list("sources").await.into_iter().find(|s| s["name"].as_str().is_some_and(|n| n.starts_with("bluez_input.")) && ours(s, &self.addr)) {
                pactl(&["set-default-source", s["name"].as_str().unwrap_or("")]).await;
            }
        } else if src.starts_with("bluez_input.")
            && let Some(s) = list("sources").await.into_iter().find(|s| s["name"].as_str().is_some_and(|n| n.starts_with("alsa_input.")))
        {
            pactl(&["set-default-source", s["name"].as_str().unwrap_or("")]).await;
        }
        true
    }

    /// WirePlumber yeniden başlayınca kulaklık bazen yalnız HFP ile bağlanıyor.
    pub fn lost_a2dp(&self) -> bool {
        !self.profiles.iter().any(|(p, _)| kind(p) == "a2dp")
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

const AUTOSWITCH: &str = "bluetooth.autoswitch-to-headset-profile";

/// Açıkken kayıt başlayınca WirePlumber kulaklığı HFP'ye geçirmez.
/// Ayar hem WirePlumber'ın kendi kaydına hem de yapılandırma dosyasına yazılır.
pub async fn call_quality(on: bool) {
    let want = (!on).to_string();
    let now = Command::new("wpctl").args(["settings", AUTOSWITCH]).output().await.ok();
    let same = now.is_some_and(|o| String::from_utf8_lossy(&o.stdout).contains(&format!("Value: {want} (Saved: {want})")));
    if !same {
        let _ = Command::new("wpctl").args(["settings", "--save", AUTOSWITCH, &want]).output().await;
    }
    let Some(dir) = dirs::config_dir().map(|d| d.join("wireplumber/wireplumber.conf.d")) else { return };
    let file = dir.join("51-pinna.conf");
    let body = format!("# pinna yazdı, uygulamadaki görüşme ayarıyla değişir\nwireplumber.settings = {{\n  {AUTOSWITCH} = {want}\n}}\n");
    if std::fs::read_to_string(&file).ok().as_deref() != Some(body.as_str())
        && let Err(e) = std::fs::create_dir_all(&dir).and_then(|_| std::fs::write(&file, body))
    {
        log::warn!("wireplumber ayarı yazılamadı: {e}");
    }
}
