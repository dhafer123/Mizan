"""Turns Penny's pose artwork (docs/brand/penny/*.png, on flat magenta) into
app assets: the magenta keyed out (edges de-tinted), each pose trimmed,
scaled to the same height (wide poses fit the width instead), feet on the
same line, centred on one square canvas, saved as WebP with transparency.
See ADR 0024.

From the repo root (needs Pillow):
    python app/tool/penny/make_poses.py docs/brand/penny app/assets/penny
"""
import glob
import os
import sys

from PIL import Image

SRC, OUT = sys.argv[1], sys.argv[2]

CANVAS = 600          # px: about 200dp at 3x
MAX_H = 520           # character height
MAX_W = 560           # wide poses (friends, sleep) are limited by width
FEET = 570            # baseline for the lowest pixel


def key(img):
    """Magenta has high red and blue and low green: the more of that, the
    more transparent. Half-transparent edges lose their pink tint."""
    img = img.convert('RGBA')
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, _ = px[x, y]
            mag = min(r, b) - g
            if mag > 150:
                px[x, y] = (0, 0, 0, 0)
            elif mag >= 60:
                a = int(255 * (150 - mag) / 90)
                px[x, y] = (max(0, r - mag // 2), g, max(0, b - mag // 3), a)
    return img


os.makedirs(OUT, exist_ok=True)
for path in sorted(glob.glob(os.path.join(SRC, 'penny_*.png'))):
    name = os.path.splitext(os.path.basename(path))[0].lower()
    img = key(Image.open(path))
    bbox = img.getchannel('A').point(lambda v: 255 if v > 20 else 0).getbbox()
    pose = img.crop(bbox)
    scale = min(MAX_H / pose.height, MAX_W / pose.width)
    pose = pose.resize(
        (round(pose.width * scale), round(pose.height * scale)), Image.LANCZOS)
    canvas = Image.new('RGBA', (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.alpha_composite(pose, ((CANVAS - pose.width) // 2, FEET - pose.height))
    out = os.path.join(OUT, f'{name}.webp')
    canvas.save(out, 'WEBP', quality=88, method=6)
    print(f'{out}: {os.path.getsize(out) // 1024} KB')
