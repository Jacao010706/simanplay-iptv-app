#!/usr/bin/env python3
"""
generate_tv_apps.py
Gera os lançadores das Smart TVs Samsung (Tizen) e LG (webOS).

Samsung: app EMPACOTADO — o app de TV do painel (/tv: MAC + chave, listas, TV ao Vivo,
Filmes, Séries, Favoritos, assinatura) vai inteiro dentro do .wgt, como a Samsung exige
para publicar na loja. É baixado do painel no build (TV_URL) com o hls.js e o qrcode.js.
LG: também EMPACOTADO (mesmo app, dentro do .ipk), para publicar na LG Content Store.
Se o painel estiver fora do ar no build, os dois caem para o lançador hospedado.

Saídas:
  build_tv/samsung/  -> empacotado aqui em <SLUG>_samsung_nao_assinado.wgt
                        (a Samsung exige assinatura com certificado Samsung — ver docs/TV_APPS.md)
  build_tv/lg/       -> empacotado no CI com `ares-package` (formato .ipk oficial)

Variáveis (vindas de normalize_inputs.py): APP_NAME, SLUG, PRIMARY_HEX, BG_HEX,
LOGO_URL, TV_URL (opcional), TV_SRC_DIR (opcional: pasta local com index.html e
qrcode.js, em vez de baixar do painel), GITHUB_RUN_NUMBER.

Casca LG white-label: tv_hosted/lg_brands.json (por SLUG) define id, título, ícones,
URL do app de TV, resolução e a última versão enviada à loja (min_version). As
variáveis LG_APP_ID, LG_TITLE, LG_ICON_URL, LG_BG_URL, LG_RESOLUTION, LG_VENDOR,
LG_VERSION e LG_MIN_VERSION sobrepõem o arquivo. Empacotar: scripts/build_lg_ipk.py.
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
HLS_JS_URL = "https://cdn.jsdelivr.net/npm/hls.js@1.5.13/dist/hls.min.js"

HERE = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(HERE, "..", "tv_hosted")
OUT = "build_tv"

def _load_lg_brands():
    path = os.path.join(SRC, "lg_brands.json")
    if not os.path.exists(path):
        return {}
    with open(path, encoding="utf-8") as f:
        return {k: v for k, v in json.load(f).items() if not k.startswith("_")}


APP_NAME = (os.environ.get("APP_NAME") or DEFAULT_NAME).strip()[:40]
SLUG = re.sub(r"[^a-z0-9_]", "", (os.environ.get("SLUG") or "primetv").lower()) or "primetv"
# Casca LG deste revendedor (lg_brands.json pelo SLUG; variáveis de ambiente têm prioridade)
LG_BRAND = _load_lg_brands().get(SLUG, {})
PRIMARY = (os.environ.get("PRIMARY_HEX") or LG_BRAND.get("primary_hex") or "e94bff").lstrip("#")
BG = (os.environ.get("BG_HEX") or LG_BRAND.get("bg_hex") or "0a0a0f").lstrip("#")
LOGO_URL = os.environ.get("LOGO_URL", "")
TV_URL = os.environ.get("TV_URL") or LG_BRAND.get("tv_url") or DEFAULT_TV_URL
RUN = re.sub(r"\D", "", os.environ.get("GITHUB_RUN_NUMBER", "")) or "1"
VERSION = f"1.0.{int(RUN) % 1000}"   # Samsung: x.y.z, cada parte <= 999


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
    """id do app na LG: lg_brands.json/LG_APP_ID ou com.primetv.<slug>."""
    app_id = (os.environ.get("LG_APP_ID") or LG_BRAND.get("app_id") or "").strip()
    if not app_id:
        part = re.sub(r"[^a-z0-9]", "", SLUG)[:30] or "app"
        app_id = "com.primetv.app" if part == "primetv" else f"com.primetv.{part}"
    # webOS: minúsculas, números, ponto e hífen, começando por letra (ex.: com.empresa.app)
    if not re.fullmatch(r"[a-z][a-z0-9-]*(\.[a-z0-9][a-z0-9-]*)+", app_id):
        raise SystemExit(f"LG: id de app inválido: {app_id!r}")
    return app_id


def lg_title():
    return ((os.environ.get("LG_TITLE") or LG_BRAND.get("title") or APP_NAME).strip()[:40]) or DEFAULT_NAME


def lg_resolution():
    res = (os.environ.get("LG_RESOLUTION") or LG_BRAND.get("resolution") or "1920x1080").strip()
    if res not in ("1920x1080", "1280x720"):
        raise SystemExit(f"LG: resolução inválida: {res!r} (use 1920x1080 ou 1280x720)")
    return res


def parse_version(v):
    m = re.fullmatch(r"(\d{1,3})\.(\d{1,3})\.(\d{1,3})", (v or "").strip())
    if not m:
        raise SystemExit(f"LG: versão inválida: {v!r} (use x.y.z, cada parte de 0 a 999)")
    return tuple(int(x) for x in m.groups())


def lg_version():
    """Versão da casca LG: LG_VERSION ou 1.<1 + run//1000>.<run % 1000> (sempre cresce e
    fica acima das 1.0.x já publicadas). Precisa ser maior que min_version (última enviada)."""
    run = int(RUN)
    version = (os.environ.get("LG_VERSION") or f"1.{1 + run // 1000}.{run % 1000}").strip()
    minimum = (os.environ.get("LG_MIN_VERSION") or LG_BRAND.get("min_version") or "0.0.0").strip()
    if parse_version(version) <= parse_version(minimum):
        raise SystemExit(f"LG: a versão {version} precisa ser maior que a última enviada ({minimum})")
    return version


def lg_vendor():
    return (os.environ.get("LG_VENDOR") or LG_BRAND.get("vendor") or "Akitemtech").strip()


# Ajusta o layout (desenhado em 1920x1080) a qualquer tela: 1280x720 e 1920x1080.
# Zera o zoom antes de medir para não somar escalas a cada "resize".
LG_FIT_SCRIPT = """<script>
(function(){
  function fit(){
    var d=document.documentElement;
    d.style.zoom='';
    var s=Math.min(window.innerWidth/1920, window.innerHeight/1080);
    if(s>0&&s<0.99){d.style.zoom=s;}
  }
  fit();
  window.addEventListener('resize',fit);
})();
</script>
"""


def lg_page(page):
    """index.html empacotado para a LG, com o ajuste de tela antes dos scripts do app
    (o zoom vale desde o primeiro desenho da tela)."""
    for anchor in ("<script>window.PRIMETV_BRAND=", '<script src="hls.min.js"></script>', "</body>"):
        i = page.find(anchor)
        if i >= 0:
            return page[:i] + LG_FIT_SCRIPT + page[i:]
    raise ValueError("app de TV sem </body>")


def lg_image(key, env_url, w, h, logo_ratio=0.7):
    """Ícone/fundo da casca: arquivo do lg_brands.json, URL (LG_*_URL) ou gerado da logo."""
    url = os.environ.get(env_url, "").strip()
    if url:
        try:
            img = Image.open(io.BytesIO(fetch(url))).convert("RGBA")
            canvas = Image.new("RGBA", (w, h), rgb(BG) + (255,))
            img.thumbnail((w, h), Image.LANCZOS)
            canvas.paste(img, ((w - img.width) // 2, (h - img.height) // 2), img)
            buf = io.BytesIO()
            canvas.convert("RGB").save(buf, "PNG")
            return buf.getvalue()
        except Exception as e:
            print(f"  aviso: {env_url} indisponível ({e}); usando o padrão")
    rel = LG_BRAND.get(key)
    if rel:
        with open(os.path.join(SRC, rel), "rb") as f:
            return f.read()
    return make_image(w, h, logo_ratio=logo_ratio)


def fetch(url):
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0", "Cache-Control": "no-cache"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return r.read()


def tv_sources():
    """index.html + qrcode.js do app de TV do painel (ou de TV_SRC_DIR) e o hls.js."""
    src_dir = os.environ.get("TV_SRC_DIR")
    if src_dir:
        with open(os.path.join(src_dir, "index.html"), encoding="utf-8") as f:
            page = f.read()
        with open(os.path.join(src_dir, "qrcode.js"), "rb") as f:
            qr = f.read()
    else:
        base = TV_URL.split("?")[0].rstrip("/")
        page = fetch(base + "/index.html").decode("utf-8")
        qr = fetch(base + "/qrcode.js")
    return page, qr, fetch(HLS_JS_URL)


def package_page(page):
    """Ajusta o /tv para rodar de dentro do .wgt: scripts locais e marca embutida."""
    for old, new in [('<script src="/tv/qrcode.js"></script>', '<script src="qrcode.js"></script>'),
                     (f'<script src="{HLS_JS_URL}"></script>', '<script src="hls.min.js"></script>')]:
        if old not in page:
            raise ValueError(f"app de TV mudou: não achei {old!r}")
        page = page.replace(old, new)
    brand = {"name": APP_NAME, "color": PRIMARY, "bg": BG}
    if LOGO_URL.startswith("https://"):
        brand["logo"] = LOGO_URL
    brand_js = json.dumps(brand, ensure_ascii=False).replace("</", "<\\/")
    inject = "<script>window.PRIMETV_BRAND=" + brand_js + ";</script>\n"
    page = page.replace('<script src="hls.min.js"></script>', inject + '<script src="hls.min.js"></script>', 1)
    page = re.sub(r"<title>.*?</title>", "<title>" + html.escape(APP_NAME) + "</title>", page, count=1, flags=re.S)
    return page


_PACKAGED = {}


def packaged_files():
    """Arquivos do app de TV empacotado (baixados uma vez e usados na Samsung e na LG).
    None = sem acesso ao painel no build: usa o lançador hospedado (funciona, mas a loja pode recusar)."""
    if "files" not in _PACKAGED:
        try:
            page, qr, hls = tv_sources()
            _PACKAGED["files"] = {"index.html": package_page(page), "qrcode.js": qr, "hls.min.js": hls}
        except Exception as e:
            print(f"  aviso: não consegui empacotar o app de TV ({e}); gerando lançador hospedado")
            _PACKAGED["files"] = None
    return _PACKAGED["files"]


def build_samsung():
    d = os.path.join(OUT, "samsung")
    shutil.rmtree(d, ignore_errors=True)
    package, name = tizen_ids()
    files = packaged_files()
    if files:
        template, kind = "samsung_packaged_config.xml", "empacotado"
    else:
        files = {"index.html": fill(read("index.html"))}
        template, kind = "samsung_config.xml", "hospedado"
    cfg = fill(read(template))
    cfg = (cfg.replace("__TIZEN_PACKAGE__", package).replace("__TIZEN_NAME__", name)
              .replace("__WIDGET_ID__", f"http://primetv.lat/{package}"))
    write(os.path.join(d, "config.xml"), cfg)
    for fname, data in files.items():
        write(os.path.join(d, fname), data)
    write(os.path.join(d, "icon.png"), make_image(512, 423))
    out = f"{SLUG}_samsung_nao_assinado.wgt"
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zf:
        for fname in sorted(os.listdir(d)):
            zf.write(os.path.join(d, fname), fname)
    print(f"  Samsung ({kind}): {out} (package {package}.{name}) — precisa ser assinado")


def build_lg(require_packaged=False):
    """Casca LG em build_tv/lg/. require_packaged: falha em vez de gerar o lançador
    hospedado (a loja recusa app que só abre um site)."""
    d = os.path.join(OUT, "lg")
    shutil.rmtree(d, ignore_errors=True)
    template = (read("lg_appinfo.json")
                .replace("__LG_APP_ID__", lg_app_id())
                .replace("__LG_VERSION__", lg_version())
                .replace("__LG_TITLE_JSON__", json.dumps(lg_title(), ensure_ascii=False)[1:-1])
                .replace("__LG_VENDOR_JSON__", json.dumps(lg_vendor(), ensure_ascii=False)[1:-1])
                .replace("__LG_RESOLUTION__", lg_resolution()))
    info = json.loads(fill(template))
    write(os.path.join(d, "appinfo.json"), json.dumps(info, ensure_ascii=False, indent=2))
    packaged = packaged_files()
    if packaged:
        files = dict(packaged)
        files["index.html"] = lg_page(files["index.html"])
    elif require_packaged:
        raise SystemExit("LG: não consegui baixar o app de TV para empacotar (TV_URL/TV_SRC_DIR)")
    else:
        files = {"index.html": fill(read("index.html"))}
    for fname, data in files.items():
        write(os.path.join(d, fname), data)
    write(os.path.join(d, "icon.png"), lg_image("icon", "LG_ICON_URL", 80, 80))
    write(os.path.join(d, "largeIcon.png"), lg_image("large_icon", "LG_ICON_URL", 130, 130))
    write(os.path.join(d, "bgImage.png"), lg_image("bg_image", "LG_BG_URL", 1920, 1080, logo_ratio=0.35))
    kind = "empacotado" if packaged else "hospedado"
    print(f"  LG ({kind}): {d}/ (id {info['id']}, {info['title']!r} {info['version']}, {info['resolution']})")
    return info


if __name__ == "__main__":
    print(f"Gerando apps de TV para {APP_NAME!r} (Samsung {VERSION})")
    print(f"  abre: {target_url()}")
    build_samsung()
    build_lg()
