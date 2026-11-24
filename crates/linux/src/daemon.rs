use pinna_core::aap::{self, Component, Mode, Packet, Pod};
use crate::audio;
use crate::mic;
use crate::spatial::{self, Spatial};
use crate::history::History;
use crate::media::{Media, t};
use pinna_core::proximity::{self, Advert};
use pinna_core::state::{self, Cell, Config, Device, State};
use anyhow::{Context, Result, anyhow, bail};
use bluer::{Adapter, Address, AdapterEvent, DiscoveryFilter, DiscoveryTransport};
use futures::StreamExt;
use log::{debug, info, warn};
use serde_json::Value;
use std::sync::Arc;
use std::collections::HashMap;
use std::time::{Duration, Instant};
use tokio::sync::{Mutex, Notify, broadcast, mpsc, watch};

const APPLE: u32 = 0x004C;
const A2DP_SINK: bluer::Uuid = bluer::Uuid::from_u128(0x0000110b_0000_1000_8000_00805f9b34fb);

#[derive(Debug, Clone)]
pub enum Event {
    State,
    CaseOpened(Advert),
    Head([i16; 5]),
}

struct Inner {
    state: State,
    config: Config,
    tx: Option<mpsc::UnboundedSender<Vec<u8>>>,
    primary_left: bool,
    warned: [u8; 2],
    last_popup: Option<Instant>,
    history: History,
    /// whether the charged notification went out: left, right, case
    full: [bool; 3],
    audio_set: bool,
    a2dp_fixed: bool,
    /// was connected when Bluetooth went off, reconnect when it is back
    reconnect: bool,
    dropped: Option<Instant>,
    /// the buds were told to open the mic
    mic_on: bool,
    /// conversation awareness was paused for the mic, restore it afterwards
    ca_paused: bool,
    /// head tracking stream is on for spatial audio
    spatial_head: bool,
    /// we turned conversation awareness off because only one bud is in
    ca_held: bool,
    /// bumped on every ear packet so a pending pause can tell it is stale
    ear_gen: u64,
    /// last advert battery of paired headphones other than the selected one
    others: HashMap<String, state::Last>,
    /// whether we asked the buds for the head tracking stream
    head_on: bool,
    gestures: pinna_core::gesture::Detector,
    epoch: Instant,
}

/// What a session needs from its channel: whole packets in, whole packets out.
pub trait Link {
    fn send(&self, b: &[u8]) -> impl std::future::Future<Output = std::io::Result<usize>>;
    fn recv(&self, b: &mut [u8]) -> impl std::future::Future<Output = std::io::Result<usize>>;
}

impl Link for bluer::l2cap::SeqPacket {
    async fn send(&self, b: &[u8]) -> std::io::Result<usize> {
        bluer::l2cap::SeqPacket::send(self, b).await
    }
    async fn recv(&self, b: &mut [u8]) -> std::io::Result<usize> {
        bluer::l2cap::SeqPacket::recv(self, b).await
    }
}

impl Link for tokio::net::UnixDatagram {
    async fn send(&self, b: &[u8]) -> std::io::Result<usize> {
        tokio::net::UnixDatagram::send(self, b).await
    }
    async fn recv(&self, b: &mut [u8]) -> std::io::Result<usize> {
        tokio::net::UnixDatagram::recv(self, b).await
    }
}

/// After this long without an advert from our buds the case scan goes part time,
/// on for SCAN_ON and off for SCAN_REST, so the radio and bluetoothd can idle.
const SCAN_IDLE: Duration = Duration::from_secs(10 * 60);
const SCAN_ON: Duration = Duration::from_secs(10);
const SCAN_REST: Duration = Duration::from_secs(20);
/// How long a bud must stay out before playback pauses.
const EAR_SETTLE: Duration = Duration::from_millis(500);

#[derive(Clone)]
pub struct Daemon {
    inner: Arc<Mutex<Inner>>,
    pub events: broadcast::Sender<Event>,
    media: Arc<Mutex<Media>>,
    adapter: Adapter,
    scan: watch::Sender<bool>,
    pairing: watch::Sender<bool>,
    /// wakes the main loop when BlueZ reports a change
    wake: Arc<Notify>,
    /// the session loop writes here on every audio packet, so no async lock
    mic: Arc<std::sync::Mutex<Option<mic::Mic>>>,
    spatial: Arc<Mutex<Option<Spatial>>>,
    /// devices with a property watcher, so one never gets two and strangers get none
    watched: Arc<std::sync::Mutex<std::collections::HashSet<Address>>>,
}

impl Daemon {
    pub async fn new(bus: zbus::Connection) -> Result<Daemon> {
        let session = bluer::Session::new().await?;
        let adapter = session.default_adapter().await?;
        let mut config = Config::load();
        // do not try to write settings from old versions that no longer exist
        config.sticky.retain(|k, _| state::STICKY.contains(&k.as_str()));
        let mut st = State { prefs: config.prefs.clone(), ..Default::default() };
        st.has_keys = config.address.as_deref().is_some_and(|a| config.keys_for(a).is_some());
        st.address = config.address.clone();
        let (events, _) = broadcast::channel(64);
        let (scan, _) = watch::channel(false);
        let (pairing, _) = watch::channel(false);
        Ok(Daemon {
            inner: Arc::new(Mutex::new(Inner {
                state: st,
                config,
                tx: None,
                primary_left: true,
                warned: [100, 100],
                last_popup: None,
                history: History::default(),
                full: [true; 3],
                audio_set: false,
                a2dp_fixed: false,
                reconnect: false,
                dropped: None,
                mic_on: false,
                ca_paused: false,
                others: HashMap::new(),
                head_on: false,
                gestures: Default::default(),
                epoch: Instant::now(),
                spatial_head: false,
                ca_held: false,
                ear_gen: 0,
            })),
            events,
            media: Arc::new(Mutex::new(Media::new(bus))),
            adapter,
            scan,
            pairing,
            wake: Arc::new(Notify::new()),
            mic: Default::default(),
            spatial: Default::default(),
            watched: Default::default(),
        })
    }

    pub fn adapter_name(&self) -> String {
        self.adapter.name().to_string()
    }

    fn changed(&self) {
        let _ = self.events.send(Event::State);
    }

    pub async fn json(&self) -> String {
        serde_json::to_string(&self.inner.lock().await.state).unwrap_or_default()
    }

    pub async fn value(&self) -> Value {
        serde_json::to_value(&self.inner.lock().await.state).unwrap_or_default()
    }

    async fn send(&self, p: Vec<u8>) -> Result<()> {
        let g = self.inner.lock().await;
        let tx = g.tx.as_ref().ok_or_else(|| anyhow!("not-connected: The headphones are not connected."))?;
        tx.send(p).map_err(|_| anyhow!("not-connected: The connection to the headphones just dropped."))
    }

    pub async fn set_mode(&self, m: &str) -> Result<()> {
        let mode = Mode::parse(m).ok_or_else(|| anyhow!("invalid: Unknown mode."))?;
        self.send(aap::control(aap::cmd::LISTENING_MODE, [mode.byte(), 0, 0, 0])).await?;
        // the ack from the buds updates it anyway, the UI should not wait
        self.inner.lock().await.state.mode = Some(mode);
        self.changed();
        Ok(())
    }

    /// Next mode in the same order and selection as press and hold on the stem.
    pub async fn cycle_mode(&self) -> Result<Mode> {
        let (cycle, mode, allow_off) = {
            let g = self.inner.lock().await;
            let cycle = g.state.settings.get("listeningCycle").and_then(|v| v.as_u64()).unwrap_or(0x0E) as u8;
            let allow_off = g.state.settings.get("allowOff").and_then(|v| v.as_bool()).unwrap_or(false);
            (cycle, g.state.mode, allow_off)
        };
        let next = next_mode(cycle, mode, allow_off).ok_or_else(|| anyhow!("invalid: No mode to switch to."))?;
        self.set_mode(next.name()).await?;
        Ok(next)
    }

