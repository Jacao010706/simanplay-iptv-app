import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simanplay_iptv/services/epg_service.dart';
import 'package:simanplay_iptv/widgets/player_controls.dart';
import 'package:simanplay_iptv/widgets/tv_focus.dart';

class _Estado {
  bool pausado = false;
  int pausas = 0;
  final saltos = <int>[];
  int gravar = 0;
  int voltar = 0;
  final agendados = <String>{};
}

Future<_Estado> _abrir(WidgetTester tester,
    {required bool aoVivo, bool gravavel = true, List<EpgProgram>? grade, DateTime? agora}) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  final e = _Estado();
  await tester.pumpWidget(MaterialApp(
    shortcuts: appShortcuts,
    builder: (c, child) => FocusRing(child: child!),
    home: StatefulBuilder(builder: (context, setState) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: PlayerRemoteControls(
          title: 'Canal Teste',
          paused: e.pausado,
          onPlayPause: () => setState(() {
            e.pausado = !e.pausado;
            e.pausas++;
          }),
          onBack: () => e.voltar++,
          onSeek: aoVivo ? null : (s) => e.saltos.add(s),
          onRecord: gravavel ? () => e.gravar++ : null,
          programs: grade,
          clock: agora == null ? null : () => agora,
          isScheduled: (p) => e.agendados.contains(p.title),
          onToggleSchedule: (p) async {
            if (!e.agendados.remove(p.title)) e.agendados.add(p.title);
          },
          child: const ColoredBox(color: Colors.black),
        ),
      );
    }),
  ));
  await tester.pump();
  return e;
}

Future<void> _tecla(WidgetTester tester, LogicalKeyboardKey k) async {
  await tester.sendKeyEvent(k);
  // 2 quadros: um para os botoes/foco, outro para o destaque acompanhar
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump(const Duration(milliseconds: 300));
}

PlayerRemoteControlsState _controles(WidgetTester tester) =>
    tester.state(find.byType(PlayerRemoteControls));

Future<void> _esconder(WidgetTester tester) async {
  await tester.pump(PlayerRemoteControls.hideAfter + const Duration(seconds: 1));
  await tester.pump();
}

