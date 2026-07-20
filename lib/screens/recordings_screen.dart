import 'dart:async';
import 'package:flutter/material.dart';
import '../core/app_config.dart';
import '../services/recording_service.dart';
import 'player_screen.dart';

class RecordingsScreen extends StatefulWidget {
  const RecordingsScreen({super.key});

  @override
  State<RecordingsScreen> createState() => _RecordingsScreenState();
}

class _RecordingsScreenState extends State<RecordingsScreen> {
  List<SavedRecording> _recordings = [];
  bool _loading = true;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _loadRecordings();

    RecordingService.instance.onUpdate = () {
      if (mounted) setState(() {});
    };

    // Refresh UI timer while recording (for elapsed/size counter)
    _ticker = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted && RecordingService.instance.isRecording) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    // Só limpa o callback se ainda somos os donos
    if (RecordingService.instance.onUpdate != null) {
      RecordingService.instance.onUpdate = null;
    }
    super.dispose();
  }

  Future<void> _loadRecordings() async {
    setState(() => _loading = true);
    final recs = await RecordingService.instance.getSavedRecordings();
    if (mounted) setState(() { _recordings = recs; _loading = false; });
  }

  Future<void> _confirmDelete(SavedRecording rec) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1a1625),
        title: const Text('Excluir gravação', style: TextStyle(color: Colors.white)),
        content: Text(
          'Deseja excluir a gravação de "${rec.channelName}"?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await RecordingService.instance.deleteRecording(rec.filePath);
      _loadRecordings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary    = Color(AppConfig.primaryColor);
    final activeRec  = RecordingService.instance.activeRecording;

    return Scaffold(
      backgroundColor: const Color(0xFF0d0b14),
      appBar: AppBar(
        title: const Text('Minhas Gravações',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF0d0b14),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: _loadRecordings,
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: Column(children: [
        // ── Gravação ativa ──────────────────────────────────────────────────
        if (activeRec != null)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.35)),
            ),
            child: Row(children: [
              // Piscando dot
              _PulsingDot(),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gravando: ${activeRec.channelName}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${activeRec.elapsedFormatted}  •  ${activeRec.sizeFormatted}',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              )),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () async {
                  await RecordingService.instance.stopRecording();
                  _loadRecordings();
                },
                icon: const Icon(Icons.stop, size: 16, color: Colors.white),
                label: const Text('Parar',
                    style: TextStyle(color: Colors.white, fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ]),
          ),

        // ── Lista de gravações ──────────────────────────────────────────────
        Expanded(child: _loading
            ? Center(child: CircularProgressIndicator(color: primary))
            : _recordings.isEmpty
                ? _buildEmpty()
                : RefreshIndicator(
                    color: primary,
                    onRefresh: _loadRecordings,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _recordings.length,
                      itemBuilder: (_, i) => _buildTile(_recordings[i], primary),
                    ),
                  )),
      ]),
    );
  }

  Widget _buildEmpty() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.videocam_off_outlined, color: Colors.white24, size: 72),
        const SizedBox(height: 20),
        const Text('Nenhuma gravação ainda',
            style: TextStyle(color: Colors.white54, fontSize: 17)),
        const SizedBox(height: 10),
        const Text(
          'Toque em "Gravar" em um canal\npara salvar e assistir depois.',
          style: TextStyle(color: Colors.white38, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ]),
    ));
  }

  Widget _buildTile(SavedRecording rec, Color primary) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1a1625),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: Container(
          width: 50, height: 50,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.video_file, color: primary, size: 28),
        ),
        title: Text(
          rec.channelName,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
          maxLines: 1, overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            '${rec.dateFormatted}  •  ${rec.sizeFormatted}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
        ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          IconButton(
            icon: Icon(Icons.play_circle_fill, color: primary, size: 34),
            tooltip: 'Assistir',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PlayerScreen(
                  urls: ['file://${rec.filePath}'],
                  title: rec.channelName,
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.white38, size: 22),
            tooltip: 'Excluir',
            onPressed: () => _confirmDelete(rec),
          ),
        ]),
      ),
    );
  }
}

// Ponto vermelho piscante para indicar gravação ativa
class _PulsingDot extends StatefulWidget {
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _ctrl,
        child: const Icon(Icons.circle, color: Colors.red, size: 10),
      );
}
