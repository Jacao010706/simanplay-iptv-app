// Rodar nas duas formas:
//   flutter test test/demo_e_assistindo_test.dart
//   flutter test test/demo_e_assistindo_test.dart --flavor play
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:simanplay_iptv/core/lista_demo.dart';
import 'package:simanplay_iptv/core/loja.dart';
import 'package:simanplay_iptv/models/app_session.dart';
import 'package:simanplay_iptv/screens/device_home_screen.dart';
import 'package:simanplay_iptv/screens/home_screen_v2.dart';
import 'package:simanplay_iptv/screens/license_gate.dart';
import 'package:simanplay_iptv/services/assistindo_service.dart';

/// Licença salva vencida (teste de 7 dias acabou) e servidor fora do ar: a tela de acesso bloqueia.
Map<String, Object> _licencaVencida() => {
      'license_device_code': 'ABC123',
      'license_last_state': jsonEncode({
        'device_code': 'ABC123',
        'mac': '7A:3F:91:C2:0B:E4',
        'device_key': '123456',
        'status': 'expired',
        'allowed': false,
        'days_left': 0,
        'until': DateTime.now().toUtc().subtract(const Duration(days: 1)).toIso8601String(),
        'pay_url': '',
        'plan': null,
      }),
    };

/// Overflow de layout e imagens de rede (sem internet no teste) não fazem parte daqui.
Future<void> _semRuido(Future<void> Function() corpo) async {
  final original = FlutterError.onError;
  FlutterError.onError = (d) {
    final s = d.exceptionAsString();
    if (s.contains('overflowed') || s.contains('HTTP request failed') || s.contains('NetworkImage')) return;
    original?.call(d);
  };
  try {
    await corpo();
  } finally {
    FlutterError.onError = original;
  }
}

