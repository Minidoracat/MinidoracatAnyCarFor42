"""補胎劑（Tire Sealant）：PIL 畫貼圖 → Blender 建模匯出 FBX＋渲染 → 32x32 物品圖示＋預覽。

用法（repo 根目錄）：python scripts/blender/tire_sealant/build.py [--blender <blender.exe>]
產物：
    MOD/.../42/media/textures/WorldItems/MinidoracatAnyCar_TireSealant.png（256x256 atlas）
    MOD/.../42/media/models_X/WorldItems/MinidoracatAnyCar_TireSealant.fbx
    MOD/.../42/media/textures/Item_MinidoracatAnyCar_TireSealant.png（32x32）
    temp/tire-sealant/preview-*.png、renders/（人看的，不進 MOD）
字型：Barlow（SIL OFL 1.1，github.com/jpt/barlow），授權全文 scripts/blender/fonts/OFL-Barlow.txt；字只烘進貼圖。
"""
import argparse
import os
import math
import subprocess
import sys

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
OUT = os.path.join(REPO, "temp", "tire-sealant")  # 預覽與中間產物
MEDIA = os.path.join(REPO, "MOD", "MinidoracatAnyCarFor42", "Contents", "mods", "MinidoracatAnyCarFor42", "42", "media")
NAME = "MinidoracatAnyCar_TireSealant"
FONTS = os.path.join(os.path.dirname(HERE), "fonts")
FONT_BOLD = os.path.join(FONTS, "Barlow-SemiBold.ttf")
FONT_MED = os.path.join(FONTS, "Barlow-Medium.ttf")

# 貼圖格局（256 px，左上原點）；build_model.py 的 UV 用同一份數字
TEX = 256
LABEL = (0, 0, 256, 160)          # 罐身一圈（周長 0.176 m × 高 0.112 m）
SW_Y, SW = 176, 32                 # 單色色塊列：y=176..208，每塊 32 px
SWATCH = {"dome": 0, "cap": 32, "hose": 64, "brass": 96, "bottom": 128, "nozzle": 160}
SWATCH2_Y = 216                    # 第二列：罐身主色（給底部斜邊）
COL = {
    "body": "#f07a12", "band": "#17181b", "stripe": "#ffd21f", "white": "#f6f4ee",
    "dome": "#b4b8bd", "cap": "#1f2023", "hose": "#141416", "brass": "#c99a3a",
    "bottom": "#8d9298", "nozzle": "#e8e6e0",
}
SS = 4


def font(path, px):
    return ImageFont.truetype(path, max(1, int(round(px))))


def tire(d, cx, cy, r, ink, bg):
    """側視輪胎圖形：外胎＋胎紋缺口＋輪圈＋5 個螺帽。"""
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=ink)
    for k in range(16):  # 胎紋：外緣的小缺口
        a = 2 * math.pi * k / 16
        x, y = cx + math.cos(a) * r * 0.93, cy + math.sin(a) * r * 0.93
        d.ellipse([x - r * 0.07, y - r * 0.07, x + r * 0.07, y + r * 0.07], fill=bg)
    d.ellipse([cx - r * 0.55, cy - r * 0.55, cx + r * 0.55, cy + r * 0.55], fill=bg)
    d.ellipse([cx - r * 0.42, cy - r * 0.42, cx + r * 0.42, cy + r * 0.42], fill=ink)
    d.ellipse([cx - r * 0.13, cy - r * 0.13, cx + r * 0.13, cy + r * 0.13], fill=bg)
    for k in range(5):
        a = 2 * math.pi * k / 5 - math.pi / 2
        x, y = cx + math.cos(a) * r * 0.27, cy + math.sin(a) * r * 0.27
        d.ellipse([x - r * 0.05, y - r * 0.05, x + r * 0.05, y + r * 0.05], fill=bg)


