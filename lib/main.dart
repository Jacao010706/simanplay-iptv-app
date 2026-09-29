import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'core/providers/theme_provider.dart';
import 'screens/activation_screen_v3.dart';
import 'screens/license_gate.dart';
import 'core/app_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized(); // necessário para o player de vídeo
  runApp(const IptvPlayerApp());
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
            title: AppConfig.appName,
            debugShowCheckedModeBanner: false,
            theme: themeProvider.themeData,
            // Teste grátis de 7 dias; depois exige plano pago no site (PIX)
            home: const LicenseGate(child: ActivationScreen()),
          );
        },
      ),
    );
  }
}