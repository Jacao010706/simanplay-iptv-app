import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import '../core/erros.dart';
import '../core/janela_pc.dart';
import '../core/plataforma.dart';
import '../core/stream_sources.dart';
import '../core/user_agent.dart';
import '../services/epg_service.dart';
import '../services/recording_service.dart';
import '../services/assistindo_service.dart';
import '../widgets/player_controls.dart';
import '../widgets/record_options.dart';

class PlayerScreen extends StatefulWidget {
  final List<String> urls;
  final String title;
  /// Canal ao vivo (sem avancar/voltar; pausa longa volta para o ao vivo)
  final bool isLive;
  /// Nome do canal para gravar (null = sem botao Gravar)
  final String? recordName;
  /// Stream id do canal no Xtream: mostra a programacao (EPG) no player
  final String? streamId;

  const PlayerScreen({
    super.key,
    required this.urls,
    required this.title,
    this.isLive = false,
    this.recordName,
    this.streamId,
  });

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player _player;
  late final VideoController _controller;
  /// Fontes a tentar, em ordem (canal ao vivo: cada URL + o outro formato .ts/.m3u8).
  /// Cada fonte é tentada UMA vez: com contas de 1 conexão, tentar de novo em seguida
  /// esbarra na conexão anterior que o servidor ainda está contando.
  late final List<String> _sources;
  int _currentUrlIndex = 0;
  String? _errorMessage;
  /// O vídeo da fonte atual já começou a tocar: erros depois disso são ignorados
  bool _started = false;
  DateTime _openedAt = DateTime.now();
  Timer? _startTimer;
  /// Motivo real da falha de cada fonte já tentada (sem URL, usuário ou senha)
  final List<String> _motivos = [];
  /// Status HTTP visto no log do mpv para a fonte atual (ex.: 401)
  int? _ultimoHttp;
  bool _algumaRecusa = false;
  /// Trocando de fonte (player parado, esperando [_pausaEntreFontes])
  bool _trocando = false;
  /// Aumenta a cada abertura: cancela trocas e timers de uma tentativa antiga
  int _geracao = 0;
  /// Aviso no meio da tela enquanto troca de fonte
  String? _aviso;
  /// PC: janela em tela cheia
  bool _telaCheia = false;

