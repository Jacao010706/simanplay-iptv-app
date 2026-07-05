import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:media_kit/media_kit.dart';
import 'core/providers/theme_provider.dart';
import 'screens/activation_screen_v3.dart';

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
            title: 'SimanPlay IPTV',
            debugShowCheckedModeBanner: false,
            theme: themeProvider.themeData,
            home: const ActivationScreen(),
          );
        },
      ),
    );
  }
}