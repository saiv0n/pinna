use earshot_core::aap::{self, Component, Mode, Packet, Pod};
use crate::media::Media;
use earshot_core::proximity::{self, Advert};
use earshot_core::state::{self, Cell, Config, State};
use anyhow::{Context, Result, anyhow, bail};
use bluer::{Adapter, Address, AdapterEvent, DiscoveryFilter, DiscoveryTransport};
use futures::StreamExt;
use log::{debug, info, warn};
use serde_json::Value;
use std::sync::Arc;
use std::time::{Duration, Instant};
use tokio::sync::{Mutex, broadcast, mpsc, watch};

const APPLE: u32 = 0x004C;

#[derive(Debug, Clone)]
pub enum Event {
    State,
    CaseOpened(Advert),
}

struct Inner {
    state: State,
    config: Config,
    tx: Option<mpsc::UnboundedSender<Vec<u8>>>,
    primary_left: bool,
    warned: [u8; 2],
    last_popup: Option<Instant>,
}

#[derive(Clone)]
pub struct Daemon {
    inner: Arc<Mutex<Inner>>,
    pub events: broadcast::Sender<Event>,
    media: Arc<Mutex<Media>>,
    adapter: Adapter,
    scan: watch::Sender<bool>,
}

impl Daemon {
    pub async fn new(bus: zbus::Connection) -> Result<Daemon> {
        let session = bluer::Session::new().await?;
        let adapter = session.default_adapter().await?;
        let config = Config::load();
        let mut st = State { prefs: config.prefs.clone(), ..Default::default() };
        st.has_keys = Config::key16(&config.enc_key).is_some();
        st.address = config.address.clone();
        let (events, _) = broadcast::channel(64);
        let (scan, _) = watch::channel(false);
        Ok(Daemon {
            inner: Arc::new(Mutex::new(Inner {
                state: st,
                config,
                tx: None,
                primary_left: true,
                warned: [100, 100],
                last_popup: None,
            })),
            events,
            media: Arc::new(Mutex::new(Media::new(bus))),
            adapter,
            scan,
        })
    }

    fn changed(&self) {
        let _ = self.events.send(Event::State);
    }

    pub async fn json(&self) -> String {
        serde_json::to_string(&self.inner.lock().await.state).unwrap_or_default()
    }

    async fn send(&self, p: Vec<u8>) -> Result<()> {
        let g = self.inner.lock().await;
        let tx = g.tx.as_ref().ok_or_else(|| anyhow!("AirPods bağlı değil"))?;
        tx.send(p).map_err(|_| anyhow!("bağlantı kapandı"))
    }

    pub async fn set_mode(&self, m: &str) -> Result<()> {
        let mode = Mode::parse(m).ok_or_else(|| anyhow!("bilinmeyen mod: {m}"))?;
        self.send(aap::control(aap::cmd::LISTENING_MODE, [mode.byte(), 0, 0, 0])).await?;
        // kulaklık onayı gelince zaten güncellenecek, arayüz beklemesin
        self.inner.lock().await.state.mode = Some(mode);
        self.changed();
        Ok(())
    }

