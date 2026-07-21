#!/usr/bin/env python3
"""
generate_tv_assets.py
Gera automaticamente os assets de TV (Android TV banner + Roku icons)
usando o logo e nome do revendedor.

Variáveis de ambiente usadas:
  APP_NAME        - Nome do app (ex: "PRIME TV")
  APP_LOGO_URL    - URL do logo do revendedor (PNG/JPG, preferencialmente fundo transparente)
  PRIMARY_COLOR   - Cor principal hex (ex: "#D4AF37")
  BG_COLOR        - Cor de fundo hex (ex: "#0a0a0a"), padrão: #0a0a0a
"""

import os, sys, urllib.request, io, math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

APP_NAME      = os.environ.get("APP_NAME", "PRIME TV")
APP_LOGO_URL  = os.environ.get("APP_LOGO_URL", "")
PRIMARY_COLOR = os.environ.get("PRIMARY_COLOR", "#D4AF37")
BG_COLOR      = os.environ.get("BG_COLOR", "#0a0a0a")

def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

PRIMARY_RGB = hex_to_rgb(PRIMARY_COLOR)
BG_RGB      = hex_to_rgb(BG_COLOR)

def load_logo(url, size):
    if not url:
        return None
    try:
        print(f"  Baixando logo: {url}")
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=15) as r:
            data = r.read()
        logo = Image.open(io.BytesIO(data)).convert("RGBA")
        logo.thumbnail((size, size), Image.LANCZOS)
        return logo
    except Exception as e:
        print(f"  ⚠️  Não foi possível baixar logo: {e}")
        return None

