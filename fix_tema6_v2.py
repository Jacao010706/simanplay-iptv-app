with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\home_screen_v2.dart", "r", encoding="utf-8") as f:
    content = f.read()

OLD = """      SliverAppBar(expandedHeight: 280, floating: false, pinned: true, backgroundColor: const Color(0xFF1a1a1a),
        flexibleSpace: FlexibleSpaceBar(
          background: Stack(children: [
            mv.isNotEmpty && mv[0].posterUrl != null
              ? Image.network(mv[0].posterUrl!, fit: BoxFit.cover, width: double.infinity, height: 280, errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1a1a2e)))
              : Container(color: const Color(0xFF1a1a2e)),
            Positioned.fill(child: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xFF0d0d0d)])))),
            Positioned(bottom: 16, left: 16, right: 16, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(AppConfig.appName, style: TextStyle(color: p, fontSize: 14, fontWeight: FontWeight.bold)),
              if (mv.isNotEmpty) Text(mv[0].name ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1),
              const SizedBox(height: 8),
              Row(children: [
                ElevatedButton(onPressed: () => onNav(2), style: ElevatedButton.styleFrom(backgroundColor: p, foregroundColor: Colors.white, minimumSize: const Size(100, 36)), child: const Text('Assistir')),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: () => onNav(1), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white38), minimumSize: const Size(80, 36)), child: const Text('Live TV', style: TextStyle(color: Colors.white))),
              ]),
            ])),
          ]),
          title: null,
        ),
        actions: [
          if (session.expiresAt != null) Center(child: Padding(padding: const EdgeInsets.only(right: 8), child: Text('Vence: \${_fmtDate(session.expiresAt!)}', style: const TextStyle(color: Colors.white54, fontSize: 10)))),
          IconButton(icon: const Icon(Icons.logout, color: Colors.white38, size: 20), onPressed: onLogout),
        ]),"""

NEW = """      SliverAppBar(expandedHeight: 280, floating: false, pinned: true, backgroundColor: const Color(0xFF0d0d0d),
        automaticallyImplyLeading: false,
        title: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          if (session.expiresAt != null) Text('Vence: \${_fmtDate(session.expiresAt!)}', style: const TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.logout, color: Colors.white38, size: 20), onPressed: onLogout),
        ]),
        flexibleSpace: FlexibleSpaceBar(
          collapseMode: CollapseMode.pin,
          background: Stack(children: [
            mv.isNotEmpty && mv[0].posterUrl != null
              ? Image.network(mv[0].posterUrl!, fit: BoxFit.cover, width: double.infinity, height: 280, errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1a1a2e)))
              : Container(color: const Color(0xFF1a1a2e)),
            Positioned.fill(child: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xFF0d0d0d)])))),
            Positioned(bottom: 16, left: 16, right: 16, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(AppConfig.appName, style: TextStyle(color: p, fontSize: 14, fontWeight: FontWeight.bold)),
              if (mv.isNotEmpty) Text(mv[0].name ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1),
              const SizedBox(height: 8),
              Row(children: [
                ElevatedButton(onPressed: () => onNav(2), style: ElevatedButton.styleFrom(backgroundColor: p, foregroundColor: Colors.white, minimumSize: const Size(100, 36)), child: const Text('Assistir')),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: () => onNav(1), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white38), minimumSize: const Size(80, 36)), child: const Text('Live TV', style: TextStyle(color: Colors.white))),
              ]),
            ])),
          ]),
        )),"""

count = content.count(OLD)
if count != 1:
    print(f"ERRO: encontrado {count} vez(es). Abortando.")
    exit(1)

content = content.replace(OLD, NEW)

with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\home_screen_v2.dart", "w", encoding="utf-8") as f:
    f.write(content)

print("OK! Tema 6 corrigido.")