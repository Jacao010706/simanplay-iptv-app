import 'package:flutter_test/flutter_test.dart';
import 'package:simanplay_iptv/services/recording_service.dart';

void main() {
  final base = DateTime(2026, 10, 5, 20, 0);
  ScheduledRecording prog(int iniMin, int fimMin, [String nome = 'Canal']) =>
      ScheduledRecording.fromProgram(
        channelName: nome,
        streamUrl: 'http://x/live/u/p/1.ts',
        programStart: base.add(Duration(minutes: iniMin)),
        programEnd: base.add(Duration(minutes: fimMin)),
        title: 'Jogo',
      );

  test('programa agendado tem folga: 2 min antes e 5 min depois', () {
    final s = prog(60, 120); // 21:00 - 22:00
    expect(s.start, DateTime(2026, 10, 5, 20, 58));
    expect(s.end, DateTime(2026, 10, 5, 22, 5));
  });

  test('so comeca a gravar na hora certa e para no fim', () {
    final s = prog(60, 120);
    expect(ScheduledRecording.due([s], DateTime(2026, 10, 5, 20, 57)), isNull);
    expect(ScheduledRecording.due([s], DateTime(2026, 10, 5, 20, 58)), s);
    expect(ScheduledRecording.due([s], DateTime(2026, 10, 5, 21, 30)), s);
    expect(ScheduledRecording.due([s], DateTime(2026, 10, 5, 22, 5)), isNull);
    expect(ScheduledRecording.expired(s, DateTime(2026, 10, 5, 22, 5)), isTrue);
    expect(ScheduledRecording.expired(s, DateTime(2026, 10, 5, 22, 4)), isFalse);
  });

  test('entre varios agendamentos escolhe o que esta no horario', () {
    final a = prog(60, 120, 'A');
    final b = prog(180, 240, 'B'); // 23:00 - 00:00
    expect(ScheduledRecording.due([a, b], DateTime(2026, 10, 5, 23, 30))?.channelName, 'B');
  });

  test('agendamento sobrevive a salvar e carregar (app reiniciado)', () {
    final s = prog(60, 120);
    final c = ScheduledRecording.fromJson(s.toJson());
    expect(c.id, s.id);
    expect(c.start, s.start);
    expect(c.end, s.end);
    expect(c.channelName, s.channelName);
    expect(c.streamUrl, s.streamUrl);
    expect(c.title, 'Jogo');
  });

  test('mesmo programa gera o mesmo id (nao duplica)', () {
    expect(prog(60, 120).id, prog(60, 120).id);
    expect(prog(60, 120).id, isNot(prog(120, 180).id));
  });
}
