// Capturas de tela do Sofae em modo TV (1920x1080) para a ficha de Android TV na Google Play.
//
// Mesmo envelope de test/loja_layout_tv_test.dart: tela 1920x1080 (960x540 lógico, densidade 2),
// modo TV do Sofae ativo e a lista de demonstração (filmes abertos da Blender). Sem internet no
// teste: as capas de rede caem no mesmo substituto (errorBuilder) dos outros testes.
// As fontes reais (Roboto e ícones do Material) são carregadas do SDK do Flutter, para o texto
// não sair em quadradinhos.
//
// Gerar os PNG (test/capturas_tv/):
//   flutter test --flavor play test/capturas_tv_test.dart --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:simanplay_iptv/core/lista_demo.dart';
import 'package:simanplay_iptv/core/loja.dart';
import 'package:simanplay_iptv/core/modo_tv.dart';
import 'package:simanplay_iptv/core/providers/theme_provider.dart';
import 'package:simanplay_iptv/screens/home_screen_v2.dart';
import 'package:simanplay_iptv/screens/home_tv_screen.dart';
import 'package:simanplay_iptv/screens/live_tv_screen.dart';
import 'package:simanplay_iptv/screens/movies_screen.dart';
import 'package:simanplay_iptv/widgets/modo_tv_widgets.dart';
import 'package:simanplay_iptv/widgets/tv_focus.dart';

/// Carrega Roboto (todas as variações) e MaterialIcons do cache do SDK do Flutter.
Future<void> _carregarFontes() async {
  final raiz = Platform.environment['FLUTTER_ROOT'] ??
      File(Platform.resolvedExecutable).parent.parent.parent.parent.parent.parent.path;
  final pasta = Directory('$raiz/bin/cache/artifacts/material_fonts');
  if (!pasta.existsSync()) fail('fontes do Flutter não encontradas em ${pasta.path}');

  Future<void> carregar(String familia, Iterable<File> arquivos) async {
    final loader = FontLoader(familia);
    for (final f in arquivos) {
      loader.addFont(Future.value(ByteData.sublistView(f.readAsBytesSync())));
    }
    await loader.load();
  }

  final arquivos = pasta.listSync().whereType<File>().toList();
  final roboto = arquivos.where((f) {
    final n = f.uri.pathSegments.last;
    return n.startsWith('Roboto-') && n.endsWith('.ttf');
  });
  await carregar('Roboto', roboto);
  await carregar('MaterialIcons', arquivos.where((f) => f.uri.pathSegments.last.startsWith('MaterialIcons')));

  // Emoji (ex.: "⭐ Favoritos"): a fonte de emoji do sistema, se houver (no CI: fonts-noto-color-emoji)
  final emoji = File('/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf');
  if (emoji.existsSync()) await carregar('NotoColorEmoji', [emoji]);
}

/// Tema do app; só no teste, emoji (ex.: "⭐ Favoritos") cai na fonte de emoji, como no aparelho.
ThemeData _tema() {
  const emoji = ['NotoColorEmoji'];
  final t = ThemeProvider().themeData;
  return t.copyWith(
    textTheme: t.textTheme.apply(fontFamilyFallback: emoji),
    primaryTextTheme: t.primaryTextTheme.apply(fontFamilyFallback: emoji),
  );
}

/// O mesmo envelope do main.dart na TV, com o tema do app: escala de texto, overscan e borda de foco.
Widget _app(Widget home) => MaterialApp(
      debugShowCheckedModeBanner: false,
      shortcuts: appShortcuts,
      theme: _tema(),
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: const TextScaler.linear(ModoTv.escalaTexto)),
          child: MargemTv(child: FocusRing(child: child!)),
        );
      },
      home: home,
    );

/// Ignora só as capas de rede (sem internet no teste).
Future<void> _semRede(Future<void> Function() corpo) async {
  final original = FlutterError.onError;
  FlutterError.onError = (d) {
    final s = d.exceptionAsString();
    if (s.contains('HTTP request failed') || s.contains('NetworkImage')) return;
    original?.call(d);
  };
  try {
    await corpo();
  } finally {
    FlutterError.onError = original;
  }
}

Future<void> _passar(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tecla(WidgetTester tester, LogicalKeyboardKey k) async {
  await tester.sendKeyEvent(k);
  await _passar(tester);
  await tester.pump(const Duration(milliseconds: 500));
}

/// Deixa as imagens (logo do asset e capas que falham) terminarem de carregar.
Future<void> _imagens(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final e in find.byType(Image).evaluate()) {
      final img = e.widget as Image;
      try {
        await precacheImage(img.image, e, onError: (_, __) {});
      } catch (_) {}
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
  });
  await _passar(tester);
}

