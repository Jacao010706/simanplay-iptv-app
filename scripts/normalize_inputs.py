#!/usr/bin/env python3
"""
normalize_inputs.py
Valida os dados enviados pelo painel (workflow_dispatch) e grava versões seguras
em $GITHUB_ENV para os passos seguintes. Os inputs chegam por variáveis IN_*,
nunca interpolados no shell (evita injeção de comandos pelo nome do app).

Saída ($GITHUB_ENV):
  APP_NAME, APP_SUBTITLE, SLUG, RELEASE_TAG, PRIMARY_HEX, BG_HEX, SURFACE_HEX,
  APP_THEME, LOGO_URL, BANNER_URL, API_URL, RESELLER_ID, RESELLER_USERNAME
"""
import os
import re
import unicodedata


def get(name, default=""):
    v = (os.environ.get(name) or "").replace("\r", " ").replace("\n", " ").strip()
    return v or default


def hex_color(value, default):
    h = (value or "").strip().lstrip("#")
    if re.fullmatch(r"[0-9a-fA-F]{3}", h):
        h = "".join(c * 2 for c in h)
    return h.lower() if re.fullmatch(r"[0-9a-fA-F]{6}", h) else default


def slugify(value):
    ascii_ = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode()
    slug = re.sub(r"[^a-z0-9]+", "_", ascii_.lower()).strip("_")
    return slug or "simanplay"


def url(value):
    return value if re.match(r"^https?://[^\s\"'`$\\]+$", value or "") else ""


app_name = get("IN_APP_NAME", "SimanPlay IPTV")[:60]
reseller_username = re.sub(r"[^A-Za-z0-9_.-]", "", get("IN_RESELLER_USERNAME"))[:40]
reseller_id = re.sub(r"\D", "", get("IN_RESELLER_ID"))[:10]
theme_raw = get("IN_APP_THEME", "1")
theme = int(theme_raw) if theme_raw.isdigit() and 1 <= int(theme_raw) <= 6 else 1
slug = slugify(app_name)
run_number = get("GITHUB_RUN_NUMBER", "0")

values = {
    "APP_NAME": app_name,
    "APP_SUBTITLE": get("IN_APP_SUBTITLE", "Conecte sua lista")[:80],
    "SLUG": slug,
    "RELEASE_TAG": f"{slugify(reseller_username) if reseller_username else slug}-{run_number}",
    "PRIMARY_HEX": hex_color(get("IN_PRIMARY_COLOR"), "e94bff"),
    "BG_HEX": hex_color(get("IN_BACKGROUND_COLOR") or get("IN_BG_COLOR"), "0d0b14"),
    "SURFACE_HEX": hex_color(get("IN_SURFACE_COLOR"), "1a1625"),
    "APP_THEME": str(theme),
    "LOGO_URL": url(get("IN_LOGO_URL")),
    "BANNER_URL": url(get("IN_BANNER_URL")),
    "API_URL": url(get("IN_API_URL")).rstrip("/") or "https://web-production-d8671.up.railway.app",
    "RESELLER_ID": reseller_id,
    "RESELLER_USERNAME": reseller_username,
}

env_file = os.environ.get("GITHUB_ENV")
lines = [f"{k}={v}" for k, v in values.items()]
if env_file:
    with open(env_file, "a", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")
for line in lines:
    print(line)
