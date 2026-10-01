import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/text_fix.dart';
import '../models/client_session.dart';
import '../models/app_session.dart';
import '../core/app_config.dart';

class ApiService {
  static Future<ClientSession> activateByMac({
    required String macAddress,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.backendUrl}/app/activate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'mac_address': macAddress}),
    );
    if (response.statusCode == 200) {
      final json = jsonDecode(decodeBody(response)) as Map<String, dynamic>;
      return ClientSession.fromJson(json);
    } else if (response.statusCode == 403) {
      throw Exception('Dispositivo não ativado');
    } else {
      throw Exception('Erro ao ativar dispositivo (${response.statusCode})');
    }
  }

  static Future<ClientSession> login({
    required String username,
    required String password,
    String? macAddress,
  }) async {
    final response = await http.post(
      Uri.parse('${AppConfig.backendUrl}/app/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        if (macAddress != null) 'mac_address': macAddress,
      }),
    );
    if (response.statusCode == 200) {
      final json = jsonDecode(decodeBody(response)) as Map<String, dynamic>;
      return ClientSession.fromJson(json);
    } else if (response.statusCode == 401) {
      throw Exception('Usuário ou senha inválidos');
    } else {
      throw Exception('Erro ao conectar ao servidor (${response.statusCode})');
    }
  }

  /// Converte ClientSession → AppSession com todos os campos necessários.
  /// Use este método nos dois lugares do activation_screen_v3.dart
  /// onde hoje você monta AppSession.simanplay() manualmente.
  static AppSession buildSession(
    ClientSession cs, {
    String? manualUsername,
    String? manualPassword,
  }) {
    return AppSession.simanplay(
      username: manualUsername ?? cs.username ?? '',
      password: manualPassword ?? '',
      primaryM3uUrl: cs.primaryUrl ?? '',
      backupM3uUrls: cs.backupPlaylists
          .map((b) => b.playlistUrl ?? '')
          .where((u) => u.isNotEmpty)
          .toList(),
      expiresAt: cs.expiresAt,
      xtreamHost: cs.xtreamHost,
      xtreamUsername: cs.xtreamUsername,
      xtreamPassword: cs.xtreamPassword,
      clientId: cs.clientId,
      resellerSlug: cs.resellerSlug,
    );
  }
}
