#!/usr/bin/env python3
"""
generate_tv_apps.py
Gera os lançadores das Smart TVs Samsung (Tizen) e LG (webOS).

Os dois são "apps hospedados": um pacote pequeno que abre o app de TV do painel
(/tv) com a marca do revendedor. Correções no painel chegam às TVs sem reinstalar.

Saídas:
  build_tv/samsung/  -> empacotado aqui em <SLUG>_samsung_nao_assinado.wgt
                        (a Samsung exige assinatura com certificado Samsung — ver docs/TV_APPS.md)
  build_tv/lg/       -> empacotado no CI com `ares-package` (formato .ipk oficial)

Variáveis (vindas de normalize_inputs.py): APP_NAME, SLUG, PRIMARY_HEX, BG_HEX,
LOGO_URL, TV_URL (opcional), GITHUB_RUN_NUMBER.
"""
import hashlib
import html
import io
import json
import os
import re
import shutil
import urllib.parse
import urllib.request
import zipfile
from xml.sax.saxutils import escape as xml_escape

from PIL import Image, ImageDraw

DEFAULT_NAME = "PRIMETV"
DEFAULT_TV_URL = "https://simanplay-iptv-admin-panel.vercel.app/tv"

APP_NAME = (os.environ.get("APP_NAME") or DEFAULT_NAME).strip()[:40]
SLUG = re.sub(r"[^a-z0-9_]", "", (os.environ.get("SLUG") or "primetv").lower()) or "primetv"
PRIMARY = (os.environ.get("PRIMARY_HEX") or "e94bff").lstrip("#")
BG = (os.environ.get("BG_HEX") or "0a0a0f").lstrip("#")
LOGO_URL = os.environ.get("LOGO_URL", "")
TV_URL = os.environ.get("TV_URL") or DEFAULT_TV_URL
RUN = re.sub(r"\D", "", os.environ.get("GITHUB_RUN_NUMBER", "")) or "1"
VERSION = f"1.0.{int(RUN) % 1000}"   # LG/Samsung: x.y.z, cada parte <= 999

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "tv_hosted")
OUT = "build_tv"


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def load_logo(size):
    if not LOGO_URL:
        return None
    try:
        req = urllib.request.Request(LOGO_URL, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=15) as r:
            img = Image.open(io.BytesIO(r.read())).convert("RGBA")
        img.thumbnail(size, Image.LANCZOS)
        return img
    except Exception as e:
        print(f"  aviso: logo indisponível ({e}); usando ícone padrão")
        return None


def make_image(w, h, logo_ratio=0.7):
    img = Image.new("RGBA", (w, h), rgb(BG) + (255,))
    draw = ImageDraw.Draw(img)
    logo = load_logo((int(w * logo_ratio), int(h * logo_ratio)))
    if logo:
        img.paste(logo, ((w - logo.width) // 2, (h - logo.height) // 2), logo)
    else:
        r = min(w, h) // 3
        cx, cy = w // 2, h // 2
        draw.ellipse([cx - r, cy - r, cx + r, cy + r], outline=rgb(PRIMARY) + (255,), width=max(2, r // 8))
        draw.polygon([(cx - r // 3, cy - r // 2), (cx - r // 3, cy + r // 2), (cx + r // 2, cy)], fill=rgb(PRIMARY) + (255,))
    buf = io.BytesIO()
    img.convert("RGB").save(buf, "PNG")
    return buf.getvalue()


def target_url():
    q = {"name": APP_NAME, "color": PRIMARY, "bg": BG}
    if LOGO_URL.startswith("https://"):
        q["logo"] = LOGO_URL
    sep = "&" if "?" in TV_URL else "?"
    return TV_URL + sep + urllib.parse.urlencode(q)


def fill(template):
    return (template
            .replace("__APP_NAME_HTML__", html.escape(APP_NAME))
            .replace("__APP_NAME_XML__", xml_escape(APP_NAME))
            .replace("__APP_NAME_JSON__", json.dumps(APP_NAME, ensure_ascii=False)[1:-1])
            .replace("__PRIMARY_HEX__", PRIMARY)
            .replace("__BG_HEX__", BG)
            .replace("__VERSION__", VERSION)
            .replace("__TARGET_URL__", json.dumps(target_url())[1:-1]))


def read(name):
    with open(os.path.join(SRC, name), encoding="utf-8") as f:
        return f.read()


def write(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    mode = "wb" if isinstance(data, bytes) else "w"
    with open(path, mode, **({} if mode == "wb" else {"encoding": "utf-8"})) as f:
        f.write(data)


def tizen_ids():
    """package: exatamente 10 chars alfanuméricos, estável por revendedor."""
    digest = hashlib.sha1(SLUG.encode()).hexdigest()
    package = ("P" + re.sub(r"[^A-Za-z0-9]", "", digest))[:10]
    name = re.sub(r"[^A-Za-z0-9]", "", APP_NAME)[:40] or "App"
    return package, name


def lg_app_id():
    part = re.sub(r"[^a-z0-9]", "", SLUG)[:30] or "app"
    return "com.primetv.app" if part == "primetv" else f"com.primetv.{part}"


def build_samsung():
    d = os.path.join(OUT, "samsung")
    shutil.rmtree(d, ignore_errors=True)
    package, name = tizen_ids()
    cfg = fill(read("samsung_config.xml"))
    cfg = (cfg.replace("__TIZEN_PACKAGE__", package).replace("__TIZEN_NAME__", name)
              .replace("__WIDGET_ID__", f"http://primetv.lat/{package}"))
    write(os.path.join(d, "config.xml"), cfg)
    write(os.path.join(d, "index.html"), fill(read("index.html")))
    write(os.path.join(d, "icon.png"), make_image(512, 423))
    out = f"{SLUG}_samsung_nao_assinado.wgt"
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zf:
        for fname in sorted(os.listdir(d)):
            zf.write(os.path.join(d, fname), fname)
    print(f"  Samsung: {out} (package {package}.{name}) — precisa ser assinado")


def build_lg():
    d = os.path.join(OUT, "lg")
    shutil.rmtree(d, ignore_errors=True)
    info = json.loads(fill(read("lg_appinfo.json")).replace("__LG_APP_ID__", lg_app_id()))
    write(os.path.join(d, "appinfo.json"), json.dumps(info, ensure_ascii=False, indent=2))
    write(os.path.join(d, "index.html"), fill(read("index.html")))
    write(os.path.join(d, "icon.png"), make_image(80, 80))
    write(os.path.join(d, "largeIcon.png"), make_image(130, 130))
    write(os.path.join(d, "bgImage.png"), make_image(1920, 1080, logo_ratio=0.35))
    print(f"  LG: {d}/ (id {info['id']}) — empacotar com: ares-package {d}")


if __name__ == "__main__":
    print(f"Gerando apps de TV para {APP_NAME!r} (versão {VERSION})")
    print(f"  abre: {target_url()}")
    build_samsung()
    build_lg()
