"""Sticker images for the garage (512 px, transparent): python make_stickers.py out/stickers"""

import math
import os
import sys

from PIL import Image, ImageDraw, ImageFont

out = sys.argv[1]
os.makedirs(out, exist_ok=True)
S = 512
OUT = (24, 22, 30, 255)


def canvas():
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    return im, ImageDraw.Draw(im)


def font(size):
    for name in ("arialbd.ttf", "Arial Bold.ttf", "DejaVuSans-Bold.ttf"):
        try:
            return ImageFont.truetype(name, size)
        except OSError:
            pass
    return ImageFont.load_default()


def star(cx, cy, r1, r2, n=5, rot=-90):
    pts = []
    for i in range(n * 2):
        r = r1 if i % 2 == 0 else r2
        a = math.radians(rot + i * 180 / n)
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


def save(im, name):
    im.save(os.path.join(out, name + ".png"))


im, d = canvas()
d.ellipse((40, 40, 472, 472), fill=(250, 250, 250, 255), outline=OUT, width=24)
f = font(360)
d.text((S / 2, S / 2 + 10), "7", font=f, fill=(220, 40, 40, 255), anchor="mm", stroke_width=10, stroke_fill=OUT)
save(im, "Number7")

im, d = canvas()
d.polygon(star(256, 270, 240, 100), fill=(255, 210, 50, 255), outline=OUT, width=18)
save(im, "Star")

im, d = canvas()
d.polygon([(300, 20), (110, 290), (240, 290), (190, 492), (402, 200), (270, 200), (340, 20)], fill=(255, 220, 40, 255), outline=OUT, width=18)
save(im, "Bolt")

im, d = canvas()
for i, (x, h, c) in enumerate([(90, 300, (255, 90, 30)), (190, 420, (255, 60, 20)), (300, 360, (255, 120, 30)), (400, 260, (255, 90, 30))]):
    d.polygon([(x - 80, 480), (x + 80, 480), (x + 30, 480 - h * 0.55), (x + 50, 480 - h), (x - 10, 480 - h * 0.6), (x - 40, 480 - h * 0.85), (x - 60, 480 - h * 0.4)], fill=c + (255,), outline=OUT, width=14)
    d.polygon([(x - 40, 480), (x + 40, 480), (x + 10, 480 - h * 0.45), (x - 20, 480 - h * 0.3)], fill=(255, 220, 60, 255))
save(im, "Flames")

im, d = canvas()
d.ellipse((50, 90, 270, 310), fill=(230, 40, 70, 255), outline=OUT, width=18)
d.ellipse((242, 90, 462, 310), fill=(230, 40, 70, 255), outline=OUT, width=18)
d.polygon([(62, 230), (450, 230), (256, 470)], fill=(230, 40, 70, 255), outline=OUT, width=18)
d.rectangle((90, 180, 420, 250), fill=(230, 40, 70, 255))
d.ellipse((120, 140, 190, 200), fill=(255, 160, 180, 255))
save(im, "Heart")

im, d = canvas()
d.ellipse((76, 40, 436, 380), fill=(245, 245, 235, 255), outline=OUT, width=18)
d.rounded_rectangle((150, 300, 362, 470), 30, fill=(245, 245, 235, 255), outline=OUT, width=18)
d.ellipse((140, 160, 240, 270), fill=OUT)
d.ellipse((272, 160, 372, 270), fill=OUT)
d.polygon([(256, 280), (230, 330), (282, 330)], fill=OUT)
for x in (200, 256, 312):
    d.line((x, 400, x, 470), fill=OUT, width=12)
save(im, "Skull")

im, d = canvas()
n = 5
cell = 440 // n
for r in range(n):
    for c in range(n):
        color = (20, 20, 24, 255) if (r + c) % 2 == 0 else (250, 250, 250, 255)
        d.rectangle((36 + c * cell, 36 + r * cell, 36 + (c + 1) * cell, 36 + (r + 1) * cell), fill=color)
d.rectangle((36, 36, 36 + n * cell, 36 + n * cell), outline=OUT, width=14)
save(im, "Checker")

im, d = canvas()
d.polygon([(60, 400), (60, 140), (160, 260), (256, 90), (352, 260), (452, 140), (452, 400)], fill=(255, 200, 50, 255), outline=OUT, width=18)
d.rectangle((60, 380, 452, 450), fill=(255, 200, 50, 255), outline=OUT, width=18)
for x, c in ((140, (230, 40, 60)), (256, (60, 140, 255)), (372, (40, 200, 90))):
    d.ellipse((x - 26, 389, x + 26, 441), fill=c + (255,), outline=OUT, width=8)
save(im, "Crown")
print("stickers", len(os.listdir(out)))
