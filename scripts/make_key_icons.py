# 輪盤用的配鑰匙／拆除短接圖示（64x64，照原版點火圖示：可用加綠色記號、不可用灰階加紅叉）
import math
import os
import sys
from PIL import Image, ImageDraw, ImageOps

S = 4  # 先畫 256 再縮小，邊緣平滑
OUT = sys.argv[1]
BRASS, DARK = (222, 172, 40, 255), (70, 48, 6, 255)


def key(d, ox, oy, k):
    # 鑰匙：圓頭（中間有孔）＋長柄＋兩個齒，k 是縮放
    def P(x, y): return (ox + x * k, oy + y * k)
    r = 30 * k
    cx, cy = P(0, 0)
    d.ellipse([cx - r - 6, cy - r - 6, cx + r + 6, cy + r + 6], fill=DARK)
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=BRASS)
    h = 11 * k
    d.ellipse([cx - h, cy - h, cx + h, cy + h], fill=(0, 0, 0, 0))
    for poly in ([P(24, -9), P(120, -9), P(120, 9), P(24, 9)],
                 [P(80, 9), P(92, 9), P(92, 30), P(80, 30)],
                 [P(102, 9), P(116, 9), P(116, 24), P(102, 24)]):
        d.polygon(poly, fill=BRASS, outline=DARK, width=int(5 * k))


def badge(d, ok):
    c, r = (196, 196), 48
    d.ellipse([c[0] - r - 6, c[1] - r - 6, c[0] + r + 6, c[1] + r + 6], fill=(20, 20, 20, 255))
    if ok:
        d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=(46, 158, 62, 255))
        d.line([(c[0] - 26, c[1]), (c[0] + 26, c[1])], fill="white", width=16)
        d.line([(c[0], c[1] - 26), (c[0], c[1] + 26)], fill="white", width=16)
    else:
        d.ellipse([c[0] - r, c[1] - r, c[0] + r, c[1] + r], fill=(200, 40, 40, 255))
        d.line([(c[0] - 22, c[1] - 22), (c[0] + 22, c[1] + 22)], fill="white", width=16)
        d.line([(c[0] - 22, c[1] + 22), (c[0] + 22, c[1] - 22)], fill="white", width=16)


def wires(d):
    # 兩條剪斷的電線（紅、黃），斷口露出銅芯
    for color, y0 in (((210, 50, 40, 255), 70), ((235, 200, 40, 255), 130)):
        left = [(20, y0 + 40), (60, y0 + 10), (100, y0)]
        right = [(150, y0 - 6), (190, y0 - 20), (236, y0 - 50)]
        for seg in (left, right):
            d.line(seg, fill=(25, 25, 25, 255), width=34, joint="curve")
            d.line(seg, fill=color, width=24, joint="curve")
        for (x, y) in (left[-1], right[0]):
            d.ellipse([x - 11, y - 11, x + 11, y + 11], fill=(200, 120, 50, 255), outline=(25, 25, 25, 255), width=4)


def make(name, draw_main, ok):
    img = Image.new("RGBA", (64 * S, 64 * S), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    draw_main(d)
    if not ok:
        rgb = ImageOps.grayscale(img.convert("RGB")).convert("RGB")
        rgb.putalpha(img.getchannel("A"))
        img = rgb
        d = ImageDraw.Draw(img)
    badge(d, ok) if (ok and name.startswith("key_make")) or not ok else None
    img.resize((64, 64), Image.LANCZOS).save(os.path.join(OUT, name + ".png"))


def make_key(d):
    k = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    key(ImageDraw.Draw(k), 52, 128, 1.45)
    k = k.rotate(35, resample=Image.BICUBIC, center=(128, 128))
    d._image.alpha_composite(k)


def unwire(d):
    wires(d)
    k = Image.new("RGBA", (256, 256), (0, 0, 0, 0))
    key(ImageDraw.Draw(k), 40, 60, 0.75)
    d._image.alpha_composite(k)


os.makedirs(OUT, exist_ok=True)
for ok in (True, False):
    suffix = "" if ok else "_off"
    make("key_make" + suffix, make_key, ok)
    make("key_unwire" + suffix, unwire, ok)
print("ok")
