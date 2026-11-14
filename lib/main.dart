import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'core/providers/theme_provider.dart';
import 'screens/device_home_screen.dart';
import 'screens/license_gate.dart';
import 'core/app_config.dart';
import 'core/janela_pc.dart';
import 'core/plataforma.dart';
import 'services/update_service.dart';
import 'widgets/pc_input.dart';
import 'widgets/tv_focus.dart';
import 'services/recording_service.dart';
import 'services/assistindo_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized(); // necessário para o player de vídeo
  // PC: janela 1280x720 (mínimo 960x540) com o nome do app. Fora do Windows não faz nada.
  await JanelaPc.iniciar();
  runApp(const IptvPlayerApp());
  // Novidades da versao + verificacao de atualizacao (em segundo plano)
  UpdateService.runStartupChecks();
  // Retoma a vigilancia das gravacoes agendadas
  RecordingService.instance.init();
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
            // PC: listas também rolam arrastando com o mouse
            scrollBehavior: Plataforma.windows ? const RolagemPc() : null,
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: themeProvider.themeData,
            // Tela inicial estilo IBO: MAC + chave do aparelho e as listas cadastradas no site
            home: const DeviceHomeScreen(),
            // Teste grátis de 7 dias; depois exige plano pago no site (PIX).
            // Envolve o app inteiro, então o bloqueio vale em qualquer tela.
            builder: (context, child) {
              // TVs costumam vir com fonte do sistema bem grande: limita o
              // aumento para o texto nao estourar botoes e campos.
              final mq = MediaQuery.of(context);
              return MediaQuery(
                data: mq.copyWith(
                    textScaler: mq.textScaler.clamp(maxScaleFactor: 1.15)),
                // PC: Esc/Backspace voltam uma tela
                child: AtalhosPc(
                  navigatorKey: appNavigatorKey,
                  child: FocusRing(
                      child: LicenseGate(child: child ?? const SizedBox.shrink())),
                ),
              );
            },
          );
        },
      ),
    );
  }
}