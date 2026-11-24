# Pinna

An AirPods manager for Linux. It connects your AirPods, shows the battery and whether they are in your ears, and lets you change almost every setting you would find on an iPhone.

![Pinna](docs/screenshot.png)

## What it does

- Shows left, right and case battery and keeps a battery chart of the last 24 hours. While the case is closed it shows the last known case level, and while the buds are away it says when they were last seen. It notifies you when the battery runs low (you pick the threshold) and when charging is done.
- Switches between noise cancellation, transparency, adaptive and off right away. In adaptive mode you can set how much outside sound gets in, from 0 to 100.
- Conversation awareness, personalized volume, noise cancellation with one AirPod, volume swipe, press speed, press and hold duration, case speaker volume, sleep detection, hearing assistance, and on models that report them Optimized Charging and Loud Sound Reduction (experimental).
- You choose which modes press and hold cycles through and what the left and right bud do. The buds forget this on every new device, so Pinna writes it again on each connection.
- Makes the buds the default output on connect, or only once you put one in. Volume and profile are in the app. The music codec is left to PipeWire (AAC on AirPods) unless you pick another one.
- Three mic choices for calls. With the computer mic or the high quality AirPods mic the buds stay in music quality (AAC). The second one is experimental: the bud mic arrives as AAC-ELD over a separate channel, Pinna decodes it into a mic named "(Pinna)" and opens it when an app starts listening. The third is the Bluetooth headset profile, where both sound and mic drop to phone quality (LC3 at 24 kHz on these buds).
- With several paired AirPods or Beats you can switch between them from the app or the tray, pair new ones and forget old ones. Each pair keeps its own keys, and the battery of the others shows up in the list and the tray tooltip when they are nearby.
- Lives in the system tray: a ring on the icon shows the lower bud, and the menu has battery, mode switching, connect and disconnect. Closing the window keeps it in the tray, and it can start in the tray when you log in.
- Pauses what is playing when you take a bud out and resumes when you put it back (any MPRIS player). Lowers the computer volume while you talk.
- A small card pops up in a corner when you open the case or the buds connect. Click it to open the app.
- Reports the headphone battery to the system through BlueZ, so UPower, GNOME, KDE and bars show it in their own battery indicators.
- While the buds are disconnected, helps you find them nearby from the signal strength of their advert, with the last two minutes of signal so you can tell if you are getting closer. There is no map of where they were last seen: the only location source on most Linux desktops is GeoClue, which sends nearby Wi-Fi networks to an online service, and Pinna keeps everything on the computer. Making them play a sound is not possible either, Apple does that through Find My.
- Can turn off conversation awareness while only one bud is in and turn it back on when both are.
- Turkish and English, and a new language is a single file (see Translations below). Follows the system language by default, and you can change it on the This Computer page.
- Shows head tracking live: the angles follow as you turn and tilt your head.
- Spatial audio (experimental): stereo sounds like it comes from two speakers in front of you, using the PipeWire HRTF filter. In head tracked mode the sound stays put when you turn your head. Needs `libmysofa` and `/usr/share/libmysofa/default.sofa`.
- Press shortcuts (experimental): bind a double, triple or long press on each bud to something on the computer, like muting the mic, volume, changing tracks, switching that bud between two modes of your choice or a command of your own. Unassigned presses do what the buds normally do.
- Head gestures (experimental): nod or shake your head a few times to play or pause, skip a track or run a command. It keeps the motion sensor on while enabled.
- Estimates how much listening time is left, and how long until full while charging, from the recent battery history. Shown in the app, the tray and `pinnactl`.
- Custom EQ (experimental) with bass, mids and treble, stored in the headphones themselves. Only shown when the model reports it.
- While the buds are away, the case scan goes part time to save power, and the "(Pinna)" mic stays in place so apps recording from it never see it vanish.

Headphone accommodation, custom transparency, mic selection and turning off ear detection are not there yet. The buds never report these values back, so I could not make sure they work. The live noise level around you, which an Apple Watch shows, is not there either: no one has found it in the protocol yet.

Tested on AirPods Pro 2 (USB-C) on x86_64. AirPods Max show one battery, and settings a model never reports (like volume swipe on AirPods 4 or adaptive mode on AirPods Max) are hidden. There is no architecture specific code, so it should build the same on aarch64 (Asahi, Raspberry Pi); the PKGBUILD lists both. Other AirPods and Beats speak the same protocol, so most settings should work, but a setting does nothing if the model does not support it.

## Install

You need Rust (1.88 or newer), Qt 6.8 or newer (Widgets, Quick, QuickControls2, DBus, Svg), CMake, Ninja, BlueZ, PipeWire (`wpctl` and `pactl`) and the FFmpeg libavcodec development package (`libavcodec-dev` on Ubuntu). Translations need `lrelease`; without it the app is English only.

```bash
./install.sh
```

The script installs everything under `~/.local` and enables the `pinnad` service with `systemctl --user`. No sudo. The service runs sandboxed: it can only write to `~/.config/pinna`, `~/.local/state/pinna`, its runtime folder and `~/.config/wireplumber/wireplumber.conf.d` for the call setting, and it has no network access. The config file that holds the BLE keys is written with 0600 permissions.

