import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../core/app_config.dart';
import '../core/plataforma.dart';
import '../core/windows_update_config.dart';

/// Versão mais nova do app Windows anunciada no JSON público ([kWindowsVersionUrl]).
class VersaoWindows {
  final String versao;
  final int build;
  final Uri url;
  final bool obrigatoria;

  const VersaoWindows({required this.versao, required this.build, required this.url, required this.obrigatoria});

  /// Lê o JSON e devolve a versão SE ela for mais nova que [buildInstalado]; senão null.
  /// Qualquer coisa estranha (JSON inválido, sem build, URL que não é https) também dá null.
  static VersaoWindows? seMaisNova(Object? json, int buildInstalado) {
    if (json is! Map || buildInstalado <= 0) return null;
    final versao = '${json['version'] ?? ''}'.trim();
    final mais = versao.lastIndexOf('+');
    final build = int.tryParse(mais < 0 ? '' : versao.substring(mais + 1));
    final url = Uri.tryParse('${json['url'] ?? ''}'.trim());
    if (build == null || build <= buildInstalado) return null;
    if (url == null || url.scheme != 'https' || url.host.isEmpty) return null;
    return VersaoWindows(versao: versao, build: build, url: url, obrigatoria: json['obrigatoria'] == true);
  }
}

/// Aviso de nova versão no PC. Roda em segundo plano depois que o app abriu: falha de rede,
/// demora ou JSON inválido só fazem o aviso não aparecer, nunca travam a abertura.
class AtualizacaoWindows {
  static const _timeout = Duration(seconds: 8);

  static Future<VersaoWindows?> buscar({http.Client? client}) async {
    if (kWindowsVersionUrl.isEmpty) return null;
    try {
      final uri = Uri.parse(kWindowsVersionUrl);
      final res = await (client != null ? client.get(uri) : http.get(uri)).timeout(_timeout);
      if (res.statusCode != 200) return null;
      return VersaoWindows.seMaisNova(jsonDecode(utf8.decode(res.bodyBytes)), AppConfig.buildNumber);
    } catch (_) {
      return null;
    }
  }

  static Future<void> verificar(BuildContext? Function() contexto) async {
    if (!Plataforma.windows) return;
    final nova = await buscar();
    if (nova == null) return;
    final ctx = contexto();
    if (ctx == null || !ctx.mounted) return;
    await mostrarAviso(ctx, nova);
  }

  static Future<void> mostrarAviso(BuildContext context, VersaoWindows nova) {
    const primaria = Color(AppConfig.primaryColor);
    return showDialog<void>(
      context: context,
      barrierDismissible: !nova.obrigatoria,
      builder: (ctx) => PopScope(
        canPop: !nova.obrigatoria,
        child: AlertDialog(
          backgroundColor: const Color(AppConfig.surfaceColor),
          title: const Text('Nova versão do ${AppConfig.appName} disponível',
              style: TextStyle(color: Colors.white)),
          content: Text(
            nova.obrigatoria
                ? 'Esta atualização é necessária para continuar usando o app. Baixe e instale a nova versão.'
                : 'Baixe e instale a nova versão para ter as últimas melhorias.',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            if (!nova.obrigatoria)
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Depois', style: TextStyle(color: Colors.white70)),
              ),
            ElevatedButton(
              autofocus: true,
              style: ElevatedButton.styleFrom(backgroundColor: primaria, foregroundColor: Colors.black),
              onPressed: () async {
                await launchUrl(nova.url, mode: LaunchMode.externalApplication).catchError((_) => false);
                if (!nova.obrigatoria && ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Baixar agora'),
            ),
          ],
        ),
      ),
    );
  }
}
