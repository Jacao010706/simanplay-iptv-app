import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../models/client_session.dart';
import 'login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PlayerScreen extends StatefulWidget {
  final ClientSession session;
  const PlayerScreen({super.key, required this.session});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  int _currentUrlIndex = 0;
  bool _showControls = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _player = Player();
    _controller = VideoController(_player);
    _player.stream.error.listen(_onPlayerError);
    _tryPlayUrl(_currentUrlIndex);
  }

  void _tryPlayUrl(int index) {
    final urls = widget.session.allPlaylistUrls;
    if (index >= urls.length) {
      setState(() {
        _errorMessage =
            'Nenhuma playlist disponível no momento. Tente novamente mais tarde.';
      });
      return;
    }
    setState(() {
      _currentUrlIndex = index;
      _errorMessage = null;
    });
    _player.open(Media(urls[index]));
  }

  void _onPlayerError(String error) {
    final urls = widget.session.allPlaylistUrls;
    final nextIndex = _currentUrlIndex + 1;
    if (nextIndex < urls.length) {
      _tryPlayUrl(nextIndex);
    } else {
      setState(() {
        _errorMessage =
            'Todas as playlists falharam. Verifique sua conexão ou contate o suporte.';
      });
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('username');
    await prefs.remove('password');
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = widget.session.allPlaylistUrls;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showControls = !_showControls),
        child: Stack(
          children: [
            Center(
              child: Video(controller: _controller),
            ),
            if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.redAccent, size: 64),
                      const SizedBox(height: 16),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _tryPlayUrl(0),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFe94bff),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (_showControls && _errorMessage == null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.live_tv,
                          color: Color(0xFFe94bff), size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'SimanPlay IPTV',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold),
                      ),
                      if (urls.length > 1) ...[
                        const SizedBox(width: 8),
                        Text(
                          '(lista ${_currentUrlIndex + 1}/${urls.length})',
                          style: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                        ),
                      ],
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white54),
                        onPressed: _logout,
                        tooltip: 'Sair',
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}