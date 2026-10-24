// Capturas de tela da Google Play a partir das telas reais da variante play, só com a
// demonstração (filmes da Blender, Creative Commons). Sem dados reais nem credenciais.
//
//   flutter test tool/capturas/capturas_play_test.dart --flavor play
//
// Saída: store/google-play/capturas/bruto/*.png (com alfa). O script que converte para PNG
// 24 bits está em store/google-play/capturas/LEIA-ME.md.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:simanplay_iptv/core/lista_demo.dart';
import 'package:simanplay_iptv/core/loja.dart';
import 'package:simanplay_iptv/core/modo_tv.dart';
import 'package:simanplay_iptv/core/providers/theme_provider.dart';
import 'package:simanplay_iptv/screens/home_screen_v2.dart';
import 'package:simanplay_iptv/screens/home_tv_screen.dart';
import 'package:simanplay_iptv/screens/license_gate.dart';
import 'package:simanplay_iptv/widgets/modo_tv_widgets.dart';

const _saida = 'store/google-play/capturas/bruto';
// Celular em pé 1080x1920 (9:16)
const _tamanho = Size(1080, 1920);
const _dpr = 2.625;

/// Aparelho novo ainda sem acesso liberado (código fictício), servidor fora do ar.
Map<String, Object> _aparelhoNovo() => {
      'license_device_code': 'DEMO01',
      'license_last_state': jsonEncode({
        'device_code': 'DEMO01',
        'mac': '7A:3F:91:C2:0B:E4',
        'device_key': '000000',
        'status': 'expired',
        'allowed': false,
        'days_left': 0,
        'until': DateTime.now().toUtc().subtract(const Duration(days: 1)).toIso8601String(),
        'pay_url': '',
        'plan': null,
      }),
    };

Future<void> _fontes() async {
  final base = '${Platform.environment['FLUTTER_ROOT'] ?? 'D:/src/flutter'}/bin/cache/artifacts/material_fonts';
  final roboto = FontLoader('Roboto');
  for (final f in ['roboto-regular.ttf', 'roboto-medium.ttf', 'roboto-bold.ttf', 'roboto-light.ttf']) {
    roboto.addFont(File('$base/$f').readAsBytes().then((b) => ByteData.view(b.buffer)));
  }
  await roboto.load();
  final icones = FontLoader('MaterialIcons')
    ..addFont(File('$base/materialicons-regular.otf').readAsBytes().then((b) => ByteData.view(b.buffer)));
  await icones.load();
  final emoji = FontLoader('ReservaEmoji')
    ..addFont(File('C:/Windows/Fonts/seguiemj.ttf').readAsBytes().then((b) => ByteData.view(b.buffer)));
  await emoji.load();
}

/// Deixa as imagens de rede (capas da Blender no Wikimedia Commons) carregarem de verdade.
Future<void> _esperarImagens(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 2)));
    await tester.pump(const Duration(milliseconds: 300));
  }
}

Future<void> _capturar(WidgetTester tester, String nome) async {
  await _esperarImagens(tester);
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('captura')));
  await tester.runAsync(() async {
    final ui.Image img = await boundary.toImage(pixelRatio: tester.view.devicePixelRatio);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final f = File('$_saida/$nome.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
  });
  // ignore: avoid_print
  print('captura: $_saida/$nome.png');
}

ThemeData _comReserva(ThemeData t) => t.copyWith(
      textTheme: t.textTheme.apply(fontFamilyFallback: const ['ReservaEmoji']),
      primaryTextTheme: t.primaryTextTheme.apply(fontFamilyFallback: const ['ReservaEmoji']),
    );

/// Baixa as capas da demonstração uma a uma (o Wikimedia recusa muitas de uma vez) e deixa no
/// cache de imagens, como no aparelho depois de alguns segundos de uso.
Future<void> _precarregarCapas(WidgetTester tester) async {
  final urls = {
    ...ListaDemo.filmes.map((f) => f.posterUrl).whereType<String>(),
    ...ListaDemo.canais.map((c) => c.logoUrl).whereType<String>(),
  };
  final ctx = tester.element(find.byType(MaterialApp));
  var ok = 0;
  for (final u in urls) {
    await tester.runAsync(() async {
      var erro = false;
      await precacheImage(NetworkImage(u), ctx, onError: (_, __) => erro = true);
      if (!erro) ok++;
      await Future.delayed(const Duration(milliseconds: 400));
    });
  }
  // ignore: avoid_print
  print('capas carregadas: $ok de ${urls.length}');
}