Future<void> _abrir(WidgetTester tester, Widget tela) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
  ModoTv.debugDefinir(tv: true, pacote: ModoTv.pacoteSofae);
  addTearDown(ModoTv.debugDefinir);
  await tester.pumpWidget(_app(tela));
  await _passar(tester);
}

Future<void> _capturar(WidgetTester tester, String arquivo) async {
  await _imagens(tester);
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('capturas_tv/$arquivo'));
}

Future<void> _fechar(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

FocusNode? _foco() => FocusManager.instance.primaryFocus;
bool _focoNaGrade() => _foco()?.context?.findAncestorWidgetOfExactType<GridView>() != null;

bool _focoNoCanal() {
  final f = _foco();
  if (f == null || f.debugLabel == 'TvTap') return false;
  final k = f.context?.findAncestorWidgetOfExactType<InkWell>()?.key;
  return k is ValueKey<String> && k.value.startsWith('canal-');
}

/// Como no aparelho: abre a tela inicial e entra no bloco pelo controle (seta para a direita e OK).
Future<void> _abrirPelaInicio(WidgetTester tester, {required int direita}) async {
  await _abrir(tester, HomeScreen(session: ListaDemo.sessao()));
  for (var i = 0; i < direita; i++) {
    await _tecla(tester, LogicalKeyboardKey.arrowRight);
  }
  await _tecla(tester, LogicalKeyboardKey.select);
  await _passar(tester);
  await tester.pump(const Duration(seconds: 1)); // transição da página
  expect(find.byType(TelaConteudoTv), findsOneWidget, reason: 'o bloco da tela inicial não abriu');
}

Future<void> _filmes(WidgetTester tester) async {
  await _abrirPelaInicio(tester, direita: 1);
  expect(find.byType(MoviesScreen), findsOneWidget, reason: 'a tela de Filmes não abriu');
}

void main() {
  setUpAll(_carregarFontes);

  testWidgets('01-inicio: tela inicial em modo TV', (tester) async {
    await _semRede(() async {
      await _abrir(tester, HomeScreen(session: ListaDemo.sessao()));
      expect(find.byType(HomeTvScreen), findsOneWidget, reason: 'a tela inicial de TV não abriu');
      await _capturar(tester, '01-inicio.png');
      await _fechar(tester);
    });
  }, skip: !Loja.play);

  testWidgets('02-filmes: grade de Filmes com um item focado', (tester) async {
    await _semRede(() async {
      await _filmes(tester);
      for (var i = 0; i < 6 && !_focoNaGrade(); i++) {
        await _tecla(tester, LogicalKeyboardKey.arrowDown);
      }
      expect(_focoNaGrade(), isTrue, reason: 'o controle não chegou aos filmes');
      await _tecla(tester, LogicalKeyboardKey.arrowRight);
      expect(_focoNaGrade(), isTrue);
      await _capturar(tester, '02-filmes.png');
      await _fechar(tester);
    });
  }, skip: !Loja.play);

  testWidgets('03-detalhes: janela de detalhes com "Assistir" focado', (tester) async {
    await _semRede(() async {
      await _filmes(tester);
      for (var i = 0; i < 6 && !_focoNaGrade(); i++) {
        await _tecla(tester, LogicalKeyboardKey.arrowDown);
      }
      expect(_focoNaGrade(), isTrue, reason: 'o controle não chegou aos filmes');
      await _tecla(tester, LogicalKeyboardKey.select);
      await _passar(tester);
      final janela = find.byKey(const Key('detalhe_filme'));
      expect(janela, findsOneWidget, reason: 'a janela de detalhes não abriu');
      expect(Focus.of(tester.element(find.descendant(of: janela, matching: find.text('Assistir')))).hasFocus,
          isTrue, reason: '"Assistir" sem o foco do controle');
      await _capturar(tester, '03-detalhes.png');
      await _fechar(tester);
    });
  }, skip: !Loja.play);

  testWidgets('04-ao-vivo: lista de canais da demonstração', (tester) async {
    await _semRede(() async {
      await _abrirPelaInicio(tester, direita: 0);
      expect(find.byType(LiveTvScreen), findsOneWidget, reason: 'a tela TV ao Vivo não abriu');
      expect(find.byKey(const ValueKey('canal-demo_canal_1')), findsOneWidget,
          reason: 'a lista de canais da demonstração não abriu');
      for (final k in [
        LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.arrowDown,
        LogicalKeyboardKey.arrowRight, LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowLeft,
        LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowRight,
      ]) {
        if (_focoNoCanal()) break;
        await _tecla(tester, k);
      }
      expect(_focoNoCanal(), isTrue, reason: 'o controle não chegou aos canais');
      await _capturar(tester, '04-ao-vivo.png');
      await _fechar(tester);
    });
  }, skip: !Loja.play);

}