    pub async fn set_setting(&self, key: &str, v: &str) -> Result<()> {
        let packet;
        let value: Value;
        {
            let g = self.inner.lock().await;
            if key == "eq" {
                // "on,50,50,50": enabled, low, mid, high
                let f: Vec<&str> = v.split(',').collect();
                let n = |i: usize| f.get(i).and_then(|x| x.trim().parse::<u8>().ok()).filter(|n| *n <= 100);
                let (Some(on), Some(low), Some(mid), Some(high)) = (f.first().and_then(|x| state::parse_bool(x.trim())), n(1), n(2), n(3)) else {
                    bail!("invalid: Invalid value for this setting.");
                };
                let e = aap::Eq { enabled: on, low, mid, high };
                drop(g);
                self.send(aap::eq(e)).await?;
                self.inner.lock().await.state.eq = Some(e);
                self.changed();
                return Ok(());
            } else if key == "holdLeft" || key == "holdRight" {
                let n: u8 = v.parse().ok().filter(|n| *n == 1 || *n == 5).context("invalid: The value must be 1 or 5.")?;
                let cur = |k: &str| g.state.settings.get(k).and_then(|x| x.as_u64()).unwrap_or(1) as u8;
                let (l, r) = if key == "holdLeft" { (n, cur("holdRight")) } else { (cur("holdLeft"), n) };
                packet = aap::control(aap::cmd::HOLD_MODE, [r, l, 0, 0]);
                value = Value::from(n);
            } else {
                let (id, kind) = state::lookup(key).ok_or_else(|| anyhow!("invalid: Unknown setting."))?;
                let b = state::encode(kind, v).ok_or_else(|| anyhow!("invalid: Invalid value for this setting."))?;
                let d2 = if id == aap::cmd::CHIME_VOLUME { b } else { 0 };
                packet = aap::control(id, [b, d2, 0, 0]);
                value = state::decode(kind, b).unwrap_or(Value::Null);
            }
        }
        self.send(packet).await?;
        let mut g = self.inner.lock().await;
        g.state.settings.insert(key.to_string(), value.clone());
        if state::STICKY.contains(&key) {
            g.config.sticky.insert(key.to_string(), value);
            g.config.save();
        }
        drop(g);
        self.changed();
        Ok(())
    }

    pub async fn set_pref(&self, key: &str, v: &str) -> Result<()> {
        let mut g = self.inner.lock().await;
        g.config.prefs.set(key, v).map_err(|e| anyhow!("invalid: {e}"))?;
        g.state.prefs = g.config.prefs.clone();
        let scan = g.config.prefs.case_scan && !g.state.connected;
        g.config.save();
        drop(g);
        if key == "callMic" {
            self.apply_call().await;
        }
        if key == "codec" {
            self.apply_codec(v).await;
        }
        if key == "headGestures" {
            let _ = self.sync_head().await;
        }
        if key == "spatial" || key == "codec" {
            self.refresh_audio().await;
        }
        if key.starts_with("stem.") && self.inner.lock().await.state.ready {
            self.send_stem_mask().await;
        }
        let _ = self.scan.send(scan);
        self.changed();
        Ok(())
    }

    pub async fn rename(&self, name: &str) -> Result<()> {
        let name = name.trim();
        if !aap::valid_name(name) {
            bail!("invalid: The name must be 1 to 32 bytes with no control characters.");
        }
        self.send(aap::rename(name)).await?;
        let addr = {
            let mut g = self.inner.lock().await;
            g.state.name = name.to_string();
            g.state.address.clone()
        };
        // change the BlueZ alias too so the audio output shows the new name
        if let Some(a) = addr.and_then(|a| a.parse::<Address>().ok())
            && let Ok(d) = self.adapter.device(a)
        {
            let _ = d.set_alias(name.to_string()).await;
        }
        self.changed();
        Ok(())
    }

    async fn target(&self) -> Result<Address> {
        let g = self.inner.lock().await;
        let a = g.state.address.clone().or(g.config.address.clone()).ok_or_else(|| anyhow!("no-device: No AirPods are paired with this computer."))?;
        Ok(a.parse()?)
    }

    async fn powered(&self) -> Result<()> {
        if !self.adapter.is_powered().await.unwrap_or(false) {
            bail!("bluetooth-off: Bluetooth is off.");
        }
        Ok(())
    }

    fn reason(e: bluer::Error) -> anyhow::Error {
        // turn the technical BlueZ error into a reason people understand
        let m = e.message.to_lowercase();
        if m.contains("page timeout") || m.contains("host is down") || m.contains("timeout") {
            anyhow!("unreachable: The headphones did not answer. Take them out of the case or open the lid and keep them close.")
        } else if m.contains("in progress") || m.contains("busy") {
            anyhow!("busy: Bluetooth is busy with something else, try again in a few seconds.")
        } else {
            anyhow!("bluetooth: {}", e.message)
        }
    }

    pub async fn power_on(&self) -> Result<()> {
        self.adapter.set_powered(true).await.map_err(Self::reason)?;
        self.wake.notify_one();
        Ok(())
    }

    pub async fn connect(&self) -> Result<()> {
        let a = self.target().await?;
        self.powered().await?;
        let d = self.adapter.device(a)?;
        // with the case scan running BlueZ tries LE and fails; retry with the classic audio profile
        if let Err(e) = d.connect().await {
            debug!("connect failed ({e}), trying A2DP");
            d.connect_profile(&A2DP_SINK).await.map_err(Self::reason)?;
        }
        // a profile connect sometimes sends no Connected event, so wake the main loop ourselves
        self.wake.notify_one();
        Ok(())
    }

    pub async fn disconnect(&self) -> Result<()> {
        let a = self.target().await?;
        self.adapter.device(a)?.disconnect().await.map_err(Self::reason)?;
        Ok(())
    }

    async fn known(&self, addr: &str, nearby: bool) -> Result<Address> {
        let g = self.inner.lock().await;
        let list = if nearby { &g.state.nearby } else { &g.state.devices };
        if !list.iter().any(|d| d.address == addr) {
            bail!("invalid: There are no headphones at this address.");
        }
        Ok(addr.parse()?)
    }

    /// Switches to another paired headphone: updates the preference, closes the session and connects the new one.
    pub async fn select(&self, addr: &str) -> Result<()> {
        let a = self.known(addr, false).await?;
        self.powered().await?;
        let old = {
            let mut g = self.inner.lock().await;
            let old = g.state.address.clone().filter(|o| o != addr && g.state.connected);
            g.config.address = Some(addr.to_string());
            g.config.save();
            if old.is_some() || !g.state.connected {
                // do not show the old device until the new one reports
                g.state.address = Some(addr.to_string());
                g.state.has_keys = g.config.keys_for(addr).is_some();
                g.state.model_id = 0;
                g.state.name.clear();
            }
            old
        };
        if let Some(o) = old.and_then(|o| o.parse::<Address>().ok()) {
            let _ = self.adapter.device(o)?.disconnect().await;
        }
        self.refresh_devices().await;
        self.changed();
        self.adapter.device(a)?.connect().await.map_err(Self::reason)?;
        Ok(())
    }

    pub async fn forget(&self, addr: &str) -> Result<()> {
        let a = self.known(addr, false).await?;
        self.adapter.remove_device(a).await.map_err(Self::reason)?;
        {
            let mut g = self.inner.lock().await;
            if g.config.address.as_deref() == Some(addr) {
                g.config.address = None;
                g.config.save();
            }
            if g.state.address.as_deref() == Some(addr) {
                g.state.address = None;
                g.state.model_id = 0;
                g.state.name.clear();
            }
        }
        self.refresh_devices().await;
        self.changed();
        Ok(())
    }

