use crate::aap::{Mode, Pod, cmd};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::BTreeMap;
use std::path::PathBuf;

#[derive(Debug, Clone, Copy, Default, Serialize)]
pub struct Cell {
    pub level: Option<u8>,
    pub charging: bool,
}

#[derive(Debug, Clone, Default, Serialize)]
pub struct Battery {
    pub left: Cell,
    pub right: Cell,
    #[serde(rename = "case")]
    pub case_: Cell,
}

#[derive(Debug, Clone, Serialize)]
pub struct Ear {
    pub left: Pod,
    pub right: Pod,
}

impl Default for Ear {
    fn default() -> Self {
        Ear { left: Pod::Unknown, right: Pod::Unknown }
    }
}

#[derive(Debug, Clone, Default, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct State {
    pub adapter: bool,
    pub address: Option<String>,
    pub connected: bool,
    /// AAP kanalı açık mı, ayarlar sadece bu durumda değiştirilebilir
    pub ready: bool,
    pub name: String,
    pub model: String,
    pub model_name: String,
    pub model_id: u16,
    pub firmware: String,
    pub serial: String,
    pub serial_left: String,
    pub serial_right: String,
    pub battery: Battery,
    pub ear: Ear,
    pub mode: Option<Mode>,
    pub speaking: bool,
    pub settings: BTreeMap<String, Value>,
    pub prefs: Prefs,
    pub has_keys: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", default)]
pub struct Prefs {
    pub auto_pause: bool,
    pub auto_resume: bool,
    pub duck_on_speech: bool,
    pub duck_level: u8,
    pub low_battery_notify: bool,
    pub popup: bool,
    pub case_scan: bool,
}

impl Default for Prefs {
    fn default() -> Self {
        Prefs {
            auto_pause: true,
            auto_resume: true,
            duck_on_speech: true,
            duck_level: 25,
            low_battery_notify: true,
            popup: true,
            case_scan: true,
        }
    }
}

impl Prefs {
    pub fn set(&mut self, key: &str, v: &str) -> anyhow::Result<()> {
        let b = || parse_bool(v).ok_or_else(|| anyhow::anyhow!("geçersiz değer: {v}"));
        match key {
            "autoPause" => self.auto_pause = b()?,
            "autoResume" => self.auto_resume = b()?,
            "duckOnSpeech" => self.duck_on_speech = b()?,
            "duckLevel" => self.duck_level = v.parse::<u8>()?.min(100),
            "lowBatteryNotify" => self.low_battery_notify = b()?,
            "popup" => self.popup = b()?,
            "caseScan" => self.case_scan = b()?,
            _ => anyhow::bail!("bilinmeyen tercih: {key}"),
        }
        Ok(())
    }
}

pub fn parse_bool(v: &str) -> Option<bool> {
    match v {
        "1" | "true" | "on" | "acik" | "açık" => Some(true),
        "0" | "false" | "off" | "kapali" | "kapalı" => Some(false),
        _ => None,
    }
}

#[derive(Debug, Clone, Copy)]
pub enum Kind {
    /// 1 açık, 2 kapalı
    Toggle,
    /// tek bayt sayı
    Number(u8, u8),
}

/// Arayüzün gördüğü ayar adı ile kontrol komutu arasındaki eşleme.
pub const SETTINGS: &[(&str, u8, Kind)] = &[
    ("conversationAwareness", cmd::CONVERSATION, Kind::Toggle),
    ("adaptiveVolume", cmd::ADAPTIVE_VOLUME, Kind::Toggle),
    ("oneBudAnc", cmd::ONE_BUD_ANC, Kind::Toggle),
    ("volumeSwipe", cmd::VOLUME_SWIPE, Kind::Toggle),
    ("sleepDetection", cmd::SLEEP_DETECTION, Kind::Toggle),
    ("allowOff", cmd::ALLOW_OFF, Kind::Toggle),
    ("hearingAssist", cmd::HEARING_ASSIST, Kind::Toggle),
    ("autoConnect", cmd::AUTO_CONNECT, Kind::Toggle),
    ("volumeSwipeInterval", cmd::VOLUME_SWIPE_INTERVAL, Kind::Number(0, 2)),
    ("pressSpeed", cmd::PRESS_SPEED, Kind::Number(0, 2)),
    ("holdDuration", cmd::HOLD_DURATION, Kind::Number(0, 2)),
    ("chimeVolume", cmd::CHIME_VOLUME, Kind::Number(0, 100)),
    ("adaptiveStrength", cmd::ADAPTIVE_STRENGTH, Kind::Number(0, 100)),
    ("listeningCycle", cmd::LISTENING_CYCLE, Kind::Number(1, 15)),
];

/// Kulaklığın bildirmediği, her bağlantıda bizim yeniden göndermemiz gereken ayarlar.
pub const STICKY: &[&str] = &["listeningCycle", "allowOff", "holdLeft", "holdRight"];

pub fn lookup(key: &str) -> Option<(u8, Kind)> {
    SETTINGS.iter().find(|s| s.0 == key).map(|s| (s.1, s.2))
}

pub fn lookup_id(id: u8) -> Option<(&'static str, Kind)> {
    SETTINGS.iter().find(|s| s.1 == id).map(|s| (s.0, s.2))
}

pub fn decode(kind: Kind, b: u8) -> Option<Value> {
    match kind {
        Kind::Toggle => match b {
            1 => Some(Value::Bool(true)),
            2 => Some(Value::Bool(false)),
            _ => None,
        },
        Kind::Number(..) => Some(Value::from(b)),
    }
}

pub fn encode(kind: Kind, v: &str) -> Option<u8> {
    match kind {
        Kind::Toggle => parse_bool(v).map(|b| if b { 1 } else { 2 }),
        Kind::Number(lo, hi) => v.parse::<u8>().ok().filter(|n| (lo..=hi).contains(n)),
    }
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
#[serde(default)]
pub struct Config {
    pub address: Option<String>,
    pub irk: Option<String>,
    pub enc_key: Option<String>,
    pub prefs: Prefs,
    /// kulaklığa her bağlantıda yeniden yazılan ayarlar
    pub sticky: BTreeMap<String, Value>,
}

fn config_path() -> PathBuf {
    dirs::config_dir().unwrap_or_else(|| PathBuf::from(".")).join("pinna").join("config.json")
}

impl Config {
    pub fn load() -> Config {
        std::fs::read_to_string(config_path())
            .ok()
            .and_then(|s| serde_json::from_str(&s).ok())
            .unwrap_or_default()
    }

    pub fn save(&self) {
        let p = config_path();
        if let Some(d) = p.parent() {
            let _ = std::fs::create_dir_all(d);
        }
        if let Ok(s) = serde_json::to_string_pretty(self) {
            let _ = std::fs::write(p, s);
        }
    }

    pub fn key16(s: &Option<String>) -> Option<[u8; 16]> {
        let s = s.as_ref()?;
        if s.len() != 32 {
            return None;
        }
        let mut k = [0u8; 16];
        for i in 0..16 {
            k[i] = u8::from_str_radix(&s[i * 2..i * 2 + 2], 16).ok()?;
        }
        Some(k)
    }

    pub fn hex(k: &[u8]) -> String {
        k.iter().map(|b| format!("{b:02x}")).collect()
    }
}
