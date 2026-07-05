with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\home_screen_v2.dart", "r", encoding="utf-8") as f:
    content = f.read()

# O Tema 5 usa _IBO5Home que tem seu proprio banner
# Vamos corrigir o banner do _IBO5Home para usar poster lateral

OLD = """    GestureDetector(onTap: () => onNav(2), child: Stack(children: [
        Container(height: 300, width: double.infinity, color: const Color(0xFF1a1a2e),
          child: feat?.posterUrl != null ? Image.network(feat!.posterUrl!, fit: BoxFit.cover, width: double.infinity, height: 300, errorBuilder: (_, __, ___) => const SizedBox()) : Center(child: Icon(Icons.movie, size: 80, color: p.withValues(alpha: 0.3)))),
        Positioned.fill(child: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xFF0f0f1a)])))),
        Positioned(bottom: 20, left: 20, right: 20, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (feat != null) Text(feat.name ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold), maxLines: 2),
          const SizedBox(height: 10),
          Row(children: [
            ElevatedButton.icon(onPressed: () => onNav(2), icon: const Icon(Icons.play_arrow, size: 18), label: const Text('Assistir'), style: ElevatedButton.styleFrom(backgroundColor: p, foregroundColor: Colors.white)),
            const SizedBox(width: 10),
            OutlinedButton(onPressed: () => onNav(3), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54)), child: const Text('Series', style: TextStyle(color: Colors.white))),
          ]),
        ])),
      ])),"""

NEW = """    GestureDetector(onTap: () => onNav(2), child: Container(height: 220, width: double.infinity, color: const Color(0xFF0f0f1a),
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        // Poster lateral esquerdo
        if (feat?.posterUrl != null)
          Image.network(feat!.posterUrl!, width: 150, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 150)),
        // Gradiente + info
        Expanded(child: Container(
          decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight,
            colors: [Color(0xFF0f0f1a), Color(0xFF0a0a14)])),
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: p.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
              child: Text('EM DESTAQUE', style: TextStyle(color: p, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1))),
            const SizedBox(height: 10),
            if (feat != null) Text(feat.name ?? '', style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold), maxLines: 3, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 14),
            Row(children: [
              ElevatedButton.icon(onPressed: () => onNav(2), icon: const Icon(Icons.play_arrow, size: 16), label: const Text('Assistir', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(backgroundColor: p, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8))),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: () => onNav(3), style: OutlinedButton.styleFrom(side: BorderSide(color: p.withValues(alpha: 0.7)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                child: Text('Series', style: TextStyle(color: p, fontSize: 12))),
            ]),
          ])),
        ),
      ]))),"""

count = content.count(OLD)
if count != 1:
    print(f"ERRO: encontrado {count} vez(es). Abortando.")
    exit(1)

content = content.replace(OLD, NEW)

with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\home_screen_v2.dart", "w", encoding="utf-8") as f:
    f.write(content)

print("OK! Banner Tema 5 corrigido com poster lateral.")