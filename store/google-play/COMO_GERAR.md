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

## Chave de envio (upload key) — uma vez por PC
**Estado em 24/10/2026:** `android/key.properties` **não existe** neste PC; o AAB de envio ainda
não foi gerado. Depois de criar o arquivo (bloco abaixo), peça o build ou rode a seção
"Build de envio".

O AAB da Play é assinado com a **chave de envio** `D:\chaves\simanplay-release.jks` (alias
`simanplay`). No Play App Signing, a Google guarda a chave que assina o app instalado; a nossa só
prova que o envio é nosso. As senhas ficam só em `android/key.properties`, que está no
`android/.gitignore` e **nunca** vai para o Git. Sem esse arquivo, o build release da Play
**para com erro** (de propósito: antes ele assinava com a chave de debug sem avisar).

Criar o arquivo sem a senha aparecer na tela nem no histórico (PowerShell):
```powershell
$s = Read-Host "Senha da keystore" -AsSecureString
$k = Read-Host "Senha da chave 'simanplay' (Enter = a mesma)" -AsSecureString
$ps = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($s))
$pk = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($k))
if (-not $pk) { $pk = $ps }
"storeFile=D:/chaves/simanplay-release.jks`nkeyAlias=simanplay`nstorePassword=$ps`nkeyPassword=$pk`n" |
  Set-Content -NoNewline -Encoding ascii D:\projetos\simanplay-iptv\simanplay-iptv-app\android\key.properties
Remove-Variable s, k, ps, pk
git -C D:\projetos\simanplay-iptv\simanplay-iptv-app check-ignore android/key.properties
```
A última linha deve imprimir `android/key.properties` (prova de que o Git ignora o arquivo).
Se a senha tiver `\`, escreva `\` no arquivo (formato `.properties`).

## Build de envio
1. Versão: `version:` no `pubspec.yaml` (`1.0.0+1` no primeiro envio). O número depois do `+`
   (`versionCode`) precisa crescer a cada envio.
2. `flutter clean`
3. `flutter build appbundle --release --no-tree-shake-icons --flavor play -Ploja=play`
   **Atenção:** `flutter build appbundle --flavor play --release` sozinho **falha** ("Gradle
   project does not define a task suitable for the requested build"): o flavor `play` só existe
   com `-Ploja=play`.
4. Saída: `build/app/outputs/bundle/playRelease/app-play-release.aab`.
5. Conferir a assinatura (não mostra senha):
   `jarsigner -verify -verbose:summary -certs build\app\outputs\bundle\playRelease\app-play-release.aab`
   deve dizer `jar verified.` e o certificado deve ter o mesmo SHA-256 de
   `keytool -list -v -keystore D:\chaves\simanplay-release.jks -alias simanplay` (pede a senha).
6. Envie o `.aab` pelo Play Console, começando pelo teste fechado.
