import 'app_config.dart';

/// Versão sem o número do build: igual ao "version:" do pubspec.yaml (conferido por teste).
const String kVersaoNome = '1.0.0';

/// Ex.: "Sofae v1.0.0+3". O número depois do + é o do build do CI (AppConfig.buildNumber).
String get versaoApp => '${AppConfig.appName} v$kVersaoNome+${AppConfig.buildNumber}';
