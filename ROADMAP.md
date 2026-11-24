# Roadmap

What's planned, roughly in order. If you want to pick something up, open an issue first so we don't do the same work twice.

## Linux

- [ ] Publish to Flathub and the AUR
- [ ] Prebuilt release builds for x86_64 and aarch64
- [ ] Reports from models other than AirPods Pro 2, starting with Pro 3, AirPods 4 and Max
- [ ] Headphone accommodation and custom transparency, once the buds can be made to report them back
- [ ] Choosing which bud's mic is used, and turning off ear detection
- [ ] The live ambient noise level, if it turns out to be in the protocol
- [ ] More accurate head tracking direction for spatial audio
- [ ] Finding the buds while they are disconnected on setups where the case advert doesn't arrive
- [ ] More languages

## Windows

Windows doesn't let a normal app open the kind of Bluetooth channel AirPods use for settings, so this comes in two steps.

- [ ] Battery, case and in-ear status from the BLE adverts, which Windows does allow without a driver. The Qt app and `crates/core` carry over as they are; only a small Windows service is new.
- [ ] Full control. The options are a signed kernel driver, or a small dedicated USB Bluetooth adapter driven by a user space stack so no driver is needed. Both need research before picking one.
- [ ] Installer, tray and start with Windows

## Android

- [ ] Battery, case and in-ear status from the BLE adverts, which needs no root
- [ ] Full control where the phone allows it. Some Android versions let apps open the channel directly; for the rest the options are root, an Xposed module, or a Shizuku based helper, and that needs research.
- [ ] Quick settings tile and a home screen widget for the battery

## Shared

- [ ] Keep `crates/core` free of OS code so every platform uses the same protocol code
- [ ] A small C or Kotlin binding for it, so the Android app doesn't have to reimplement the protocol
