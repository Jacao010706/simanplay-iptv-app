with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\home_screen_v2.dart", "r", encoding="utf-8") as f:
    content = f.read()

OLD = '''      if (liveCats.isNotEmpty) {
        final ch = await service.getLiveStreams(liveCats[0].id, liveCats[0].name);
        _channels = ch.take(10).toList();
      }
      if (movieCats.isNotEmpty) {
        final mv = await service.getMovies(movieCats[0].id, movieCats[0].name);
        _movies = mv.take(10).toList();
      }
      if (seriesCats.isNotEmpty) {
        final sr = await service.getSeries(seriesCats[0].id, seriesCats[0].name);
        _series = sr.take(10).toList();
      }'''

NEW = '''      // Canais: pega de até 5 categorias diferentes e mistura
      if (liveCats.isNotEmpty) {
        final cats = liveCats.take(5).toList();
        final List<dynamic> allCh = [];
        for (final cat in cats) {
          final ch = await service.getLiveStreams(cat.id, cat.name);
          allCh.addAll(ch.take(3));
          if (allCh.length >= 15) break;
        }
        allCh.shuffle();
        _channels = allCh.take(10).toList();
      }
      // Filmes: pega de até 3 categorias diferentes
      if (movieCats.isNotEmpty) {
        final cats = movieCats.take(3).toList();
        final List<dynamic> allMv = [];
        for (final cat in cats) {
          final mv = await service.getMovies(cat.id, cat.name);
          allMv.addAll(mv.take(4));
          if (allMv.length >= 12) break;
        }
        allMv.shuffle();
        _movies = allMv.take(10).toList();
      }
      // Series: pega de até 3 categorias diferentes
      if (seriesCats.isNotEmpty) {
        final cats = seriesCats.take(3).toList();
        final List<dynamic> allSr = [];
        for (final cat in cats) {
          final sr = await service.getSeries(cat.id, cat.name);
          allSr.addAll(sr.take(4));
          if (allSr.length >= 12) break;
        }
        allSr.shuffle();
        _series = allSr.take(10).toList();
      }'''

count = content.count(OLD)
if count != 1:
    print(f"ERRO: bloco encontrado {count} vez(es). Abortando.")
    exit(1)

content = content.replace(OLD, NEW)

with open(r"C:\Users\Jacques\iptv-player-app\lib\screens\home_screen_v2.dart", "w", encoding="utf-8") as f:
    f.write(content)

print("OK! Canais agora pegam de multiplas categorias.")