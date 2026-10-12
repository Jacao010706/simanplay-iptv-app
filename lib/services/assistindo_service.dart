import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_config.dart';

/// "Assistindo agora": o app avisa o painel (admin e revendedor do cliente) que está aberto e o
/// que está tocando. O vídeo não passa pelo nosso servidor, por isso o aviso vem do app:
/// ao entrar, ao abrir ou fechar o player, a cada 30 s durante o vídeo e a cada 60 s no menu.
///
/// Usa o token que o backend devolve em /app/login e /app/activate (tv_token, vale 30 dias);
/// nunca envia a senha. Sem token (cliente que não é do painel) não avisa nada.
/// Se o painel encerrar a conexão, [derrubado] recebe a mensagem e o player fecha.
class Assistindo {
  Assistindo._();

  static const _kToken = 'assistindo_tv_token';
  static const _kDevice = 'assistindo_device_id';

  static String? _token;
  static String _device = '';
  static String _tipo = 'menu';
  static String _titulo = '';
  static Timer? _timer;
  static int _tick = 0;

  /// Mensagem quando o revendedor encerra a conexão pelo painel.
  static final StreamController<String> derrubado = StreamController<String>.broadcast();

  /// Chamar no início do app: recupera o token salvo (o cliente continua aparecendo online
  /// depois de reabrir o app, sem precisar entrar de novo).
  static Future<void> iniciar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _device = prefs.getString(_kDevice) ?? '';
      if (_device.isEmpty) {
        final r = Random.secure();
        _device = 'and-${List.generate(12, (_) => r.nextInt(36).toRadixString(36)).join()}';
        await prefs.setString(_kDevice, _device);
      }
      final t = prefs.getString(_kToken);
      if (t != null && t.isNotEmpty) _ligar(t);
    } catch (_) {}
  }

  /// Chamar depois do login/ativação com o tv_token do backend (null = saiu da conta).
  static Future<void> configurar(String? token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (token == null || token.isEmpty) {
        await prefs.remove(_kToken);
      } else {
        await prefs.setString(_kToken, token);
      }
    } catch (_) {}
    if (token == null || token.isEmpty) {
      _timer?.cancel();
      _timer = null;
      _token = null;
      _tipo = 'menu';
      _titulo = '';
      return;
    }
    _ligar(token);
  }

  static void _ligar(String token) {
    _token = token;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _tick++;
      if (_tipo != 'menu' || _tick.isEven) _avisar();
    });
    _avisar();
  }

  /// [tipo]: canal, filme, serie ou menu.
  static void conteudo(String tipo, String titulo) {
    if (tipo == _tipo && titulo == _titulo) return;
    _tipo = tipo;
    _titulo = tipo == 'menu' ? '' : titulo;
    _avisar();
  }

  /// Tipo pelo endereço do vídeo do Xtream (/live/, /movie/, /series/).
  static String tipoDaUrl(String url, {bool aoVivo = false}) {
    if (aoVivo || url.contains('/live/')) return 'canal';
    if (url.contains('/series/')) return 'serie';
    return 'filme';
  }

  static Future<void> _avisar() async {
    final token = _token;
    if (token == null) return;
    try {
      final r = await http
          .post(
            Uri.parse('${AppConfig.backendUrl}/app/tv/assistindo'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'token': token,
              'tipo': _tipo,
              'titulo': _titulo,
              'aparelho': 'Android',
              'device': _device,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) {
        final d = jsonDecode(r.body);
        if (d is Map && d['parar'] == true) {
          _tipo = 'menu';
          _titulo = '';
          derrubado.add((d['mensagem'] as String?) ?? 'Sua conexão foi encerrada.');
        }
      } else if (r.statusCode == 401) {
        // Token vencido ou senha trocada: para de avisar até o próximo login
        await configurar(null);
      }
    } catch (_) {
      // Sem internet: tenta de novo no próximo ciclo
    }
  }
}
