#!/usr/bin/env python3
"""
generate_app_config.py
Gera lib/app_config.dart com os dados do revendedor.
"""
import os

APP_NAME         = os.environ.get("APP_NAME",         "SimanPlay")
APP_SUBTITLE     = os.environ.get("APP_SUBTITLE",     "Conecte sua lista")
PRIMARY_COLOR    = os.environ.get("PRIMARY_COLOR",    "FF6B35")
BG_COLOR         = os.environ.get("BG_COLOR",         "0d0d1a")
SURFACE_COLOR    = os.environ.get("SURFACE_COLOR",    "1a1a2e")
BANNER_URL       = os.environ.get("BANNER_URL",       "")
LOGO_URL         = os.environ.get("LOGO_URL",         "")
API_URL          = os.environ.get("API_URL",          "https://simanplay-backend.up.railway.app")
RESELLER_ID      = os.environ.get("RESELLER_ID",      "")
RESELLER_USERNAME= os.environ.get("RESELLER_USERNAME","")

# Garantir que as cores não tenham #
PRIMARY_COLOR = PRIMARY_COLOR.lstrip("#")
BG_COLOR      = BG_COLOR.lstrip("#")
SURFACE_COLOR = SURFACE_COLOR.lstrip("#")

dart_content = f"""// AUTO-GENERATED — não editar manualmente
// Gerado por scripts/generate_app_config.py

class AppConfig {{
  static const String appName         = '{APP_NAME}';
  static const String appSubtitle     = '{APP_SUBTITLE}';
  static const String primaryColor    = '#{PRIMARY_COLOR}';
  static const String bgColor         = '#{BG_COLOR}';
  static const String surfaceColor    = '#{SURFACE_COLOR}';
  static const String bannerUrl       = '{BANNER_URL}';
  static const String logoUrl         = '{LOGO_URL}';
  static const String apiUrl          = '{API_URL}';
  static const String resellerId      = '{RESELLER_ID}';
  static const String resellerUsername= '{RESELLER_USERNAME}';

  // URL curta de download para este revendedor
  static const String downloadUrl     = 'https://primetv.lat/d/{RESELLER_ID}';
}}
"""

os.makedirs("lib", exist_ok=True)
with open("lib/app_config.dart", "w", encoding="utf-8") as f:
    f.write(dart_content)

print(f"✅ lib/app_config.dart gerado para: {APP_NAME}")