void main() {
  testWidgets('OK do controle pausa e continua (controles escondidos)', (tester) async {
    final e = await _abrir(tester, aoVivo: true);
    await _esconder(tester);
    expect(_controles(tester).controlsVisible, isFalse);

    await _tecla(tester, LogicalKeyboardKey.select);
    expect(e.pausado, isTrue, reason: 'OK nao pausou');
    expect(find.byIcon(Icons.pause_circle_filled), findsOneWidget, reason: 'sem indicador de pausa');
    expect(_controles(tester).controlsVisible, isTrue, reason: 'pausado deve mostrar os controles');

    // Pausado: os controles nao somem sozinhos
    await _esconder(tester);
    expect(_controles(tester).controlsVisible, isTrue);

    await _tecla(tester, LogicalKeyboardKey.select);
    expect(e.pausado, isFalse, reason: 'OK nao continuou');
    await _esconder(tester);
  });

  testWidgets('tecla play/pause do controle funciona sempre', (tester) async {
    final e = await _abrir(tester, aoVivo: true);
    await _tecla(tester, LogicalKeyboardKey.mediaPlayPause);
    expect(e.pausas, 1);
    await _tecla(tester, LogicalKeyboardKey.mediaPlayPause);
    expect(e.pausas, 2);
    await _esconder(tester);
  });

  testWidgets('filme: setas laterais voltam/avancam 10s', (tester) async {
    final e = await _abrir(tester, aoVivo: false, gravavel: false);
    await _esconder(tester);
    await _tecla(tester, LogicalKeyboardKey.arrowRight);
    await _tecla(tester, LogicalKeyboardKey.arrowLeft);
    expect(e.saltos, [10, -10]);
    await _esconder(tester);
  });

  testWidgets('ao vivo: setas nao pulam o video, mostram os controles', (tester) async {
    final e = await _abrir(tester, aoVivo: true);
    await _esconder(tester);
    await _tecla(tester, LogicalKeyboardKey.arrowRight);
    expect(e.saltos, isEmpty);
    expect(_controles(tester).controlsVisible, isTrue);
    await _esconder(tester);
  });

  testWidgets('com controles na tela: setas andam ate Gravar e OK grava', (tester) async {
    final e = await _abrir(tester, aoVivo: true);
    await _esconder(tester);
    // Seta para baixo mostra os controles com o Pausar selecionado
    await _tecla(tester, LogicalKeyboardKey.arrowDown);
    expect(_controles(tester).selectedButton, 'play');
    final borda = tester.widget<Container>(find.byKey(const ValueKey('player-btn-play')));
    expect((borda.decoration as BoxDecoration).border, isNotNull,
        reason: 'botao selecionado sem destaque');
    // Direita ate o Gravar
    await _tecla(tester, LogicalKeyboardKey.arrowRight);
    expect(_controles(tester).selectedButton, 'rec', reason: 'seta direita nao chegou no Gravar');
    await _tecla(tester, LogicalKeyboardKey.arrowRight); // ja e o ultimo: fica nele
    expect(_controles(tester).selectedButton, 'rec');
    await _tecla(tester, LogicalKeyboardKey.select);
    expect(e.gravar, 1, reason: 'OK no Gravar nao gravou');
    expect(e.pausas, 0, reason: 'OK no Gravar nao deve pausar');
    // Volta para o Pausar e OK pausa
    await _tecla(tester, LogicalKeyboardKey.arrowLeft);
    expect(_controles(tester).selectedButton, 'play');
    await _tecla(tester, LogicalKeyboardKey.select);
    expect(e.pausas, 1);
    await _tecla(tester, LogicalKeyboardKey.select);
    expect(e.pausas, 2);
    await _esconder(tester);
  });

  testWidgets('filme: botoes voltar/avancar 10s pelo controle', (tester) async {
    final e = await _abrir(tester, aoVivo: false, gravavel: false);
    await _tecla(tester, LogicalKeyboardKey.arrowDown); // mostra e seleciona o Pausar
    expect(_controles(tester).selectedButton, 'play');
    await _tecla(tester, LogicalKeyboardKey.arrowLeft);
    expect(_controles(tester).selectedButton, 'rew');
    await _tecla(tester, LogicalKeyboardKey.select);
    await _tecla(tester, LogicalKeyboardKey.arrowRight);
    await _tecla(tester, LogicalKeyboardKey.arrowRight);
    expect(_controles(tester).selectedButton, 'fwd');
    await _tecla(tester, LogicalKeyboardKey.select);
    expect(e.saltos, [-10, 10]);
    await _esconder(tester);
  });

  testWidgets('botao Voltar acessivel pelo controle', (tester) async {
    final e = await _abrir(tester, aoVivo: true);
    await _tecla(tester, LogicalKeyboardKey.arrowDown); // seleciona o Pausar
    await _tecla(tester, LogicalKeyboardKey.arrowUp); // sobe para o Voltar
    expect(_controles(tester).selectedButton, 'back');
    await _tecla(tester, LogicalKeyboardKey.select);
    expect(e.voltar, 1, reason: 'OK no Voltar nao voltou');
    await _tecla(tester, LogicalKeyboardKey.arrowDown);
    expect(_controles(tester).selectedButton, 'play');
    await _esconder(tester);
  });

  testWidgets('controles somem sozinhos e a selecao reinicia', (tester) async {
    await _abrir(tester, aoVivo: true);
    await _tecla(tester, LogicalKeyboardKey.arrowDown);
    expect(_controles(tester).selectedButton, 'play');
    await _esconder(tester);
    expect(_controles(tester).controlsVisible, isFalse);
    expect(_controles(tester).selectedButton, isNull);
  });

  group('programacao (EPG) no player ao vivo', () {
    final agora = DateTime(2026, 10, 1, 20, 30);
    EpgProgram prog(String t, int h, int m, int h2, int m2) =>
        EpgProgram(title: t, description: 'Sobre $t', start: DateTime(2026, 10, 1, h, m), end: DateTime(2026, 10, 1, h2, m2));
    final grade = [
      prog('Jornal', 20, 0, 21, 0),
      prog('Novela', 21, 0, 22, 0),
      prog('Futebol', 22, 0, 23, 59),
      prog('Filme', 23, 59, 23, 59 + 0).copyWithEnd(DateTime(2026, 10, 2, 1, 30)),
    ];

    testWidgets('painel AGORA com horario, progresso e os proximos 3', (tester) async {
      await _abrir(tester, aoVivo: true, grade: grade, agora: agora);
      expect(find.byKey(const ValueKey('epg-now-panel')), findsOneWidget);
      expect(find.text('AGORA'), findsOneWidget);
      expect(find.text('20:00–21:00'), findsOneWidget);
      expect(find.text('Jornal'), findsOneWidget);
      final barra = tester.widget<LinearProgressIndicator>(find.byKey(const ValueKey('epg-progress')));
      expect(barra.value, closeTo(0.5, 0.01));
      expect(find.text('21:00  Novela'), findsOneWidget);
      expect(find.text('22:00  Futebol'), findsOneWidget);
      expect(find.text('23:59  Filme'), findsOneWidget);
      await _esconder(tester);
    });

    testWidgets('sem dados: Programacao indisponivel', (tester) async {
      await _abrir(tester, aoVivo: true, grade: const [], agora: agora);
      expect(find.text('Programacao indisponivel'), findsOneWidget);
      await _esconder(tester);
    });

    testWidgets('botao Programacao alcancavel pelas setas; OK abre a grade; cima/baixo, OK agenda; seta esquerda fecha',
        (tester) async {
      final e = await _abrir(tester, aoVivo: true, grade: grade, agora: agora);
      await _tecla(tester, LogicalKeyboardKey.arrowDown); // Pausar
      await _tecla(tester, LogicalKeyboardKey.arrowRight); // Gravar
      await _tecla(tester, LogicalKeyboardKey.arrowRight); // Programacao
      expect(_controles(tester).selectedButton, 'guide', reason: 'seta nao chegou no botao Programacao');
      await _tecla(tester, LogicalKeyboardKey.select);
      expect(_controles(tester).guideOpen, isTrue, reason: 'OK nao abriu a programacao');
      expect(find.byKey(const ValueKey('epg-guide-panel')), findsOneWidget);
      expect(e.pausas, 0, reason: 'abrir a programacao nao deve pausar');
      final painel = tester.getRect(find.byKey(const ValueKey('epg-guide-panel')));
      expect(painel.width, closeTo(960 * 0.4, 1), reason: 'painel deve ocupar ~40% da largura');
      expect(painel.right, closeTo(960, 1), reason: 'painel deve ficar na direita');

      // Com a grade aberta os controles nao somem sozinhos
      await _esconder(tester);
      expect(_controles(tester).controlsVisible, isTrue);
      expect(_controles(tester).guideOpen, isTrue);

      await _tecla(tester, LogicalKeyboardKey.arrowDown);
      await _tecla(tester, LogicalKeyboardKey.arrowDown);
      expect(_controles(tester).guideSelected, 2);
      await _tecla(tester, LogicalKeyboardKey.select);
      expect(e.agendados, {'Futebol'}, reason: 'OK nao agendou o programa escolhido');
      expect(find.text('Agendada'), findsOneWidget);
      await _tecla(tester, LogicalKeyboardKey.select);
      expect(e.agendados, isEmpty, reason: 'OK de novo deveria desagendar');
      await _tecla(tester, LogicalKeyboardKey.arrowUp);
      expect(_controles(tester).guideSelected, 1);
      for (var i = 0; i < 5; i++) {
        await _tecla(tester, LogicalKeyboardKey.arrowDown);
      }
      expect(_controles(tester).guideSelected, 3, reason: 'selecao deve parar no ultimo programa');

      await _tecla(tester, LogicalKeyboardKey.arrowLeft);
      expect(_controles(tester).guideOpen, isFalse, reason: 'seta esquerda nao fechou a programacao');
      expect(find.byKey(const ValueKey('epg-guide-panel')), findsNothing);
      expect(_controles(tester).selectedButton, 'guide');
      await _esconder(tester);
      expect(_controles(tester).controlsVisible, isFalse, reason: 'fechada a grade, os controles voltam a sumir');
    });

    testWidgets('Voltar do controle fecha a programacao sem sair do player', (tester) async {
      final e = await _abrir(tester, aoVivo: true, grade: grade, agora: agora);
      await _tecla(tester, LogicalKeyboardKey.arrowDown);
      await _tecla(tester, LogicalKeyboardKey.arrowRight);
      await _tecla(tester, LogicalKeyboardKey.arrowRight);
      await _tecla(tester, LogicalKeyboardKey.select);
      expect(_controles(tester).guideOpen, isTrue);
      // goBack nao existe no simulador de teclas do teste; Escape usa o mesmo caminho
      await _tecla(tester, LogicalKeyboardKey.escape);
      expect(_controles(tester).guideOpen, isFalse);
      expect(e.voltar, 0);
      await _esconder(tester);
    });

    testWidgets('filme (sem programacao) nao mostra o botao nem o painel', (tester) async {
      await _abrir(tester, aoVivo: false, gravavel: false);
      expect(find.byKey(const ValueKey('player-btn-guide')), findsNothing);
      expect(find.byKey(const ValueKey('epg-now-panel')), findsNothing);
      await _esconder(tester);
    });
  });
}

extension on EpgProgram {
  EpgProgram copyWithEnd(DateTime end) => EpgProgram(title: title, description: description, start: start, end: end);
}