    pub async fn set_setting(&self, key: &str, v: &str) -> Result<()> {
        let packet;
        let value: Value;
        {
            let g = self.inner.lock().await;
            if key == "holdLeft" || key == "holdRight" {
                let n: u8 = v.parse().ok().filter(|n| *n == 1 || *n == 5).context("1 ya da 5 olmalı")?;
                let cur = |k: &str| g.state.settings.get(k).and_then(|x| x.as_u64()).unwrap_or(1) as u8;
                let (l, r) = if key == "holdLeft" { (n, cur("holdRight")) } else { (cur("holdLeft"), n) };
                packet = aap::control(aap::cmd::HOLD_MODE, [r, l, 0, 0]);
                value = Value::from(n);
            } else {
                let (id, kind) = state::lookup(key).ok_or_else(|| anyhow!("bilinmeyen ayar: {key}"))?;
                let b = state::encode(kind, v).ok_or_else(|| anyhow!("geçersiz değer: {v}"))?;
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
        g.config.prefs.set(key, v)?;
        g.state.prefs = g.config.prefs.clone();
        let scan = g.config.prefs.case_scan && !g.state.connected;
        g.config.save();
        drop(g);
        let _ = self.scan.send(scan);
        self.changed();
        Ok(())
    }

    pub async fn rename(&self, name: &str) -> Result<()> {
        let name = name.trim();
        if name.is_empty() || name.len() > 32 {
            bail!("isim 1-32 bayt olmalı");
        }
        self.send(aap::rename(name)).await?;
        let addr = {
            let mut g = self.inner.lock().await;
            g.state.name = name.to_string();
            g.state.address.clone()
        };
        // BlueZ tarafındaki takma ad da değişsin ki ses çıkışında yeni isim görünsün
        if let Some(a) = addr.and_then(|a| a.parse::<Address>().ok())
            && let Ok(d) = self.adapter.device(a)
        {
            let _ = d.set_alias(name.to_string()).await;
        }
        self.changed();
        Ok(())
    }

    pub async fn raw(&self, id: u8, d1: u8, d2: u8) -> Result<()> {
        self.send(aap::control(id, [d1, d2, 0, 0])).await
    }

    async fn target(&self) -> Result<Address> {
        let g = self.inner.lock().await;
        let a = g.state.address.clone().or(g.config.address.clone()).ok_or_else(|| anyhow!("eşli AirPods bulunamadı"))?;
        Ok(a.parse()?)
    }

    pub async fn connect(&self) -> Result<()> {
        let a = self.target().await?;
        self.adapter.set_powered(true).await?;
        self.adapter.device(a)?.connect().await?;
        Ok(())
    }

    pub async fn disconnect(&self) -> Result<()> {
        let a = self.target().await?;
        self.adapter.device(a)?.disconnect().await?;
        Ok(())
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
        let cmd = std::env::var("EARSHOT_POPUP").unwrap_or_else(|_| "earshot --popup".into());
        let mut parts = cmd.split_whitespace();
        if let Some(bin) = parts.next() {
            match tokio::process::Command::new(bin).args(parts).spawn() {
                Ok(_) => debug!("açılır kart başlatıldı"),
                Err(e) => warn!("açılır kart başlatılamadı: {e}"),
            }
        }
    }

    /// Eşli Apple kulaklıklarını bulur; bağlı olanı döndürür.
    async fn find(&self) -> Option<Address> {
        let addrs = self.adapter.device_addresses().await.ok()?;
        let preferred = self.inner.lock().await.config.address.clone();
        let mut known = None;
        let mut connected = None;
        for a in addrs {
            let Ok(d) = self.adapter.device(a) else { continue };
            if !d.is_paired().await.unwrap_or(false) {
                continue;
            }
            let Ok(Some(m)) = d.modalias().await else { continue };
            if m.vendor != APPLE || !is_headphone(m.product as u16) {
                continue;
            }
            let is_pref = preferred.as_deref() == Some(&a.to_string());
            if known.is_none() || is_pref {
                known = Some((a, m.product as u16, d.alias().await.unwrap_or_default()));
            }
            if d.is_connected().await.unwrap_or(false) && (connected.is_none() || is_pref) {
                connected = Some(a);
            }
        }
        let mut g = self.inner.lock().await;
        if let Some((a, product, alias)) = known
            && (g.state.address.is_none() || g.state.model_id == 0)
        {
            g.state.address = Some(a.to_string());
            g.state.model_id = product;
            g.state.model_name = proximity::model_name(product).into();
            if g.state.name.is_empty() {
                g.state.name = alias;
            }
        }
        connected
    }

    pub async fn run(self) -> Result<()> {
        tokio::spawn(self.clone().scan_loop());
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
                info!("{addr} bağlı, AAP oturumu açılıyor");
                if let Err(e) = self.session(addr).await {
                    warn!("oturum bitti: {e:#}");
                }
                self.on_disconnect().await;
            } else {
                let scan = self.inner.lock().await.state.prefs.case_scan && powered;
                let _ = self.scan.send(scan);
                // önceki durumda bağlıydıysa temizle
                if self.inner.lock().await.state.connected {
                    self.on_disconnect().await;
                }
            }
            tokio::time::sleep(Duration::from_secs(2)).await;
        }
    }

