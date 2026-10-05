import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:simanplay_iptv/widgets/tv_focus.dart';
import 'package:simanplay_iptv/widgets/tv_search_field.dart';

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

bool _buscaFocada() => _foco()?.debugLabel == 'TvSearchField';

void main() {
  late List<String> digitados;
  late List<String> clicados;

  Future<void> montar(WidgetTester tester) async {
    _telaTv(tester);
    digitados = [];
    clicados = [];
    await tester.pumpWidget(MaterialApp(
      shortcuts: appShortcuts,
      builder: (c, child) => FocusRing(child: child!),
      home: Scaffold(
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TvSearchField(
              controller: TextEditingController(),
              onChanged: digitados.add,
              decoration: const InputDecoration(hintText: 'Buscar canal...'),
            ),
          ),
          for (var i = 0; i < 4; i++)
            TvTap(
              onTap: () => clicados.add('canal$i'),
              child: SizedBox(height: 60, width: 300, child: Text('canal$i')),
            ),
        ]),
      ),
    ));
    await tester.pump();
  }

  bool readOnly(WidgetTester tester) => tester.widget<TextField>(find.byType(TextField)).readOnly;
  String? focadoTexto() {
    final ctx = _foco()?.context;
    if (ctx == null) return null;
    final text = find.descendant(of: find.byWidget(ctx.widget), matching: find.byType(Text));
    return text.evaluate().isEmpty ? null : (text.evaluate().first.widget as Text).data;
  }

  testWidgets('seta para baixo foca a busca sem abrir o teclado', (tester) async {
    await montar(tester);
    await _tecla(tester, LogicalKeyboardKey.arrowDown);
    expect(_buscaFocada(), isTrue, reason: 'a busca deveria receber o foco');
    expect(tester.testTextInput.isVisible, isFalse, reason: 'teclado abriu sozinho');
    expect(readOnly(tester), isTrue);
  });

  testWidgets('da busca, seta para baixo vai para a lista e seta para cima volta', (tester) async {
    await montar(tester);
    await _tecla(tester, LogicalKeyboardKey.arrowDown);
    expect(_buscaFocada(), isTrue);

    await _tecla(tester, LogicalKeyboardKey.arrowDown);
    expect(_buscaFocada(), isFalse, reason: 'foco ficou preso na busca');
    expect(focadoTexto(), 'canal0');

    await _tecla(tester, LogicalKeyboardKey.arrowUp);
    expect(_buscaFocada(), isTrue, reason: 'seta para cima nao voltou para a busca');
    expect(tester.testTextInput.isVisible, isFalse);
  });

  testWidgets('OK ativa a edicao, abre o teclado e a digitacao chega no onChanged', (tester) async {
    await montar(tester);
    await _tecla(tester, LogicalKeyboardKey.arrowDown);
    await _tecla(tester, LogicalKeyboardKey.select);
    expect(readOnly(tester), isFalse, reason: 'OK nao ativou a edicao');
    expect(tester.testTextInput.isVisible, isTrue, reason: 'teclado nao abriu');

    await tester.enterText(find.byType(TextField), 'globo');
    await tester.pump();
    expect(digitados, ['globo']);
    expect(clicados, isEmpty, reason: 'OK na busca acionou um item da lista');
  });

  testWidgets('em edicao, seta para baixo sai da busca, fecha o teclado e volta a ser somente leitura',
      (tester) async {
    await montar(tester);
    await _tecla(tester, LogicalKeyboardKey.arrowDown);
    await _tecla(tester, LogicalKeyboardKey.select);
    expect(tester.testTextInput.isVisible, isTrue);

    await _tecla(tester, LogicalKeyboardKey.arrowDown);
    expect(focadoTexto(), 'canal0');
    expect(tester.testTextInput.isVisible, isFalse, reason: 'teclado continuou aberto');
    expect(readOnly(tester), isTrue);
  });

  testWidgets('toque no campo (celular) ativa a edicao', (tester) async {
    await montar(tester);
    await tester.tap(find.byType(TextField));
    await tester.pump(const Duration(milliseconds: 400));
    expect(readOnly(tester), isFalse);
    expect(tester.testTextInput.isVisible, isTrue);
  });
}
