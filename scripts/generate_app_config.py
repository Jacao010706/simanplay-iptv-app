#!/usr/bin/env python3
"""
generate_app_config.py
Gera lib/core/app_config.dart (o arquivo que o app realmente usa) com os dados
do white-label do revendedor enviados pelo painel.

Variáveis de ambiente (todas opcionais):
  APP_NAME, APP_SUBTITLE, PRIMARY_COLOR, BG_COLOR, SURFACE_COLOR (hex, com ou sem #),
  APP_THEME (1-6), LOGO_URL, BANNER_URL, API_URL, RESELLER_ID, RESELLER_USERNAME
"""
import os
import re

DEFAULTS = {
    "primary": "e94bff",
    "bg": "0d0b14",
    "surface": "1a1625",
    "api": "https://web-production-d8671.up.railway.app",
}


def env(name, default=""):
    value = os.environ.get(name, "")
    return value.strip() if value and value.strip() else default


def hex_color(value, default):
    """'#e94bff' / 'e94bff' / '#fff' -> 'e94bff'. Valor inválido vira o padrão."""
    h = (value or "").strip().lstrip("#")
    if not h:
        return default
    if re.fullmatch(r"[0-9a-fA-F]{3}", h):
        h = "".join(c * 2 for c in h)
    if not re.fullmatch(r"[0-9a-fA-F]{6}", h):
        print(f"  aviso: cor inválida {value!r}, usando #{default}")
        return default
    return h.lower()


def theme(value):
    try:
        t = int(str(value).strip())
    except ValueError:
        t = 1
    return t if 1 <= t <= 6 else 1


def dart_str(value):
    """String literal Dart segura (aspas, barras, $ e quebras de linha)."""
    s = (value or "").replace("\\", "\\\\").replace("'", "\\'").replace("$", "\\$")
    s = s.replace("\r", " ").replace("\n", " ")
    return f"'{s}'"


def build_config():
    primary = hex_color(env("PRIMARY_COLOR"), DEFAULTS["primary"])
    bg = hex_color(env("BG_COLOR"), DEFAULTS["bg"])
    surface = hex_color(env("SURFACE_COLOR"), DEFAULTS["surface"])
    logo_url = env("LOGO_URL")
    return {
        "appName": env("APP_NAME", "SimanPlay IPTV"),
        "appSubtitle": env("APP_SUBTITLE", "Conecte sua lista"),
        "primaryColor": f"0xFF{primary.upper()}",
        "backgroundColor": f"0xFF{bg.upper()}",
        "surfaceColor": f"0xFF{surface.upper()}",
        "backendUrl": env("API_URL", DEFAULTS["api"]).rstrip("/"),
        "bannerUrl": env("BANNER_URL"),
        "logoUrl": logo_url,
        "useCustomLogo": bool(logo_url),
        "appTheme": theme(env("APP_THEME", "1")),
        "resellerId": env("RESELLER_ID"),
        "resellerUsername": env("RESELLER_USERNAME"),
    }


def render(c):
    return f"""// AUTO-GERADO por scripts/generate_app_config.py no build do white-label.
// Para testes locais pode ser editado; o build sobrescreve este arquivo.
class AppConfig {{
  static const String appName = {dart_str(c['appName'])};
  static const String appSubtitle = {dart_str(c['appSubtitle'])};
  static const String appVersion = 'v1.0';

  // Cores (ARGB)
  static const int primaryColor = {c['primaryColor']};
  static const int backgroundColor = {c['backgroundColor']};
  static const int surfaceColor = {c['surfaceColor']};

  // Backend SimanPlay
  static const String backendUrl = {dart_str(c['backendUrl'])};

  // Banner de fundo da tela de login (vazio = sem banner)
  static const String bannerUrl = {dart_str(c['bannerUrl'])};

  // Logo do revendedor (URL). Vazio = ícone padrão.
  static const String logoUrl = {dart_str(c['logoUrl'])};
  static const bool useCustomLogo = {'true' if c['useCustomLogo'] else 'false'};
  static const double logoSize = 100.0;
  static const bool usePlayIcon = false; // false = TV, true = Play Circle

  // Tema da home: 1 Grade, 2 Netflix, 3 Sidebar, 4 IBO Banner+Grade,
  // 5 IBO Sidebar Escura, 6 IBO Banner Tela Cheia
  static const int appTheme = {c['appTheme']};

  static const String resellerId = {dart_str(c['resellerId'])};
  static const String resellerUsername = {dart_str(c['resellerUsername'])};
}}
"""


def xml_text(value):
    return (value.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
                 .replace('"', "&quot;").replace("'", "&apos;"))


def set_launcher_name(name):
    """Nome embaixo do ícone: Android (android:label) e iOS (CFBundleDisplayName)."""
    manifest = "android/app/src/main/AndroidManifest.xml"
    if os.path.exists(manifest):
        with open(manifest, encoding="utf-8") as f:
            m = f.read()
        m2, n = re.subn(r'(<application\b[^>]*?\sandroid:label=")[^"]*(")',
                        lambda g: g.group(1) + xml_text(name) + g.group(2), m, count=1)
        if n:
            with open(manifest, "w", encoding="utf-8", newline="") as f:
                f.write(m2)
        print(f"  Android label: {'ok' if n else 'NÃO encontrado'}")
    plist = "ios/Runner/Info.plist"
    if os.path.exists(plist):
        with open(plist, encoding="utf-8") as f:
            p = f.read()
        p2, n = re.subn(r"(<key>CFBundleDisplayName</key>\s*<string>)[^<]*(</string>)",
                        lambda g: g.group(1) + xml_text(name) + g.group(2), p, count=1)
        if n:
            with open(plist, "w", encoding="utf-8", newline="") as f:
                f.write(p2)
        print(f"  iOS display name: {'ok' if n else 'NÃO encontrado'}")


if __name__ == "__main__":
    config = build_config()
    os.makedirs("lib/core", exist_ok=True)
    with open("lib/core/app_config.dart", "w", encoding="utf-8", newline="\n") as f:
        f.write(render(config))
    # Só no build do white-label (o CI define APP_NAME); rodar local não mexe nos manifests
    if os.environ.get("APP_NAME"):
        set_launcher_name(config["appName"])
    print(f"OK: lib/core/app_config.dart gerado para {config['appName']!r} "
          f"(tema {config['appTheme']}, cor {config['primaryColor']}, logo {'sim' if config['useCustomLogo'] else 'não'})")
