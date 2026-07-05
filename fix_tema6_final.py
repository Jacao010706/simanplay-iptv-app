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
              if (mv.isNotEmpty) Text(mv[0].name ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 8)]), maxLines: 2),
              const SizedBox(height: 10),
              Row(children: [
                ElevatedButton.icon(onPressed: () => onNav(2), icon: const Icon(Icons.play_arrow, size: 18), label: const Text('Assistir'),
                  style: ElevatedButton.styleFrom(backgroundColor: p, foregroundColor: Colors.white, minimumSize: const Size(100, 38))),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: () => onNav(1), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54), minimumSize: const Size(80, 38)),
                  child: const Text('Live TV', style: TextStyle(color: Colors.white))),
              ]),
            ])),
          ]),
          title: Row(children: [Icon(Icons.live_tv, color: p, size: 18), const SizedBox(width: 6), Text(AppConfig.appName, style: const TextStyle(fontSize: 14))]),
        ),
        actions: [
          if (session.expiresAt != null) Center(child: Padding(padding: const EdgeInsets.only(right: 8), child: Text('Vence: ${_fmtDate(session.expiresAt!)}', style: const TextStyle(color: Colors.white54, fontSize: 10)))),
          IconButton(icon: const Icon(Icons.logout, color: Colors.white38, size: 20), onPressed: onLogout),
        ]),
      SliverToBoxAdapter(child: loading
        ? const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
        : Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            _hList('Filmes', mv, const Color(0xFF4b7bff), () => onNav(2)),
            _hList('Series', sr, const Color(0xFF00c896), () => onNav(3)),
            _hList('TV ao Vivo', ch, p, () => onNav(1), isChannel: true),
          ]))),"""

NEW = """      SliverAppBar(expandedHeight: 280, floating: false, pinned: false, backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        flexibleSpace: FlexibleSpaceBar(
          collapseMode: CollapseMode.pin,
          background: Stack(children: [
            mv.isNotEmpty && mv[0].posterUrl != null
              ? Image.network(mv[0].posterUrl!, fit: BoxFit.cover, width: double.infinity, height: 280, errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1a1a2e)))
              : Container(color: const Color(0xFF1a1a2e)),
            Positioned.fill(child: Container(decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xFF0d0d0d)])))),
            Positioned(top: 8, right: 8, child: SafeArea(child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (session.expiresAt != null) Text('Vence: \${_fmtDate(session.expiresAt!)}', style: const TextStyle(color: Colors.white54, fontSize: 10)),
              const SizedBox(width: 4),
              GestureDetector(onTap: onLogout, child: const Icon(Icons.logout, color: Colors.white54, size: 20)),
              const SizedBox(width: 8),
            ]))),
            Positioned(bottom: 16, left: 16, right: 16, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (mv.isNotEmpty) Text(mv[0].name ?? '', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black, blurRadius: 8)]), maxLines: 2),
              const SizedBox(height: 10),
              Row(children: [
                ElevatedButton.icon(onPressed: () => onNav(2), icon: const Icon(Icons.play_arrow, size: 18), label: const Text('Assistir'),
                  style: ElevatedButton.styleFrom(backgroundColor: p, foregroundColor: Colors.white, minimumSize: const Size(100, 38))),
                const SizedBox(width: 8),
                OutlinedButton(onPressed: () => onNav(1), style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white54), minimumSize: const Size(80, 38)),
                  child: const Text('Live TV', style: TextStyle(color: Colors.white))),
              ]),
            ])),
          ]),
        )),
      SliverToBoxAdapter(child: loading
        ? const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
        : Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            _hList('TV ao Vivo', ch, p, () => onNav(1), isChannel: true),
            _hList('Filmes', mv, const Color(0xFF4b7bff), () => onNav(2)),
            _hList('Series', sr, const Color(0xFF00c896), () => onNav(3)),
          ]))),"""

count = content.count(OLD)
if count != 1:
    print(f"ERRO: encontrado {count} vez(es). Abortando.")
    exit(1)

content = content.replace(OLD, NEW)

with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\home_screen_v2.dart", "w", encoding="utf-8") as f:
    f.write(content)

print("OK! Tema 6 corrigido - sem titulo duplicado, TV ao Vivo primeiro.")