    /// Looks for headphones in pairing mode for 30 seconds.
    pub async fn discover(&self, on: bool) -> Result<()> {
        if on {
            self.powered().await?;
        }
        let _ = self.pairing.send(on);
        Ok(())
    }

    pub async fn pair(&self, addr: &str) -> Result<()> {
        let a = self.known(addr, true).await?;
        let d = self.adapter.device(a)?;
        if !d.is_paired().await.unwrap_or(false) {
            d.pair().await.map_err(|_| anyhow!("pair-failed: Pairing did not finish. With the lid open, hold the button on the back until the light flashes white."))?;
        }
        d.set_trusted(true).await?;
        self.watch_device(a);
        let _ = self.pairing.send(false);
        {
            let mut g = self.inner.lock().await;
            g.config.address = Some(addr.to_string());
            g.config.save();
        }
        d.connect().await?;
        self.refresh_devices().await;
        self.changed();
        Ok(())
    }

    pub async fn set_audio(&self, key: &str, v: &str) -> Result<()> {
        let addr = {
            let g = self.inner.lock().await;
            g.state.address.clone().filter(|_| g.state.connected)
        }
        .ok_or_else(|| anyhow!("not-connected: The headphones are not connected."))?;
        let ok = match key {
            "profile" if v == "a2dp" || v == "hfp" => true,
            "volume" if v.parse::<u8>().is_ok_and(|n| n <= 100) => true,
            "default" if v == "true" => true,
            _ => bail!("invalid: Invalid audio setting."),
        };
        let (t, _) = audio::find(&addr).await.ok_or_else(|| anyhow!("audio: PipeWire has no audio device for these headphones."))?;
        let ok = ok
            && match key {
                "profile" => t.set_profile(v).await,
                "volume" => t.set_volume(v.parse().unwrap_or(0)).await,
                _ => t.make_default().await,
            };
        if !ok {
            bail!("audio: PipeWire did not accept this change.");
        }
        self.refresh_audio().await;
        Ok(())
    }

    async fn apply_codec(&self, codec: &str) {
        let addr = {
            let g = self.inner.lock().await;
            g.state.address.clone().filter(|_| g.state.connected)
        };
        if let Some(a) = addr
            && let Some((t, _)) = audio::find(&a).await
            && t.set_codec(codec).await
        {
            tokio::time::sleep(Duration::from_millis(800)).await;
        }
    }

    async fn refresh_audio(&self) {
        let (addr, connected) = {
            let g = self.inner.lock().await;
            (g.state.address.clone(), g.state.connected)
        };
        let found = match &addr {
            Some(a) if connected => audio::find(a).await,
            _ => None,
        };
        let (target, a) = match found {
            Some((t, a)) => (Some(t), a),
            None => (None, Default::default()),
        };
        let mut g = self.inner.lock().await;
        // make it default the first time the output shows up, then respect the user choice
        let fix_a2dp = target.as_ref().is_some_and(|t| t.lost_a2dp()) && !g.a2dp_fixed;
        if fix_a2dp {
            g.a2dp_fixed = true;
            let d = addr.as_deref().and_then(|a| a.parse::<Address>().ok()).and_then(|a| self.adapter.device(a).ok());
            drop(g);
            if let Some(d) = d {
                info!("A2DP missing, asking for it again");
                let _ = d.connect_profile(&A2DP_SINK).await;
            }
            g = self.inner.lock().await;
        }
        let make_default = a.available && !a.is_default && !g.audio_set && g.state.prefs.auto_output;
        let codec = (a.available && !g.audio_set && !g.state.prefs.codec.is_empty()).then(|| g.state.prefs.codec.clone());
        if a.available {
            g.audio_set = true;
        }
        let mut a = a;
        a.mic_active = g.mic_on;
        let changed = g.state.audio != a;
        g.state.audio = a;
        drop(g);
        // a codec the user picked, once per connection; switching restarts the stream
        if let (Some(c), Some(t)) = (codec, &target)
            && t.set_codec(&c).await
        {
            info!("switched music to {c}");
            tokio::time::sleep(Duration::from_millis(800)).await;
            return Box::pin(self.refresh_audio()).await;
        }
        if make_default && let Some(t) = target {
            t.make_default().await;
            return Box::pin(self.refresh_audio()).await;
        }
        self.apply_spatial(target.and_then(|t| t.sink)).await;
        if changed {
            self.changed();
        }
    }

    async fn apply_spatial(&self, sink: Option<String>) {
        if std::env::var_os("PINNA_FAKE").is_some() {
            return;
        }
        let (mode, name) = {
            let g = self.inner.lock().await;
            (g.state.prefs.spatial.clone(), g.state.name.clone())
        };
        let sink = sink.filter(|_| mode != "off" && spatial::available());
        let mut sp = self.spatial.lock().await;
        if sp.as_ref().map(|s| s.sink()) != sink.as_deref() {
            if let Some(s) = sp.take() {
                s.stop().await;
            }
            if let Some(k) = &sink {
                *sp = Spatial::start(k, &name).await;
                if sp.is_none() {
                    warn!("could not start spatial audio");
                }
            }
        }
        let head = sp.is_some() && mode == "head";
        if !head && let Some(s) = sp.as_mut() {
            s.center().await;
        }
        drop(sp);
        let mut g = self.inner.lock().await;
        if g.state.ready && head != g.spatial_head {
            g.spatial_head = head;
            drop(g);
            let _ = self.sync_head().await;
        }
    }

    /// Applies the call setting: WirePlumber HFP switching and the Pinna virtual mic.
    async fn apply_call(&self) {
        // the fake buds share PipeWire with the real service; leave its mic and settings alone
        if std::env::var_os("PINNA_FAKE").is_some() {
            return;
        }
        let (mode, connected, name) = {
            let g = self.inner.lock().await;
            // the paired name while the buds are away, the source outlives the connection
            let name = if g.state.name.is_empty() { g.state.devices.first().map(|d| d.name.clone()).unwrap_or_default() } else { g.state.name.clone() };
            (g.config.prefs.call_mic.clone(), g.state.connected, name)
        };
        audio::call_quality(mode != "hfp").await;
        // the source stays while the setting is on, even when the buds are away; only the
        // default mic moves, so recording apps never see a device vanish
        let want = mode == "airpods";
        let has = self.mic.lock().unwrap_or_else(|e| e.into_inner()).is_some();
        if want && !has {
            match mic::Mic::open(if name.is_empty() { "AirPods" } else { &name }).await {
                Some(m) => *self.mic.lock().unwrap_or_else(|e| e.into_inner()) = Some(m),
                None => warn!("could not open the virtual mic"),
            }
        } else if !want {
            let m = self.mic.lock().unwrap_or_else(|e| e.into_inner()).take();
            match m {
                Some(m) => {
                    mic::park().await;
                    m.close().await;
                }
                None => mic::cleanup().await,
            }
            self.mic_activity().await;
        }
        // a source opened while the buds were away carries a generic name; rename it once
        // they connect, but only while nothing records so no app sees it vanish
        let stale = connected
            && self.mic.lock().unwrap_or_else(|e| e.into_inner()).as_ref().is_some_and(|m| m.desc != mic::description(&name));
        if stale && !mic::in_use().await {
            let m = self.mic.lock().unwrap_or_else(|e| e.into_inner()).take();
            if let Some(m) = m {
                m.close().await;
            }
            *self.mic.lock().unwrap_or_else(|e| e.into_inner()) = mic::Mic::open(&name).await;
        }
        if want && self.mic.lock().unwrap_or_else(|e| e.into_inner()).is_some() {
            if connected {
                mic::make_default().await;
            } else {
                mic::park().await;
            }
        }
    }