Future<void> _tocar(WidgetTester tester, String texto) async {
  final alvo = find.text(texto);
  expect(alvo, findsWidgets, reason: 'não achei "$texto" na tela');
  // o último é o da barra de baixo (o primeiro pode ser o título de uma seção)
  await tester.tap(alvo.last, warnIfMissed: false);
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

/// Rede só para os servidores das capas da demonstração (Wikimedia Commons). Qualquer outro
/// endereço (o nosso servidor de licença, por exemplo) falha como se estivesse sem internet:
/// o teste nunca registra aparelho nem consulta nada em produção.
class _SoDemonstracao extends HttpOverrides {
  static const _permitidos = {'upload.wikimedia.org', 'thumb.wikimedia.org'};

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final c = super.createHttpClient(context);
    c.connectionFactory = (uri, proxyHost, proxyPort) {
      if (!_permitidos.contains(uri.host)) {
        throw SocketException('bloqueado no teste de capturas: ${uri.host}');
      }
      return uri.scheme == 'https'
          ? SecureSocket.startConnect(uri.host, uri.port).then((t) => t)
          : Socket.startConnect(uri.host, uri.port).then((t) => t);
    };
    return c;
  }
}

/// Prepara a rede, as fontes e o app (igual ao IptvPlayerApp do main.dart) e abre a tela de
/// aparelho sem acesso. Na TV usa a mesma escala de texto e margem de overscan do main.dart.
Future<void> _abrirApp(WidgetTester tester, {required bool tv}) async {
  expect(Loja.play, isTrue, reason: 'rode com --flavor play');
  HttpOverrides.global = _SoDemonstracao(); // só as capas abertas; o resto fica sem rede
  await tester.runAsync(_fontes);
  // Trava de segurança: o servidor de produção tem de estar inalcançável neste teste
  final producao = await tester.runAsync(() async {
    try {
      final r = await (await HttpClient().getUrl(Uri.parse('https://web-production-d8671.up.railway.app/'))).close();
      return 'ALCANÇÁVEL (${r.statusCode})';
    } on SocketException {
      return 'bloqueado';
    }
  });
  expect(producao, 'bloqueado', reason: 'o teste não pode falar com o servidor de produção');
  tester.view.physicalSize = tv ? const Size(1920, 1080) : _tamanho;
  tester.view.devicePixelRatio = tv ? 2.0 : _dpr;
  addTearDown(tester.view.reset);
  ModoTv.debugDefinir(tv: tv, pacote: ModoTv.pacoteSofae);
  addTearDown(() => ModoTv.debugDefinir());

  final ruido = FlutterError.onError;
  FlutterError.onError = (d) {
    final s = d.exceptionAsString();
    if (s.contains('overflowed') || s.contains('HTTP') || s.contains('NetworkImage') || s.contains('Socket')) return;
    ruido?.call(d);
  };
  addTearDown(() => FlutterError.onError = ruido);

  SharedPreferences.setMockInitialValues(_aparelhoNovo());
  ListaDemo.emUso.value = false;
  await tester.pumpWidget(RepaintBoundary(
    key: const Key('captura'),
    child: ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: Builder(builder: (c) => MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _comReserva(c.watch<ThemeProvider>().themeData),
            builder: (c, child) => MediaQuery(
              data: MediaQuery.of(c).copyWith(
                  textScaler: tv ? const TextScaler.linear(ModoTv.escalaTexto) : TextScaler.noScaling),
              child: MargemTv(child: LicenseGate(child: child!)),
            ),
            home: const SizedBox(),
          )),
    ),
  ));
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
  expect(find.byType(LicenseBlockedScreen), findsOneWidget);
}

Future<void> _abrirDemonstracao(WidgetTester tester) async {
  await _precarregarCapas(tester);
  await tester.tap(find.byKey(const Key('demo_sem_licenca')));
  await tester.pump();
  await tester.pump(const Duration(seconds: 2));
}

void main() {
  testWidgets('capturas do celular (demonstração)', (tester) async {
    await _abrirApp(tester, tv: false);
    await _capturar(tester, '1-codigo-do-aparelho');
    await _abrirDemonstracao(tester);
    expect(find.byType(HomeScreen), findsOneWidget);
    await _capturar(tester, '2-inicio-demonstracao');
    await _tocar(tester, 'Filmes');
    await _capturar(tester, '3-filmes-abertos');
    await _tocar(tester, 'Ao Vivo');
    await _capturar(tester, '4-tv-ao-vivo-demonstracao');
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('capturas da Android TV (demonstração)', (tester) async {
    await _abrirApp(tester, tv: true);
    await _capturar(tester, 'tv-1-codigo-do-aparelho');
    await _abrirDemonstracao(tester);
    expect(find.byType(HomeTvScreen), findsOneWidget, reason: 'Sofae na TV abre a tela de 4 blocos');
    await _capturar(tester, 'tv-2-inicio');
    await _tocar(tester, 'Filmes');
    await _capturar(tester, 'tv-3-filmes-abertos');
  }, timeout: const Timeout(Duration(minutes: 5)));
}
