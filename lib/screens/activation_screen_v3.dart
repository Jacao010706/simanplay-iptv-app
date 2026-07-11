import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/app_config.dart';
import '../models/app_session.dart';
import '../services/api_service.dart';
import '../services/xtream_service.dart';
import 'home_screen_v2.dart';

class ActivationScreen extends StatefulWidget {
  const ActivationScreen({super.key});
  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _spUserCtrl = TextEditingController();
  final _spPassCtrl = TextEditingController();
  bool _spLoading = false;
  bool _spShowPass = false;
  String? _spError;
  final _xHostCtrl = TextEditingController();
  final _xUserCtrl = TextEditingController();
  final _xPassCtrl = TextEditingController();
  bool _xLoading = false;
  bool _xShowPass = false;
  String? _xError;
  String? _macAddress;
  bool _checkingMac = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initMacAndLogin();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _spUserCtrl.dispose();
    _spPassCtrl.dispose();
    _xHostCtrl.dispose();
    _xUserCtrl.dispose();
    _xPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _initMacAndLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final sessionJson = prefs.getString('session');
    if (sessionJson != null) {
      try {
        final session = AppSession.fromJson(
            jsonDecode(sessionJson) as Map<String, dynamic>);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen(session: session)),
        );
        return;
      } catch (_) {}
    }
    String? mac;
    try {
      final info = NetworkInfo();
      mac = await info.getWifiBSSID();
      mac = mac?.toUpperCase().trim();
      if (mac == null || mac.isEmpty || mac == '02:00:00:00:00:00') mac = null;
    } catch (_) {
      mac = null;
    }
    setState(() {
      _macAddress = mac;
      _checkingMac = false;
    });
    if (mac != null) {
      try {
        final clientSession = await ApiService.activateByMac(macAddress: mac);
        if (clientSession.status == 'ativo' &&
            clientSession.allPlaylistUrls.isNotEmpty) {
          final session = AppSession.simanplay(
            username: 'mac:$mac',
            password: '',
            primaryM3uUrl: clientSession.primaryUrl ?? '',
            backupM3uUrls: clientSession.backupPlaylists
                .map((b) => b.playlistUrl ?? '')
                .where((u) => u.isNotEmpty)
                .toList(),
            expiresAt: clientSession.expiresAt,
            xtreamHost: clientSession.xtreamHost,
            xtreamUsername: clientSession.xtreamUsername,
            xtreamPassword: clientSession.xtreamPassword,
          );
          final prefs2 = await SharedPreferences.getInstance();
          await prefs2.setString('session', jsonEncode(session.toJson()));
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => HomeScreen(session: session)),
          );
          return;
        }
      } catch (_) {}
    }
  }

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
      final session = AppSession.simanplay(
        username: _spUserCtrl.text.trim(),
        password: _spPassCtrl.text,
        primaryM3uUrl: clientSession.primaryUrl ?? '',
        backupM3uUrls: clientSession.backupPlaylists
            .map((b) => b.playlistUrl ?? '')
            .where((u) => u.isNotEmpty)
            .toList(),
        expiresAt: clientSession.expiresAt,
        xtreamHost: clientSession.xtreamHost,
        xtreamUsername: clientSession.xtreamUsername,
        xtreamPassword: clientSession.xtreamPassword,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session', jsonEncode(session.toJson()));
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(session: session)),
      );
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
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('session', jsonEncode(session.toJson()));
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(session: session)),
      );
    } catch (e) {
      setState(() {
        _xError = e.toString().replaceFirst('Exception: ', '');
        _xLoading = false;
      });
    }
  }

  Widget _buildLogo(Color primary) {
    if (AppConfig.useCustomLogo) {
      return Image.asset('assets/logo.png', height: AppConfig.logoSize,
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

    if (_checkingMac) {
      return Scaffold(
        backgroundColor: bg,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLogo(primary),
              const SizedBox(height: 24),
              CircularProgressIndicator(color: primary),
              const SizedBox(height: 16),
              const Text('Verificando dispositivo...',
                  style: TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      );
    }

    final hasBanner = AppConfig.bannerUrl.isNotEmpty;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Fundo com banner (se configurado)
          if (hasBanner)
            CachedNetworkImage(
              imageUrl: AppConfig.bannerUrl,
              fit: BoxFit.cover,
              placeholder: (_, __) => Container(color: bg),
              errorWidget: (_, __, ___) => Container(color: bg),
            ),
          // Overlay escuro sobre o banner para legibilidade
          if (hasBanner)
            Container(color: Colors.black.withOpacity(0.55)),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF2a2538)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.devices, color: Colors.white54, size: 16),
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
                        tabs: const [
                          Tab(text: 'SimanPlay'),
                          Tab(text: 'Xtream Codes'),
                        ],
                      ),
                      SizedBox(
                        height: 240,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildSimanPlayTab(primary),
                            _buildXtreamTab(primary),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(AppConfig.appVersion,
                    style: const TextStyle(color: Colors.white24, fontSize: 11)),
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
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildTextField(controller: _spUserCtrl, label: 'Usuário', icon: Icons.person),
          const SizedBox(height: 12),
          _buildTextField(
            controller: _spPassCtrl,
            label: 'Senha',
            icon: Icons.lock,
            obscure: !_spShowPass,
            suffixIcon: IconButton(
              icon: Icon(_spShowPass ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white54),
              onPressed: () => setState(() => _spShowPass = !_spShowPass),
            ),
          ),
          if (_spError != null) ...[
            const SizedBox(height: 10),
            _buildError(_spError!),
          ],
          const SizedBox(height: 12),
          _buildButton(label: 'Entrar', loading: _spLoading, onPressed: _loginSimanPlay, primary: primary),
        ],
      ),
    );
  }

  Widget _buildXtreamTab(Color primary) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          _buildTextField(controller: _xHostCtrl, label: 'URL do servidor', icon: Icons.link),
          const SizedBox(height: 10),
          _buildTextField(controller: _xUserCtrl, label: 'Usuário', icon: Icons.person),
          const SizedBox(height: 10),
          _buildTextField(
            controller: _xPassCtrl,
            label: 'Senha',
            icon: Icons.lock,
            obscure: !_xShowPass,
            suffixIcon: IconButton(
              icon: Icon(_xShowPass ? Icons.visibility_off : Icons.visibility,
                  color: Colors.white54),
              onPressed: () => setState(() => _xShowPass = !_xShowPass),
            ),
          ),
          if (_xError != null) ...[
            const SizedBox(height: 8),
            _buildError(_xError!),
          ],
          const SizedBox(height: 12),
          _buildButton(label: 'Conectar', loading: _xLoading, onPressed: _loginXtream, primary: primary),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscure = false,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54, fontSize: 13),
        filled: true,
        fillColor: Color(AppConfig.backgroundColor),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        prefixIcon: Icon(icon, color: Colors.white54, size: 20),
        suffixIcon: suffixIcon,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
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
    required String label,
    required bool loading,
    required VoidCallback onPressed,
    required Color primary,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: loading
            ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
            : Text(label,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}
