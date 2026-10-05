import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../core/stream_sources.dart';
import '../services/recording_service.dart';
import '../widgets/player_controls.dart';
import '../widgets/record_options.dart';

class PlayerScreen extends StatefulWidget {
  final List<String> urls;
  final String title;
  /// Canal ao vivo (sem avancar/voltar; pausa longa volta para o ao vivo)
  final bool isLive;
  /// Nome do canal para gravar (null = sem botao Gravar)
  final String? recordName;

  const PlayerScreen({
    super.key,
    required this.urls,
    required this.title,
    this.isLive = false,
    this.recordName,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  /// Fontes a tentar, em ordem (canal ao vivo: cada URL + o outro formato .ts/.m3u8)
  late final List<String> _sources;
  int _currentUrlIndex = 0;
  String? _errorMessage;
  /// Novas tentativas já feitas na fonte atual (cada fonte é tentada 2 vezes)
  int _retries = 0;
  /// O vídeo da fonte atual já começou a tocar: erros depois disso são ignorados
  bool _started = false;
  DateTime _openedAt = DateTime.now();
  Timer? _startTimer;
  String? _lastError;
  String? _failedUrl;
  final List<StreamSubscription<dynamic>> _subs = [];

  static const _startTimeout = Duration(seconds: 12);
  bool _paused = false;
  DateTime? _pausedAt;
  Timer? _recTick;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _player = Player(
      configuration: const PlayerConfiguration(
        // Libera buffers maiores para streams ao vivo
        // 64 MB: permite pausar o ao vivo por um tempo sem perder o ponto
        bufferSize: 64 * 1024 * 1024,
        logLevel: MPVLogLevel.warn,
      ),
    );

    _controller = VideoController(
      _player,
      configuration: const VideoControllerConfiguration(
        // Força decodificação por software — resolve tela preta em muitos dispositivos
        enableHardwareAcceleration: false,
      ),
    );

    _sources = widget.isLive ? liveStreamSources(widget.urls) : List.of(widget.urls);
    _subs.add(_player.stream.error.listen(_onPlayerError));
    _subs.add(_player.stream.position.listen((p) {
      if (p > Duration.zero) _markStarted();
    }));
    _tryPlayUrl(0);

    // Atualiza o selo REC (tempo/tamanho) enquanto grava
    if (widget.recordName != null) {
      _recTick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && RecordingService.instance.isRecording) setState(() {});
      });
    }
  }

  void _togglePause() {
    if (_paused) {
      final pausedFor = _pausedAt == null
          ? Duration.zero
          : DateTime.now().difference(_pausedAt!);
      setState(() => _paused = false);
      // Ao vivo pausado por muito tempo: o servidor pode ter derrubado a
      // conexao; reabre o canal direto no ao vivo.
      if (widget.isLive && pausedFor > const Duration(minutes: 2)) {
        _tryPlayUrl(_currentUrlIndex);
      } else {
        _player.play();
      }
    } else {
      _player.pause();
      setState(() {
        _paused = true;
        _pausedAt = DateTime.now();
      });
    }
  }

  void _seek(int seconds) {
    final target = _player.state.position + Duration(seconds: seconds);
    _player.seek(target < Duration.zero ? Duration.zero : target);
  }

  bool get _isRecordingThis {
    final rs = RecordingService.instance;
    return rs.isRecording && rs.activeRecording?.channelName == widget.recordName;
  }

  Future<void> _toggleRecording() async {
    final rs = RecordingService.instance;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (_isRecordingThis) {
      await rs.stopRecording();
      messenger?.showSnackBar(const SnackBar(
          content: Text('Gravacao salva em "Minhas Gravacoes" (TV ao Vivo).')));
    } else {
      final d = await pickRecordingDuration(context);
      if (d == null || !mounted) return;
      if (rs.isRecording) await rs.stopRecording();
      await rs.startRecording(
        widget.recordName!,
        _sources[_currentUrlIndex],
        duration: d == Duration.zero ? null : d,
      );
      messenger?.showSnackBar(const SnackBar(
          content: Text('Gravando. Pode sair do player: a gravacao continua com o app aberto.')));
    }
    if (mounted) setState(() {});
  }

  void _tryPlayUrl(int index, {bool retry = false}) {
    _startTimer?.cancel();
    if (index >= _sources.length) {
      setState(() {
        _errorMessage = 'Nenhuma playlist disponível no momento.';
      });
      return;
    }
    setState(() {
      _currentUrlIndex = index;
      _errorMessage = null;
      _paused = false;
    });
    if (!retry) _retries = 0;
    _started = false;
    _openedAt = DateTime.now();
    _player.open(
      Media(_sources[index]),
      play: true,
    );
    // Sem erro e sem imagem em 12 s: considera a fonte falha
    _startTimer = Timer(_startTimeout,
        () => _sourceFailed('O vídeo não começou em ${_startTimeout.inSeconds} s'));
  }

  void _markStarted() {
    if (_started) return;
    _started = true;
    _startTimer?.cancel();
  }

  void _onPlayerError(String error) {
    // Avisos do mpv com o vídeo já tocando não derrubam o canal
    if (_started || _player.state.playing || _player.state.position > Duration.zero) {
      _lastError = error;
      return;
    }
    // Erros que chegam logo após abrir ainda são da fonte anterior
    if (DateTime.now().difference(_openedAt) < const Duration(milliseconds: 500)) return;
    _sourceFailed(error);
  }

  void _sourceFailed(String reason) {
    if (!mounted || _started || _errorMessage != null) return;
    _startTimer?.cancel();
    _lastError = reason;
    _failedUrl = _sources[_currentUrlIndex];
    if (_retries < 1) {
      _retries++;
      _tryPlayUrl(_currentUrlIndex, retry: true);
    } else if (_currentUrlIndex + 1 < _sources.length) {
      _tryPlayUrl(_currentUrlIndex + 1);
    } else {
      setState(() {
        _errorMessage = 'Todas as fontes falharam. Verifique sua conexão.';
      });
    }
  }

  @override
  void dispose() {
    // Restaura todas as orientações ao sair do player
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _recTick?.cancel();
    _startTimer?.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _errorMessage != null
          ? _buildError()
          : PlayerRemoteControls(
              title: widget.title,
              subtitle: widget.urls.length > 1 || _currentUrlIndex > 0
                  ? 'Fonte ${_currentUrlIndex + 1}/${_sources.length}'
                  : null,
              paused: _paused,
              onPlayPause: _togglePause,
              onBack: () => Navigator.pop(context),
              onSeek: widget.isLive ? null : _seek,
              onRecord: widget.recordName == null ? null : _toggleRecording,
              recording: _isRecordingThis,
              recordingInfo: _isRecordingThis
                  ? 'REC ${RecordingService.instance.activeRecording!.elapsedFormatted}'
                      '${RecordingService.instance.activeRecording!.stopAtFormatted != null ? ' ate ${RecordingService.instance.activeRecording!.stopAtFormatted}' : ''}'
                  : null,
              child: Stack(
          children: [
            // Player de vídeo
            SizedBox.expand(
              child: Video(
                controller: _controller,
                fill: Colors.black,
                fit: BoxFit.fill,
                // Controles proprios (PlayerRemoteControls), feitos para o controle remoto
                controls: NoVideoControls,
              ),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 64),
            const SizedBox(height: 16),
            Text(_errorMessage!,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                textAlign: TextAlign.center),
            if (_lastError != null || _failedUrl != null) ...[
              const SizedBox(height: 8),
              // Detalhe técnico para o suporte (sem usuário e senha)
              Text(
                [
                  if (_lastError != null) _lastError!,
                  if (_failedUrl != null) maskStreamUrl(_failedUrl!),
                ].join('\n'),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  autofocus: true,
                  onPressed: () => _tryPlayUrl(0),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Tentar novamente'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFe94bff)),
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
    );
  }
}
