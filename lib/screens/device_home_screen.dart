import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_config.dart';
import '../models/app_session.dart';
import '../services/device_lists_service.dart';
import '../services/license_service.dart';
import '../services/xtream_service.dart';
import 'activation_screen_v3.dart';
import 'home_screen_v2.dart';

/// Abre a home com a sessão escolhida e a salva para a próxima abertura.
Future<void> openHome(BuildContext context, AppSession session) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('session', jsonEncode(session.toJson()));
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => HomeScreen(session: session)),
    (_) => false,
  );
}

/// Tela inicial estilo IBO Player: mostra o MAC e a chave do aparelho e as listas
/// que o cliente (ou o revendedor) cadastrou no site para este MAC.
class DeviceHomeScreen extends StatefulWidget {
  /// true na abertura do app: entra direto na última lista usada (ou na única cadastrada).
  final bool autoEnter;
  const DeviceHomeScreen({super.key, this.autoEnter = true});

  @override
  State<DeviceHomeScreen> createState() => _DeviceHomeScreenState();
}

class _DeviceHomeScreenState extends State<DeviceHomeScreen> {
  LicenseState? _lic;
  List<DevicePlaylist>? _lists;
  String? _error;
  bool _loading = true;
  int? _opening; // id da lista sendo aberta
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    if (widget.autoEnter) {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('session');
      if (saved != null) {
        try {
          final session = AppSession.fromJson(jsonDecode(saved) as Map<String, dynamic>);
          if (!mounted) return;
          await openHome(context, session);
          return;
        } catch (_) {}
      }
    }
    var lic = LicenseService.current;
    if (lic == null || lic.mac.isEmpty) lic = await LicenseService.check();
    if (!mounted) return;
    setState(() => _lic = lic);
    await _refresh(first: true);
    // Enquanto a tela está aberta, confere se o cliente cadastrou/alterou listas no site
    _poll = Timer.periodic(const Duration(seconds: 20), (_) => _refresh());
  }

  Future<void> _refresh({bool first = false}) async {
    final lic = _lic;
    if (lic == null || lic.mac.isEmpty || lic.deviceKey.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Não foi possível obter o MAC do aparelho. Verifique a internet.';
      });
      return;
    }
    try {
      final items = await DeviceListsService.fetch(mac: lic.mac, key: lic.deviceKey);
      if (!mounted) return;
      setState(() {
        _lists = items;
        _error = null;
        _loading = false;
      });
      if (first && widget.autoEnter && items.length == 1) _open(items.first);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Sem conexão com o servidor. Tentando de novo…';
      });
    }
  }

  Future<void> _open(DevicePlaylist p) async {
    if (_opening != null) return;
    setState(() {
      _opening = p.id;
      _error = null;
    });
    try {
      if (p.isXtream) {
        await XtreamService(host: p.host ?? '', username: p.username ?? '', password: p.password ?? '')
            .authenticate();
      }
      if (!mounted) return;
      _poll?.cancel();
      await openHome(context, p.toSession());
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _opening = null;
        _error = 'Não foi possível abrir "${p.name}": ${e.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  void _manual() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ActivationScreen()));
  }

  Widget _logo(Color primary) {
    if (AppConfig.useCustomLogo) {
      return Image.network(AppConfig.logoUrl,
          height: 56, errorBuilder: (_, __, ___) => Icon(Icons.live_tv, size: 48, color: primary));
    }
    return Icon(Icons.live_tv, size: 48, color: primary);
  }

  @override
  Widget build(BuildContext context) {
    final primary = Color(AppConfig.primaryColor);
    final bg = Color(AppConfig.backgroundColor);
    final surface = Color(AppConfig.surfaceColor);
    final lic = _lic;

    final device = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('MAC do aparelho', style: TextStyle(color: Colors.white54, fontSize: 13)),
          SelectableText(lic?.displayId ?? '—',
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
          const SizedBox(height: 10),
          const Text('Chave do aparelho', style: TextStyle(color: Colors.white54, fontSize: 13)),
          SelectableText(lic?.deviceKey.isNotEmpty == true ? lic!.deviceKey : '—',
              style: TextStyle(color: primary, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 4)),
          const SizedBox(height: 14),
          const Text('Para adicionar suas listas, acesse pelo celular:',
              style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          const SelectableText(DeviceListsService.siteShort,
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('e digite o MAC e a chave acima.', style: TextStyle(color: Colors.white70, fontSize: 14)),
          if (lic != null && lic.mac.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
              child: QrImageView(data: DeviceListsService.siteUrl(lic.mac), size: 150, backgroundColor: Colors.white),
            ),
            const SizedBox(height: 4),
            const Text('Ou aponte a câmera do celular', style: TextStyle(color: Colors.white38, fontSize: 12)),
          ],
          if (lic != null && lic.isTrial) ...[
            const SizedBox(height: 12),
            Text('Teste grátis: ${lic.daysLeft} dia(s) restante(s)',
                style: const TextStyle(color: Colors.amberAccent, fontSize: 13)),
          ],
        ],
      ),
    );

    final lists = _lists ?? const <DevicePlaylist>[];
    final listsPanel = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Expanded(
            child: Text('Suas listas${_lists != null ? ' (${lists.length})' : ''}',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600)),
          ),
          IconButton(
            tooltip: 'Atualizar listas',
            onPressed: _loading ? null : () { setState(() => _loading = true); _refresh(); },
            icon: const Icon(Icons.refresh, color: Colors.white70),
          ),
        ]),
        const SizedBox(height: 8),
        if (_loading && _lists == null)
          Padding(padding: const EdgeInsets.all(24), child: Center(child: CircularProgressIndicator(color: primary))),
        if (_lists != null && lists.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(12)),
            child: const Text(
              'Nenhuma lista cadastrada ainda.\n'
              'Cadastre pelo site com o MAC e a chave ao lado. Ela aparece aqui sozinha em alguns segundos.',
              style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.4),
            ),
          ),
        for (var i = 0; i < lists.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _PlaylistTile(
              playlist: lists[i],
              autofocus: i == 0,
              opening: _opening == lists[i].id,
              primary: primary,
              surface: surface,
              onTap: () => _open(lists[i]),
            ),
          ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: const TextStyle(color: Colors.amberAccent, fontSize: 13)),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          autofocus: lists.isEmpty,
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,
            side: const BorderSide(color: Colors.white38),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: _manual,
          icon: const Icon(Icons.keyboard),
          label: const Text('Entrar com servidor, usuário e senha ou link M3U'),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1000),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    _logo(primary),
                    const SizedBox(width: 12),
                    Text(AppConfig.appName,
                        style: TextStyle(color: primary, fontSize: 28, fontWeight: FontWeight.bold)),
                  ]),
                  const SizedBox(height: 20),
                  LayoutBuilder(builder: (context, c) {
                    if (c.maxWidth > 700) {
                      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SizedBox(width: 340, child: device),
                        const SizedBox(width: 24),
                        Expanded(child: listsPanel),
                      ]);
                    }
                    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      listsPanel,
                      const SizedBox(height: 20),
                      device,
                    ]);
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PlaylistTile extends StatelessWidget {
  final DevicePlaylist playlist;
  final bool autofocus;
  final bool opening;
  final Color primary;
  final Color surface;
  final VoidCallback onTap;

  const _PlaylistTile({
    required this.playlist,
    required this.autofocus,
    required this.opening,
    required this.primary,
    required this.surface,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        autofocus: autofocus,
        borderRadius: BorderRadius.circular(12),
        focusColor: primary.withValues(alpha: 0.25),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(playlist.isXtream ? Icons.dns : Icons.playlist_play, color: primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(playlist.name,
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                Text(playlist.subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 12), overflow: TextOverflow.ellipsis),
              ]),
            ),
            opening
                ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: primary))
                : const Icon(Icons.chevron_right, color: Colors.white38),
          ]),
        ),
      ),
    );
  }
}
