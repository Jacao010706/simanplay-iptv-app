#!/usr/bin/env python3
"""
generate_launcher_icons.py
Ícone do aplicativo (Android, iOS e Windows) no build do white-label.

- Sem logo: fundo escuro (BG_HEX, padrão #0d0b14), símbolo de play em cima e o nome do
  app (APP_NAME, padrão PRIMETV) grande na cor principal (PRIMARY_HEX, padrão #e94bff).
- Com LOGO_URL: logo do revendedor centralizado sobre o mesmo fundo escuro.
Também grava store/android/icone-512.png (ícone da Google Play, 512x512).

Variáveis: APP_NAME, LOGO_URL, PRIMARY_HEX, BG_HEX (sem #). Rodar da raiz do projeto.
"""
import glob
import io
import os
import re
import urllib.request

from PIL import Image, ImageDraw, ImageFont

PRIMARY = re.sub(r"[^0-9a-fA-F]", "", os.environ.get("PRIMARY_HEX") or "e94bff")[:6] or "e94bff"
LOGO_URL = os.environ.get("LOGO_URL", "")
BG = re.sub(r"[^0-9a-fA-F]", "", os.environ.get("BG_HEX") or "0d0b14")[:6] or "0d0b14"
APP_NAME = (os.environ.get("APP_NAME") or "PRIMETV").strip()[:30] or "PRIMETV"
FONTS = ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "arialbd.ttf", "DejaVuSans-Bold.ttf"]


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def gradient(size, color):
    dark = tuple(int(c * 0.45) for c in color)
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x * 0.6 + y * 0.4) / (size - 1)
            px[x, y] = tuple(int(dark[i] + (color[i] - dark[i]) * t) for i in range(3))
    return img


def tv_symbol(size, color=(255, 255, 255)):
    S = size * 4
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    lw = S // 16
    d.rounded_rectangle([S * 0.08, S * 0.26, S * 0.92, S * 0.86], radius=S // 9, outline=color, width=lw)
    d.line([(S * 0.36, S * 0.06), (S * 0.5, S * 0.24)], fill=color, width=lw)
    d.line([(S * 0.64, S * 0.06), (S * 0.5, S * 0.24)], fill=color, width=lw)
    cx, cy, r = S * 0.52, S * 0.56, S * 0.17
    d.polygon([(cx - r * 0.8, cy - r), (cx - r * 0.8, cy + r), (cx + r, cy)], fill=color)
    return im.resize((size, size), Image.LANCZOS)


def load_logo(max_size):
    if not LOGO_URL:
        return None
    try:
        req = urllib.request.Request(LOGO_URL, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=20) as r:
            logo = Image.open(io.BytesIO(r.read())).convert("RGBA")
        logo.thumbnail((max_size, max_size), Image.LANCZOS)
        return logo
    except Exception as e:
        print(f"  aviso: logo indisponível ({e}); usando ícone padrão")
        return None


def font_that_fits(text, max_width, max_size):
    """Maior fonte (negrito) em que o texto cabe na largura."""
    for path in FONTS:
        try:
            ImageFont.truetype(path, 10)
        except OSError:
            continue
        size = max_size
        while size > 10:
            f = ImageFont.truetype(path, size)
            box = f.getbbox(text)
            if box[2] - box[0] <= max_width:
                return f
            size -= 4
        return ImageFont.truetype(path, size)
    return ImageFont.load_default()


def play_symbol(size, color):
    """Círculo com triângulo de play (desenhado em 4x e reduzido para ficar liso)."""
    S = size * 4
    im = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.ellipse([S * 0.04, S * 0.04, S * 0.96, S * 0.96], outline=color, width=S // 14)
    cx, cy, r = S * 0.54, S * 0.5, S * 0.24
    d.polygon([(cx - r * 0.85, cy - r), (cx - r * 0.85, cy + r), (cx + r, cy)], fill=color)
    return im.resize((size, size), Image.LANCZOS)


def base_icon(size=1024):
    img = Image.new("RGBA", (size, size), rgb(BG) + (255,))
    logo = load_logo(int(size * 0.66))
    if logo:
        img.paste(logo, ((size - logo.width) // 2, (size - logo.height) // 2), logo)
        return img
    color = rgb(PRIMARY) + (255,)
    sym = play_symbol(int(size * 0.40), color)
    img.paste(sym, ((size - sym.width) // 2, int(size * 0.14)), sym)
    d = ImageDraw.Draw(img)
    font = font_that_fits(APP_NAME, int(size * 0.84), int(size * 0.22))
    box = d.textbbox((0, 0), APP_NAME, font=font)
    x = (size - (box[2] - box[0])) // 2 - box[0]
    y = int(size * 0.62) - box[1]
    d.text((x, y), APP_NAME, font=font, fill=color)
    return img


def rounded(img, radius_ratio=0.22):
    s = img.width
    mask = Image.new("L", (s, s), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, s - 1, s - 1], radius=int(s * radius_ratio), fill=255)
    out = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def main():
    base = base_icon()
    n = 0
    # Android: cantos arredondados (ícone legado)
    android = rounded(base)
    for f in glob.glob("android/app/src/main/res/mipmap-*/ic_launcher.png"):
        size = Image.open(f).size[0]
        android.resize((size, size), Image.LANCZOS).save(f, "PNG")
        n += 1
    # iOS: quadrado cheio, sem transparência (a Apple aplica o arredondamento)
    ios_rgb = base.convert("RGB")
    for f in glob.glob("ios/Runner/Assets.xcassets/AppIcon.appiconset/*.png"):
        size = Image.open(f).size[0]
        ios_rgb.resize((size, size), Image.LANCZOS).save(f, "PNG")
        n += 1
    # macOS (mesmo projeto Flutter), se existir
    for f in glob.glob("macos/Runner/Assets.xcassets/AppIcon.appiconset/*.png"):
        size = Image.open(f).size[0]
        rounded(base).resize((size, size), Image.LANCZOS).save(f, "PNG")
        n += 1
    # Windows (.ico com vários tamanhos)
    ico = "windows/runner/resources/app_icon.ico"
    if os.path.exists(ico):
        rounded(base).save(ico, format="ICO", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])
        n += 1
    # Google Play: ícone 512x512 quadrado, sem transparência
    os.makedirs("store/android", exist_ok=True)
    base.convert("RGB").resize((512, 512), Image.LANCZOS).save("store/android/icone-512.png", "PNG")
    n += 1
    print(f"Ícones do app gerados ({'logo do revendedor' if LOGO_URL else 'ícone PRIMETV'}): {n} arquivos")


if __name__ == "__main__":
    main()
