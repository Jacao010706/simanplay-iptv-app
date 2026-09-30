import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_config.dart';
import '../services/license_service.dart';

/// Verifica a licença ao abrir (e ao voltar para o app). Libera o [child]
/// durante o teste grátis ou com plano ativo; senão mostra a tela de pagamento.
class LicenseGate extends StatefulWidget {
  final Widget child;
  const LicenseGate({super.key, required this.child});

  @override
  State<LicenseGate> createState() => _LicenseGateState();
}

class _LicenseGateState extends State<LicenseGate> with WidgetsBindingObserver {
  LicenseState? _state;
  bool _trialNoticeShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final st = await LicenseService.check();
    if (!mounted) return;
    setState(() => _state = st);
    if (st.allowed && st.isTrial && st.daysLeft > 0 && !_trialNoticeShown) {
      _trialNoticeShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.showSnackBar(SnackBar(
          duration: const Duration(seconds: 6),
          content: Text('Teste grátis: ${st.daysLeft} dia(s) restante(s). MAC: ${st.displayId}'),
        ));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = _state;
    if (st == null) {
      final primary = Color(AppConfig.primaryColor);
      return Scaffold(
        backgroundColor: Color(AppConfig.backgroundColor),
        body: Center(child: CircularProgressIndicator(color: primary)),
      );
    }
    if (st.allowed) return widget.child;
    return LicenseBlockedScreen(state: st, onCheckAgain: _refresh);
  }
}

class LicenseBlockedScreen extends StatefulWidget {
  final LicenseState state;
  final Future<void> Function() onCheckAgain;
  const LicenseBlockedScreen({super.key, required this.state, required this.onCheckAgain});

  @override
  State<LicenseBlockedScreen> createState() => _LicenseBlockedScreenState();
}

class _LicenseBlockedScreenState extends State<LicenseBlockedScreen> {
  Timer? _poll;
  bool _checking = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    // Confere sozinho a cada 15 s: quando o PIX é aprovado, o app libera.
    _poll = Timer.periodic(const Duration(seconds: 15), (_) => widget.onCheckAgain());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  String get _payUrl => widget.state.payUrl.isNotEmpty
      ? widget.state.payUrl
      : 'https://simanplay-iptv-admin-panel.vercel.app/app';

  Future<void> _openSite() async {
    final ok = await launchUrl(Uri.parse(_payUrl), mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok && mounted) {
      setState(() => _msg = 'Não foi possível abrir o navegador. Leia o QR Code com o celular.');
    }
  }

  Future<void> _check() async {
    setState(() { _checking = true; _msg = null; });
    await widget.onCheckAgain();
    if (mounted) {
      setState(() {
        _checking = false;
        _msg = 'Ainda não identificamos o pagamento. Se já pagou, aguarde alguns segundos.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Color(AppConfig.primaryColor);
    final bg = Color(AppConfig.backgroundColor);
    final surface = Color(AppConfig.surfaceColor);
    final st = widget.state;
    final titulo = st.plan != null ? 'Sua assinatura venceu' : 'Seu período de teste grátis terminou';

    final info = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(AppConfig.appName, style: TextStyle(color: primary, fontSize: 28, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text(titulo, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text(
          'Para continuar usando, assine um plano pelo site com PIX:\n'
          'Mensal R\$ 5,00  •  Semestral R\$ 8,00  •  Anual R\$ 13,00',
          style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.5),
        ),
        const SizedBox(height: 16),
        const Text('MAC do aparelho', style: TextStyle(color: Colors.white54, fontSize: 13)),
        const SizedBox(height: 4),
        Text(st.displayId,
            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold, letterSpacing: 2)),
        const SizedBox(height: 18),
        Wrap(spacing: 12, runSpacing: 12, children: [
          ElevatedButton.icon(
            autofocus: true,
            style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
            onPressed: _openSite,
            icon: const Icon(Icons.open_in_browser),
            label: const Text('Pagar pelo site', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white38),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
            onPressed: _checking ? null : _check,
            icon: _checking
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            label: const Text('Já paguei — verificar', style: TextStyle(fontSize: 16)),
          ),
        ]),
        if (_msg != null) ...[
          const SizedBox(height: 12),
          Text(_msg!, style: const TextStyle(color: Colors.amberAccent, fontSize: 13)),
        ],
        if (st.offline) ...[
          const SizedBox(height: 8),
          const Text('Sem conexão com o servidor. Verifique a internet.', style: TextStyle(color: Colors.white38, fontSize: 12)),
        ],
      ],
    );

    final qr = Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        QrImageView(data: _payUrl, size: 190, backgroundColor: Colors.white),
        const SizedBox(height: 6),
        const Text('Aponte a câmera do celular', style: TextStyle(color: Colors.black87, fontSize: 12)),
      ]),
    );

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              constraints: const BoxConstraints(maxWidth: 900),
              decoration: BoxDecoration(color: surface, borderRadius: BorderRadius.circular(16)),
              child: LayoutBuilder(builder: (context, c) {
                final wide = c.maxWidth > 620;
                return wide
                    ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                        Expanded(child: info),
                        const SizedBox(width: 24),
                        qr,
                      ])
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        info,
                        const SizedBox(height: 20),
                        Center(child: qr),
                      ]);
              }),
            ),
          ),
        ),
      ),
    );
  }
}
