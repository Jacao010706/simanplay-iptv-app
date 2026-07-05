with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\home_screen_v2.dart", "r", encoding="utf-8") as f:
    content = f.read()

# 1. Corrige o carregamento de canais para pegar 1 por categoria
OLD_LOAD_CH = """    if (liveCats.isNotEmpty) {
      final all = <dynamic>[];
      for (final c in liveCats.take(5)) { all.addAll(await svc.getLiveStreams(c.id, c.name)); if (all.length >= 20) break; }
      all.shuffle(); result['channels'] = all.take(12).toList();
    }"""

NEW_LOAD_CH = """    if (liveCats.isNotEmpty) {
      final all = <dynamic>[];
      // Pega o primeiro canal de cada categoria (sem duplicar)
      for (final c in liveCats.take(20)) {
        final ch = await svc.getLiveStreams(c.id, c.name);
        if (ch.isNotEmpty) all.add(ch.first);
        if (all.length >= 15) break;
      }
      result['channels'] = all;
    }"""

count = content.count(OLD_LOAD_CH)
if count != 1:
    print(f"ERRO channels: encontrado {count} vez(es).")
    exit(1)
content = content.replace(OLD_LOAD_CH, NEW_LOAD_CH)
print("channels load OK")

# 2. Reorganiza a ordem das listas no Tema 4 (TV ao Vivo primeiro)
OLD_ORDER = """        if (!loading) ...[_hList('Filmes em Destaque', mv, const Color(0xFF4b7bff), () => onNav(2)), _hList('Series Populares', sr, const Color(0xFF00c896), () => onNav(3)), _hList('TV ao Vivo', ch, p, () => onNav(1), isChannel: true)],"""

NEW_ORDER = """        if (!loading) ...[_hList('TV ao Vivo', ch, p, () => onNav(1), isChannel: true), _hList('Filmes em Destaque', mv, const Color(0xFF4b7bff), () => onNav(2)), _hList('Series Populares', sr, const Color(0xFF00c896), () => onNav(3))],"""

count2 = content.count(OLD_ORDER)
if count2 != 1:
    print(f"ERRO order: encontrado {count2} vez(es).")
    exit(1)
content = content.replace(OLD_ORDER, NEW_ORDER)
print("order OK")

# 3. Corrige o banner para aparecer corretamente
OLD_BANNER = """      Stack(children: [
        // Fundo escuro
        Container(height: 280, width: double.infinity, color: const Color(0xFF050508)),
        // Poster centralizado com altura maior
        if (feat?.posterUrl != null)
          Positioned(top: 0, bottom: 0, left: 0, right: 0,
            child: Center(child: Image.network(feat!.posterUrl!, height: 280, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const SizedBox()))),"""

NEW_BANNER = """      Stack(children: [
        // Fundo escuro
        SizedBox(height: 260, width: double.infinity, child: Container(color: const Color(0xFF050508))),
        // Poster centralizado
        SizedBox(height: 260, width: double.infinity,
          child: feat?.posterUrl != null
            ? Image.network(feat!.posterUrl!, height: 260, width: double.infinity, fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const SizedBox())
            : const SizedBox()),"""

count3 = content.count(OLD_BANNER)
if count3 != 1:
    print(f"ERRO banner: encontrado {count3} vez(es).")
    exit(1)
content = content.replace(OLD_BANNER, NEW_BANNER)
print("banner OK")

# 4. Corrige altura dos gradientes e info
OLD_GRAD = """        // Gradiente esquerda forte para esconder borda do poster
        Positioned.fill(child: Container(decoration: const BoxDecoration(gradient: LinearGradient(
          begin: Alignment.centerLeft, end: Alignment.centerRight,
          stops: [0.0, 0.25, 0.65, 1.0],
          colors: [Color(0xFF050508), Color(0x99050508), Colors.transparent, Color(0xFF050508)])))),
        // Gradiente inferior
        Positioned.fill(child: Container(decoration: const BoxDecoration(gradient: LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          stops: [0.0, 0.4, 1.0],
          colors: [Color(0xFF0a0a0a), Color(0x88050508), Colors.transparent])))),"""

NEW_GRAD = """        // Gradiente lateral
        SizedBox(height: 260, width: double.infinity, child: Container(decoration: const BoxDecoration(gradient: LinearGradient(
          begin: Alignment.centerLeft, end: Alignment.centerRight,
          stops: [0.0, 0.2, 0.7, 1.0],
          colors: [Color(0xFF050508), Color(0x99050508), Colors.transparent, Color(0xFF050508)])))),
        // Gradiente inferior
        SizedBox(height: 260, width: double.infinity, child: Container(decoration: const BoxDecoration(gradient: LinearGradient(
          begin: Alignment.bottomCenter, end: Alignment.topCenter,
          stops: [0.0, 0.5, 1.0],
          colors: [Color(0xFF0a0a0a), Color(0x88050508), Colors.transparent])))),"""

count4 = content.count(OLD_GRAD)
if count4 != 1:
    print(f"ERRO grad: encontrado {count4} vez(es).")
    exit(1)
content = content.replace(OLD_GRAD, NEW_GRAD)
print("gradient OK")

with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\home_screen_v2.dart", "w", encoding="utf-8") as f:
    f.write(content)

print("OK! Tema 4 corrigido.")