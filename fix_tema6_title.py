with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\home_screen_v2.dart", "r", encoding="utf-8") as f:
    content = f.read()

# Remove o texto SimanPlay IPTV que aparece no banner do Tema 6
OLD = """            Positioned(bottom: 16, left: 16, right: 16, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(AppConfig.appName, style: TextStyle(color: p, fontSize: 14, fontWeight: FontWeight.bold)),
              if (mv.isNotEmpty) Text(mv[0].name ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1),
              const SizedBox(height: 8),
              Row(children: [
                ElevatedButton(onPressed: () => onNav(2), style: ElevatedButton.styleFrom(backgroundColor: p, foregroundColor: Colors.white, minimumSize: const Size(100, 36)), child: const Text('Assistir')),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: () => onNav(1), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white38), minimumSize: const Size(80, 36)), child: const Text('Live TV', style: TextStyle(color: Colors.white))),
              ]),
            ])),"""

NEW = """            Positioned(bottom: 16, left: 16, right: 16, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (mv.isNotEmpty) Text(mv[0].name ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 8)]), maxLines: 2),
              const SizedBox(height: 10),
              Row(children: [
                ElevatedButton.icon(onPressed: () => onNav(2), icon: const Icon(Icons.play_arrow, size: 18), label: const Text('Assistir'),
                  style: ElevatedButton.styleFrom(backgroundColor: p, foregroundColor: Colors.white, minimumSize: const Size(100, 38))),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: () => onNav(1), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54), minimumSize: const Size(80, 38)),
                  child: const Text('Live TV', style: TextStyle(color: Colors.white))),
              ]),
            ])),"""

count = content.count(OLD)
if count != 1:
    print(f"ERRO: encontrado {count} vez(es). Abortando.")
    exit(1)

content = content.replace(OLD, NEW)

with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\home_screen_v2.dart", "w", encoding="utf-8") as f:
    f.write(content)

print("OK! Titulo duplicado removido do Tema 6.")