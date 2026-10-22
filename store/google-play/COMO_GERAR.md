# Build da Google Play (variante `play`)

A variante só existe quando o Gradle recebe `-Ploja=play`. Sem isso, o build é o de sempre
(APK do painel, workflow `build_apk.yml` sem mudança, com o atualizador interno).

| | APK do painel | Play (`--flavor play -Ploja=play`) |
|---|---|---|
| applicationId | `APPLICATION_ID` do workflow | `com.sofae.app` (fixo no flavor) |
| Atualizador interno (`UpdateService`, `installApk`) | sim | não: `Loja.play` é constante e o Dart descarta o código; o Kotlin vem de `src/play` (stub) |
| `REQUEST_INSTALL_PACKAGES`, FileProvider, consulta `INSTALL_PACKAGE` | sim | removidos (`src/play/AndroidManifest.xml`) |
| Preço, PIX, QR, link do site, aviso de teste grátis | sim | não (`license_gate.dart`, `device_home_screen.dart`) |
| Gravação (botões, agendamento, serviço e permissões) | sim | não (`player_screen.dart`, `live_tv_screen.dart`, `main.dart`, `src/play/AndroidManifest.xml`) |
| Jogos do Dia | sim | não (6 temas em `home_screen_v2.dart`) |
| Marca | a do revendedor (`AppConfig`, gerado pelo workflow) | Sofae fixa (`lib/core/marca.dart`, `src/play/res`, `assets/play/`, rótulo no manifesto) |
| Lista de demonstração | não | botão "Ver demonstração" (`lib/core/lista_demo.dart`) |

## Validar localmente (não é o build de envio)
```
flutter test --flavor play            # suíte inteira na variante Play
flutter test                          # suíte inteira no APK do painel
flutter build appbundle --debug --flavor play -Ploja=play
```
Saída: `build/app/outputs/bundle/playDebug/app-play-debug.aab`.

**Sempre rode `flutter clean` antes de um build de envio.** Em 22/10/2026, o Gradle (AGP 9)
reaproveitou a saída antiga de três tarefas: `mergePlayReleaseJniLibFolders`,
`mergePlayReleaseNativeLibs` e `stripPlayReleaseDebugSymbols`. Resultado: o AAB saiu com o
`libapp.so` do build anterior, embora o novo já estivesse em
`build/app/intermediates/flutter/playRelease/jniLibs/`.

Para conferir depois de gerar, procure no `base/lib/arm64-v8a/libapp.so` do AAB um texto que
acabou de mudar.

## Build de envio (só quando a conta existir; NÃO feito)
1. Versão: ajuste `version:` no `pubspec.yaml`. O `versionCode` precisa crescer a cada envio.
2. Chave de upload: decisão do Jacques (ver o relatório, item "Assinatura"). Nunca commite a
   chave.
3. Rode `flutter clean`.
4. Rode `flutter build appbundle --release --no-tree-shake-icons --flavor play -Ploja=play`, com
   o `android/key.properties` apontando para a **chave de upload**.
5. Envie o `.aab` pelo Play Console, começando pelo teste fechado.
