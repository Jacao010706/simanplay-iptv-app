import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
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
  int _currentUrlIndex = 0;
  String? _errorMessage;
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

    _player.stream.error.listen(_onPlayerError);
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
        widget.urls[_currentUrlIndex],
        duration: d == Duration.zero ? null : d,
      );
      messenger?.showSnackBar(const SnackBar(
          content: Text('Gravando. Pode sair do player: a gravacao continua com o app aberto.')));
    }
    if (mounted) setState(() {});
  }

  void _tryPlayUrl(int index) {
    if (index >= widget.urls.length) {
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
    _player.open(
      Media(widget.urls[index]),
      play: true,
    );
  }

  void _onPlayerError(String error) {
    final nextIndex = _currentUrlIndex + 1;
    if (nextIndex < widget.urls.length) {
      _tryPlayUrl(nextIndex);
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
              subtitle: widget.urls.length > 1
                  ? 'Fonte ${_currentUrlIndex + 1}/${widget.urls.length}'
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
