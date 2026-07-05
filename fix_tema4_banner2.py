with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\home_screen_v2.dart", "r", encoding="utf-8") as f:
    content = f.read()

OLD = """      Container(height: 220, width: double.infinity, color: const Color(0xFF1a1a2e),
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Poster lateral
          if (feat?.posterUrl != null)
            ClipRRect(borderRadius: const BorderRadius.only(topRight: Radius.circular(8), bottomRight: Radius.circular(8)),
              child: Image.network(feat!.posterUrl!, width: 140, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox(width: 140))),
          // Info lateral
          Expanded(child: Container(
            decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.centerLeft, end: Alignment.centerRight, colors: [Color(0xFF1a1a2e), Color(0xFF0a0a0a)])),
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: p.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                child: Text('EM DESTAQUE', style: TextStyle(color: p, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1))),
              const SizedBox(height: 10),
              if (feat != null) Text(feat.name ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 3, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 16),
              Row(children: [
                ElevatedButton.icon(onPressed: () => onNav(2), icon: const Icon(Icons.play_arrow, size: 16), label: const Text('Assistir', style: TextStyle(fontSize: 12)),
                  style: ElevatedButton.styleFrom(backgroundColor: p, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8))),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: () => onNav(2), style: OutlinedButton.styleFrom(side: BorderSide(color: p), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                  child: Text('+ Info', style: TextStyle(color: p, fontSize: 12))),
              ]),
            ])),
          ),
        ])),"""

NEW = """      Stack(children: [
        // Fundo com poster centralizado sem distorcao
        Container(height: 240, width: double.infinity, color: const Color(0xFF0a0a0a),
          child: feat?.posterUrl != null
            ? Image.network(feat!.posterUrl!, height: 240, width: double.infinity, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox())
            : const SizedBox()),
        // Gradiente lateral e inferior
        Container(height: 240, decoration: const BoxDecoration(gradient: LinearGradient(
          begin: Alignment.centerLeft, end: Alignment.centerRight,
          colors: [Color(0xFF0a0a0a), Colors.transparent, Colors.transparent, Color(0xFF0a0a0a)]))),
        Container(height: 240, decoration: BoxDecoration(gradient: LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          colors: [const Color(0xFF0a0a0a), Colors.transparent.withValues(alpha: 0)]))),
        // Info sobreposta na parte inferior
        Positioned(bottom: 12, left: 20, right: 20, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: p.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(4)),
              child: Text('EM DESTAQUE', style: TextStyle(color: p, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1))),
            const SizedBox(height: 6),
            if (feat != null) Text(feat.name ?? '', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 8)]), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 10),
            Row(children: [
              ElevatedButton.icon(onPressed: () => onNav(2), icon: const Icon(Icons.play_arrow, size: 16), label: const Text('Assistir', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(backgroundColor: p, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8))),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: () => onNav(2), style: OutlinedButton.styleFrom(side: BorderSide(color: p.withValues(alpha: 0.7)), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
                child: Text('+ Info', style: TextStyle(color: p, fontSize: 12))),
            ]),
          ])),
        ])),
      ]),"""

count = content.count(OLD)
if count != 1:
    print(f"ERRO: bloco encontrado {count} vez(es). Abortando.")
    exit(1)

content = content.replace(OLD, NEW)

with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\home_screen_v2.dart", "w", encoding="utf-8") as f:
    f.write(content)

print("OK! Banner do Tema 4 corrigido com poster centralizado.")