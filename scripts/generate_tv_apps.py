#!/usr/bin/env python3
"""
generate_tv_apps.py
Gera apps personalizados para Samsung Tizen (.wgt) e LG webOS (.ipk)
com o logo e cores do revendedor.
"""
import os, zipfile, urllib.request, io
from PIL import Image, ImageDraw

APP_NAME      = os.environ.get("APP_NAME", "SimanPlay")
APP_LOGO_URL  = os.environ.get("APP_LOGO_URL", "")
PRIMARY_COLOR = os.environ.get("PRIMARY_COLOR", "#FF6B35").lstrip("#")
BG_COLOR      = os.environ.get("BG_COLOR", "#0d0d1a").lstrip("#")
API_URL       = os.environ.get("API_URL", "https://simanplay-backend.up.railway.app")

def hex_to_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def load_logo(url, size):
    if not url: return None
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=15) as r:
            data = r.read()
        logo = Image.open(io.BytesIO(data)).convert("RGBA")
        logo.thumbnail((size, size), Image.LANCZOS)
        return logo
    except Exception as e:
        print(f"  ⚠️  Logo não disponível: {e}")
        return None

def generate_icon(size):
    primary = hex_to_rgb(PRIMARY_COLOR)
    bg      = hex_to_rgb(BG_COLOR)
    img     = Image.new("RGBA", (size, size), bg + (255,))
    draw    = ImageDraw.Draw(img)

    logo = load_logo(APP_LOGO_URL, int(size * 0.7))
    if logo:
        lw, lh = logo.size
        img.paste(logo, ((size-lw)//2, (size-lh)//2), logo)
    else:
        r = size // 3
        cx, cy = size // 2, size // 2
        draw.ellipse([cx-r-2, cy-r-2, cx+r+2, cy+r+2], fill=tuple(int(v*0.6) for v in primary)+(255,))
        draw.ellipse([cx-r, cy-r, cx+r, cy+r], fill=bg+(255,))
        pts = [(cx-r//3, cy-r//3), (cx-r//3, cy+r//3), (cx+r//2, cy)]
        draw.polygon(pts, fill=primary+(255,))

    for i in range(3):
        draw.rectangle([i, i, size-i-1, size-i-1], outline=primary+(200,))

    buf = io.BytesIO()
    img.save(buf, "PNG")
    return buf.getvalue()

def replace_placeholders(content):
    return (content
        .replace("APP_NAME_PLACEHOLDER", APP_NAME)
        .replace("APP_THEME_PLACEHOLDER", PRIMARY_COLOR)
        .replace("APP_BG_PLACEHOLDER", BG_COLOR)
        .replace("API_BASE_PLACEHOLDER", API_URL)
    )

def build_samsung_wgt():
    print("\n📦 Empacotando Samsung Tizen (.wgt)...")
    out = "simanplay_samsung.wgt"
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zf:
        for root, dirs, files in os.walk("samsung_tizen"):
            for fname in files:
                fpath = os.path.join(root, fname)
                arcname = os.path.relpath(fpath, "samsung_tizen")
                with open(fpath, "rb") as f:
                    raw = f.read()
                if fpath.endswith((".html", ".js", ".css", ".xml", ".json")):
                    raw = replace_placeholders(raw.decode("utf-8", errors="ignore")).encode("utf-8")
                zf.writestr(arcname, raw)
        zf.writestr("images/icon.png",    generate_icon(512))
        zf.writestr("images/icon_hd.png", generate_icon(512))
    print(f"  ✅ Samsung: {out}")

def build_lg_ipk():
    print("\n📦 Empacotando LG webOS (.ipk)...")
    out = "simanplay_lg.ipk"
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zf:
        for root, dirs, files in os.walk("lg_webos"):
            for fname in files:
                fpath = os.path.join(root, fname)
                arcname = os.path.relpath(fpath, "lg_webos")
                with open(fpath, "rb") as f:
                    raw = f.read()
                if fpath.endswith((".html", ".js", ".css", ".xml", ".json")):
                    raw = replace_placeholders(raw.decode("utf-8", errors="ignore")).encode("utf-8")
                zf.writestr(arcname, raw)
        zf.writestr("images/icon.png",       generate_icon(80))
        zf.writestr("images/icon_large.png", generate_icon(130))
    print(f"  ✅ LG webOS: {out}")

if __name__ == "__main__":
    print(f"\n🖥️  Gerando apps TV para: {APP_NAME}")
    build_samsung_wgt()
    build_lg_ipk()
    print("\n✅ Apps TV gerados!\n")
