// PipeWire side: finds the card and output of the buds from pactl JSON output.

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
    active: String,
    /// name, priority and codec of each available profile
    profiles: Vec<(String, u64, String)>,
}

/// "High Fidelity Playback (A2DP Sink, codec AAC)" -> "AAC"
fn codec_of(desc: &str) -> String {
    desc.split("codec ").nth(1).map(|c| c.trim_end_matches(')').trim().to_string()).unwrap_or_default()
}

/// A2DP codecs, best first, each once; older PipeWire spells the profiles with underscores
fn codecs(profiles: &[(String, u64, String)]) -> Vec<String> {
    let mut v: Vec<&(String, u64, String)> = profiles.iter().filter(|p| kind(&p.0) == "a2dp" && !p.2.is_empty()).collect();
    v.sort_by_key(|a| std::cmp::Reverse(a.1));
    let mut out: Vec<String> = Vec::new();
    for p in v {
        if !out.contains(&p.2) {
            out.push(p.2.clone());
        }
    }
    out
}

pub async fn find(addr: &str) -> Option<(Target, Audio)> {
    let card = list("cards").await.into_iter().find(|c| ours(c, addr))?;
    let active = card["active_profile"].as_str().unwrap_or("off").to_string();
    let profiles: Vec<(String, u64, String)> = card["profiles"]
        .as_object()
        .map(|m| {
            m.iter()
                .filter(|(_, p)| p["available"].as_bool().unwrap_or(true))
                .map(|(k, p)| (k.clone(), p["priority"].as_u64().unwrap_or(0), codec_of(p["description"].as_str().unwrap_or(""))))
                .collect()
        })
        .unwrap_or_default();
    let sink = list("sinks").await.into_iter().find(|s| ours(s, addr));
    let default = pactl(&["get-default-sink"]).await.unwrap_or_default();
    let codec = codec_of(card["profiles"][&active]["description"].as_str().unwrap_or(""));
    let mut a = Audio { profile: kind(&active).into(), codec, codecs: codecs(&profiles), ..Default::default() };
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
    Some((Target { card, addr: addr.into(), sink: name, active, profiles }, a))
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
        // several codecs per kind; the one PipeWire ranks highest is best (AAC, LC3)
        let Some((p, _, _)) = self.profiles.iter().filter(|(p, _, _)| kind(p) == want).max_by_key(|(_, prio, _)| *prio) else {
            return false;
        };
        if pactl(&["set-card-profile", &self.card, p]).await.is_none() {
            return false;
        }
        // apps should use the headset mic when picked, and the internal one after
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

    /// After a WirePlumber restart the buds sometimes come back with HFP only.
    pub fn lost_a2dp(&self) -> bool {
        !self.profiles.iter().any(|(p, _, _)| kind(p) == "a2dp")
    }

    /// Switches music to this codec, only while on A2DP so calls are left alone.
    /// Returns false when nothing changed.
    pub async fn set_codec(&self, codec: &str) -> bool {
        if kind(&self.active) != "a2dp" {
            return false;
        }
        let best = self.profiles.iter().filter(|p| kind(&p.0) == "a2dp" && (codec.is_empty() || p.2 == codec)).max_by_key(|p| p.1);
        match best {
            Some(p) if p.0 != self.active => pactl(&["set-card-profile", &self.card, &p.0]).await.is_some(),
            _ => false,
        }
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

pub async fn default_sink() -> Option<String> {
    pactl(&["get-default-sink"]).await.map(|s| s.trim().to_string()).filter(|s| !s.is_empty())
}

pub async fn set_default_sink(name: &str) -> bool {
    pactl(&["set-default-sink", name]).await.is_some()
}

const AUTOSWITCH: &str = "bluetooth.autoswitch-to-headset-profile";

/// While on, WirePlumber does not switch the buds to HFP when recording starts.
/// Written both to WirePlumber state and to a config file.
pub async fn call_quality(on: bool) {
    let want = (!on).to_string();
    let now = Command::new("wpctl").args(["settings", AUTOSWITCH]).output().await.ok();
    let same = now.is_some_and(|o| String::from_utf8_lossy(&o.stdout).contains(&format!("Value: {want} (Saved: {want})")));
    if !same {
        let _ = Command::new("wpctl").args(["settings", "--save", AUTOSWITCH, &want]).output().await;
    }
    let Some(dir) = dirs::config_dir().map(|d| d.join("wireplumber/wireplumber.conf.d")) else { return };
    let file = dir.join("51-pinna.conf");
    let body = format!("# written by pinna, follows the call setting in the app\nwireplumber.settings = {{\n  {AUTOSWITCH} = {want}\n}}\n");
    if std::fs::read_to_string(&file).ok().as_deref() != Some(body.as_str())
        && let Err(e) = std::fs::create_dir_all(&dir).and_then(|_| std::fs::write(&file, body))
    {
        log::warn!("could not write the wireplumber setting: {e}");
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn p(n: &str, prio: u64, desc: &str) -> (String, u64, String) {
        (n.into(), prio, codec_of(desc))
    }

    #[test]
    fn profile_names_old_and_new() {
        assert_eq!(kind("a2dp-sink"), "a2dp");
        assert_eq!(kind("a2dp_sink"), "a2dp");
        assert_eq!(kind("a2dp-sink-sbc_xq"), "a2dp");
        assert_eq!(kind("headset-head-unit"), "hfp");
        assert_eq!(kind("headset_head_unit"), "hfp");
        assert_eq!(kind("off"), "off");
    }

    #[test]
    fn codec_list() {
        let list = vec![
            p("a2dp-sink", 18, "High Fidelity Playback (A2DP Sink, codec AAC)"),
            p("a2dp-sink-sbc", 16, "High Fidelity Playback (A2DP Sink, codec SBC)"),
            p("a2dp-sink-sbc_xq", 17, "High Fidelity Playback (A2DP Sink, codec SBC-XQ)"),
            p("headset-head-unit", 1, "Headset Head Unit (HSP/HFP, codec LC3-24kHz)"),
            p("off", 0, "Off"),
        ];
        assert_eq!(codecs(&list), vec!["AAC", "SBC-XQ", "SBC"]);
        assert_eq!(codec_of("Off"), "");
    }
}
