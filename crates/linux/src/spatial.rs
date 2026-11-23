// Uzamsal ses: PipeWire filter-chain içinde iki sanal hoparlör (HRTF), baş dönünce ters yöne çevrilir
// ki ses odada sabit kalsın.

use std::path::Path;
use std::process::Stdio;
use std::time::{Duration, Instant};
use tokio::process::{Child, Command};

pub const NODE: &str = "pinna_spatial";
const SOFA: &str = "/usr/share/libmysofa/default.sofa";
/// hoparlörlerin önden açısı, stüdyo monitörü gibi
const SPREAD: f32 = 30.0;

pub fn available() -> bool {
    Path::new(SOFA).exists()
}

pub struct Spatial {
    child: Child,
    sink: String,
    base: Option<f32>,
    last_t: Instant,
    sent: f32,
    sent_at: Instant,
}

async fn pactl(args: &[&str]) -> Option<String> {
    let out = Command::new("pactl").args(args).output().await.ok()?;
    out.status.success().then(|| String::from_utf8_lossy(&out.stdout).trim().to_string())
}

fn conf(sink: &str, desc: &str) -> String {
    let sp = |n: &str, az: f32| {
        format!(
            "{{ type = sofa label = spatializer name = {n} config = {{ filename = \"{SOFA}\" }} \
             control = {{ \"Azimuth\" = {az:.1} \"Elevation\" = 0.0 \"Radius\" = 1.0 }} }}"
        )
    };
    format!(
        "{{ node.description = \"{desc}\" media.name = \"{desc}\" filter.graph = {{ nodes = [ {} {} \
         {{ type = builtin label = mixer name = mixL }} {{ type = builtin label = mixer name = mixR }} ] \
         links = [ {{ output = \"spL:Out L\" input = \"mixL:In 1\" }} {{ output = \"spR:Out L\" input = \"mixL:In 2\" }} \
         {{ output = \"spL:Out R\" input = \"mixR:In 1\" }} {{ output = \"spR:Out R\" input = \"mixR:In 2\" }} ] \
         inputs = [ \"spL:In\" \"spR:In\" ] outputs = [ \"mixL:Out\" \"mixR:Out\" ] }} \
         capture.props = {{ node.name = {NODE} media.class = Audio/Sink audio.channels = 2 audio.position = [ FL FR ] \
         device.icon_name = audio-headphones-bluetooth }} \
         playback.props = {{ node.name = {NODE}.out node.passive = true audio.channels = 2 audio.position = [ FL FR ] \
         target.object = \"{sink}\" node.dont-reconnect = true }} }}",
        sp("spL", SPREAD),
        sp("spR", 360.0 - SPREAD)
    )
}

impl Spatial {
    /// Sanal çıkışı açar ve varsayılan yapar. Kulaklık varsayılan değilse dokunmaz.
    pub async fn start(sink: &str, name: &str) -> Option<Spatial> {
        let desc: String = format!("{name} (Uzamsal)").chars().filter(|c| c.is_alphanumeric() || " ()-.".contains(*c)).collect();
        let child = Command::new("pw-cli")
            .args(["-m", "load-module", "libpipewire-module-filter-chain", &conf(sink, &desc)])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .kill_on_drop(true)
            .spawn()
            .ok()?;
        let mut up = false;
        for _ in 0..30 {
            tokio::time::sleep(Duration::from_millis(100)).await;
            if pactl(&["list", "short", "sinks"]).await.is_some_and(|s| s.lines().any(|l| l.split('\t').nth(1) == Some(NODE))) {
                up = true;
                break;
            }
        }
        if !up {
            return None;
        }
        if pactl(&["get-default-sink"]).await.as_deref() == Some(sink) {
            pactl(&["set-default-sink", NODE]).await;
        }
        // kulaklığa doğrudan giden akışlar da sanal çıkışa taşınsın
        if let Some(list) = pactl(&["list", "short", "sink-inputs"]).await {
            let sinks = pactl(&["list", "short", "sinks"]).await.unwrap_or_default();
            let id = sinks.lines().find(|l| l.split('\t').nth(1) == Some(sink)).and_then(|l| l.split('\t').next()).unwrap_or("");
            for l in list.lines() {
                let f: Vec<&str> = l.split('\t').collect();
                if f.get(1) == Some(&id) && !id.is_empty() {
                    pactl(&["move-sink-input", f[0], NODE]).await;
                }
            }
        }
        let now = Instant::now();
        Some(Spatial { child, sink: sink.into(), base: None, last_t: now, sent: 0.0, sent_at: now })
    }

    pub fn sink(&self) -> &str {
        &self.sink
    }

    pub async fn stop(mut self) {
        if pactl(&["get-default-sink"]).await.as_deref() == Some(NODE) {
            pactl(&["set-default-sink", &self.sink]).await;
        }
        // modül kapanınca akışlar varsayılana döner
        let _ = self.child.kill().await;
    }

    async fn turn(&mut self, rel: f32) {
        let az = |a: f32| (a - rel).rem_euclid(360.0);
        let p = format!("{{ params = [ \"spL:Azimuth\" {:.1} \"spR:Azimuth\" {:.1} ] }}", az(SPREAD), az(360.0 - SPREAD));
        let _ = Command::new("pw-cli").args(["set-param", NODE, "Props", &p]).output().await;
        self.sent = rel;
        self.sent_at = Instant::now();
    }

    /// Baş takibi örneği. Başlangıç yönü yavaşça başın ortalamasına kayar; uzun süre yana bakınca
    /// ses de oraya yerleşir, sensör kayması birikmez.
    pub async fn head(&mut self, v: [i16; 5]) {
        let yaw = (v[1] as f32 - v[2] as f32) / 2.0 / 32000.0 * 180.0;
        let now = Instant::now();
        let dt = now.duration_since(self.last_t).as_secs_f32().min(1.0);
        self.last_t = now;
        let base = self.base.get_or_insert(yaw);
        *base += (yaw - *base) * (dt / 20.0);
        let rel = (yaw - *base).clamp(-120.0, 120.0);
        if (rel - self.sent).abs() >= 2.0 && self.sent_at.elapsed() >= Duration::from_millis(30) {
            self.turn(rel).await;
        }
    }

    /// Takip kapanınca ses öne döner.
    pub async fn center(&mut self) {
        self.base = None;
        if self.sent != 0.0 {
            self.turn(0.0).await;
        }
    }
}
