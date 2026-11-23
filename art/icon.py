# Uygulama ikonunu kulaklık render'ından üretir.
# Kullanım: python3 art/icon.py app/assets/bud.png dist/icon.png
import sys
from PIL import Image, ImageChops, ImageDraw, ImageFilter

SIZE = 1024
src, out = sys.argv[1], sys.argv[2]


def squircle(size, n=5.0):
    # Apple ikonlarındaki süper elips köşe
    m = Image.new("L", (size, size), 0)
    px = m.load()
    r = size / 2
    for y in range(size):
        for x in range(size):
            dx = abs((x + 0.5 - r) / r)
            dy = abs((y + 0.5 - r) / r)
            if dx**n + dy**n <= 1:
                px[x, y] = 255
    return m


big = SIZE * 2
bg = Image.new("RGB", (big, big))
d = ImageDraw.Draw(bg)
for y in range(big):
    t = y / big
    c = int(252 - 30 * t), int(252 - 28 * t), int(254 - 22 * t)
    d.line([(0, y), (big, y)], fill=c)

bud = Image.open(src).convert("RGBA")
bbox = bud.getbbox()
if bbox:
    bud = bud.crop(bbox)
h = int(big * 0.62)
bud = bud.resize((int(bud.width * h / bud.height), h), Image.LANCZOS)
right = bud.transpose(Image.FLIP_LEFT_RIGHT)

canvas = bg.convert("RGBA")
gap = int(big * 0.015)
y = (big - h) // 2 + int(big * 0.02)
x1 = big // 2 - bud.width - gap
x2 = big // 2 + gap

shadow = Image.new("RGBA", (big, big), (0, 0, 0, 0))
for img, x in ((bud, x1), (right, x2)):
    a = img.split()[3].point(lambda v: int(v * 0.28))
    s = Image.new("RGBA", img.size, (20, 24, 32, 0))
    s.putalpha(a)
    shadow.alpha_composite(s, (x, y + int(big * 0.025)))
shadow = shadow.filter(ImageFilter.GaussianBlur(big * 0.02))
canvas.alpha_composite(shadow)
canvas.alpha_composite(bud, (x1, y))
canvas.alpha_composite(right, (x2, y))

mask = squircle(SIZE).resize((big, big), Image.LANCZOS)
canvas.putalpha(ImageChops.multiply(canvas.split()[3], mask))
canvas = canvas.resize((SIZE, SIZE), Image.LANCZOS)

# kenar boşluğu: ikon kılavuzlarındaki gibi %10
final = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
inner = int(SIZE * 0.82)
final.alpha_composite(canvas.resize((inner, inner), Image.LANCZOS), ((SIZE - inner) // 2, (SIZE - inner) // 2))
final.resize((512, 512), Image.LANCZOS).save(out)
print("yazıldı:", out)
