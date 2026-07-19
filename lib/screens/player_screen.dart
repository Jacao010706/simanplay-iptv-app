import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../core/app_config.dart';

class PlayerScreen extends StatefulWidget {
  final List<String> urls;
  final String title;

  const PlayerScreen({
    super.key,
    required this.urls,
    required this.title,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  int _currentUrlIndex = 0;
  bool _showControls = true;
  String? _errorMessage;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  double _volume = 100.0;
  bool _showVolume = false;
  Timer? _hideTimer;
  final List<StreamSubscription> _subs = [];

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

    _subs.add(_player.stream.error.listen(_onPlayerError));
    _subs.add(_player.stream.playing.listen((p) {
      if (mounted) setState(() => _isPlaying = p);
    }));
    _subs.add(_player.stream.position.listen((p) {
      if (mounted) setState(() => _position = p);
    }));
    _subs.add(_player.stream.duration.listen((d) {
      if (mounted) setState(() => _duration = d);
    }));

    _tryPlayUrl(0);
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _toggleControls() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  void _onTapControl() {
    _startHideTimer();
  }

  void _tryPlayUrl(int index) {
    if (index >= widget.urls.length) {
      setState(() {
        _errorMessage = 'Nenhuma fonte disponível no momento.';
      });
      return;
    }
    setState(() {
      _currentUrlIndex = index;
      _errorMessage = null;
    });
    _player.open(Media(widget.urls[index]));
  }

  void _onPlayerError(String error) {
    final next = _currentUrlIndex + 1;
    if (next < widget.urls.length) {
      _tryPlayUrl(next);
    } else {
      if (mounted) {
        setState(() {
          _errorMessage = 'Todas as fontes falharam. Verifique sua conexão.';
        });
      }
    }
  }

  void _togglePlayPause() {
    _onTapControl();
    if (_isPlaying) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  void _seek(double value) {
    _onTapControl();
    final target = Duration(
        milliseconds: (value * _duration.inMilliseconds).round());
    _player.seek(target);
  }

  void _skipSeconds(int seconds) {
    _onTapControl();
    final target = _position + Duration(seconds: seconds);
    _player.seek(target.isNegative ? Duration.zero : target);
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Color(AppConfig.primaryColor);
    final bool isLive = _duration == Duration.zero;

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: _toggleControls,
        child: Stack(
          children: [
            // Video
            Center(child: Video(controller: _controller)),

            // Error overlay
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
                      Text(_errorMessage!,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 16),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _tryPlayUrl(0),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Tentar novamente'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: primary),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back),
                            label: const Text('Voltar'),
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2a2538)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            // Controls overlay
            if (_showControls && _errorMessage == null) ...[
              // Top bar
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
                        Colors.black.withValues(alpha: 0.85),
                        Colors.transparent
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
                  child: SafeArea(
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Expanded(
                          child: Text(
                            widget.title,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w500,
                                fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isLive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.circle,
                                    color: Colors.white, size: 8),
                                SizedBox(width: 4),
                                Text('AO VIVO',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        if (widget.urls.length > 1) ...[
                          const SizedBox(width: 8),
                          Text(
                            'Fonte ${_currentUrlIndex + 1}/${widget.urls.length}',
                            style: const TextStyle(
                                color: Colors.white54, fontSize: 11),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),

              // Center play/pause + skip buttons
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isLive) ...[
                      _controlButton(
                        icon: Icons.replay_10,
                        onTap: () => _skipSeconds(-10),
                        size: 36,
                      ),
                      const SizedBox(width: 24),
                    ],
                    GestureDetector(
                      onTap: _togglePlayPause,
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                              width: 2),
                        ),
                        child: Icon(
                          _isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                    ),
                    if (!isLive) ...[
                      const SizedBox(width: 24),
                      _controlButton(
                        icon: Icons.forward_10,
                        onTap: () => _skipSeconds(10),
                        size: 36,
                      ),
                    ],
                  ],
                ),
              ),

              // Bottom bar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.9),
                        Colors.transparent
                      ],
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  child: SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Seek bar (only for VOD)
                        if (!isLive) ...[
                          Row(
                            children: [
                              Text(
                                _formatDuration(_position),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 11),
                              ),
                              Expanded(
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: primary,
                                    inactiveTrackColor: Colors.white24,
                                    thumbColor: primary,
                                    thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 6),
                                    overlayShape: const RoundSliderOverlayShape(
                                        overlayRadius: 14),
                                    trackHeight: 3,
                                  ),
                                  child: Slider(
                                    value: _duration.inMilliseconds > 0
                                        ? (_position.inMilliseconds /
                                                _duration.inMilliseconds)
                                            .clamp(0.0, 1.0)
                                        : 0.0,
                                    onChanged: _seek,
                                  ),
                                ),
                              ),
                              Text(
                                _formatDuration(_duration),
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                        ],

                        // Volume row
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                _onTapControl();
                                setState(() => _showVolume = !_showVolume);
                              },
                              child: Icon(
                                _volume == 0
                                    ? Icons.volume_off
                                    : Icons.volume_up,
                                color: Colors.white70,
                                size: 20,
                              ),
                            ),
                            if (_showVolume) ...[
                              const SizedBox(width: 4),
                              SizedBox(
                                width: 100,
                                child: SliderTheme(
                                  data: SliderTheme.of(context).copyWith(
                                    activeTrackColor: primary,
                                    inactiveTrackColor: Colors.white24,
                                    thumbColor: primary,
                                    thumbShape: const RoundSliderThumbShape(
                                        enabledThumbRadius: 5),
                                    trackHeight: 2,
                                  ),
                                  child: Slider(
                                    value: _volume,
                                    min: 0,
                                    max: 100,
                                    onChanged: (v) {
                                      _onTapControl();
                                      setState(() => _volume = v);
                                      _player.setVolume(v);
                                    },
                                  ),
                                ),
                              ),
                            ],
                            const Spacer(),
                            // Fullscreen toggle (already fullscreen in landscape)
                            GestureDetector(
                              onTap: () {
                                _onTapControl();
                                SystemChrome.setEnabledSystemUIMode(
                                    SystemUiMode.immersiveSticky);
                              },
                              child: const Icon(Icons.fullscreen,
                                  color: Colors.white70, size: 22),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _controlButton({
    required IconData icon,
    required VoidCallback onTap,
    double size = 28,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: size),
      ),
    );
  }
}
