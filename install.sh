#!/usr/bin/env bash
# Builds Pinna and installs it into the user directory. No sudo needed.
set -euo pipefail
cd "$(dirname "$0")"

prefix="${PREFIX:-$HOME/.local}"

echo "Building the Rust service"
cargo build --release

echo "Building the app"
# the translation needs lrelease; without it the app is English only
cmake -S app -B app/build -G Ninja -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build app/build

install -Dm755 target/release/pinnad "$prefix/bin/pinnad"
install -Dm755 target/release/pinnactl "$prefix/bin/pinnactl"
install -Dm755 app/build/pinna "$prefix/bin/pinna"
install -Dm644 dist/dev.pinna.Pinna.desktop "$prefix/share/applications/dev.pinna.Pinna.desktop"
# the card has its own class, let the portal know it too
install -Dm644 dist/dev.pinna.Popup.desktop "$prefix/share/applications/dev.pinna.Popup.desktop"
install -Dm644 dist/icon.png "$prefix/share/icons/hicolor/512x512/apps/dev.pinna.Pinna.png"
install -Dm644 dist/pinnad.service "$HOME/.config/systemd/user/pinnad.service"
# start on demand when the app or pinnactl calls the service
install -Dm644 dist/dev.pinna.Daemon.service "$prefix/share/dbus-1/services/dev.pinna.Daemon.service"

# BLE keys live here, keep them private
mkdir -p "$HOME/.config/pinna" "$HOME/.local/state/pinna" "$HOME/.config/wireplumber/wireplumber.conf.d"
chmod 700 "$HOME/.config/pinna" "$HOME/.local/state/pinna"

systemctl --user daemon-reload
systemctl --user enable --now pinnad.service
systemctl --user restart pinnad.service
# do not mix an old running app with the new build
pkill -x pinna || true

echo "Installed. Open Pinna from your app menu."
if ! grep -qi "^DeviceID *= *bluetooth:004C" /etc/bluetooth/main.conf 2>/dev/null; then
    echo
    echo "Optional: some Apple features need the DeviceID setting under"
    echo "This Computer > Bluetooth."
fi
