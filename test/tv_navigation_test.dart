import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simanplay_iptv/models/app_session.dart';
import 'package:simanplay_iptv/screens/home_screen_v2.dart';
import 'package:simanplay_iptv/widgets/tv_focus.dart';

FocusNode? _foco() {
  final f = FocusManager.instance.primaryFocus;
  return (f == null || f is FocusScopeNode) ? null : f;
}

Future<void> _tecla(WidgetTester tester, LogicalKeyboardKey k) async {
  await tester.sendKeyEvent(k);
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void _telaTv(WidgetTester tester) {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 2.0; // 960x540 logico, como nas TVs
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('TvTap: setas navegam em menus, listas e grades; OK aciona',
      (tester) async {
    _telaTv(tester);
    final clicados = <String>[];
    Widget item(String id, double w) => TvTap(
          onTap: () => clicados.add(id),
          child: Container(width: w, height: 60, color: Colors.blue, child: Text(id)),
        );
    await tester.pumpWidget(MaterialApp(
      builder: (c, child) => FocusRing(child: child!),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Column(children: [
            Row(children: [item('menu1', 80), item('menu2', 80), item('menu3', 80)]),
            const SizedBox(height: 20),
            SizedBox(
              height: 60,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [for (var i = 0; i < 20; i++) item('canal$i', 120)],
              ),
            ),
            const SizedBox(height: 20),
            for (var r = 0; r < 6; r++)
              Row(children: [for (var c = 0; c < 4; c++) item('filme$r$c', 150)]),
          ]),
        ),
      ),
    ));
    await tester.pump();

    // Sem nada focado: a primeira seta ja seleciona um item
    await _tecla(tester, LogicalKeyboardKey.arrowDown);
    expect(_foco(), isNotNull, reason: 'seta nao selecionou nenhum item');
    expect(find.byKey(FocusRing.ringKey), findsOneWidget,
        reason: 'item selecionado sem destaque visivel');

    final vistos = <FocusNode>{};
    for (final k in [
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowLeft,
    ]) {
      await _tecla(tester, k);
      final f = _foco();
      expect(f, isNotNull, reason: 'perdeu o foco apos $k');
      vistos.add(f!);
    }
    expect(vistos.length, greaterThanOrEqualTo(5),
        reason: 'o foco nao andou pelos itens');

    // Desce ate o fim da grade: a tela rola junto e o destaque acompanha
    for (var i = 0; i < 8; i++) {
      await _tecla(tester, LogicalKeyboardKey.arrowDown);
    }
    final ring = tester.getRect(find.byKey(FocusRing.ringKey));
    expect(ring.top, greaterThanOrEqualTo(-4), reason: 'item focado fora da tela');
    expect(ring.bottom, lessThanOrEqualTo(544), reason: 'item focado fora da tela');

    // OK no controle aciona o item
    await _tecla(tester, LogicalKeyboardKey.select);
    expect(clicados, isNotEmpty, reason: 'OK nao acionou o item');
    final antes = clicados.length;
    await _tecla(tester, LogicalKeyboardKey.enter);
    expect(clicados.length, antes + 1);
  });

  for (var tema = 1; tema <= 6; tema++) {
    testWidgets('home tema $tema: controle remoto navega e mostra o destaque',
        (tester) async {
      _telaTv(tester);
      final original = FlutterError.onError;
      // Avisos de layout (overflow) nao fazem parte deste teste
      FlutterError.onError = (d) {
        if (!d.exceptionAsString().contains('overflowed')) original?.call(d);
      };
      try {
        await tester.pumpWidget(MaterialApp(
          builder: (c, child) => FocusRing(child: child!),
          home: HomeScreen(
            session: const AppSession(type: SessionType.simanplay),
            debugTheme: tema,
          ),
        ));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        final vistos = <FocusNode>{};
        for (final k in [
          LogicalKeyboardKey.arrowDown,
          LogicalKeyboardKey.arrowRight,
          LogicalKeyboardKey.arrowRight,
          LogicalKeyboardKey.arrowDown,
          LogicalKeyboardKey.arrowLeft,
          LogicalKeyboardKey.arrowUp,
        ]) {
          await _tecla(tester, k);
          final f = _foco();
          if (f != null) vistos.add(f);
        }
        expect(vistos.length, greaterThanOrEqualTo(2),
            reason: 'tema $tema: as setas do controle nao navegam');
        expect(_foco(), isNotNull, reason: 'tema $tema: ficou sem item selecionado');
        expect(find.byKey(FocusRing.ringKey), findsOneWidget,
            reason: 'tema $tema: item selecionado sem destaque visivel');
      } finally {
        FlutterError.onError = original;
      }
    });
  }
}
