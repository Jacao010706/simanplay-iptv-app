import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/app_config.dart';
import '../models/app_session.dart';
import '../services/api_service.dart';
import '../services/license_service.dart';
import '../services/xtream_service.dart';
import 'device_home_screen.dart';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});
  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late TabController _tabController;

  // Botões de cada aba: rolamos até eles quando o teclado abre, para que os
  // campos e o botão fiquem sempre acima do teclado.
  final _spButtonKey = GlobalKey();
  final _xButtonKey = GlobalKey();
  final _m3uButtonKey = GlobalKey();

  late final FocusNode _spUserFocus = _fieldFocusNode(_spButtonKey);
  late final FocusNode _spPassFocus = _fieldFocusNode(_spButtonKey);
  late final FocusNode _xHostFocus = _fieldFocusNode(_xButtonKey);
  late final FocusNode _xUserFocus = _fieldFocusNode(_xButtonKey);
  late final FocusNode _xPassFocus = _fieldFocusNode(_xButtonKey);
  late final FocusNode _m3uUrlFocus = _fieldFocusNode(_m3uButtonKey);
  GlobalKey? _focusedButtonKey;

  // SimanPlay
  final _spUserCtrl = TextEditingController();
  final _spPassCtrl = TextEditingController();
  bool _spLoading = false;
  bool _spShowPass = false;
  String? _spError;

  // Xtream Codes
  final _xHostCtrl = TextEditingController();
  final _xUserCtrl = TextEditingController();
  final _xPassCtrl = TextEditingController();
  bool _xLoading = false;
  bool _xShowPass = false;
  String? _xError;

  // M3U URL
  final _m3uUrlCtrl = TextEditingController();
  bool _m3uLoading = false;
  String? _m3uError;

  // MAC do aparelho gerado pelo sistema (o mesmo mostrado na tela inicial)
  String? get _macAddress {
    final mac = LicenseService.current?.mac ?? '';
    return mac.isEmpty ? null : mac;
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabController.dispose();
    for (final node in [
      _spUserFocus,
      _spPassFocus,
      _xHostFocus,
      _xUserFocus,
      _xPassFocus,
      _m3uUrlFocus,
    ]) {
      node.dispose();
    }
    _spUserCtrl.dispose();
    _spPassCtrl.dispose();
    _xHostCtrl.dispose();
    _xUserCtrl.dispose();
    _xPassCtrl.dispose();
    _m3uUrlCtrl.dispose();
    super.dispose();
  }

  FocusNode _fieldFocusNode(GlobalKey buttonKey) {
    final node = FocusNode();
    node.addListener(() {
      if (node.hasFocus) {
        _focusedButtonKey = buttonKey;
        _revealButton(buttonKey);
      } else if (_focusedButtonKey == buttonKey) {
        _focusedButtonKey = null;
      }
    });
    return node;
  }

  /// Rola a tela (e a aba) até o botão da aba ficar visível acima do teclado.
  void _revealButton(GlobalKey buttonKey) {
    // Espera o teclado terminar de abrir e o Scaffold encolher o body; o
    // endOfFrame garante que o layout já está com a altura nova da tela.
    Future.delayed(const Duration(milliseconds: 350), () async {
      await WidgetsBinding.instance.endOfFrame;
      final ctx = buttonKey.currentContext;
      if (!mounted || ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  // O teclado da TV pode abrir (ou mudar de altura) depois do foco: rola de novo.
  @override
  void didChangeMetrics() {
    final key = _focusedButtonKey;
    if (key != null) _revealButton(key);
  }

  /// Só para testes: mostra a mensagem de erro do login.
  @visibleForTesting
  void debugSetError(String message) => setState(() => _spError = message);

  Future<void> _loginSimanPlay() async {
    setState(() {
      _spLoading = true;
      _spError = null;
    });
    try {
      final clientSession = await ApiService.login(
        username: _spUserCtrl.text.trim(),
        password: _spPassCtrl.text,
        macAddress: _macAddress,
      );
      if (clientSession.status == 'expirado') {
        setState(() {
          _spError = 'Assinatura expirada. Contate o suporte.';
          _spLoading = false;
        });
        return;
      }
      if (clientSession.allPlaylistUrls.isEmpty) {
        setState(() {
          _spError = 'Nenhuma playlist configurada para este cliente.';
          _spLoading = false;
        });
        return;
      }
      final session = ApiService.buildSession(
        clientSession,
        manualUsername: _spUserCtrl.text.trim(),
        manualPassword: _spPassCtrl.text,
      );
      if (!mounted) return;
      await openHome(context, session);
    } catch (e) {
      setState(() {
        _spError = e.toString().replaceFirst('Exception: ', '');
        _spLoading = false;
      });
    }
  }

  Future<void> _loginXtream() async {
    final host = _xHostCtrl.text.trim().replaceAll(RegExp(r'/$'), '');
    if (host.isEmpty || _xUserCtrl.text.isEmpty || _xPassCtrl.text.isEmpty) {
      setState(() => _xError = 'Preencha todos os campos.');
      return;
    }
    setState(() {
      _xLoading = true;
      _xError = null;
    });
    try {
      final service = XtreamService(
        host: host,
        username: _xUserCtrl.text.trim(),
        password: _xPassCtrl.text,
      );
      await service.authenticate();
      final session = AppSession.xtream(
        host: host,
        username: _xUserCtrl.text.trim(),
        password: _xPassCtrl.text,
      );
      if (!mounted) return;
      await openHome(context, session);
    } catch (e) {
      setState(() {
        _xError = e.toString().replaceFirst('Exception: ', '');
        _xLoading = false;
      });
    }
  }

  Future<void> _loginM3U() async {
    final url = _m3uUrlCtrl.text.trim();
    if (url.isEmpty) {
      setState(() => _m3uError = 'Informe a URL da playlist M3U.');
      return;
    }
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      setState(() => _m3uError = 'URL inválida. Use http:// ou https://');
      return;
    }
    setState(() {
      _m3uLoading = true;
      _m3uError = null;
    });
    try {
      final session = AppSession.simanplay(
        username: 'm3u',
        password: '',
        primaryM3uUrl: url,
      );
      if (!mounted) return;
      await openHome(context, session);
    } catch (e) {
      setState(() {
        _m3uError = e.toString().replaceFirst('Exception: ', '');
        _m3uLoading = false;
      });
    }
  }

  Widget _buildLogo(Color primary) {
    if (AppConfig.useCustomLogo) {
      return Image.network(AppConfig.logoUrl,
          height: AppConfig.logoSize,
          errorBuilder: (_, __, ___) => Icon(Icons.live_tv,
              size: AppConfig.logoSize * 0.75, color: primary));
    }
    return Icon(
      AppConfig.usePlayIcon ? Icons.play_circle : Icons.live_tv,
      size: AppConfig.logoSize * 0.75,
      color: primary,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Color(AppConfig.primaryColor);
    final bg = Color(AppConfig.backgroundColor);
    final surface = Color(AppConfig.surfaceColor);

    final hasBanner = AppConfig.bannerUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: bg,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (hasBanner)
            CachedNetworkImage(
              imageUrl: AppConfig.bannerUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: bg),
              errorWidget: (_, __, ___) => Container(color: bg),
            ),
          if (hasBanner)
            Container(color: Colors.black.withOpacity(0.55)),
          if (Navigator.of(context).canPop())
            const SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: Padding(padding: EdgeInsets.all(8), child: BackButton(color: Colors.white70)),
              ),
            ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    _buildLogo(primary),
                    if (_macAddress != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF2a2538)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.devices,
                                color: Colors.white54, size: 16),
                            const SizedBox(width: 8),
                            Text('MAC: $_macAddress',
                                style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                    fontFamily: 'monospace')),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 32),
                    Container(
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF2a2538)),
                      ),
                      child: Column(
                        children: [
                          TabBar(
                            controller: _tabController,
                            indicatorColor: primary,
                            labelColor: primary,
                            unselectedLabelColor: Colors.white54,
                            dividerColor: const Color(0xFF2a2538),
                            labelStyle: const TextStyle(fontSize: 12),
                            tabs: const [
                              Tab(text: AppConfig.appName),
                              Tab(text: 'Xtream'),
                              Tab(text: 'URL M3U'),
                            ],
                          ),
                          SizedBox(
                            height: 420,
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildSimanPlayTab(primary),
                                _buildXtreamTab(primary),
                                _buildM3UTab(primary),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(AppConfig.appVersion,
                        style: const TextStyle(
                            color: Colors.white24, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimanPlayTab(Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        children: [
          _buildTextField(
              controller: _spUserCtrl,
              focusNode: _spUserFocus,
              label: 'Usuário',
              icon: Icons.person),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _spPassCtrl,
            focusNode: _spPassFocus,
            label: 'Senha',
            icon: Icons.lock,
            obscure: !_spShowPass,
            suffixIcon: IconButton(
              icon: Icon(
                  _spShowPass ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white54),
              onPressed: () => setState(() => _spShowPass = !_spShowPass),
            ),
          ),
          if (_spError != null) ...[
            const SizedBox(height: 10),
            _buildError(_spError!),
          ],
          const SizedBox(height: 12),
          _buildButton(
              key: _spButtonKey,
              label: 'Entrar',
              loading: _spLoading,
              onPressed: _loginSimanPlay,
              primary: primary),
        ],
      ),
    );
  }

  Widget _buildXtreamTab(Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        children: [
          _buildTextField(
              controller: _xHostCtrl,
              focusNode: _xHostFocus,
              label: 'URL do servidor',
              icon: Icons.link),
          const SizedBox(height: 10),
          _buildTextField(
              controller: _xUserCtrl,
              focusNode: _xUserFocus,
              label: 'Usuário',
              icon: Icons.person),
          const SizedBox(height: 10),
          _buildTextField(
            controller: _xPassCtrl,
            focusNode: _xPassFocus,
            label: 'Senha',
            icon: Icons.lock,
            obscure: !_xShowPass,
            suffixIcon: IconButton(
              icon: Icon(
                  _xShowPass ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white54),
              onPressed: () => setState(() => _xShowPass = !_xShowPass),
            ),
          ),
          if (_xError != null) ...[
            const SizedBox(height: 8),
            _buildError(_xError!),
          ],
          const SizedBox(height: 12),
          _buildButton(
              key: _xButtonKey,
              label: 'Conectar',
              loading: _xLoading,
              onPressed: _loginXtream,
              primary: primary),
        ],
      ),
    );
  }

  Widget _buildM3UTab(Color primary) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cole a URL da sua lista M3U:',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 10),
          _buildTextField(
            controller: _m3uUrlCtrl,
            focusNode: _m3uUrlFocus,
            label: 'https://servidor.com/lista.m3u',
            icon: Icons.playlist_play,
            keyboardType: TextInputType.url,
          ),
          if (_m3uError != null) ...[
            const SizedBox(height: 10),
            _buildError(_m3uError!),
          ],
          const SizedBox(height: 16),
          _buildButton(
              key: _m3uButtonKey,
              label: 'Carregar lista',
              loading: _m3uLoading,
              onPressed: _loginM3U,
              primary: primary),
          const SizedBox(height: 12),
          const Text(
            'Suporta listas M3U e M3U Plus (.m3u, .m3u8)',
            style: TextStyle(color: Colors.white24, fontSize: 10),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    FocusNode? focusNode,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        filled: true,
        fillColor: Color(AppConfig.backgroundColor),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none),
        prefixIcon: Icon(icon, color: Colors.white54, size: 20),
        suffixIcon: suffixIcon,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
    );
  }

  Widget _buildError(String message) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade700),
      ),
      child: Text(message,
          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
          textAlign: TextAlign.center),
    );
  }

  Widget _buildButton({
    Key? key,
    required String label,
    required bool loading,
    required VoidCallback onPressed,
    required Color primary,
  }) {
    // A folga embaixo também entra na rolagem: o botão não fica colado no teclado.
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        height: 46,
        child: ElevatedButton(
          onPressed: loading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: loading
              ? const CircularProgressIndicator(
                  color: Colors.white, strokeWidth: 2)
              : Text(label,
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
        ),
      ),
    );
  }
}
