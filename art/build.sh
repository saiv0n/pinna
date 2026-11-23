#!/usr/bin/env bash
# Görselleri baştan üretir: render, kırpma, ikon.
# Kullanım: art/build.sh <Airpods_ForSketchfab.fbx> [örnek sayısı]
set -euo pipefail
cd "$(dirname "$0")/.."
fbx="$1"
samples="${2:-512}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

blender -b -P art/render.py -- "$fbx" "$tmp" "$samples" all

python3 - "$tmp" app/assets <<'PY'
import sys
from PIL import Image
src, dst = sys.argv[1], sys.argv[2]

def crop(im, margin=0.04):
    box = im.getchannel("A").point(lambda a: 255 if a > 6 else 0).getbbox()
    im = im.crop(box)
    m = int(max(im.size) * margin)
    out = Image.new("RGBA", (im.width + 2 * m, im.height + 2 * m), (0, 0, 0, 0))
    out.alpha_composite(im, (m, m))
    return out

# render sağ kulaklığı çiziyor, uygulama soldakini bekliyor
bud = crop(Image.open(f"{src}/bud.png").convert("RGBA")).transpose(Image.FLIP_LEFT_RIGHT)
bud.thumbnail((700, 900), Image.LANCZOS)
bud.save(f"{dst}/bud.png", optimize=True)
pair = crop(Image.open(f"{src}/set.png").convert("RGBA"))
pair.thumbnail((1100, 900), Image.LANCZOS)
pair.save(f"{dst}/set.png", optimize=True)
print("görseller yazıldı")
PY

python3 art/icon.py app/assets/bud.png dist/icon.png
