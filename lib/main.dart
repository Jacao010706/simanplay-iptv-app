import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'core/providers/theme_provider.dart';
import 'screens/device_home_screen.dart';
import 'screens/license_gate.dart';
import 'core/app_config.dart';
import 'services/update_service.dart';
import 'widgets/tv_focus.dart';
import 'services/recording_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized(); // necessário para o player de vídeo
  runApp(const IptvPlayerApp());
  // Novidades da versao + verificacao de atualizacao (em segundo plano)
  UpdateService.runStartupChecks();
  // Retoma a vigilancia das gravacoes agendadas
  RecordingService.instance.init();
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
                child: FocusRing(
                    child: LicenseGate(child: child ?? const SizedBox.shrink())),
              );
            },
          );
        },
      ),
    );
  }
}