with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\home_screen_v2.dart", "r", encoding="utf-8") as f:
    content = f.read()

OLD = """      Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        _hList('Filmes', mv, const Color(0xFF4b7bff), () => onNav(2)),
        _hList('Series', sr, const Color(0xFF00c896), () => onNav(3)),
        _hList('TV ao Vivo', ch, p, () => onNav(1), isChannel: true),
      ])),"""

NEW = """      Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        _hList('TV ao Vivo', ch, p, () => onNav(1), isChannel: true),
        _hList('Filmes', mv, const Color(0xFF4b7bff), () => onNav(2)),
        _hList('Series', sr, const Color(0xFF00c896), () => onNav(3)),
      ])),"""

count = content.count(OLD)
if count != 1:
    print(f"ERRO: encontrado {count} vez(es). Abortando.")
    exit(1)

content = content.replace(OLD, NEW)

with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\home_screen_v2.dart", "w", encoding="utf-8") as f:
    f.write(content)

print("OK! Tema 5 com TV ao Vivo na primeira linha.")