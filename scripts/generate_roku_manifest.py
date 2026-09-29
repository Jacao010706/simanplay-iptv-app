#!/usr/bin/env python3
"""
generate_roku_manifest.py
Gera roku_channel/manifest e roku_channel/components/Config.brs com a marca do
revendedor. As imagens vêm de scripts/generate_tv_assets.py.

Variáveis: APP_NAME (padrão PRIMETV), PRIMARY_HEX, BG_HEX, SURFACE_HEX,
TV_API_BASE (padrão: painel na Vercel), GITHUB_RUN_NUMBER.
"""
import os
import re

APP_NAME = (os.environ.get("APP_NAME") or "PRIMETV").strip()[:40]
PRIMARY = re.sub(r"[^0-9a-fA-F]", "", os.environ.get("PRIMARY_HEX") or "e94bff")[:6] or "e94bff"
BG = re.sub(r"[^0-9a-fA-F]", "", os.environ.get("BG_HEX") or "0a0a0f")[:6] or "0a0a0f"
SURFACE = re.sub(r"[^0-9a-fA-F]", "", os.environ.get("SURFACE_HEX") or "1a1625")[:6] or "1a1625"
API_BASE = (os.environ.get("TV_API_BASE") or "https://simanplay-iptv-admin-panel.vercel.app").rstrip("/")
RUN = int(re.sub(r"\D", "", os.environ.get("GITHUB_RUN_NUMBER", "")) or 1)


def brs_str(value):
    # String BrightScript: aspas duplicadas; sem quebras de linha
    return '"' + value.replace('"', '""').replace("\r", " ").replace("\n", " ") + '"'


# Manifest: uma chave=valor por linha; tira "=" e quebras do nome
title = APP_NAME.replace("\n", " ").replace("\r", " ")
manifest = f"""title={title}
subtitle=TV ao Vivo, Filmes e Series
major_version=1
minor_version=0
build_version={RUN}
ui_resolutions=fhd
mm_icon_focus_hd=pkg:/images/icon_focus_hd.png
mm_icon_side_hd=pkg:/images/icon_side_hd.png
splash_screen_fhd=pkg:/images/splash_hd.jpg
splash_screen_hd=pkg:/images/splash_hd.jpg
splash_color=#{BG}
splash_min_time=1000
bs_const=debug=false
supports_input_launch=1
"""

config = f"""' AUTO-GERADO por scripts/generate_roku_manifest.py no build do white-label.
function appConfig() as object
    return {{
        appName: {brs_str(APP_NAME)}
        apiBase: {brs_str(API_BASE)}
        primaryHex: {brs_str(PRIMARY.lower())}
        bgHex: {brs_str(BG.lower())}
        surfaceHex: {brs_str(SURFACE.lower())}
    }}
end function
"""

os.makedirs("roku_channel/components", exist_ok=True)
with open("roku_channel/manifest", "w", encoding="utf-8", newline="\n") as f:
    f.write(manifest)
with open("roku_channel/components/Config.brs", "w", encoding="utf-8", newline="\n") as f:
    f.write(config)
print(f"Roku: manifest + Config.brs gerados para {APP_NAME!r} (build {RUN})")
