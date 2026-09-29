#!/usr/bin/env python3
"""
generate_launcher_icons.py
Ícone do aplicativo (Android, iOS e Windows) no build do white-label.

- Com LOGO_URL: logo do revendedor centralizado sobre um degradê da cor principal.
- Sem logo: ícone PRIMETV (TV com botão play) sobre o degradê.

Variáveis: LOGO_URL, PRIMARY_HEX (sem #). Rodar da raiz do projeto.
"""
import glob
import io
import os
import re
import urllib.request

from PIL import Image, ImageDraw

PRIMARY = re.sub(r"[^0-9a-fA-F]", "", os.environ.get("PRIMARY_HEX") or "e94bff")[:6] or "e94bff"
LOGO_URL = os.environ.get("LOGO_URL", "")


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


def base_icon(size=1024):
    img = gradient(size, rgb(PRIMARY)).convert("RGBA")
    logo = load_logo(int(size * 0.66))
    sym = logo or tv_symbol(int(size * 0.62))
    img.paste(sym, ((size - sym.width) // 2, (size - sym.height) // 2 + (0 if logo else size // 40)), sym)
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
    print(f"Ícones do app gerados ({'logo do revendedor' if LOGO_URL else 'ícone PRIMETV'}): {n} arquivos")


if __name__ == "__main__":
    main()
