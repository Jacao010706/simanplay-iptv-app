import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simanplay_iptv/widgets/player_controls.dart';
import 'package:simanplay_iptv/widgets/tv_focus.dart';

class _Estado {
  bool pausado = false;
  int pausas = 0;
  final saltos = <int>[];
  int gravar = 0;
  int voltar = 0;
}

Future<_Estado> _abrir(WidgetTester tester, {required bool aoVivo, bool gravavel = true}) async {
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
    // Seta para baixo mostra os controles e seleciona o pausar
    await _tecla(tester, LogicalKeyboardKey.arrowDown);
    expect(find.byKey(FocusRing.ringKey), findsOneWidget, reason: 'sem destaque no botao');
    // Anda para a direita ate o botao Gravar
    for (var i = 0; i < 3 && e.gravar == 0; i++) {
      await _tecla(tester, LogicalKeyboardKey.arrowRight);
      final focado = FocusManager.instance.primaryFocus?.context;
      final noGravar = focado != null &&
          find
              .descendant(
                  of: find.byWidget(focado.widget), matching: find.byIcon(Icons.fiber_manual_record))
              .evaluate()
              .isNotEmpty;
      if (noGravar) await _tecla(tester, LogicalKeyboardKey.select);
    }
    expect(e.gravar, 1, reason: 'nao foi possivel acionar Gravar pelo controle');
    expect(e.pausas, 0, reason: 'OK no Gravar nao deve pausar');
    await _esconder(tester);
  });

  testWidgets('botao Voltar acessivel pelo controle', (tester) async {
    final e = await _abrir(tester, aoVivo: true);
    await _tecla(tester, LogicalKeyboardKey.arrowDown); // foca o pausar
    await _tecla(tester, LogicalKeyboardKey.arrowUp); // sobe para a barra de cima
    await _tecla(tester, LogicalKeyboardKey.select);
    expect(e.voltar, 1, reason: 'nao chegou no Voltar com a seta para cima');
    await _esconder(tester);
  });
}
