"""Shop icons from the kit renders: crop to the object, square, dark outline + soft shadow, 512 px.

Usage: python make_icons.py out/icons_raw out/icons   (also writes out/icons_sheet.png to check them side by side)
"""

import glob
import os
import sys

from PIL import Image, ImageDraw, ImageFilter

src, dst = sys.argv[1], sys.argv[2]
os.makedirs(dst, exist_ok=True)
for f in sorted(glob.glob(os.path.join(src, "*.png"))):
    im = Image.open(f).convert("RGBA")
    bbox = im.getchannel("A").point(lambda a: 255 if a > 10 else 0).getbbox()
    im = im.crop(bbox)
    side = int(max(im.size) * 1.18)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(im, ((side - im.width) // 2, (side - im.height) // 2), im)
    canvas = canvas.resize((512, 512), Image.LANCZOS)
    alpha = canvas.getchannel("A")
    outline = alpha.filter(ImageFilter.MaxFilter(11))
    shadow = outline.filter(ImageFilter.GaussianBlur(8))
    out = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    sh = Image.new("RGBA", (512, 512), (0, 0, 0, 0))
    sh.putalpha(shadow.point(lambda a: int(a * 0.45)))
    out.alpha_composite(sh, (0, 8))
    ol = Image.new("RGBA", (512, 512), (24, 22, 30, 255))
    ol.putalpha(outline)
    out.alpha_composite(ol)
    out.alpha_composite(canvas)
    out.save(os.path.join(dst, os.path.basename(f)))

files = sorted(glob.glob(os.path.join(dst, "*.png")))
sheet = Image.new("RGB", (200 * len(files), 220), (52, 58, 74))
draw = ImageDraw.Draw(sheet)
for i, f in enumerate(files):
    icon = Image.open(f).resize((180, 180))
    sheet.paste(icon, (i * 200 + 10, 30), icon)
    draw.text((i * 200 + 8, 6), os.path.basename(f)[:-4], fill=(255, 255, 255))
sheet.save(os.path.join(os.path.dirname(dst.rstrip("/\\")) or ".", "icons_sheet.png"))
print(f"{len(files)} icons")