    /// Opens the headset mic when an app starts listening to the virtual mic and closes it after.
    async fn mic_activity(&self) {
        let open = self.mic.lock().unwrap_or_else(|e| e.into_inner()).is_some();
        let want = open && mic::in_use().await;
        if self.inner.lock().await.mic_on && !want {
            // apps like Discord close and reopen the device right away, and the buds stop sending
            // audio after a quick STOP and START, so closing is delayed a bit
            let me = self.clone();
            tokio::spawn(async move {
                tokio::time::sleep(Duration::from_secs(3)).await;
                me.mic_apply().await;
            });
        } else {
            self.mic_apply().await;
        }
    }

    async fn mic_apply(&self) {
        let open = self.mic.lock().unwrap_or_else(|e| e.into_inner()).is_some();
        let want = open && mic::in_use().await;
        let mut g = self.inner.lock().await;
        if g.mic_on == want || (want && !g.state.connected) {
            return;
        }
        g.mic_on = want;
        g.state.audio.mic_active = want;
        // with conversation awareness on the buds duck the other side while you talk
        let ca = g.state.settings.get("conversationAwareness").and_then(Value::as_bool) == Some(true);
        let pause = want && ca;
        let resume = !want && std::mem::take(&mut g.ca_paused);
        g.ca_paused |= pause;
        drop(g);
        info!("headset mic {}", if want { "opening" } else { "closing" });
        if let Some(m) = self.mic.lock().unwrap_or_else(|e| e.into_inner()).as_mut() {
            m.last = Some(Instant::now());
        }
        let _ = self.send(if want { aap::MIC_START } else { aap::MIC_STOP }.to_vec()).await;
        if pause || resume {
            let _ = self.send(aap::control(aap::cmd::CONVERSATION, [if want { 2 } else { 1 }, 0, 0, 0])).await;
        }
        self.changed();
    }

    /// Restarts the mic if the buds stop sending audio while it is open.
    async fn mic_watchdog(self) {
        loop {
            tokio::time::sleep(Duration::from_secs(1)).await;
            {
                let g = self.inner.lock().await;
                // with no bud worn the buds send nothing, restarting would only loop
                let worn = g.state.ear.left == Pod::Ear || g.state.ear.right == Pod::Ear;
                if !g.mic_on || !worn {
                    continue;
                }
            }
            let stale = {
                let mut g = self.mic.lock().unwrap_or_else(|e| e.into_inner());
                match g.as_mut() {
                    Some(m) if m.last.is_none_or(|t| t.elapsed() > Duration::from_secs(2)) => {
                        m.last = Some(Instant::now());
                        true
                    }
                    _ => false,
                }
            };
            if stale {
                info!("headset mic went silent, restarting");
                let _ = self.send(aap::MIC_STOP.to_vec()).await;
                tokio::time::sleep(Duration::from_millis(500)).await;
                let _ = self.send(aap::MIC_START.to_vec()).await;
            }
        }
    }

    pub async fn head_tracking(&self, on: bool) -> Result<()> {
        self.inner.lock().await.state.head_tracking = on;
        self.sync_head().await?;
        self.changed();
        Ok(())
    }

    /// One head tracking stream shared by the live view, spatial audio and head gestures.
    async fn sync_head(&self) -> Result<()> {
        let mut g = self.inner.lock().await;
        let want = g.state.ready && (g.state.head_tracking || g.spatial_head || g.state.prefs.head_gestures);
        if want == g.head_on {
            return Ok(());
        }
        g.head_on = want;
        g.gestures.reset();
        drop(g);
        self.send(if want { aap::HEAD_START } else { aap::HEAD_STOP }.to_vec()).await
    }

    /// Refreshes the list of paired Apple headphones.
    async fn refresh_devices(&self) -> Vec<Device> {
        let mut list = Vec::new();
        for a in self.adapter.device_addresses().await.unwrap_or_default() {
            let Ok(d) = self.adapter.device(a) else { continue };
            if !d.is_paired().await.unwrap_or(false) {
                continue;
            }
            let Ok(Some(m)) = d.modalias().await else { continue };
            if m.vendor != APPLE || !is_headphone(m.product as u16) {
                continue;
            }
            list.push(Device {
                address: a.to_string(),
                name: d.alias().await.unwrap_or_default(),
                model_name: proximity::model_name(m.product as u16).into(),
                model_id: m.product as u16,
                connected: d.is_connected().await.unwrap_or(false),
                last: None,
            });
        }
        let mut g = self.inner.lock().await;
        for d in &mut list {
            d.last = g.others.get(&d.address).cloned();
        }
        if g.state.devices != list {
            g.state.devices = list.clone();
            drop(g);
            self.changed();
        }
        list
    }

    pub async fn popup(&self) {
        let mut g = self.inner.lock().await;
        if !g.state.prefs.popup {
            return;
        }
        if g.last_popup.is_some_and(|t| t.elapsed() < Duration::from_secs(20)) {
            return;
        }
        g.last_popup = Some(Instant::now());
        drop(g);
        let cmd = std::env::var("PINNA_POPUP").unwrap_or_else(|_| "pinna --popup".into());
        // the service is sandboxed; run the card as its own unit in the user session
        let mut c = tokio::process::Command::new("systemd-run");
        c.args(["--user", "--quiet", "--collect", "--"]).args(cmd.split_whitespace());
        match c.status().await {
            Ok(s) if s.success() => debug!("popup started"),
            r => warn!("could not start popup: {r:?}"),
        }
    }

    /// Picks the connected headphones; the preferred one if there are several.
    async fn find(&self) -> Option<Address> {
        let list = self.refresh_devices().await;
        let preferred = self.inner.lock().await.config.address.clone();
        let pick = |only_connected: bool| {
            let mut it = list.iter().filter(|d| !only_connected || d.connected);
            let first = it.clone().next();
            it.find(|d| Some(&d.address) == preferred.as_ref()).or(first).cloned()
        };
        let mut g = self.inner.lock().await;
        if let Some(d) = pick(false)
            && (g.state.address.is_none() || g.state.model_id == 0)
        {
            g.state.address = Some(d.address.clone());
            g.state.model_id = d.model_id;
            g.state.model_name = d.model_name.clone();
            if g.state.name.is_empty() {
                g.state.name = d.name.clone();
            }
        }
        drop(g);
        pick(true).and_then(|d| d.address.parse().ok())
    }

    /// Talks to the pretend buds in crate::fake instead of BlueZ, reconnecting if it ends.
    pub async fn run_fake(self) -> Result<()> {
        loop {
            let (ours, theirs) = tokio::net::UnixDatagram::pair()?;
            tokio::spawn(crate::fake::headset(theirs));
            {
                let mut g = self.inner.lock().await;
                g.state.adapter = true;
                g.state.connected = true;
                g.state.address = Some(crate::fake::ADDRESS.into());
                let p = crate::fake::profile();
                g.state.model_name = p.model_name.into();
                g.state.model_id = p.product;
                g.state.devices = vec![Device {
                    address: crate::fake::ADDRESS.into(),
                    name: p.name.into(),
                    model_name: p.model_name.into(),
                    model_id: p.product,
                    connected: true,
                    last: None,
                }];
            }
            self.changed();
            ours.send(aap::HANDSHAKE).await?;
            if let Err(e) = self.talk(ours).await {
                warn!("fake session ended: {e:#}");
            }
            self.on_disconnect().await;
            tokio::time::sleep(Duration::from_secs(2)).await;
        }
    }

