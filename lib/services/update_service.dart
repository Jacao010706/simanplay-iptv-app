import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:open_file_plus/open_file_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_config.dart';
import '../core/release_notes.dart';

/// Chave global do Navigator: permite mostrar avisos em qualquer tela.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

const Color _primary = Color(AppConfig.primaryColor);
const Color _surface = Color(AppConfig.surfaceColor);

class UpdateService {
  static bool _started = false;

  /// Chamado uma vez ao abrir o app (main.dart). Espera a tela inicial
  /// assentar, mostra as novidades (se o app acabou de ser atualizado)
  /// e depois verifica se existe versao mais nova no servidor.
  static Future<void> runStartupChecks() async {
    if (_started) return;
    _started = true;
    await Future.delayed(const Duration(seconds: 4));
    await _showReleaseNotesIfNeeded();
    final ctx = appNavigatorKey.currentContext;
    if (ctx != null && ctx.mounted) await checkForUpdate(ctx);
  }

  static Future<void> _showReleaseNotesIfNeeded() async {
    // buildNumber 0 = build local de teste (nao veio do CI)
    if (AppConfig.buildNumber <= 0 || ReleaseNotes.items.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSeen = prefs.getInt('last_seen_build') ?? 0;
      if (lastSeen == AppConfig.buildNumber) return;
      await prefs.setInt('last_seen_build', AppConfig.buildNumber);
      final ctx = appNavigatorKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      await showDialog(
        context: ctx,
        builder: (dCtx) => AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(children: [
            Icon(Icons.auto_awesome, color: _primary),
            SizedBox(width: 10),
            Expanded(
              child: Text('App atualizado!',
                  style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ]),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Novidades desta versao:',
                    style: TextStyle(color: Colors.white70, fontSize: 13)),
                const SizedBox(height: 10),
                for (final item in ReleaseNotes.items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  ', style: TextStyle(color: _primary, fontSize: 14)),
                        Expanded(
                          child: Text(item,
                              style: const TextStyle(color: Colors.white, fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              autofocus: true, // controle remoto da TV ja cai neste botao
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.of(dCtx).pop(),
              child: const Text('OK',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (_) {}
  }

  /// Verifica nova versão no backend ao abrir o app.
  /// Se houver, exibe dialog com download automático e instalação.
  static Future<void> checkForUpdate(BuildContext context) async {
    if (AppConfig.resellerUsername.isEmpty) return;

    try {
      final uri = Uri.parse(
        '${AppConfig.backendUrl}/app/check-update'
        '?reseller_username=${Uri.encodeComponent(AppConfig.resellerUsername)}'
        '&current_build=${AppConfig.buildNumber}',
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final serverBuild = (data['build_number'] as num?)?.toInt() ?? 0;
      final apkUrl = data['apk_url'] as String? ?? '';

      if (serverBuild <= AppConfig.buildNumber || apkUrl.isEmpty) return;
      if (!context.mounted) return;

      _showUpdateDialog(context, apkUrl, serverBuild);
    } catch (_) {
      // Sem Internet ou backend indisponível — continua sem interromper
    }
  }

  static void _showUpdateDialog(BuildContext ctx, String apkUrl, int serverBuild) {
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (dialogCtx) => _UpdateDialog(apkUrl: apkUrl, buildNumber: serverBuild),
    );
  }
}

class _UpdateDialog extends StatefulWidget {
  final String apkUrl;
  final int buildNumber;
  const _UpdateDialog({required this.apkUrl, required this.buildNumber});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  double? _progress; // null = aguardando confirmação, 0-1 = baixando
  String? _error;

  Future<void> _downloadAndInstall() async {
    setState(() { _progress = 0; _error = null; });

    try {
      final dir = await getTemporaryDirectory();
      final filePath = '${dir.path}/app_update.apk';
      final file = File(filePath);
      if (await file.exists()) await file.delete();

      final dio = Dio();
      await dio.download(
        widget.apkUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _progress = received / total);
          }
        },
      );

      if (!mounted) return;
      setState(() => _progress = 1.0);

      // Abre o instalador do sistema (mostra dialog "Instalar?" ao usuário)
      final result = await OpenFile.open(filePath, type: 'application/vnd.android.package-archive');
      if (result.type != ResultType.done && mounted) {
        setState(() { _error = 'Não foi possível abrir o instalador: ${result.message}'; _progress = null; });
      } else if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() { _error = 'Falha no download: $e'; _progress = null; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDownloading = _progress != null && _progress! < 1.0;
    final isDone = _progress == 1.0;

    return PopScope(
      canPop: _progress == null,
      child: AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: [
          Icon(
            isDone ? Icons.check_circle : Icons.system_update,
            color: _primary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isDownloading
                  ? 'Baixando atualização...'
                  : isDone
                      ? 'Pronto para instalar'
                      : 'Nova versão disponível',
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
        ]),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_progress == null && _error == null) ...[
              Text(
                'Uma nova versão do app está disponível, com melhorias e correções.\n\n'
                'A atualização é baixada e instalada aqui mesmo, em poucos segundos.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
            if (isDownloading) ...[
              Text(
                '${(_progress! * 100).toStringAsFixed(0)}%',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: Colors.white12,
                  valueColor: const AlwaysStoppedAnimation<Color>(_primary),
                  minHeight: 8,
                ),
              ),
            ],
            if (isDone)
              const Text(
                'Download concluído. Confirme a instalação na tela seguinte.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
              const SizedBox(height: 4),
              TextButton(
                onPressed: _downloadAndInstall,
                child: const Text('Tentar novamente',
                    style: TextStyle(color: _primary)),
              ),
            ],
          ],
        ),
        actions: _progress == null
            ? [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Mais tarde',
                      style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton.icon(
                  autofocus: true,
                  icon: const Icon(Icons.download, color: Colors.white, size: 18),
                  label: const Text('Atualizar agora',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: _downloadAndInstall,
                ),
              ]
            : null,
      ),
    );
  }
}
