// Capturas de tela do Sofae em modo TV (1920x1080) para a ficha de Android TV na Google Play.
//
// Mesmo envelope de test/loja_layout_tv_test.dart: tela 1920x1080 (960x540 lógico, densidade 2),
// modo TV do Sofae ativo e a lista de demonstração (filmes abertos da Blender). Sem internet no
// teste: as capas (test/capturas_tv/capas.txt) são baixadas antes pelo workflow para
// test/capturas_tv/capas/ e servidas aqui por um HttpClient falso, que devolve o arquivo local.
// As fontes reais (Roboto e ícones do Material) são carregadas do SDK do Flutter, para o texto
// não sair em quadradinhos.
//
// Gerar os PNG (test/capturas_tv/):
//   (baixar as capas: ver o passo "Capas da demonstração" em .github/workflows/sofae-loja.yml)
//   flutter test --flavor play test/capturas_tv_test.dart --update-goldens
import 'dart:async';
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

/// Capas baixadas pelo workflow (test/capturas_tv/capas/), pelo nome do arquivo na URL.
final _pastaCapas = Directory('test/capturas_tv/capas');

/// URLs das capas que a demonstração usa (filmes e logos dos canais).
Set<String> _urlsDaDemo() => {
      for (final f in ListaDemo.filmes)
        if (f.posterUrl != null) f.posterUrl!,
      for (final c in ListaDemo.canais)
        if (c.logoUrl != null) c.logoUrl!,
    };

String _nome(Uri u) => Uri.decodeComponent(u.pathSegments.last);

File? _capaLocal(Uri u) {
  final f = File('${_pastaCapas.path}/${u.pathSegments.last}');
  if (f.existsSync()) return f;
  if (!_pastaCapas.existsSync()) return null;
  for (final g in _pastaCapas.listSync().whereType<File>()) {
    if (Uri.decodeComponent(g.uri.pathSegments.last) == _nome(u)) return g;
  }
  return null;
}

/// HttpClient falso das imagens de rede: devolve o arquivo local da capa (404 se não houver).
class _CapasLocais implements HttpClient {
  @override
  bool autoUncompress = false;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async => _Pedido(url);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Pedido implements HttpClientRequest {
  _Pedido(this.uri);
  @override
  final Uri uri;
  @override
  final HttpHeaders headers = _Cabecalhos();

  @override
  Future<HttpClientResponse> close() async {
    final f = _capaLocal(uri);
    return _Resposta(f == null ? null : f.readAsBytesSync());
  }

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Cabecalhos implements HttpHeaders {
  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

class _Resposta extends Stream<List<int>> implements HttpClientResponse {
  _Resposta(this._bytes);
  final List<int>? _bytes;

  @override
  int get statusCode => _bytes == null ? HttpStatus.notFound : HttpStatus.ok;
  @override
  int get contentLength => _bytes?.length ?? 0;
  @override
  HttpClientResponseCompressionState get compressionState => HttpClientResponseCompressionState.notCompressed;

  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      Stream<List<int>>.fromIterable([if (_bytes != null) _bytes])
          .listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

/// As capas da demonstração estão todas na lista do workflow e já baixadas.
void _conferirCapas() {
  final lista = File('test/capturas_tv/capas.txt')
      .readAsLinesSync()
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty && !l.startsWith('#'))
      .toSet();
  for (final u in _urlsDaDemo()) {
    expect(lista, contains(u), reason: 'capa da demonstração fora de test/capturas_tv/capas.txt: $u');
    expect(_capaLocal(Uri.parse(u)), isNotNull,
        reason: 'capa não baixada em ${_pastaCapas.path}: $u (o workflow baixa antes do teste)');
  }
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

/// Sem internet: as imagens de rede vêm de [_CapasLocais]. Erros de imagem continuam ignorados
/// (01 e 04 têm logos fora da demonstração).
Future<void> _semRede(Future<void> Function() corpo) async {
  final original = FlutterError.onError;
  FlutterError.onError = (d) {
    final s = d.exceptionAsString();
    if (s.contains('HTTP request failed') || s.contains('NetworkImage')) return;
    original?.call(d);
  };
  debugNetworkImageHttpClientProvider = _CapasLocais.new;
  try {
    await corpo();
  } finally {
    debugNetworkImageHttpClientProvider = null;
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

Future<void> _capturar(WidgetTester tester, String arquivo, {bool assentar = false}) async {
  await _imagens(tester);
  // Espera as animações (abertura da janela, foco do botão) terminarem
  if (assentar) await tester.pumpAndSettle();
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

  testWidgets('02-filmes: grade de Filmes (7 por linha, com capas) e um item focado', (tester) async {
    _conferirCapas();
    await _semRede(() async {
      await _filmes(tester);
      for (var i = 0; i < 6 && !_focoNaGrade(); i++) {
        await _tecla(tester, LogicalKeyboardKey.arrowDown);
      }
      expect(_focoNaGrade(), isTrue, reason: 'o controle não chegou aos filmes');
      await _tecla(tester, LogicalKeyboardKey.arrowRight);
      expect(_focoNaGrade(), isTrue);
      expect(tester.widget<GridView>(find.byType(GridView)).gridDelegate,
          isA<SliverGridDelegateWithFixedCrossAxisCount>().having((d) => d.crossAxisCount, 'colunas', 7));
      await _capturar(tester, '02-filmes.png');
      await _fechar(tester);
    });
  }, skip: !Loja.play);

  testWidgets('03-detalhes: janela de detalhes com capa, sinopse e "Assistir" focado', (tester) async {
    _conferirCapas();
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
      expect(find.descendant(of: janela, matching: find.text('SINOPSE')), findsOneWidget);
      await _capturar(tester, '03-detalhes.png', assentar: true);
      expect(Focus.of(tester.element(find.descendant(of: janela, matching: find.text('Assistir')))).hasFocus,
          isTrue, reason: '"Assistir" perdeu o foco depois das animações');
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
