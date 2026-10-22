# Build da Google Play (variante `play`)

A variante só existe quando o Gradle recebe `-Ploja=play`. Sem isso, o build é o de sempre
(APK do painel, workflow `build_apk.yml` sem mudança, com o atualizador interno).

| | APK do painel | Play (`--flavor play -Ploja=play`) |
|---|---|---|
| applicationId | `APPLICATION_ID` do workflow | `com.sofae.app` (fixo no flavor) |
| Atualizador interno (`UpdateService`, `installApk`) | sim | não: `Loja.play` é constante e o Dart descarta o código; o Kotlin vem de `src/play` (stub) |
| `REQUEST_INSTALL_PACKAGES`, FileProvider, consulta `INSTALL_PACKAGE` | sim | removidos (`src/play/AndroidManifest.xml`) |
| Preço, PIX, QR, link do site, aviso de teste grátis | sim | não (`license_gate.dart`, `device_home_screen.dart`) |

## Validar localmente (não é o build de envio)
```
flutter test test/loja_play_test.dart --flavor play
flutter build appbundle --debug --flavor play -Ploja=play
```
Saída: `build/app/outputs/bundle/playDebug/app-play-debug.aab`.

## Build de envio (só quando a conta existir; NÃO feito)
1. Versão: `version:` no `pubspec.yaml` (o `versionCode` precisa crescer a cada envio).
2. Chave de upload: decisão do Jacques (ver relatório, "Assinatura"). Nunca commitar a chave.
3. `flutter build appbundle --release --flavor play -Ploja=play` com `android/key.properties`
   apontando para a **chave de upload**.
4. Enviar o `.aab` pelo Play Console (teste fechado primeiro).