def texture(path):
    W = TEX * SS
    im = Image.new("RGB", (W, W), COL["body"])
    d = ImageDraw.Draw(im)
    x0, y0, x1, y1 = (v * SS for v in LABEL)
    h = y1 - y0
    # 罐身由下往上：底部黑帶、主色、黃色斜條帶、黑色字帶、主色、頂部黑細條
    d.rectangle([x0, y1 - h * 0.08, x1, y1], fill=COL["band"])
    d.rectangle([x0, y0 + h * 0.36, x1, y0 + h * 0.62], fill=COL["band"])
    d.rectangle([x0, y0 + h * 0.66, x1, y0 + h * 0.74], fill=COL["stripe"])
    d.rectangle([x0, y0, x1, y0 + h * 0.05], fill=COL["band"])
    # 正面圖案重複兩次（u=0.25、0.75），任何角度都看得到一組
    for cu in (0.25, 0.75):
        cx = x0 + (x1 - x0) * cu
        d.text((cx, y0 + h * 0.425), "TIRE", font=font(FONT_BOLD, h * 0.125), fill=COL["white"], anchor="mm")
        d.text((cx, y0 + h * 0.555), "SEALANT", font=font(FONT_BOLD, h * 0.125), fill=COL["white"], anchor="mm")
        tire(d, cx, y0 + h * 0.215, h * 0.135, COL["band"], COL["body"])
        d.text((cx, y0 + h * 0.83), "INFLATES & SEALS", font=font(FONT_MED, h * 0.085), fill=COL["band"], anchor="mm")
    for name, sx in SWATCH.items():
        d.rectangle([sx * SS, SW_Y * SS, (sx + SW) * SS - 1, (SW_Y + SW) * SS - 1], fill=COL[name])
    d.rectangle([0, SWATCH2_Y * SS, SW * SS - 1, (SWATCH2_Y + SW) * SS - 1], fill=COL["band"])
    im.resize((TEX, TEX), Image.LANCZOS).save(path)


def icon(src, dst):
    """原版物品圖示風格：32x32 透明底、物體約 28px、1px 深色外框（對照 UI2.pack 的 Item_SprayPaint）。"""
    im = Image.open(src).convert("RGBA")
    im = im.crop(im.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox())
    s = 28.0 / max(im.size)
    im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
    a = im.getchannel("A").point(lambda v: 255 if v > 110 else 0)
    im = ImageEnhance.Sharpness(ImageEnhance.Color(ImageEnhance.Contrast(im.convert("RGB")).enhance(1.25)).enhance(1.2)).enhance(1.4)
    im.putalpha(a)
    canvas = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    canvas.paste(im, ((32 - im.width) // 2, (32 - im.height) // 2), im)
    mask = canvas.getchannel("A")
    out = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    out.paste(Image.new("RGBA", (32, 32), (28, 26, 24, 255)), (0, 0), mask.filter(ImageFilter.MaxFilter(3)))
    out.paste(canvas, (0, 0), mask)
    out.save(dst)


def preview_icon(dst):
    """自己的圖示和原版 Item_SprayPaint／Item_Hairspray／Item_TirePump 並排，各放大 8 倍。"""
    sys.path.insert(0, HERE)
    from pzfmt import read_pack
    pack = r"D:/SteamLibrary/steamapps/common/ProjectZomboid/media/texturepacks/UI2.pack"
    want = ["Item_SprayPaint", "Item_Hairspray", "Item_TirePump"]
    found = {}
    for p in read_pack(open(pack, "rb").read()):
        for n, x, y, w, h, ox, oy, fx, fy in p["entries"]:
            if n in want:
                c = Image.new("RGBA", (fx, fy))
                c.paste(p["image"].crop((x, y, x + w, y + h)), (ox, oy))
                found[n] = c
    ims = [Image.open(os.path.join(MEDIA, "textures", f"Item_{NAME}.png")).convert("RGBA")] + [found[n] for n in want]
    k = 8
    sheet = Image.new("RGBA", (len(ims) * (32 * k + 16) + 16, 32 * k + 32), (78, 82, 78, 255))
    for i, c in enumerate(ims):
        big = c.resize((32 * k, 32 * k), Image.NEAREST)
        sheet.paste(big, (16 + i * (32 * k + 16), 16), big)
    sheet.save(dst)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--blender", default=r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe")
    a = ap.parse_args()
    for sub in (("textures", "WorldItems"), ("models_X", "WorldItems")):
        os.makedirs(os.path.join(MEDIA, *sub), exist_ok=True)
    texture(os.path.join(MEDIA, "textures", "WorldItems", NAME + ".png"))
    renders = os.path.join(OUT, "renders")
    os.makedirs(renders, exist_ok=True)
    cmd = [a.blender, "--background", "--factory-startup", "--python", os.path.join(HERE, "build_model.py"), "--", MEDIA, renders, OUT]
    r = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    sys.stdout.write("\n".join(l for l in r.stdout.splitlines() if l.startswith(("VERIFY", "exported", "BUILD"))) + "\n")
    if r.returncode != 0 or "BUILD OK" not in r.stdout:
        sys.stdout.write(r.stdout[-4000:] + r.stderr[-4000:])
        sys.exit("blender build failed")
    icon(os.path.join(renders, "icon.png"), os.path.join(MEDIA, "textures", f"Item_{NAME}.png"))
    preview_icon(os.path.join(OUT, "preview-icon.png"))
    print("build ok ->", MEDIA)


if __name__ == "__main__":
    main()