  static const _pausaEntreFontes = Duration(seconds: 3);
  final List<StreamSubscription<dynamic>> _subs = [];
  // Programacao do canal ao vivo (null = canal sem EPG)
  List<EpgProgram>? _epg;
  bool _epgLoading = false;
  Timer? _epgTick;

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
    // Status HTTP da fonte (o erro do mpv nem sempre traz o código)
    _subs.add(_player.stream.log.listen((log) {
      final m = RegExp(r'(?:HTTP error|Server returned) (\d{3})').firstMatch(log.text);
      if (m != null) _ultimoHttp = int.tryParse(m[1]!);
    }));
    // User-Agent também na propriedade do mpv (além do cabeçalho de cada Media)
    final plataforma = _player.platform;
    if (plataforma is NativePlayer) {
      plataforma.setProperty('user-agent', kIptvUserAgent).catchError((_) {});
    }
    _subs.add(_player.stream.position.listen((p) {
      if (p > Duration.zero) _markStarted();
    }));
    _tryPlayUrl(0);
    _startEpg();
    // "Assistindo agora" no painel; se o revendedor encerrar a conexão, o player fecha
    Assistindo.conteudo(
        Assistindo.tipoDaUrl(widget.urls.isNotEmpty ? widget.urls.first : '', aoVivo: widget.isLive), widget.title);
    _subs.add(Assistindo.derrubado.stream.listen((msg) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.of(context).maybePop();
      messenger?.showSnackBar(SnackBar(content: Text(msg)));
    }));

    // Atualiza o selo REC (tempo/tamanho) enquanto grava
    if (widget.recordName != null) {
      _recTick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted && RecordingService.instance.isRecording) setState(() {});
      });
    }
  }

  bool get _hasEpg =>
      widget.isLive && (widget.streamId?.isNotEmpty ?? false) && EpgService.instance.isAvailable;

  void _startEpg() {
    if (!_hasEpg) return;
    _epg = EpgService.instance.cached(widget.streamId!) ?? const [];
    _loadEpg();
    // A cada minuto: avanca o programa atual/progresso e renova quando o cache vencer
    _epgTick = Timer.periodic(const Duration(minutes: 1), (_) => _loadEpg());
  }

  Future<void> _loadEpg() async {
    if (_epg?.isEmpty ?? true) setState(() => _epgLoading = true);
    final list = await EpgService.instance.getEpg(widget.streamId!);
    if (!mounted) return;
    setState(() {
      _epg = list;
      _epgLoading = false;
    });
  }

  String get _channelName => widget.recordName ?? widget.title;

  ScheduledRecording _scheduleFor(EpgProgram p) => ScheduledRecording.fromProgram(
        channelName: _channelName,
        streamUrl: widget.urls.first,
        programStart: p.start,
        programEnd: p.end,
        title: p.title,
      );

  bool _isScheduled(EpgProgram p) {
    final id = _scheduleFor(p).id;
    return RecordingService.instance.schedules.any((s) => s.id == id);
  }

  Future<void> _toggleSchedule(EpgProgram p) async {
    final rs = RecordingService.instance;
    final sched = _scheduleFor(p);
    if (_isScheduled(p)) {
      await rs.removeSchedule(sched.id);
    } else {
      await rs.addSchedule(sched);
    }
    if (mounted) setState(() {});
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

  void _tryPlayUrl(int index) {
    _startTimer?.cancel();
    _geracao++;
    _trocando = false;
    if (index >= _sources.length) {
      setState(() {
        _errorMessage = 'Nenhuma playlist disponível no momento.';
      });
      return;
    }
    if (index == 0) {
      _motivos.clear();
      _algumaRecusa = false;
    }
    setState(() {
      _currentUrlIndex = index;
      _errorMessage = null;
      _paused = false;
      _aviso = null;
    });
    _started = false;
    _ultimoHttp = null;
    _openedAt = DateTime.now();
    _player.open(
      Media(_sources[index], httpHeaders: kIptvHeaders),
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
    // Avisos do mpv com o vídeo já tocando (ou do player parado na troca) não derrubam o canal
    if (_trocando || _started || _player.state.playing || _player.state.position > Duration.zero) {
      return;
    }
    // Erros que chegam logo após abrir ainda são da fonte anterior
    if (DateTime.now().difference(_openedAt) < const Duration(milliseconds: 500)) return;
    _sourceFailed(error);
  }

  /// Formato da fonte para mostrar na tela (nunca a URL).
  static String _formato(String url) {
    final path = Uri.tryParse(url)?.path ?? '';
    final ultimo = path.substring(path.lastIndexOf('/') + 1);
    final ponto = ultimo.lastIndexOf('.');
    return ponto < 0 ? 'stream' : ultimo.substring(ponto + 1).toLowerCase();
  }

  static String _textoHttp(int code) => switch (code) {
        401 || 403 => 'HTTP $code (acesso negado pelo servidor)',
        404 => 'HTTP 404 (não encontrado no servidor)',
        >= 500 => 'HTTP $code (erro no servidor)',
        _ => 'HTTP $code',
      };

  Future<void> _sourceFailed(String reason) async {
    if (!mounted || _started || _trocando || _errorMessage != null) return;
    _startTimer?.cancel();
    _trocando = true;
    final geracao = ++_geracao;
    final i = _currentUrlIndex;
    final http = _ultimoHttp;
    if (http == 401 || http == 403) _algumaRecusa = true;
    var detalhe = http != null ? _textoHttp(http) : semCredenciais(reason).trim();
    if (detalhe.length > 140) detalhe = '${detalhe.substring(0, 140)}…';
    _motivos.add('Fonte ${i + 1}/${_sources.length} (${_formato(_sources[i])}): $detalhe');

    // Para e libera o player antes da próxima fonte
    try {
      await _player.stop();
    } catch (_) {}
    if (!mounted || geracao != _geracao) return;

    if (i + 1 < _sources.length) {
      setState(() => _aviso =
          'A fonte ${i + 1} não abriu. Tentando a fonte ${i + 2}/${_sources.length} em ${_pausaEntreFontes.inSeconds} s…');
      await Future<void>.delayed(_pausaEntreFontes);
      if (!mounted || geracao != _geracao) return;
      _tryPlayUrl(i + 1);
    } else {
      setState(() {
        _trocando = false;
        _aviso = null;
        _errorMessage = _algumaRecusa
            ? 'O servidor recusou o acesso a este conteúdo agora (a conta pode estar em uso em outro '
                'aparelho ou bloqueada temporariamente). Feche outros apps com esta lista e tente em alguns minutos.'
            : 'Não foi possível reproduzir este conteúdo. Verifique sua conexão e tente novamente.';
      });
    }
  }

  Future<void> _alternarTelaCheia() async {
    final ligada = await JanelaPc.alternarTelaCheia();
    if (mounted) setState(() => _telaCheia = ligada);
  }

  @override
  void dispose() {
    // Restaura todas as orientações ao sair do player
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _recTick?.cancel();
    _startTimer?.cancel();
    _geracao++;
    if (_telaCheia) JanelaPc.definirTelaCheia(false);
    _epgTick?.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
    _player.dispose();
    Assistindo.conteudo('menu', '');
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
              subtitle: _sources.length > 1
                  ? 'Fonte ${_currentUrlIndex + 1}/${_sources.length}'
                  : null,
              onFullscreen: Plataforma.windows ? _alternarTelaCheia : null,
              fullscreen: _telaCheia,
              paused: _paused,
              onPlayPause: _togglePause,
              onBack: () => Navigator.pop(context),
              onSeek: widget.isLive ? null : _seek,
              onRecord: widget.recordName == null ? null : _toggleRecording,
              recording: _isRecordingThis,
              programs: _epg,
              programsLoading: _epgLoading,
              isScheduled: _epg == null ? null : _isScheduled,
              onToggleSchedule: _epg == null || widget.recordName == null ? null : _toggleSchedule,
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
            if (_aviso != null)
              Center(
                child: Container(
                  margin: const EdgeInsets.all(24),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(10)),
                  child: Text(_aviso!,
                      style: const TextStyle(color: Colors.white, fontSize: 15), textAlign: TextAlign.center),
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
            if (_motivos.isNotEmpty) ...[
              const SizedBox(height: 8),
              // Motivo real de cada fonte, para o suporte (sem URL, usuário ou senha)
              Text(
                _motivos.join('\n'),
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 4,
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
