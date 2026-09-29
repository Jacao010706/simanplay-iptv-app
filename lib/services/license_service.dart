import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_config.dart';

/// Situação da licença de uso do app neste aparelho.
class LicenseState {
  final String deviceCode; // ex.: K7M4-Q2XP
  final String status; // trial | active | expired
  final bool allowed;
  final int daysLeft;
  final DateTime? until;
  final String payUrl;
  final String? plan; // último plano pago (null = nunca pagou)
  final bool offline; // resposta veio do cache (sem internet)

  const LicenseState({
    required this.deviceCode,
    required this.status,
    required this.allowed,
    required this.daysLeft,
    required this.until,
    required this.payUrl,
    this.plan,
    this.offline = false,
  });

  factory LicenseState.fromJson(Map<String, dynamic> j, {bool offline = false}) {
    return LicenseState(
      deviceCode: (j['device_code'] ?? '').toString(),
      status: (j['status'] ?? 'expired').toString(),
      allowed: j['allowed'] == true,
      daysLeft: (j['days_left'] is int) ? j['days_left'] as int : int.tryParse('${j['days_left']}') ?? 0,
      until: j['until'] != null ? DateTime.tryParse(j['until'].toString()) : null,
      payUrl: (j['pay_url'] ?? '').toString(),
      plan: j['plan']?.toString(),
      offline: offline,
    );
  }

  bool get isTrial => status == 'trial';
}

/// Teste grátis de 7 dias + planos pagos no site (PIX). O app só consulta o servidor.
class LicenseService {
  static const _kCode = 'license_device_code';
  static const _kCache = 'license_last_state';
  static const _channel = MethodChannel('primetv/device');
  static const _timeout = Duration(seconds: 15);

  static String get _platform {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isMacOS) return 'macos';
    return 'outro';
  }

  static Future<String?> _hardwareId() async {
    if (kIsWeb || !Platform.isAndroid) return null;
    try {
      return await _channel.invokeMethod<String>('androidId');
    } catch (_) {
      return null;
    }
  }

  static Future<LicenseState> _post(String path, Map<String, dynamic> body) async {
    final res = await http
        .post(Uri.parse('${AppConfig.backendUrl}$path'),
            headers: {'Content-Type': 'application/json'}, body: jsonEncode(body))
        .timeout(_timeout);
    if (res.statusCode == 404) throw const _NotFound();
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    return LicenseState.fromJson(jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>);
  }

  static Future<LicenseState> _register(SharedPreferences prefs) async {
    final st = await _post('/license/register', {
      'hw_id': await _hardwareId(),
      'platform': _platform,
      'app_version': AppConfig.appVersion,
    });
    await prefs.setString(_kCode, st.deviceCode);
    return st;
  }

  /// Consulta (ou cria) a licença deste aparelho.
  /// Sem internet, usa a última resposta salva enquanto ela ainda estiver válida.
  static Future<LicenseState> check() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      final code = prefs.getString(_kCode);
      LicenseState st;
      if (code == null || code.isEmpty) {
        st = await _register(prefs);
      } else {
        try {
          st = await _post('/license/check', {
            'device_code': code,
            'platform': _platform,
            'app_version': AppConfig.appVersion,
          });
        } on _NotFound {
          st = await _register(prefs);
        }
      }
      await prefs.setString(_kCache, jsonEncode({
        'device_code': st.deviceCode,
        'status': st.status,
        'allowed': st.allowed,
        'days_left': st.daysLeft,
        'until': st.until?.toIso8601String(),
        'pay_url': st.payUrl,
        'plan': st.plan,
      }));
      return st;
    } catch (_) {
      return _fromCache(prefs);
    }
  }

  static LicenseState _fromCache(SharedPreferences prefs) {
    final raw = prefs.getString(_kCache);
    if (raw == null) {
      // Primeiro uso sem internet: deixa abrir (as listas também precisam de internet)
      return LicenseState(
        deviceCode: prefs.getString(_kCode) ?? '',
        status: 'trial',
        allowed: true,
        daysLeft: 0,
        until: null,
        payUrl: '',
        offline: true,
      );
    }
    final cached = LicenseState.fromJson(jsonDecode(raw) as Map<String, dynamic>, offline: true);
    final stillValid = cached.until != null && cached.until!.isAfter(DateTime.now().toUtc());
    return LicenseState(
      deviceCode: cached.deviceCode,
      status: stillValid ? cached.status : 'expired',
      allowed: cached.allowed && stillValid,
      daysLeft: cached.daysLeft,
      until: cached.until,
      payUrl: cached.payUrl,
      plan: cached.plan,
      offline: true,
    );
  }
}

class _NotFound implements Exception {
  const _NotFound();
}