Packaging files live in `dist/`. `dist/arch/PKGBUILD` builds a `pinna-git` package for Arch; after installing it, run `systemctl --user enable --now pinnad.service`. `dist/flatpak/dev.pinna.Pinna.yml` is a Flatpak manifest on the KDE 6.11 runtime. In the Flatpak the app starts the service itself, `pinnactl` runs with `flatpak run --command=pinnactl dev.pinna.Pinna`, and the call profile setting needs `wpctl`, which the runtime lacks; volume and mic mute fall back to `pactl`. After changing `Cargo.lock`, refresh the offline crate list with `dist/flatpak/cargo-sources.py Cargo.lock > dist/flatpak/cargo-sources.json`.

Pair the buds once from your system Bluetooth settings. Pinna finds them after that.

Some features want to see an Apple device on the other end. The DeviceID setting on the This Computer page adds this line to `/etc/bluetooth/main.conf` and restarts Bluetooth. It shows the command and asks for your password first. To do it by hand:

```
DeviceID = bluetooth:004C:0000:0000
```

On Hyprland, to float the window and open the card at the top right:

```lua
hl.window_rule({ name = "pinna", match = { class = "^(dev.pinna.Pinna)$" }, float = true, center = true, size = "900 620" })
hl.window_rule({ name = "pinna-card", match = { class = "^(dev.pinna.Popup)$" }, float = true, pin = true, move = "(monitor_w-window_w-16) 16", no_initial_focus = true })
```

## Command line

```bash
pinnactl                     # status
pinnactl mode adaptive       # off, anc, transparency, adaptive
pinnactl cycle               # step through the modes
pinnactl card                # show the battery card
pinnactl set conversationAwareness on
pinnactl watch               # one JSON line per change
pinnactl waybar              # lines for a Waybar custom module
```

`pinnactl cycle` steps through the same modes as press and hold on the stem. It works well on a Hyprland shortcut:

```
bind = SUPER, A, exec, pinnactl cycle
```

On KDE, GNOME and other desktops with the global shortcuts portal, turn on Global shortcuts on the This Computer page and pick the keys in the desktop's shortcut settings. There is one for the next mode, one for each mode and one that shows the battery card.

## Waybar

`pinnactl waybar` prints a line for a custom module whenever something changes: the lower bud in the bar, every battery and the mode in the tooltip, and classes like `connected`, `disconnected`, `low`, `charging` and the mode name for styling.

```json
"custom/airpods": {
    "exec": "pinnactl waybar",
    "return-type": "json",
    "restart-interval": 5,
    "format": "󰋋 {}",
    "on-click": "pinnactl cycle",
    "on-click-right": "pinna"
}
```

## Caelestia bar

`shell/caelestia/PinnaStatus.qml` shows a headphone icon, the lowest battery and the mode in the bar. Left click changes the mode, right click opens the app. Put the file under `modules/bar/components/status/` and add a `DelegateChoice` to `StatusIcons.qml`.

## Translations

Each language is one file, `app/i18n/pinna_<code>.ts`, and it covers the app, the tray and the notifications the service sends. To start one, run `app/i18n/update.py de` (any language code), fill in the translations with Qt Linguist or a text editor, and rebuild. The new language shows up on the This Computer page by itself. Run `app/i18n/update.py` again after changing texts to add the new ones to every file.

## How it works

Three parts:

- `crates/core` is the protocol itself: packets, BLE advert parsing, the settings table. It does not depend on the OS, so Windows and Android versions can use it later.
- `crates/linux` is the `pinnad` service that talks to BlueZ, plus `pinnactl`. The service publishes its state on D-Bus as `dev.pinna.Daemon`.
- `app` is the Qt Quick interface. Source strings are English; after adding new ones, `app/i18n/update.py` updates every translation file.

To work without a headset, run a second daemon with pretend AirPods next to the real one and point the app or `pinnactl` at it:

```bash
PINNA_FAKE=1 PINNA_BUS=dev.pinna.Test XDG_CONFIG_HOME=/tmp/pinna-test XDG_STATE_HOME=/tmp/pinna-test target/release/pinnad
PINNA_BUS=dev.pinna.Test app/build/pinna
```

`PINNA_FAKE=pro3`, `max` or `airpods4` instead of `1` pretends to be that model, with the controls and battery layout it reports, so you can see which settings the app hides for it. The packets come from captures posted in LibrePods and CAPod; the parser tests in `crates/core/src/aap.rs` use the same ones with names and serials removed.

For screenshots without any daemon, `PINNA_STATE=app/fixtures/connected.json` (or `max.json`, `finding.json`) loads a fixed state, and `PINNA_SHOT=file.png` saves the window and quits.

The headphone images are rendered in Blender. The model is Jed Falcone's [AirPods Pro](https://sketchfab.com/3d-models/3f84ddc3d87a4ec0a5e5f379abfecd9c), licensed [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The model is not in the repo; download it from Sketchfab and rebuild the images with:

```bash
art/build.sh ~/Downloads/airpods-pro/source/Airpods_ForSketchfab.fbx
```

Lighting, materials and framing live in `art/render.py`. The left stem is missing in the model, so the right bud is mirrored.

Thanks to the [LibrePods](https://github.com/kavishdevar/librepods) team for their protocol work.

## License

GPL-3.0. AirPods is a trademark of Apple; Pinna has no connection to Apple.
