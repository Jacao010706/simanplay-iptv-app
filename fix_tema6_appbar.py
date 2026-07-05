with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\home_screen_v2.dart", "r", encoding="utf-8") as f:
    content = f.read()

OLD = """      SliverAppBar(expandedHeight: 280, floating: false, pinned: true, backgroundColor: const Color(0xFF0d0d0d),
        automaticallyImplyLeading: false,
        title: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          if (session.expiresAt != null) Text('Vence: \${_fmtDate(session.expiresAt!)}', style: const TextStyle(color: Colors.white54, fontSize: 10)),
          const SizedBox(width: 8),
          IconButton(icon: const Icon(Icons.logout, color: Colors.white38, size: 20), onPressed: onLogout),
        ]),"""

NEW = """      SliverAppBar(expandedHeight: 280, floating: false, pinned: false, backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: null,"""

count = content.count(OLD)
if count != 1:
    print(f"ERRO: encontrado {count} vez(es). Abortando.")
    exit(1)

content = content.replace(OLD, NEW)

# Move logout e vencimento para dentro do banner
OLD_BANNER_INFO = """            Positioned(bottom: 16, left: 16, right: 16, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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

NEW_BANNER_INFO = """            Positioned(top: 8, right: 8, child: Row(children: [
              if (session.expiresAt != null) Text('Vence: \${_fmtDate(session.expiresAt!)}', style: const TextStyle(color: Colors.white54, fontSize: 10)),
              IconButton(icon: const Icon(Icons.logout, color: Colors.white54, size: 20), onPressed: onLogout),
            ])),
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
            ])),"""

count2 = content.count(OLD_BANNER_INFO)
if count2 != 1:
    print(f"ERRO banner: encontrado {count2} vez(es). Abortando.")
    exit(1)

content = content.replace(OLD_BANNER_INFO, NEW_BANNER_INFO)

# Remove actions que ficaram sobrando
OLD_ACTIONS = """        actions: [
          if (session.expiresAt != null) Center(child: Padding(padding: const EdgeInsets.only(right: 8), child: Text('Vence: \${_fmtDate(session.expiresAt!)}', style: const TextStyle(color: Colors.white54, fontSize: 10)))),
          IconButton(icon: const Icon(Icons.logout, color: Colors.white38, size: 20), onPressed: onLogout),
        ]),"""

NEW_ACTIONS = """        actions: []),"""

count3 = content.count(OLD_ACTIONS)
if count3 != 1:
    print(f"ERRO actions: encontrado {count3} vez(es). Abortando.")
    exit(1)

content = content.replace(OLD_ACTIONS, NEW_ACTIONS)

with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\home_screen_v2.dart", "w", encoding="utf-8") as f:
    f.write(content)

print("OK! Tema 6 AppBar corrigido.")