def draw_tv_icon(draw, cx, cy, size, color):
    tx, ty = cx - int(size*0.45), cy - int(size*0.38)
    tw, th = int(size*0.9), int(size*0.6)
    draw.rounded_rectangle([tx, ty, tx+tw, ty+th], radius=max(3, size//15), fill=color)
    draw.rounded_rectangle([tx+4, ty+4, tx+tw-4, ty+th-4], radius=max(2, size//20),
                           fill=BG_RGB + (255,) if isinstance(BG_RGB, tuple) and len(BG_RGB)==3 else BG_RGB)
    pts = [(cx-size//8, cy-size//10), (cx-size//8, cy+size//10), (cx+size//8, cy-size//50)]
    draw.polygon(pts, fill=color)
    draw.rectangle([cx-size//25, ty+th, cx+size//25, ty+th+size//8], fill=color)
    draw.rectangle([cx-size//6, ty+th+size//8, cx+size//6, ty+th+size//7], fill=color)

def generate_android_banner(out_path):
    W, H = 320, 180
    img = Image.new("RGB", (W, H), BG_RGB)
    draw = ImageDraw.Draw(img)

    for i in range(W):
        factor = 1 + (i / W) * 0.12
        c = tuple(min(255, int(v * factor)) for v in BG_RGB)
        draw.rectangle([i, 0, i+1, H], fill=c)

    logo_area_size = 120
    cx, cy = 80, 90
    logo = load_logo(APP_LOGO_URL, logo_area_size)

    if logo:
        lw, lh = logo.size
        img.paste(logo, (cx - lw//2, cy - lh//2), logo)
    else:
        tv_img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        tv_draw = ImageDraw.Draw(tv_img)
        r = 62
        tv_draw.ellipse([cx-r-3, cy-r-3, cx+r+3, cy+r+3], fill=tuple(int(v*0.6) for v in PRIMARY_RGB))
        tv_draw.ellipse([cx-r, cy-r, cx+r, cy+r], fill=BG_RGB)
        draw_tv_icon(tv_draw, cx, cy, 90, PRIMARY_RGB)
        img = Image.alpha_composite(img.convert("RGBA"), tv_img).convert("RGB")
        draw = ImageDraw.Draw(img)

    area_x = 160
    center_x = area_x + (W - area_x) // 2

    try:
        font_name = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 34)
    except:
        font_name = ImageFont.load_default()

    words = APP_NAME.strip().split()
    if len(words) >= 2:
        line1 = " ".join(words[:-1])
        line2 = words[-1]
    else:
        line1 = APP_NAME
        line2 = ""

    def text_w(t, f):
        b = f.getbbox(t)
        return b[2] - b[0]

    lh_px = 42
    lines = [line1, line2] if line2 else [line1]
    total = lh_px * len(lines)
    y = (H - total) // 2

    for line in lines:
        x = center_x - text_w(line, font_name) // 2
        draw.text((x, y), line, font=font_name, fill=PRIMARY_RGB)
        y += lh_px

    draw.rectangle([0, 0, W, 3], fill=PRIMARY_RGB)
    draw.rectangle([0, H-3, W, H], fill=PRIMARY_RGB)

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    img.save(out_path)
    print(f"  ✅ Android TV banner → {out_path}")

def generate_roku_icon(out_path, w, h, logo_size):
    img = Image.new("RGBA", (w, h), BG_RGB + (255,))
    draw = ImageDraw.Draw(img)

    for i in range(w):
        factor = 1 + (i / w) * 0.15
        c = tuple(min(255, int(v * factor)) for v in BG_RGB) + (255,)
        draw.rectangle([i, 0, i+1, h], fill=c)

    cx, cy = w // 2, h // 2
    logo = load_logo(APP_LOGO_URL, logo_size)

    if logo:
        lw, lh_l = logo.size
        img.paste(logo, (cx - lw//2, cy - lh_l//2), logo)
    else:
        r = logo_size // 2
        draw.ellipse([cx-r-2, cy-r-2, cx+r+2, cy+r+2], fill=tuple(int(v*0.6) for v in PRIMARY_RGB) + (255,))
        draw.ellipse([cx-r, cy-r, cx+r, cy+r], fill=BG_RGB + (255,))
        draw_tv_icon(draw, cx, cy, logo_size - 10, PRIMARY_RGB)

    draw.rectangle([0, 0, w, 3], fill=PRIMARY_RGB + (255,))
    draw.rectangle([0, h-3, w, h], fill=PRIMARY_RGB + (255,))
    draw.rectangle([0, 0, 3, h], fill=PRIMARY_RGB + (255,))
    draw.rectangle([w-3, 0, w, h], fill=PRIMARY_RGB + (255,))

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    img.save(out_path)
    print(f"  ✅ Roku icon ({w}x{h}) → {out_path}")

def generate_roku_splash(out_path):
    W, H = 1280, 720
    img = Image.new("RGB", (W, H), BG_RGB)
    draw = ImageDraw.Draw(img)

    for i in range(W):
        factor = 1 + (i / W) * 0.1
        c = tuple(min(255, int(v * factor)) for v in BG_RGB)
        draw.rectangle([i, 0, i+1, H], fill=c)

    logo_size = 300
    cx, cy = W // 2, H // 2 - 60
    logo = load_logo(APP_LOGO_URL, logo_size)

    if logo:
        lw, lh_l = logo.size
        img.paste(logo, (cx - lw//2, cy - lh_l//2), logo)
    else:
        img_rgba = img.convert("RGBA")
        tv_draw = ImageDraw.Draw(img_rgba)
        r = 150
        tv_draw.ellipse([cx-r-4, cy-r-4, cx+r+4, cy+r+4], fill=tuple(int(v*0.6) for v in PRIMARY_RGB) + (255,))
        tv_draw.ellipse([cx-r, cy-r, cx+r, cy+r], fill=BG_RGB + (255,))
        draw_tv_icon(tv_draw, cx, cy, 220, PRIMARY_RGB)
        img = img_rgba.convert("RGB")
        draw = ImageDraw.Draw(img)

    try:
        font_big = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 80)
    except:
        font_big = ImageFont.load_default()

    b = font_big.getbbox(APP_NAME)
    tw = b[2] - b[0]
    draw.text(((W - tw) // 2, H // 2 + 110), APP_NAME, font=font_big, fill=PRIMARY_RGB)

    draw.rectangle([0, 0, W, 4], fill=PRIMARY_RGB)
    draw.rectangle([0, H-4, W, H], fill=PRIMARY_RGB)

    os.makedirs(os.path.dirname(out_path), exist_ok=True)
    img.save(out_path, quality=95)
    print(f"  ✅ Roku splash (1280x720) → {out_path}")

if __name__ == "__main__":
    print(f"\n🎨 Gerando assets de TV para: {APP_NAME}")
    print(f"   Logo URL : {APP_LOGO_URL or '(padrão - ícone TV)'}")
    print(f"   Cor      : {PRIMARY_COLOR}")
    print(f"   Fundo    : {BG_COLOR}\n")

    for density in ["mdpi", "hdpi", "xhdpi", "xxhdpi", "xxxhdpi"]:
        generate_android_banner(
            f"android/app/src/main/res/mipmap-{density}/tv_banner.png"
        )

    generate_roku_icon("roku_channel/images/icon_focus_hd.png",  336, 210, 160)
    generate_roku_icon("roku_channel/images/icon_side_hd.png",   108,  69,  50)
    generate_roku_splash("roku_channel/images/splash_hd.jpg")

    print("\n✅ Todos os assets gerados com sucesso!\n")
