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

/// Removes virtual sources left from a previous run.
pub async fn cleanup() {
    // the JSON output has no module ids, so the short list is used
    let Some(s) = pactl(&["list", "modules", "short"]).await else { return };
    let tag = format!("source_name={SOURCE} ");
    for l in s.lines().filter(|l| l.contains("module-pipe-source") && l.contains(&tag)) {
        if let Some(id) = l.split_whitespace().next() {
            pactl(&["unload-module", id]).await;
        }
    }
}

impl Mic {
    pub async fn open(name: &str) -> Option<Mic> {
        cleanup().await;
        let dec = Decoder::new()?;
        let path = fifo_path();
        std::fs::create_dir_all(path.parent()?).ok()?;
        // the pactl argument parser breaks on quotes and apostrophes
        let desc: String = format!("{name} (Pinna)").chars().filter(|c| c.is_alphanumeric() || " ()-.".contains(*c)).collect();
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
        Some(Mic { module, dec, fifo: None, path, pcm: vec![0.0; 960], bytes: Vec::new(), last: None })
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
    let Some(s) = pactl(&["-f", "json", "list", "sources"]).await else { return false };
    let Ok(Value::Array(list)) = serde_json::from_str::<Value>(&s) else { return false };
    list.iter().any(|x| x["name"] == SOURCE && x["state"] == "RUNNING")
}

pub async fn make_default() {
    pactl(&["set-default-source", SOURCE]).await;
}
