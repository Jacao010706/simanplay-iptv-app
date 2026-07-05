with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\home_screen_v2.dart", "r", encoding="utf-8") as f:
    content = f.read()

OLD = """      Stack(children: [
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

NEW = """      Stack(children: [
        // Fundo escuro
        Container(height: 280, width: double.infinity, color: const Color(0xFF050508)),
        // Poster centralizado com altura maior
        if (feat?.posterUrl != null)
          Positioned(top: 0, bottom: 0, left: 0, right: 0,
            child: Center(child: Image.network(feat!.posterUrl!, height: 280, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox()))),
        // Gradiente esquerda forte para esconder borda do poster
        Positioned.fill(child: Container(decoration: const BoxDecoration(gradient: LinearGradient(
          begin: Alignment.centerLeft, end: Alignment.centerRight,
          stops: [0.0, 0.25, 0.65, 1.0],
          colors: [Color(0xFF050508), Color(0x99050508), Colors.transparent, Color(0xFF050508)])))),
        // Gradiente inferior
        Positioned.fill(child: Container(decoration: const BoxDecoration(gradient: LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          stops: [0.0, 0.4, 1.0],
          colors: [Color(0xFF0a0a0a), Color(0x88050508), Colors.transparent])))),
        // Info sobreposta
        Positioned(bottom: 16, left: 20, right: 20, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: p.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(4)),
            child: Text('EM DESTAQUE', style: TextStyle(color: p, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1))),
          const SizedBox(height: 6),
          if (feat != null) Text(feat.name ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black, blurRadius: 12), Shadow(color: Colors.black, blurRadius: 24)]), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 12),
          Row(children: [
            ElevatedButton.icon(onPressed: () => onNav(2), icon: const Icon(Icons.play_arrow, size: 18), label: const Text('Assistir'),
              style: ElevatedButton.styleFrom(backgroundColor: p, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10))),
            const SizedBox(width: 10),
            OutlinedButton(onPressed: () => onNav(2), style: OutlinedButton.styleFrom(side: BorderSide(color: p.withValues(alpha: 0.7)), padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10)),
              child: Text('+ Info', style: TextStyle(color: p))),
          ]),
        ])),
      ]),"""

count = content.count(OLD)
if count != 1:
    print(f"ERRO: bloco encontrado {count} vez(es). Abortando.")
    exit(1)

content = content.replace(OLD, NEW)

with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\home_screen_v2.dart", "w", encoding="utf-8") as f:
    f.write(content)

print("OK! Banner Tema 4 melhorado.")