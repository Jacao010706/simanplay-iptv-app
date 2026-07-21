#!/usr/bin/env python3
"""Gera o manifest do canal Roku com dados do revendedor."""
import os

APP_NAME    = os.environ.get("APP_NAME", "PRIME TV")
APP_VERSION = os.environ.get("APP_VERSION", "1")

content = f"""title={APP_NAME}
subtitle=IPTV - TV ao Vivo, Filmes e Series
major_version=1
minor_version=0
build_version={APP_VERSION}
mm_icon_focus_hd=pkg:/images/icon_focus_hd.png
mm_icon_side_hd=pkg:/images/icon_side_hd.png
splash_screen_hd=pkg:/images/splash_hd.jpg
splash_color=#0a0a0a
splash_min_time=0
bs_const=const_debug_enable=false
supports_input_launch=false
"""
os.makedirs("roku_channel", exist_ok=True)
with open("roku_channel/manifest", "w") as f:
    f.write(content)
print(f"✅ Roku manifest gerado para: {APP_NAME}")