    pub async fn run(self) -> Result<()> {
        tokio::spawn(self.clone().scan_loop());
        tokio::spawn(self.clone().pair_loop());
        tokio::spawn(self.clone().bluez_events());
        tokio::spawn(self.clone().audio_events());
        tokio::spawn(self.clone().mic_watchdog());
        let me = self.clone();
        tokio::spawn(async move {
            me.apply_call().await;
        });
        loop {
            let powered = self.adapter.is_powered().await.unwrap_or(false);
            {
                let mut g = self.inner.lock().await;
                if g.state.adapter != powered {
                    g.state.adapter = powered;
                    drop(g);
                    self.changed();
                }
            }
            if let Some(addr) = self.find().await {
                let _ = self.scan.send(false);
                info!("{addr} connected, opening AAP session");
                if let Err(e) = self.session(addr).await {
                    warn!("session ended: {e:#}");
                }
                self.on_disconnect().await;
            } else {
                let scan = self.inner.lock().await.state.prefs.case_scan && powered;
                let _ = self.scan.send(scan);
                // clean up if we were connected before
                if self.inner.lock().await.state.connected {
                    self.on_disconnect().await;
                }
            }
            // no polling: sleep until BlueZ sends an event, but check now and then anyway
            tokio::select! {
                _ = self.wake.notified() => {}
                _ = tokio::time::sleep(Duration::from_secs(60)) => {}
            }
        }
    }

    /// Listens for changes on the adapter and paired headphones.
    async fn bluez_events(self) {
        loop {
            if let Err(e) = self.watch_adapter().await {
                debug!("BlueZ events: {e}");
            }
            tokio::time::sleep(Duration::from_secs(3)).await;
        }
    }

    async fn watch_adapter(&self) -> Result<()> {
        let mut events = self.adapter.events().await?;
        for a in self.adapter.device_addresses().await? {
            self.watch_device(a);
        }
        while let Some(ev) = events.next().await {
            match ev {
                AdapterEvent::DeviceAdded(a) => self.watch_device(a),
                AdapterEvent::DeviceRemoved(_) => {
                    self.refresh_devices().await;
                }
                AdapterEvent::PropertyChanged(bluer::AdapterProperty::Powered(on)) => {
                    let mut g = self.inner.lock().await;
                    // this can arrive just before or after the disconnect event
                    let just_dropped = g.dropped.is_some_and(|t| t.elapsed() < Duration::from_secs(5));
                    if !on && (g.state.connected || just_dropped) {
                        g.reconnect = true;
                    }
                    let reconnect = on && std::mem::take(&mut g.reconnect);
                    if g.state.adapter != on {
                        g.state.adapter = on;
                        drop(g);
                        self.changed();
                    } else {
                        drop(g);
                    }
                    self.wake.notify_one();
                    if reconnect {
                        // resume from sleep goes this way too; retry a few times until the buds are ready
                        let me = self.clone();
                        tokio::spawn(async move {
                            for _ in 0..3 {
                                tokio::time::sleep(Duration::from_secs(2)).await;
                                if me.inner.lock().await.state.connected || me.connect().await.is_ok() {
                                    break;
                                }
                            }
                        });
                    }
                }
                _ => {}
            }
        }
        Ok(())
    }

    fn watch_device(&self, a: Address) {
        if !self.watched.lock().unwrap_or_else(|e| e.into_inner()).insert(a) {
            return;
        }
        let me = self.clone();
        tokio::spawn(async move {
            // only Apple devices that are paired or have a fixed address; rotating addresses come and go
            // by the hundreds while scanning, and each watcher holds a system bus subscription
            let ok = match me.adapter.device(a) {
                Ok(d) => {
                    matches!(d.modalias().await, Ok(Some(m)) if m.vendor == APPLE)
                        && (d.is_paired().await.unwrap_or(false)
                            || !matches!(d.address_type().await, Ok(bluer::AddressType::LeRandom)))
                }
                Err(_) => false,
            };
            if ok && let Ok(d) = me.adapter.device(a) && let Ok(mut ev) = d.events().await {
                while let Some(bluer::DeviceEvent::PropertyChanged(p)) = ev.next().await {
                    use bluer::DeviceProperty as P;
                    if matches!(p, P::Connected(_) | P::Paired(_) | P::Alias(_) | P::ServicesResolved(_)) {
                        me.refresh_devices().await;
                        me.wake.notify_one();
                    }
                }
            }
            me.watched.lock().unwrap_or_else(|e| e.into_inner()).remove(&a);
        });
    }

    /// Listens to PipeWire changes with pactl subscribe; audio state is never polled.
    async fn audio_events(self) {
        use tokio::io::AsyncBufReadExt;
        loop {
            let child = tokio::process::Command::new("pactl")
                .arg("subscribe")
                .stdout(std::process::Stdio::piped())
                .kill_on_drop(true)
                .spawn();
            let Ok(mut child) = child else {
                tokio::time::sleep(Duration::from_secs(30)).await;
                continue;
            };
            let Some(out) = child.stdout.take() else { continue };
            let mut lines = tokio::io::BufReader::new(out).lines();
            self.refresh_audio().await;
            while let Ok(Some(l)) = lines.next_line().await {
                if l.contains(" source") {
                    self.mic_activity().await;
                }
                if !(l.contains(" sink ") || l.contains(" card ") || l.contains(" server")) {
                    continue;
                }
                // fold bursts of events into one refresh
                while let Ok(Ok(Some(_))) = tokio::time::timeout(Duration::from_millis(80), lines.next_line()).await {}
                if self.inner.lock().await.state.connected {
                    self.refresh_audio().await;
                }
            }
            let _ = child.kill().await;
            tokio::time::sleep(Duration::from_secs(3)).await;
        }
    }

    async fn on_disconnect(&self) {
        let mut g = self.inner.lock().await;
        g.tx = None;
        g.state.connected = false;
        g.state.ready = false;
        g.state.speaking = false;
        g.state.ear = Default::default();
        g.state.eq = None;
        g.state.estimate = Default::default();
        g.state.battery = Default::default();
        g.state.head_tracking = false;
        g.spatial_head = false;
        g.head_on = false;
        g.state.audio = Default::default();
        g.audio_set = false;
        g.a2dp_fixed = false;
        g.dropped = Some(Instant::now());
        g.mic_on = false;
        g.ca_paused = false;
        drop(g);
        self.apply_call().await;
        self.media.lock().await.forget();
        self.changed();
    }

    async fn session(&self, addr: Address) -> Result<()> {
        {
            let mut g = self.inner.lock().await;
            g.state.connected = true;
            g.state.address = Some(addr.to_string());
            if g.config.address.as_deref() != Some(&addr.to_string()) {
                g.config.address = Some(addr.to_string());
                g.config.save();
            }
            if let Some(d) = g.state.devices.iter().find(|d| d.address == addr.to_string()).cloned() {
                g.state.model_id = d.model_id;
                g.state.model_name = d.model_name;
            }
        }
        self.changed();

        let sa = bluer::l2cap::SocketAddr::new(addr, bluer::AddressType::BrEdr, aap::PSM);
        let mut sock = None;
        for i in 0..5 {
            match bluer::l2cap::SeqPacket::connect(sa).await {
                Ok(s) => {
                    sock = Some(s);
                    break;
                }
                Err(e) => {
                    debug!("L2CAP denemesi {i}: {e}");
                    tokio::time::sleep(Duration::from_millis(800)).await;
                    if !self.adapter.device(addr)?.is_connected().await.unwrap_or(false) {
                        bail!("device closed the connection");
                    }
                }
            }
        }
        let sock = sock.ok_or_else(|| anyhow!("could not open the AAP channel"))?;
        // bluer sometimes returns before the link is up, wait until ENOTCONN clears
        let mut tries = 0;
        loop {
            match sock.send(aap::HANDSHAKE).await {
                Ok(_) => break,
                Err(e) if e.raw_os_error() == Some(107) && tries < 50 => {
                    tries += 1;
                    tokio::time::sleep(Duration::from_millis(100)).await;
                }
                Err(e) => return Err(e.into()),
            }
        }

        let me = self.clone();
        tokio::spawn(async move {
            // PipeWire opens the card a bit after connecting; look twice in case an event is missed
            for s in [2, 6] {
                tokio::time::sleep(Duration::from_secs(s)).await;
                me.refresh_audio().await;
            }
            // sometimes only our AAP channel comes up and the buds never start A2DP, so there is
            // no audio device at all (LibrePods #799); ask for it once
            let (up, connected) = {
                let g = me.inner.lock().await;
                (g.state.audio.available, g.state.connected)
            };
            if connected && !up && let Ok(d) = me.adapter.device(addr) {
                info!("no audio device after connecting, asking for A2DP");
                if let Err(e) = d.connect_profile(&A2DP_SINK).await {
                    debug!("A2DP request failed: {e}");
                }
                tokio::time::sleep(Duration::from_secs(3)).await;
                me.refresh_audio().await;
            }
        });

        self.talk(sock).await
    }