    async fn on_disconnect(&self) {
        let mut g = self.inner.lock().await;
        g.tx = None;
        g.state.connected = false;
        g.state.ready = false;
        g.state.speaking = false;
        g.state.ear = Default::default();
        g.state.battery = Default::default();
        drop(g);
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
                        bail!("cihaz bağlantıyı kesti");
                    }
                }
            }
        }
        let sock = sock.ok_or_else(|| anyhow!("AAP kanalı açılamadı"))?;
        // bluer bazen bağlantı kurulmadan dönüyor, ENOTCONN bitene kadar bekle
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

        let (tx, mut rx) = mpsc::unbounded_channel::<Vec<u8>>();
        self.inner.lock().await.tx = Some(tx.clone());

        let mut buf = vec![0u8; 2048];
        let mut announced = false;
        loop {
            tokio::select! {
                r = sock.recv(&mut buf) => {
                    let n = r?;
                    if n == 0 { bail!("kanal kapandı"); }
                    let data = &buf[..n];
                    debug!("<- {}", Config::hex(data));
                    if let Some(p) = aap::parse(data) {
                        if matches!(p, Packet::HandshakeAck) {
                            self.after_handshake(&tx).await;
                        }
                        let first_battery = matches!(p, Packet::Battery(_)) && !announced;
                        self.handle(p).await;
                        if first_battery {
                            announced = true;
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
                debug!("{k} geri yüklenemedi: {e}");
            }
        }
        self.changed();
    }

    async fn handle(&self, p: Packet) {
        let mut g = self.inner.lock().await;
        match p {
            Packet::Battery(list) => {
                if let Some(first) = list.iter().find(|e| e.component != Component::Case) {
                    g.primary_left = first.component == Component::Left;
                }
                for e in list {
                    let cell = Cell { level: e.connected.then_some(e.level), charging: e.charging };
                    match e.component {
                        Component::Left => g.state.battery.left = cell,
                        Component::Right => g.state.battery.right = cell,
                        Component::Case => g.state.battery.case_ = cell,
                    }
                }
                let low = self.low_battery(&mut g);
                drop(g);
                if let Some(msg) = low {
                    self.media.lock().await.notify("AirPods pili azaldı", &msg, "battery-caution").await;
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
                drop(g);
                if known {
                    let mut m = self.media.lock().await;
                    if all_in_case {
                        m.forget();
                    } else if after < before && prefs.auto_pause {
                        m.pause_all().await;
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
                drop(g);
                if prefs.duck_on_speech {
                    self.media.lock().await.speech(level, prefs.duck_level).await;
                }
            }
            Packet::Info(i) => {
                g.state.name = i.name;
                g.state.model = i.model;
                g.state.firmware = i.firmware;
                g.state.serial = i.serial;
                g.state.serial_left = i.serial_left;
                g.state.serial_right = i.serial_right;
            }
            Packet::Keys { irk, enc } => {
                info!("BLE anahtarları alındı");
                g.config.irk = Some(Config::hex(&irk));
                g.config.enc_key = Some(Config::hex(&enc));
                g.state.has_keys = true;
                g.config.save();
            }
            Packet::HandshakeAck | Packet::Other(_) => return,
        }
        self.changed();
    }

    fn low_battery(&self, g: &mut Inner) -> Option<String> {
        if !g.state.prefs.low_battery_notify {
            return None;
        }
        let mut msg = None;
        for (i, (cell, side)) in [(g.state.battery.left, "Sol"), (g.state.battery.right, "Sağ")].iter().enumerate() {
            let Some(lvl) = cell.level else { continue };
            if cell.charging || lvl > 20 {
                g.warned[i] = 100;
                continue;
            }
            let step = if lvl <= 10 { 10 } else { 20 };
            if step < g.warned[i] {
                g.warned[i] = step;
                msg = Some(format!("{side} AirPod %{lvl}"));
            }
        }
        msg
    }

    async fn scan_loop(self) {
        let mut want = self.scan.subscribe();
        loop {
            while !*want.borrow_and_update() {
                if want.changed().await.is_err() {
                    return;
                }
            }
            if let Err(e) = self.scan_once(&mut want).await {
                debug!("tarama hatası: {e}");
                tokio::time::sleep(Duration::from_secs(5)).await;
            }
        }
    }

    async fn scan_once(&self, want: &mut watch::Receiver<bool>) -> Result<()> {
        self.adapter
            .set_discovery_filter(DiscoveryFilter {
                transport: DiscoveryTransport::Le,
                duplicate_data: true,
                ..Default::default()
            })
            .await?;
        let mut stream = self.adapter.discover_devices_with_changes().await?;
        debug!("kutu taraması başladı");
        let mut lid_open = false;
        loop {
            tokio::select! {
                _ = want.changed() => {
                    if !*want.borrow() { debug!("kutu taraması durdu"); return Ok(()); }
                }
                ev = stream.next() => {
                    let Some(AdapterEvent::DeviceAdded(a)) = ev else {
                        if ev.is_none() { return Ok(()); }
                        continue;
                    };
                    let Some(adv) = self.advert(a).await else { continue };
                    let opened = adv.lid_open && !lid_open;
                    lid_open = adv.lid_open;
                    {
                        let mut g = self.inner.lock().await;
                        if g.state.connected { continue; }
                        g.state.battery.left = Cell { level: adv.left, charging: adv.left_charging };
                        g.state.battery.right = Cell { level: adv.right, charging: adv.right_charging };
                        g.state.battery.case_ = Cell { level: adv.case_, charging: adv.case_charging };
                    }
                    self.changed();
                    if opened {
                        info!("kutu açıldı");
                        let _ = self.events.send(Event::CaseOpened(adv));
                        self.popup().await;
                    }
                }
            }
        }
    }

    async fn advert(&self, a: Address) -> Option<Advert> {
        let d = self.adapter.device(a).ok()?;
        let rssi = d.rssi().await.ok()??;
        let data = d.manufacturer_data().await.ok()??;
        let raw = data.get(&(APPLE as u16))?;
        let (irk, enc, model) = {
            let g = self.inner.lock().await;
            (Config::key16(&g.config.irk), Config::key16(&g.config.enc_key), g.state.model_id)
        };
        let ours = match irk {
            Some(k) => proximity::rpa_matches(a.0, &k),
            None => rssi > -60,
        };
        if !ours {
            return None;
        }
        let adv = proximity::parse(raw, enc.as_ref())?;
        if model != 0 && adv.model != model {
            return None;
        }
        Some(adv)
    }
}

fn in_ear(p: &Pod) -> u8 {
    (*p == Pod::Ear) as u8
}

fn is_headphone(product: u16) -> bool {
    // AirPods ve Beats ürün kimlikleri 0x20xx aralığında
    product & 0xff00 == 0x2000
}
