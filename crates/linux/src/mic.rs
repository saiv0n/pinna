// The high quality mic of the buds: decodes the AAC-ELD frames in 0x58 packets
// into a virtual PipeWire source. The buds stay on A2DP meanwhile.

use pinna_core::aap;
use serde_json::Value;
use std::ffi::c_void;
use std::io::Write;
use std::os::unix::fs::OpenOptionsExt;
use std::path::PathBuf;
use tokio::process::Command;

pub const SOURCE: &str = "pinna_mic";
/// +12 dB
const GAIN: f32 = 4.0;

unsafe extern "C" {
    fn eld_new(asc: *const u8, asc_len: i32, rate: i32) -> *mut c_void;
    fn eld_decode(e: *mut c_void, au: *const u8, len: i32, out: *mut f32, max: i32) -> i32;
    fn eld_free(e: *mut c_void);
}

struct Decoder(*mut c_void);

// the decoder is only used under the Mic lock
unsafe impl Send for Decoder {}

impl Decoder {
    fn new() -> Option<Self> {
        let asc = aap::MIC_ASC;
        let p = unsafe { eld_new(asc.as_ptr(), asc.len() as i32, 48_000) };
        (!p.is_null()).then_some(Decoder(p))
    }
}

impl Drop for Decoder {
    fn drop(&mut self) {
        unsafe { eld_free(self.0) }
    }
}

pub struct Mic {
    module: String,
    /// shown name, like "saivon's AirPods Pro (Pinna)"
    pub desc: String,
    dec: Decoder,
    fifo: Option<std::fs::File>,
    path: PathBuf,
    pcm: Vec<f32>,
    bytes: Vec<u8>,
    /// when the last audio packet arrived
    pub last: Option<std::time::Instant>,
}

fn fifo_path() -> PathBuf {
    dirs::runtime_dir().unwrap_or_else(std::env::temp_dir).join("pinna").join("mic")
}

async fn pactl(args: &[&str]) -> Option<String> {
    let out = Command::new("pactl").args(args).output().await.ok()?;
    out.status.success().then(|| String::from_utf8_lossy(&out.stdout).trim().to_string())
}

/// Our virtual sources loaded right now: module id and shown name.
async fn loaded() -> Vec<(String, String)> {
    // the JSON output has no module ids, so the short list is used
    let Some(s) = pactl(&["list", "modules", "short"]).await else { return vec![] };
    let tag = format!("source_name={SOURCE} ");
    s.lines()
        .filter(|l| l.contains("module-pipe-source") && l.contains(&tag))
        .filter_map(|l| {
            let id = l.split_whitespace().next()?.to_string();
            let desc = l.split("device.description=\"").nth(1).and_then(|r| r.split('"').next()).unwrap_or("").to_string();
            Some((id, desc))
        })
        .collect()
}

pub fn description(name: &str) -> String {
    // the pactl argument parser breaks on quotes and apostrophes
    format!("{name} (Pinna)").chars().filter(|c| c.is_alphanumeric() || " ()-.".contains(*c)).collect()
}

/// Removes virtual sources left from a previous run.
pub async fn cleanup() {
    for (id, _) in loaded().await {
        pactl(&["unload-module", &id]).await;
    }
}

/// With no headset to feed it, move the default mic off our silent source.
pub async fn park() {
    if pactl(&["get-default-source"]).await.as_deref() != Some(SOURCE) {
        return;
    }
    let Some(s) = pactl(&["list", "short", "sources"]).await else { return };
    let other = s.lines().filter_map(|l| l.split('\t').nth(1)).find(|n| n.starts_with("alsa_input.") || (n.starts_with("bluez_input.") && *n != SOURCE));
    if let Some(n) = other {
        pactl(&["set-default-source", n]).await;
    }
}

