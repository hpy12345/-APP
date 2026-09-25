# -*- coding: utf-8 -*-
"""生成「记账本」启动图标：朱砂方章 + 描金边 + 宋体「记」字。

产物：
- mipmap-{mdpi..xxxhdpi}/ic_launcher.png            完整方图（旧 API）
- mipmap-{mdpi..xxxhdpi}/ic_launcher_foreground.png 自适应图标前景（透明底，内容居中 66% 安全区）
"""
import os
from PIL import Image, ImageDraw, ImageFont

RES = r"F:\手机记账APP\android_app\android\app\src\main\res"
FONT_CANDIDATES = [
    r"C:\Windows\Fonts\simsun.ttc",   # 中易宋体
    r"C:\Windows\Fonts\msyh.ttc",     # 微软雅黑（兜底）
]

# 调色（与 App Palette 一致）
CINNABAR_TOP = (184, 84, 74)    # #B8544A
CINNABAR_MID = (158, 64, 52)    # #9E4034
CINNABAR_BOT = (127, 47, 38)    # #7F2F26
GOLD = (216, 189, 138)          # 描金 #D8BD8A
GOLD_TEXT = (239, 226, 200)     # #EFE2C8


def load_font(px):
    for path in FONT_CANDIDATES:
        if os.path.exists(path):
            try:
                return ImageFont.truetype(path, px)
            except Exception:
                continue
    return ImageFont.load_default()


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def seal(size, radius_ratio=0.22, pad_ratio=0.0):
    """朱砂方章（径向渐变 + 金边 + 「记」）。pad_ratio 为内容留白比例。"""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    pad = round(size * pad_ratio)
    inner = size - pad * 2

    # 径向渐变底（中心偏左上）
    grad = Image.new("RGB", (inner, inner))
    gpx = grad.load()
    cx, cy = inner * 0.38, inner * 0.28
    maxd = (inner ** 2 + inner ** 2) ** 0.5 * 0.72
    for y in range(inner):
        for x in range(inner):
            d = ((x - cx) ** 2 + (y - cy) ** 2) ** 0.5 / maxd
            t = min(1.0, d)
            if t < 0.55:
                c = lerp(CINNABAR_TOP, CINNABAR_MID, t / 0.55)
            else:
                c = lerp(CINNABAR_MID, CINNABAR_BOT, (t - 0.55) / 0.45)
            gpx[x, y] = c

    # 圆角蒙版
    mask = Image.new("L", (inner, inner), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([0, 0, inner - 1, inner - 1],
                         radius=round(inner * radius_ratio), fill=255)
    img.paste(grad, (pad, pad), mask)

    # 描金边框（内描）
    d = ImageDraw.Draw(img)
    bw = max(2, round(inner * 0.028))
    d.rounded_rectangle(
        [pad + bw, pad + bw, pad + inner - bw - 1, pad + inner - bw - 1],
        radius=round(inner * radius_ratio * 0.86),
        outline=GOLD + (235,), width=bw)

    # 「记」字
    font = load_font(round(inner * 0.52))
    bbox = d.textbbox((0, 0), "记", font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    d.text((pad + (inner - tw) / 2 - bbox[0], pad + (inner - th) / 2 - bbox[1]),
           "记", font=font, fill=GOLD_TEXT + (255,))
    return img


DENSITIES = {
    "mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192,
}
FG_SCALE = 4.5  # foreground: 108dp → mdpi 108px；相对 launcher 的 48px 是 2.25x
FG_PAD = 0.17   # adaptive icon 安全区：内容缩到中间 ~66%

for name, px in DENSITIES.items():
    outdir = os.path.join(RES, f"mipmap-{name}")
    os.makedirs(outdir, exist_ok=True)
    seal(px).save(os.path.join(outdir, "ic_launcher.png"))
    fg_px = round(px * (108 / 48))
    seal(fg_px, pad_ratio=FG_PAD).save(
        os.path.join(outdir, "ic_launcher_foreground.png"))
    print(f"{name}: launcher {px}px / foreground {fg_px}px")

os.makedirs(os.path.join(RES, "mipmap-anydpi-v26"), exist_ok=True)
print("done")
