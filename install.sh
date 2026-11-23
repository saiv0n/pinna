#!/usr/bin/env bash
# Earshot'u derleyip kullanıcı dizinine kurar. sudo gerekmez.
set -euo pipefail
cd "$(dirname "$0")"

prefix="${PREFIX:-$HOME/.local}"

echo "Rust servisi derleniyor"
cargo build --release

echo "Arayüz derleniyor"
cmake -S app -B app/build -G Ninja -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build app/build

install -Dm755 target/release/earshotd "$prefix/bin/earshotd"
install -Dm755 target/release/earshotctl "$prefix/bin/earshotctl"
install -Dm755 app/build/earshot "$prefix/bin/earshot"
install -Dm644 dist/dev.earshot.Earshot.desktop "$prefix/share/applications/dev.earshot.Earshot.desktop"
install -Dm644 dist/icon.png "$prefix/share/icons/hicolor/512x512/apps/dev.earshot.Earshot.png"
install -Dm644 dist/earshotd.service "$HOME/.config/systemd/user/earshotd.service"
# arayüz ya da earshotctl servisi çağırınca kendiliğinden başlasın
install -Dm644 dist/dev.earshot.Daemon.service "$prefix/share/dbus-1/services/dev.earshot.Daemon.service"

systemctl --user daemon-reload
systemctl --user enable --now earshotd.service
systemctl --user restart earshotd.service

echo "Kuruldu. Uygulama menüsünden Earshot'u açabilirsin."
if ! grep -qi "^DeviceID *= *bluetooth:004C" /etc/bluetooth/main.conf 2>/dev/null; then
    echo
    echo "İsteğe bağlı: bazı Apple özellikleri için /etc/bluetooth/main.conf içine"
    echo "  DeviceID = bluetooth:004C:0000:0000"
    echo "satırını ekleyip 'sudo systemctl restart bluetooth' çalıştırabilirsin."
fi
