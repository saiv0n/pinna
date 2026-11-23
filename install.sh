#!/usr/bin/env bash
# Pinna'yı derleyip kullanıcı dizinine kurar. sudo gerekmez.
set -euo pipefail
cd "$(dirname "$0")"

prefix="${PREFIX:-$HOME/.local}"

echo "Rust servisi derleniyor"
cargo build --release

echo "Arayüz derleniyor"
cmake -S app -B app/build -G Ninja -DCMAKE_BUILD_TYPE=Release >/dev/null
cmake --build app/build

install -Dm755 target/release/pinnad "$prefix/bin/pinnad"
install -Dm755 target/release/pinnactl "$prefix/bin/pinnactl"
install -Dm755 app/build/pinna "$prefix/bin/pinna"
install -Dm644 dist/dev.pinna.Pinna.desktop "$prefix/share/applications/dev.pinna.Pinna.desktop"
install -Dm644 dist/icon.png "$prefix/share/icons/hicolor/512x512/apps/dev.pinna.Pinna.png"
install -Dm644 dist/pinnad.service "$HOME/.config/systemd/user/pinnad.service"
# arayüz ya da pinnactl servisi çağırınca kendiliğinden başlasın
install -Dm644 dist/dev.pinna.Daemon.service "$prefix/share/dbus-1/services/dev.pinna.Daemon.service"

systemctl --user daemon-reload
systemctl --user enable --now pinnad.service
systemctl --user restart pinnad.service

echo "Kuruldu. Uygulama menüsünden Pinna'yı açabilirsin."
if ! grep -qi "^DeviceID *= *bluetooth:004C" /etc/bluetooth/main.conf 2>/dev/null; then
    echo
    echo "İsteğe bağlı: bazı Apple özellikleri için /etc/bluetooth/main.conf içine"
    echo "  DeviceID = bluetooth:004C:0000:0000"
    echo "satırını ekleyip 'sudo systemctl restart bluetooth' çalıştırabilirsin."
fi
