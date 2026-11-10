#!/usr/bin/python3
# Adds a language badge (e.g. "EN") to the cover: langbadge.py <in> <out> <text>
import sys
from PIL import Image, ImageDraw, ImageFont, ImageFilter, ImageChops
src, out, text = sys.argv[1:4]
im = Image.open(src).convert("RGB")
W, H = im.size
s = W / 600.0
font = ImageFont.truetype("/usr/share/fonts/truetype/google-fonts/Poppins-BoldItalic.ttf", int(30 * s))
cx, cy, bw, bh = int(515 * s), int(452 * s), int(84 * s), int(46 * s)
box = (cx - bw // 2, cy - bh // 2, cx + bw // 2, cy + bh // 2)
glow = Image.new("RGB", im.size, (0, 0, 0))
ImageDraw.Draw(glow).rounded_rectangle(box, radius=int(12 * s), outline=(60, 255, 60), width=int(5 * s))
glow = glow.filter(ImageFilter.GaussianBlur(5 * s))
im = ImageChops.add(im, glow)
d = ImageDraw.Draw(im)
d.rounded_rectangle(box, radius=int(12 * s), fill=(8, 8, 20), outline=(90, 255, 90), width=int(3 * s))
bb = d.textbbox((0, 0), text, font=font)
tx = cx - (bb[2] - bb[0]) // 2 - bb[0]
ty = cy - (bb[3] - bb[1]) // 2 - bb[1]
d.text((tx, ty), text, font=font, fill=(235, 255, 235))
im.save(out, quality=92)
