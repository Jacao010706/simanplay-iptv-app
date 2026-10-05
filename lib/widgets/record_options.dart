import 'package:flutter/material.dart';

String _hm(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Pergunta por quanto tempo gravar.
/// Retorna: null = cancelou; Duration.zero = ate o usuario parar;
/// outra duracao = para sozinho depois desse tempo.
Future<Duration?> pickRecordingDuration(
  BuildContext context, {
  DateTime? programEnd,
  String? programTitle,
}) {
  final now = DateTime.now();
  final fimPrograma = programEnd?.add(const Duration(minutes: 5));
  final temPrograma = fimPrograma != null && fimPrograma.isAfter(now);

  return showDialog<Duration>(
    context: context,
    builder: (ctx) {
      Widget opcao(String label, Duration valor, {bool foco = false, IconData icon = Icons.timer}) {
        return ListTile(
          autofocus: foco,
          leading: Icon(icon, color: Colors.white70),
          title: Text(label, style: const TextStyle(color: Colors.white)),
          onTap: () => Navigator.pop(ctx, valor),
        );
      }

      return AlertDialog(
        backgroundColor: const Color(0xFF1a1625),
        title: const Text('Gravar por quanto tempo?', style: TextStyle(color: Colors.white)),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              if (temPrograma)
                opcao(
                  'Ate o fim de "${(programTitle ?? '').isEmpty ? 'programa atual' : programTitle}" (${_hm(fimPrograma)})',
                  fimPrograma.difference(now),
                  foco: true,
                  icon: Icons.live_tv,
                ),
              opcao('Ate eu parar', Duration.zero, foco: !temPrograma, icon: Icons.all_inclusive),
              opcao('30 minutos', const Duration(minutes: 30)),
              opcao('1 hora', const Duration(hours: 1)),
              opcao('2 horas', const Duration(hours: 2)),
              opcao('3 horas', const Duration(hours: 3)),
              opcao('4 horas', const Duration(hours: 4)),
            ]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Colors.white54)),
          ),
        ],
      );
    },
  );
}
