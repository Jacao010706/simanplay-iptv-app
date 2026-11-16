import 'app_config.dart';
import 'marca.dart';

/// Versão sem o número do build: igual ao "version:" do pubspec.yaml (conferido por teste).
const String kVersaoNome = '1.1.0';

/// Ex.: "Sofae v1.1.0+1007". O número depois do + é o do build do CI (AppConfig.buildNumber;
/// na versão de loja, o versionCode).
String get versaoApp => '${Marca.appName} v$kVersaoNome+${AppConfig.buildNumber}';
