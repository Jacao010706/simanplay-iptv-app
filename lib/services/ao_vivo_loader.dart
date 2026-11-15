import 'package:http/http.dart' as http;

import '../core/m3u_service.dart';
import '../models/app_session.dart';
import '../models/category.dart';
import '../models/channel.dart';
import 'xtream_service.dart';

/// Pastas e canais da aba Ao Vivo.
class ListaAoVivo {
  final List<Category> categorias;
  final List<Channel> canais;
  const ListaAoVivo(this.categorias, this.canais);
}

/// Escolhe de onde vêm os canais da aba Ao Vivo:
/// - conta Xtream: API (erros aparecem para o usuário, como antes);
/// - lista M3U com usuário e senha no link (get.php): API; se ela falhar (rede, conta
///   recusada, resposta inválida, servidor sem player_api.php) ou vier vazia, cai no M3U
///   sem mostrar erro;
/// - lista M3U sem credenciais: M3U, só com os canais ao vivo.
class CarregadorAoVivo {
  static Future<ListaAoVivo> carregar(AppSession session, {http.Client? client}) async {
    if (session.isXtream) return _xtream(session, client);
    if (session.hasXtreamAccess) {
      try {
        final api = await _xtream(session, client);
        if (api.canais.isNotEmpty) return api;
      } catch (_) {
        // Sem erro na tela: tenta o M3U
      }
    }
    return _m3u(session, client);
  }

  static Future<ListaAoVivo> _xtream(AppSession s, http.Client? client) async {
    final svc = XtreamService(
      host: s.effectiveXtreamHost!,
      username: s.effectiveXtreamUsername!,
      password: s.effectiveXtreamPassword!,
      client: client,
    );
    // Uma chamada para as categorias e uma para todos os canais; pastas só das
    // categorias de get_live_categories que ficaram com canais
    final cats = await svc.getLivePastas();
    final canais = await svc.getAllLiveStreams();
    return ListaAoVivo(cats, canais);
  }

  static Future<ListaAoVivo> _m3u(AppSession s, http.Client? client) async {
    final url = s.primaryM3uUrl ?? '';
    if (url.isEmpty) throw Exception('URL da playlist não configurada');
    final canais = await M3uService(client: client).fetchAoVivo(url);
    // Pastas pelo group-title, na ordem da lista, só dos canais mantidos
    final cats = canais
        .map((c) => c.categoryName)
        .toSet()
        .map((name) => Category(id: name, name: name, type: 'live'))
        .toList();
    return ListaAoVivo(cats, canais);
  }
}