    /// The packet loop of a session, over the real L2CAP socket or a fake one.
    async fn talk<L: Link>(&self, sock: L) -> Result<()> {
        let (tx, mut rx) = mpsc::unbounded_channel::<Vec<u8>>();
        self.inner.lock().await.tx = Some(tx.clone());

        let mut buf = vec![0u8; 2048];
        let mut announced = false;
        loop {
            tokio::select! {
                r = sock.recv(&mut buf) => {
                    let n = r?;
                    if n == 0 { bail!("channel closed"); }
                    let data = &buf[..n];
                    if data.len() > 8 && data[4] == 0x58 {
                        if let Some(m) = self.mic.lock().unwrap_or_else(|e| e.into_inner()).as_mut() {
                            m.feed(data);
                        }
                        continue;
                    }
                    debug!("<- {}", Config::hex(data));
                    if let Some(p) = aap::parse(data) {
                        if matches!(p, Packet::HandshakeAck) {
                            self.after_handshake(&tx).await;
                        }
                        let first_battery = matches!(p, Packet::Battery(_)) && !announced;
                        self.handle(p).await;
                        if first_battery {
                            announced = true;
                            self.apply_call().await;
                            self.popup().await;
                        }
                    }
                }
                Some(p) = rx.recv() => {
                    debug!("-> {}", Config::hex(&p));
                    sock.send(&p).await?;
                }
            }
        }
    }

    async fn after_handshake(&self, tx: &mpsc::UnboundedSender<Vec<u8>>) {
        let _ = tx.send(aap::FEATURES.to_vec());
        let _ = tx.send(aap::NOTIFY.to_vec());
        let mut g = self.inner.lock().await;
        if !g.state.has_keys {
            let _ = tx.send(aap::REQUEST_KEYS.to_vec());
        }
        g.state.ready = true;
        let sticky = g.config.sticky.clone();
        drop(g);
        for (k, v) in sticky {
            let s = match &v {
                Value::Bool(b) => b.to_string(),
                other => other.to_string(),
            };
            if let Err(e) = self.set_setting(&k, &s).await {
                debug!("could not restore {k}: {e}");
            }
        }
        self.send_stem_mask().await;
        let _ = self.sync_head().await;
        self.changed();
    }

