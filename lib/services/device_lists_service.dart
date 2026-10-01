import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_config.dart';
import '../core/text_fix.dart';
import '../models/app_session.dart';

/// Lista cadastrada no site para este aparelho (MAC + chave), estilo IBO Player.
class DevicePlaylist {
  final int id;
  final String name;
  final String type; // xtream | m3u
  final String? host;
  final String? username;
  final String? password;
  final String? m3uUrl;

  const DevicePlaylist({
    required this.id,
    required this.name,
    required this.type,
    this.host,
    this.username,
    this.password,
    this.m3uUrl,
  });

  factory DevicePlaylist.fromJson(Map<String, dynamic> j) => DevicePlaylist(
        id: j['id'] is int ? j['id'] as int : int.tryParse('${j['id']}') ?? 0,
        name: (j['name'] ?? '').toString(),
        type: (j['type'] ?? 'm3u').toString(),
        host: j['xtream_host']?.toString(),
        username: j['xtream_username']?.toString(),
        password: j['xtream_password']?.toString(),
        m3uUrl: j['m3u_url']?.toString(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'xtream_host': host,
        'xtream_username': username,
        'xtream_password': password,
        'm3u_url': m3uUrl,
      };

  bool get isXtream => type == 'xtream';

  String get subtitle => isXtream ? 'Xtream · ${host ?? ''}' : 'Lista M3U';

  AppSession toSession() => isXtream
      ? AppSession.xtream(host: host ?? '', username: username ?? '', password: password ?? '')
      : AppSession.simanplay(username: 'm3u', password: '', primaryM3uUrl: m3uUrl ?? '');
}

class DeviceListsService {
  static const _kCache = 'device_playlists_cache';

  /// Baixa as listas do aparelho. Sem internet, devolve as últimas salvas.
  static Future<List<DevicePlaylist>> fetch({required String mac, required String key}) async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final res = await http
          .post(Uri.parse('${AppConfig.backendUrl}/license/device/login'),
              headers: {'Content-Type': 'application/json'}, body: jsonEncode({'mac': mac, 'key': key}))
          .timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final data = decodeJson(res) as Map<String, dynamic>;
      final items = (data['playlists'] as List? ?? [])
          .map((e) => DevicePlaylist.fromJson(e as Map<String, dynamic>))
          .toList();
      await prefs.setString(_kCache, jsonEncode(items.map((p) => p.toJson()).toList()));
      return items;
    } catch (_) {
      final raw = prefs.getString(_kCache);
      if (raw == null) rethrow;
      return (fixTextTree(jsonDecode(raw)) as List).map((e) => DevicePlaylist.fromJson(e as Map<String, dynamic>)).toList();
    }
  }

  /// Endereço do site de cadastro (o QR Code aponta para cá já com o MAC).
  static String siteUrl(String mac) =>
      'https://simanplay-iptv-admin-panel.vercel.app/dispositivo?mac=${mac.replaceAll(':', '')}';

  static const siteShort = 'simanplay-iptv-admin-panel.vercel.app/dispositivo';
}