void _telaTv(WidgetTester tester) {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 2.0;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => ListaDemo.emUso.value = false);

  group('demonstração sem licença', () {
    testWidgets('teste vencido: a demonstração abre mesmo assim (só na Play) e só ela passa', (tester) async {
      _telaTv(tester);
      SharedPreferences.setMockInitialValues(_licencaVencida());
      await _semRuido(() async {
        await tester.pumpWidget(MaterialApp(
          builder: (c, child) => LicenseGate(child: child!),
          home: const Text('APP_LIBERADO'),
        ));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(find.byType(LicenseBlockedScreen), findsOneWidget, reason: 'licença vencida bloqueia');
        expect(find.text('APP_LIBERADO'), findsNothing);

        if (!Loja.play) {
          // APK do painel: a tela de pagamento continua igual, sem demonstração
          expect(find.byKey(const Key('demo_sem_licenca')), findsNothing);
        } else {
          await tester.tap(find.byKey(const Key('demo_sem_licenca')));
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          expect(find.byType(HomeScreen), findsOneWidget, reason: 'a demonstração abriu sem licença');
          expect(find.byType(LicenseBlockedScreen), findsNothing);
          expect(find.text('APP_LIBERADO'), findsNothing, reason: 'o resto do app continua bloqueado');
          expect(ListaDemo.emUso.value, isTrue);

          // Sair da demonstração (Sair da conta ou abrir outra lista): a tela de licença volta
          ListaDemo.emUso.value = false;
          await tester.pump();
          await tester.pump(const Duration(seconds: 1));
          expect(find.byType(HomeScreen), findsNothing);
          expect(find.byType(LicenseBlockedScreen), findsOneWidget);
          expect(find.text('APP_LIBERADO'), findsNothing);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 30));
      });
    });

    testWidgets('abrir a demonstração pelo openHome marca a demo; outra lista desmarca', (tester) async {
      SharedPreferences.setMockInitialValues({});
      late BuildContext ctx;
      await _semRuido(() async {
        await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
          ctx = c;
          return const SizedBox();
        })));
        await openHome(ctx, ListaDemo.sessao());
        await tester.pump();
        expect(ListaDemo.emUso.value, Loja.play, reason: 'só a Play tem demonstração');
        await openHome(ctx, AppSession.xtream(host: 'http://minha.lista.invalid', username: 'u', password: 'p'));
        await tester.pump();
        expect(ListaDemo.emUso.value, isFalse);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 30));
      });
    });
  });

  group('assistindo agora', () {
    test('quais sessões são da conta do painel', () {
      // Login com usuário e senha do painel (ApiService.buildSession marca a sessão)
      expect(AppSession.simanplay(username: 'joao', password: 'x', primaryM3uUrl: 'http://a/b', contaPainel: true)
          .daContaDoPainel, isTrue);
      // Modo Livre: Xtream digitado no app e link M3U digitado (usuário "m3u", sem senha)
      expect(AppSession.xtream(host: 'http://s', username: 'u', password: 'p').daContaDoPainel, isFalse);
      expect(AppSession.simanplay(username: 'm3u', password: '', primaryM3uUrl: 'http://a/l.m3u').daContaDoPainel,
          isFalse);
      // Demonstração
      expect(ListaDemo.sessao().daContaDoPainel, isFalse);
      // Sessões salvas por versões antigas (sem a marca): painel continua sendo painel
      final antigaPainel = AppSession.fromJson({'type': 'simanplay', 'simanplayUsername': 'joao',
          'simanplayPassword': 'x', 'primaryM3uUrl': 'http://a/b'});
      final antigaM3u = AppSession.fromJson({'type': 'simanplay', 'simanplayUsername': 'm3u',
          'simanplayPassword': '', 'primaryM3uUrl': 'http://a/l.m3u'});
      expect(antigaPainel.daContaDoPainel, isTrue);
      expect(antigaM3u.daContaDoPainel, isFalse);
      // A marca sobrevive a salvar e abrir de novo
      final salva = AppSession.fromJson(jsonDecode(jsonEncode(
          AppSession.simanplay(username: 'joao', password: 'x', primaryM3uUrl: 'http://a/b', contaPainel: true)
              .toJson())) as Map<String, dynamic>);
      expect(salva.daContaDoPainel, isTrue);
    });

    /// Conta os avisos que chegariam ao painel (POST /app/tv/assistindo). Tudo numa zona só:
    /// o aviso periódico roda na zona em que o timer foi criado.
    Future<List<String>> comPainelFalso(Future<void> Function(List<String> avisos) corpo) async {
      final avisos = <String>[];
      await http.runWithClient(() => corpo(avisos), () => MockClient((req) async {
            if (req.url.path.endsWith('/app/tv/assistindo')) avisos.add(req.body);
            return http.Response('{"ok": true}', 200);
          }));
      return avisos;
    }

    for (final caso in [
      ('Modo Livre (Xtream digitado)', AppSession.xtream(host: 'http://minha.lista.invalid', username: 'u', password: 'p'), false),
      ('Modo Livre (link M3U)', AppSession.simanplay(username: 'm3u', password: '', primaryM3uUrl: 'http://minha.lista.invalid/l.m3u'), false),
      ('conta do painel', AppSession.simanplay(username: 'joao', password: 'x', primaryM3uUrl: 'http://painel.invalid/l.m3u', contaPainel: true), true),
    ]) {
      testWidgets('ao abrir ${caso.$1}: ${caso.$3 ? "continua" : "para"} de avisar o painel', (tester) async {
        SharedPreferences.setMockInitialValues({});
        late BuildContext ctx;
        var antes = 0;
        var depois = 0;
        await _semRuido(() async {
          await tester.pumpWidget(MaterialApp(home: Builder(builder: (c) {
            ctx = c;
            return const SizedBox();
          })));
          await comPainelFalso((avisos) async {
            // Estava logado no painel: o app avisava
            await Assistindo.configurar('token-do-painel');
            await tester.pump();
            expect(Assistindo.ativo, isTrue);
            antes = avisos.length;
            expect(antes, greaterThan(0), reason: 'logado no painel, o app avisa');

            await openHome(ctx, caso.$2);
            await tester.pump();
            Assistindo.conteudo('filme', 'Um filme qualquer'); // começou a assistir
            await tester.pump(const Duration(minutes: 3)); // 6 ciclos de 30 s
            depois = avisos.length - antes;
          });
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 30));
        });
        final prefs = await SharedPreferences.getInstance();
        if (caso.$3) {
          expect(depois, greaterThanOrEqualTo(6), reason: 'conta do painel continua avisando (filme: a cada 30 s)');
          expect(Assistindo.ativo, isTrue);
          await Assistindo.configurar(null);
        } else {
          expect(depois, 0, reason: 'nenhum aviso ao painel com lista própria');
          expect(Assistindo.ativo, isFalse);
          expect(prefs.getString('assistindo_tv_token'), isNull, reason: 'o token do painel foi esquecido');
        }
      });
    }

    testWidgets('ao reabrir o app com lista própria salva, não volta a avisar', (tester) async {
      SharedPreferences.setMockInitialValues({
        'assistindo_tv_token': 'token-antigo',
        'session': jsonEncode(AppSession.xtream(host: 'http://minha.lista.invalid', username: 'u', password: 'p').toJson()),
      });
      final avisos = await comPainelFalso((_) async {
        await Assistindo.iniciar();
        await tester.pump(const Duration(minutes: 2));
      });
      expect(avisos, isEmpty);
      expect(Assistindo.ativo, isFalse);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('assistindo_tv_token'), isNull);
    });

    testWidgets('ao reabrir o app com a conta do painel salva, continua avisando', (tester) async {
      SharedPreferences.setMockInitialValues({
        'assistindo_tv_token': 'token-do-painel',
        'session': jsonEncode(AppSession.simanplay(username: 'joao', password: 'x',
            primaryM3uUrl: 'http://painel.invalid/l.m3u', contaPainel: true).toJson()),
      });
      final avisos = await comPainelFalso((_) async {
        await Assistindo.iniciar();
        await tester.pump();
      });
      expect(avisos, isNotEmpty);
      expect(Assistindo.ativo, isTrue);
      await Assistindo.configurar(null);
    });
  });
}