    async fn handle(&self, p: Packet) {
        let mut g = self.inner.lock().await;
        match p {
            Packet::Battery(list) => {
                if let Some(first) = list.iter().find(|e| e.component != Component::Case) {
                    g.primary_left = first.component != Component::Right;
                }
                // history, estimates and warnings then work unchanged for a single battery
                g.state.one_battery = list.iter().any(|e| e.component == Component::Single);
                for e in list {
                    let cell = Cell { level: e.connected.then_some(e.level), charging: e.charging };
                    match e.component {
                        Component::Left | Component::Single => g.state.battery.left = cell,
                        Component::Right => g.state.battery.right = cell,
                        Component::Case => g.state.battery.case_ = cell,
                    }
                }
                let low = self.low_battery(&mut g);
                let full = self.charged(&mut g);
                let b = g.state.battery.clone();
                g.history.record(&b);
                let rows = crate::history::read();
                let now = rows.last().map(|r| r[0]).unwrap_or(0).max(
                    std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs() as i64).unwrap_or(0),
                );
                let est = |i: usize, c: &Cell| {
                    let s: Vec<(i64, i16)> = rows.iter().map(|r| (r[0], r[i] as i16)).collect();
                    pinna_core::estimate::minutes(&s, now, c.charging)
                };
                g.state.estimate = state::Estimate { left: est(1, &b.left), right: est(2, &b.right) };
                drop(g);
                let m = self.media.lock().await;
                if let Some(msg) = low {
                    m.notify(t("AirPods battery low"), &msg, "battery-caution").await;
                }
                if let Some(msg) = full {
                    m.notify(t("Charging complete"), &msg, "battery-full-charged").await;
                }
            }
            Packet::Ear(primary, secondary) => {
                let (l, r) = if g.primary_left { (primary, secondary) } else { (secondary, primary) };
                let before = in_ear(&g.state.ear.left) + in_ear(&g.state.ear.right);
                let known = g.state.ear.left != Pod::Unknown;
                g.state.ear.left = l;
                g.state.ear.right = r;
                let after = in_ear(&l) + in_ear(&r);
                let prefs = g.state.prefs.clone();
                let all_in_case = l == Pod::Case && r == Pod::Case;
                // only pause when the sound goes to the buds, not music on the speakers
                let ours = !g.state.audio.available || g.state.audio.is_default;
                g.ear_gen += 1;
                let ear_gen = g.ear_gen;
                let ca_on = g.state.settings.get("conversationAwareness").and_then(|v| v.as_bool()) == Some(true);
                // with one bud in, conversation awareness ducks everything; it comes back with both in
                let ca = if prefs.ca_one_bud && after == 1 && ca_on && !g.ca_held {
                    g.ca_held = true;
                    Some(2)
                } else if g.ca_held && (after == 2 || !prefs.ca_one_bud) {
                    g.ca_held = false;
                    Some(1)
                } else {
                    None
                };
                drop(g);
                if let Some(b) = ca {
                    let _ = self.send(aap::control(aap::cmd::CONVERSATION, [b, 0, 0, 0])).await;
                }
                if known {
                    let mut m = self.media.lock().await;
                    if all_in_case {
                        m.forget();
                    } else if after < before && prefs.auto_pause && ours {
                        // ear sensors flicker for a moment when you adjust a bud; only pause if it stays out
                        let me = self.clone();
                        tokio::spawn(async move {
                            tokio::time::sleep(EAR_SETTLE).await;
                            let g = me.inner.lock().await;
                            let now = in_ear(&g.state.ear.left) + in_ear(&g.state.ear.right);
                            if g.ear_gen == ear_gen && now < before {
                                drop(g);
                                me.media.lock().await.pause_all().await;
                            }
                        });
                    } else if after > before && prefs.auto_resume {
                        m.resume().await;
                    }
                }
            }
            Packet::Control { id, data } => {
                if id == aap::cmd::LISTENING_MODE {
                    g.state.mode = Mode::from_byte(data[0]);
                } else if id == aap::cmd::HOLD_MODE {
                    g.state.settings.insert("holdRight".into(), Value::from(data[0]));
                    g.state.settings.insert("holdLeft".into(), Value::from(data[1]));
                } else if let Some((key, kind)) = state::lookup_id(id)
                    && let Some(v) = state::decode(kind, data[0])
                {
                    g.state.settings.insert(key.into(), v);
                }
            }
            Packet::Speaking(level) => {
                g.state.speaking = level <= 2;
                let prefs = g.state.prefs.clone();
                let g_mic = g.mic_on;
                drop(g);
                // your own voice in a call should not duck the computer
                if prefs.duck_on_speech && !g_mic {
                    self.media.lock().await.speech(level, prefs.duck_level).await;
                }
            }
            Packet::Info(i) => {
                // the product id table may not know newer models; the part number fills in
                if (g.state.model_name.is_empty() || g.state.model_name == "AirPods")
                    && let Some(n) = proximity::model_from_part(&i.model)
                {
                    g.state.model_name = n.into();
                }
                g.state.name = i.name;
                g.state.model = i.model;
                g.state.firmware = i.firmware;
                g.state.version = i.version;
                g.state.serial = i.serial;
                g.state.serial_left = i.serial_left;
                g.state.serial_right = i.serial_right;
            }
            Packet::Keys { irk, enc } => {
                info!("got BLE keys");
                if let Some(a) = g.state.address.clone() {
                    g.config.set_keys(&a, &irk, &enc);
                    g.state.has_keys = true;
                    g.config.save();
                }
            }
            Packet::Head(v) => {
                let feed = g.spatial_head;
                let gesture = if g.state.prefs.head_gestures {
                    let (yaw, pitch) = pinna_core::gesture::angles(v);
                    let t = g.epoch.elapsed().as_secs_f32();
                    g.gestures.feed(t, yaw, pitch).map(|x| match x {
                        pinna_core::gesture::Gesture::Nod => ("nod", g.state.prefs.gesture_nod.clone()),
                        pinna_core::gesture::Gesture::Shake => ("shake", g.state.prefs.gesture_shake.clone()),
                    })
                } else {
                    None
                };
                drop(g);
                if let Some((name, action)) = gesture {
                    info!("head gesture: {name}, {action}");
                    self.act(&action).await;
                }
                if feed && let Some(s) = self.spatial.lock().await.as_mut() {
                    s.head(v).await;
                }
                let _ = self.events.send(Event::Head(v));
                return;
            }
            Packet::Eq(e) => g.state.eq = Some(e),
            Packet::Stem { press, left } => {
                drop(g);
                self.stem(press, left).await;
                return;
            }
            Packet::HandshakeAck | Packet::Other(_) => return,
        }
        self.changed();
    }

    async fn send_stem_mask(&self) {
        let mask = self.inner.lock().await.state.prefs.stem_mask();
        if let Err(e) = self.send(aap::control(aap::cmd::STEM_CONFIG, [mask, 0, 0, 0])).await {
            debug!("could not send stem config: {e}");
        }
    }

    /// When the buds forward a press. An unassigned side mimics what the buds would do.
    async fn stem(&self, press: u8, left: bool) {
        let (name, fallback) = match press {
            6 => ("double", "next"),
            7 => ("triple", "previous"),
            8 => ("long", "mode"),
            _ => return,
        };
        let side = if left { "left" } else { "right" };
        let action = {
            let g = self.inner.lock().await;
            let hold = g.state.settings.get(if left { "holdLeft" } else { "holdRight" }).and_then(|v| v.as_u64());
            let fb = if press == 8 && hold == Some(5) { "nothing" } else { fallback };
            g.state.prefs.stem.get(&format!("{name}.{side}")).cloned().unwrap_or_else(|| fb.into())
        };
        info!("stem press: {name} {side}, {action}");
        self.act(&action).await;
    }

    /// What a stem press or head gesture was bound to.
    async fn act(&self, action: &str) {
        let mode = self.inner.lock().await.state.mode;
        let wpctl = |args: &[&str]| {
            let mut c = tokio::process::Command::new("wpctl");
            c.args(args);
            c
        };
        match action {
            "playPause" => self.media.lock().await.player("PlayPause").await,
            "next" => self.media.lock().await.player("Next").await,
            "previous" => self.media.lock().await.player("Previous").await,
            "volumeUp" => drop(wpctl(&["set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", "5%+"]).status().await),
            "volumeDown" => drop(wpctl(&["set-volume", "@DEFAULT_AUDIO_SINK@", "5%-"]).status().await),
            "micMute" => {
                let _ = wpctl(&["set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]).status().await;
                let out = wpctl(&["get-volume", "@DEFAULT_AUDIO_SOURCE@"]).output().await;
                let muted = out.is_ok_and(|o| String::from_utf8_lossy(&o.stdout).contains("MUTED"));
                let (title, icon) = if muted { (t("Microphone muted"), "microphone-sensitivity-muted") } else { (t("Microphone on"), "audio-input-microphone") };
                self.media.lock().await.notify(title, "", icon).await;
            }
            "ancTransparency" => {
                let next = if mode == Some(Mode::Anc) { Mode::Transparency } else { Mode::Anc };
                if let Err(e) = self.send(aap::control(aap::cmd::LISTENING_MODE, [next.byte(), 0, 0, 0])).await {
                    warn!("could not change mode: {e}");
                }
            }
            "mode" => {
                if let Err(e) = self.cycle_mode().await {
                    warn!("could not change mode: {e}");
                }
            }
            c => {
                if let Some(cmd) = c.strip_prefix("cmd:") {
                    // the service is sandboxed; run the command in the user session
                    let r = tokio::process::Command::new("systemd-run")
                        .args(["--user", "--quiet", "--collect", "--", "sh", "-c", cmd])
                        .status()
                        .await;
                    if !r.is_ok_and(|s| s.success()) {
                        warn!("command failed: {cmd}");
                    }
                }
            }
        }
    }

    fn low_battery(&self, g: &mut Inner) -> Option<String> {
        if !g.state.prefs.low_battery_notify {
            return None;
        }
        let mut msg = None;
        let one = g.state.one_battery.then(|| g.state.model_name.clone());
        for (i, (cell, side)) in [(g.state.battery.left, t("Left")), (g.state.battery.right, t("Right"))].iter().enumerate() {
            let Some(lvl) = cell.level else { continue };
            let limit = g.state.prefs.low_battery;
            if cell.charging || lvl > limit {
                g.warned[i] = 100;
                continue;
            }
            let step = if lvl <= limit / 2 { limit / 2 } else { limit };
            if step < g.warned[i] {
                g.warned[i] = step;
                msg = Some(match &one {
                    Some(name) => format!("{name} {lvl}%"),
                    None => format!("{side} AirPod {lvl}%"),
                });
            }
        }
        msg
    }

    fn charged(&self, g: &mut Inner) -> Option<String> {
        let b = &g.state.battery;
        let left = if g.state.one_battery { g.state.model_name.clone() } else { t("Left AirPod").to_string() };
        let cells = [(b.left, left), (b.right, t("Right AirPod").to_string()), (b.case_, t("Case").to_string())];
        let mut done = Vec::new();
        for (i, (c, name)) in cells.iter().enumerate() {
            match c.level {
                // no notification if it starts full; going from below 95% to 100 means it charged,
                // the charging bit is ignored since some buds clear it once full
                Some(100) if !g.full[i] => {
                    g.full[i] = true;
                    done.push(name.clone());
                }
                Some(l) if l < 95 => g.full[i] = false,
                _ => {}
            }
        }
        (g.state.prefs.charged_notify && !done.is_empty()).then(|| done.join(", ") + " 100%")
    }

    async fn pair_loop(self) {
        let mut want = self.pairing.subscribe();
        loop {
            while !*want.borrow_and_update() {
                if want.changed().await.is_err() {
                    return;
                }
            }
            self.inner.lock().await.state.discovering = true;
            self.changed();
            let r = tokio::time::timeout(Duration::from_secs(30), self.pair_scan(&mut want)).await;
            if let Ok(Err(e)) = r {
                debug!("pairing scan: {e}");
            }
            let _ = self.pairing.send(false);
            let mut g = self.inner.lock().await;
            g.state.discovering = false;
            g.state.nearby.clear();
            drop(g);
            self.changed();
        }
    }

    async fn pair_scan(&self, want: &mut watch::Receiver<bool>) -> Result<()> {
        self.adapter
            .set_discovery_filter(DiscoveryFilter { transport: DiscoveryTransport::BrEdr, ..Default::default() })
            .await?;
        let mut stream = self.adapter.discover_devices().await?;
        loop {
            tokio::select! {
                _ = want.changed() => if !*want.borrow() { return Ok(()) },
                ev = stream.next() => {
                    let Some(AdapterEvent::DeviceAdded(a)) = ev else {
                        if ev.is_none() { return Ok(()) }
                        continue;
                    };
                    let Ok(d) = self.adapter.device(a) else { continue };
                    if d.is_paired().await.unwrap_or(true) {
                        continue;
                    }
                    let name = d.alias().await.unwrap_or_default();
                    let apple = matches!(d.modalias().await, Ok(Some(m)) if m.vendor == APPLE);
                    // AirPods in pairing mode often have no modalias, check the name
                    if !apple && !name.contains("AirPods") && !name.contains("Beats") {
                        continue;
                    }
                    let mut g = self.inner.lock().await;
                    if !g.state.nearby.iter().any(|n| n.address == a.to_string()) {
                        g.state.nearby.push(Device { address: a.to_string(), name, ..Default::default() });
                        drop(g);
                        self.changed();
                    }
                }
            }
        }
    }

    async fn scan_loop(self) {
        let mut want = self.scan.subscribe();
        let mut seen = Instant::now();
        loop {
            while !*want.borrow_and_update() {
                if want.changed().await.is_err() {
                    return;
                }
                // a fresh disconnect or a toggle starts with full scanning
                seen = Instant::now();
            }
            match self.scan_once(&mut want, &mut seen).await {
                // duty cycle: nothing of ours around, rest the radio for a while
                Ok(true) => {
                    tokio::select! {
                        _ = want.changed() => {}
                        _ = tokio::time::sleep(SCAN_REST) => {}
                    }
                }
                Ok(false) => {}
                Err(e) => {
                    debug!("scan error: {e}");
                    tokio::time::sleep(Duration::from_secs(5)).await;
                }
            }
        }
    }

    /// Returns true when it stopped to rest because our buds have been quiet for a while.
    async fn scan_once(&self, want: &mut watch::Receiver<bool>, seen: &mut Instant) -> Result<bool> {
        self.adapter
            .set_discovery_filter(DiscoveryFilter {
                transport: DiscoveryTransport::Le,
                duplicate_data: true,
                // far away adverts are useless here and only cost wakeups
                rssi: Some(-95),
                ..Default::default()
            })
            .await?;
        let mut stream = self.adapter.discover_devices_with_changes().await?;
        debug!("case scan started");
        let mut lid_open = false;
        let started = Instant::now();
        let mut tick = tokio::time::interval(Duration::from_secs(1));
        loop {
            tokio::select! {
                _ = want.changed() => {
                    if !*want.borrow() { debug!("case scan stopped"); return Ok(false); }
                }
                _ = tick.tick() => {
                    if seen.elapsed() > SCAN_IDLE && started.elapsed() > SCAN_ON {
                        return Ok(true);
                    }
                }
                ev = stream.next() => {
                    let Some(AdapterEvent::DeviceAdded(a)) = ev else {
                        if ev.is_none() { return Ok(false); }
                        continue;
                    };
                    let Some((owner, adv, rssi)) = self.advert(a).await else { continue };
                    let now = std::time::SystemTime::now().duration_since(std::time::UNIX_EPOCH).map(|d| d.as_secs()).unwrap_or(0);
                    {
                        let mut g = self.inner.lock().await;
                        let selected = g.state.address.as_deref().is_some_and(|s| s.eq_ignore_ascii_case(&owner));
                        if !selected {
                            let last = state::Last { left: adv.left, right: adv.right, case_: adv.case_, at: now };
                            let key = g.state.devices.iter().find(|d| d.address.eq_ignore_ascii_case(&owner)).map(|d| d.address.clone());
                            if let Some(k) = key {
                                g.others.insert(k.clone(), last.clone());
                                if let Some(d) = g.state.devices.iter_mut().find(|d| d.address == k) {
                                    d.last = Some(last);
                                }
                                drop(g);
                                self.changed();
                            }
                            continue;
                        }
                    }
                    *seen = Instant::now();
                    let opened = adv.lid_open && !lid_open;
                    lid_open = adv.lid_open;
                    {
                        let mut g = self.inner.lock().await;
                        if g.state.connected { continue; }
                        g.state.battery.left = Cell { level: adv.left, charging: adv.left_charging };
                        g.state.battery.right = Cell { level: adv.right, charging: adv.right_charging };
                        g.state.battery.case_ = Cell { level: adv.case_, charging: adv.case_charging };
                        g.state.note_signal(rssi, now);
                    }
                    self.changed();
                    if opened {
                        info!("case opened");
                        let _ = self.events.send(Event::CaseOpened(adv));
                        self.popup().await;
                    }
                }
            }
        }
    }

    /// Whose advert this is: the address of the paired headphones it belongs to.
    async fn advert(&self, a: Address) -> Option<(String, Advert, i16)> {
        let d = self.adapter.device(a).ok()?;
        let rssi = d.rssi().await.ok()??;
        let data = d.manufacturer_data().await.ok()??;
        let raw = data.get(&(APPLE as u16))?;
        let g = self.inner.lock().await;
        let selected = g.state.address.clone().unwrap_or_default();
        let model = g.state.model_id;
        let owner = g.config.keys.keys().find_map(|addr| {
            let (irk, enc) = g.config.keys_for(addr)?;
            proximity::rpa_matches(a.0, &irk).then(|| (addr.clone(), enc))
        });
        let (owner, enc) = match owner {
            Some((addr, enc)) => (addr, Some(enc)),
            // no keys yet for the selected pair: only something right next to us counts
            None if g.config.keys_for(&selected).is_none() && rssi > -60 => (selected.to_uppercase(), None),
            None => return None,
        };
        drop(g);
        let adv = proximity::parse(raw, enc.as_ref())?;
        if owner.eq_ignore_ascii_case(&selected) && model != 0 && adv.model != model {
            return None;
        }
        Some((owner, adv, rssi))
    }
}

fn in_ear(p: &Pod) -> u8 {
    (*p == Pod::Ear) as u8
}

fn is_headphone(product: u16) -> bool {
    // AirPods and Beats product ids are in the 0x20xx range
    product & 0xff00 == 0x2000
}

fn next_mode(cycle: u8, mode: Option<Mode>, allow_off: bool) -> Option<Mode> {
    let order = [(Mode::Anc, 2), (Mode::Transparency, 4), (Mode::Adaptive, 8), (Mode::Off, 1)];
    // without the off option the buds refuse it and the cycle gets stuck
    let list: Vec<Mode> = order
        .iter()
        .filter(|(m, b)| cycle & b != 0 && (*m != Mode::Off || allow_off))
        .map(|(m, _)| *m)
        .collect();
    let at = list.iter().position(|m| Some(*m) == mode);
    at.map_or(list.first(), |i| list.get((i + 1) % list.len())).copied()
}

#[cfg(test)]
mod cycle_tests {
    use super::*;

    #[test]
    fn follows_the_stem_selection() {
        assert_eq!(next_mode(0x0E, Some(Mode::Anc), false), Some(Mode::Transparency));
        assert_eq!(next_mode(0x0E, Some(Mode::Adaptive), false), Some(Mode::Anc));
        assert_eq!(next_mode(0x06, Some(Mode::Transparency), false), Some(Mode::Anc));
        // off is selected but not allowed
        assert_eq!(next_mode(0x03, Some(Mode::Anc), false), Some(Mode::Anc));
        assert_eq!(next_mode(0x03, Some(Mode::Anc), true), Some(Mode::Off));
        assert_eq!(next_mode(0x0E, None, false), Some(Mode::Anc));
        assert_eq!(next_mode(0, None, false), None);
    }
}
