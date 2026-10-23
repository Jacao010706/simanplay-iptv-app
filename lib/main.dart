import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'core/providers/theme_provider.dart';
import 'screens/device_home_screen.dart';
import 'screens/license_gate.dart';
import 'core/marca.dart';
import 'core/loja.dart';
import 'core/modo_tv.dart';
import 'services/update_service.dart';
import 'widgets/tv_focus.dart';
import 'widgets/modo_tv_widgets.dart';
import 'services/recording_service.dart';
import 'services/assistindo_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized(); // necessário para o player de vídeo
  // TV/TV box/Fire TV e pacote do APK: fonte, overscan, saída e (Sofae) telas sem pagamento
  await ModoTv.iniciar();
  runApp(const IptvPlayerApp());
  // Novidades da versao + verificacao de atualizacao (em segundo plano).
  // Na Play quem atualiza e a loja: o atualizador nem entra no build.
  if (!Loja.play) UpdateService.runStartupChecks();
  // Retoma a vigilancia das gravacoes agendadas (a Play nao tem gravacao)
  if (!Loja.play) RecordingService.instance.init();
  // "Assistindo agora" no painel: retoma os avisos com o token salvo
  Assistindo.iniciar();
}

class IptvPlayerApp extends StatelessWidget {
  const IptvPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ThemeProvider()..loadSavedTheme(),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            navigatorKey: appNavigatorKey,
            shortcuts: appShortcuts,
            title: Marca.appName,
            debugShowCheckedModeBanner: false,
            theme: themeProvider.themeData,
            // Tela inicial estilo IBO: MAC + chave do aparelho e as listas cadastradas no site
            home: const DeviceHomeScreen(),
            // Teste grátis de 7 dias; depois exige plano pago no site (PIX).
            // Envolve o app inteiro, então o bloqueio vale em qualquer tela.
            builder: (context, child) {
              // TVs costumam vir com fonte do sistema bem grande: limita o
              // aumento para o texto nao estourar botoes e campos. Na TV a escala e
              // fixa (texto legivel a ~3 m) e o app ganha a margem de overscan.
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(
                    textScaler: ModoTv.tv
                        ? const TextScaler.linear(ModoTv.escalaTexto)
                        : mq.textScaler.clamp(maxScaleFactor: 1.15)),
                child: MargemTv(
                    child: FocusRing(
                        child: LicenseGate(child: child ?? const SizedBox.shrink()))),
              );
            },
          );
        },
      ),
    );
  }
}