impl Mic {
    /// Opens the virtual source, or adopts the one a previous run left loaded. Apps like Discord
    /// crash when a source they record from disappears, so it is kept for as long as possible.
    pub async fn open(name: &str) -> Option<Mic> {
        let dec = Decoder::new()?;
        let path = fifo_path();
        std::fs::create_dir_all(path.parent()?).ok()?;
        let old = loaded().await;
        if let [(id, desc)] = old.as_slice()
            && path.exists()
        {
            return Some(Mic { module: id.clone(), desc: desc.clone(), dec, fifo: None, path, pcm: vec![0.0; 960], bytes: Vec::new(), last: None });
        }
        cleanup().await;
        let desc = description(name);
        let module = pactl(&[
            "load-module",
            "module-pipe-source",
            &format!("source_name={SOURCE}"),
            &format!("file={}", path.display()),
            "format=float32le",
            &format!("rate={}", aap::MIC_RATE),
            "channels=1",
            &format!("source_properties='device.description=\"{desc}\" device.icon_name=audio-headset-bluetooth'"),
        ])
        .await?;
        Some(Mic { module, desc, dec, fifo: None, path, pcm: vec![0.0; 960], bytes: Vec::new(), last: None })
    }

    pub async fn close(self) {
        pactl(&["unload-module", &self.module]).await;
    }

    /// Decodes a 0x58 packet into the virtual source. If the reader lags, audio is dropped; the session never waits.
    pub fn feed(&mut self, sdu: &[u8]) {
        self.last = Some(std::time::Instant::now());
        for au in aap::mic_frames(sdu) {
            let max = self.pcm.len() as i32;
            let n = unsafe { eld_decode(self.dec.0, au.as_ptr(), au.len() as i32, self.pcm.as_mut_ptr(), max) };
            if n <= 0 {
                log::debug!("could not decode mic frame ({} bytes)", au.len());
                continue;
            }
            self.bytes.clear();
            for s in &self.pcm[..n as usize] {
                // the buds send very quiet audio, apps could not hear speech
                let v = (s * GAIN).tanh();
                self.bytes.extend_from_slice(&v.to_le_bytes());
            }
            self.write();
        }
    }

    // 480 samples are 1920 bytes, under PIPE_BUF, so a write is all or nothing
    fn write(&mut self) {
        if self.fifo.is_none() {
            // O_NONBLOCK: a write must not hang if PipeWire stops reading
            self.fifo = std::fs::OpenOptions::new()
                .write(true)
                .custom_flags(0o4000)
                .open(&self.path)
                .inspect_err(|e| log::debug!("mikrofon fifo: {e}"))
                .ok();
        }
        if let Some(f) = &mut self.fifo
            && let Err(e) = f.write(&self.bytes)
            && e.kind() != std::io::ErrorKind::WouldBlock
        {
            self.fifo = None;
        }
    }
}

/// Whether some app is recording from the virtual source
pub async fn in_use() -> bool {
    let (Some(src), Some(out)) = (pactl(&["-f", "json", "list", "sources"]).await, pactl(&["-f", "json", "list", "source-outputs"]).await) else {
        return false;
    };
    let parse = |s: &str| serde_json::from_str::<Value>(s).ok().and_then(|v| v.as_array().cloned()).unwrap_or_default();
    recording(&parse(&src), &parse(&out))
}

/// A real recorder on our source. Level meters (pavucontrol, the Plasma volume applet) open
/// 25 Hz peak streams that would otherwise wake the headset mic (LibrePods #888).
fn recording(sources: &[Value], outputs: &[Value]) -> bool {
    let Some(idx) = sources.iter().find(|x| x["name"] == SOURCE).and_then(|x| x["index"].as_u64()) else { return false };
    outputs.iter().any(|o| {
        let p = &o["properties"];
        let peaks = p["resample.peaks"] == "true" || p["media.name"].as_str().is_some_and(|n| n.contains("Peak detect"));
        o["source"].as_u64() == Some(idx) && !peaks && o["corked"] != true
    })
}


pub async fn make_default() {
    pactl(&["set-default-source", SOURCE]).await;
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn level_meters_are_not_recorders() {
        let sources = [json!({ "index": 7, "name": SOURCE }), json!({ "index": 3, "name": "alsa_input.pci" })];
        let meter = json!({ "source": 7, "corked": false, "properties": { "media.name": "Peak detect", "resample.peaks": "true" } });
        let discord = json!({ "source": 7, "corked": false, "properties": { "application.name": "WEBRTC VoiceEngine" } });
        let other = json!({ "source": 3, "corked": false, "properties": {} });
        assert!(!recording(&sources, &[meter.clone(), other.clone()]));
        assert!(recording(&sources, &[meter, discord.clone()]));
        let paused = json!({ "source": 7, "corked": true, "properties": {} });
        assert!(!recording(&sources, &[paused]));
        assert!(!recording(&sources[1..], &[discord]));
    }
}
