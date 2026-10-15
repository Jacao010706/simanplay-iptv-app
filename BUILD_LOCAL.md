# Build local (teste no emulador)

O APK oficial de cada revendedor sai só pelo GitHub Actions (`build_apk.yml`): só ARM
(`android-arm` e `android-arm64`), assinado com a chave oficial. Ele não tem x86_64.

Para testar no emulador do notebook (x86_64), gere um APK **de debug** com x86_64.
Ele é assinado com a chave de debug do computador: serve só para teste, não atualiza
por cima do APK oficial (e vice-versa) e nunca deve ir para cliente.

## Comando (PowerShell, na pasta do app)

```powershell
$env:APPLICATION_ID = "com.sofae.app"   # ID do revendedor que quer testar
D:\src\flutter\bin\flutter build apk --debug --target-platform android-x64
Remove-Item Env:APPLICATION_ID
```

APK gerado: `build\app\outputs\flutter-apk\app-debug.apk`

Instalar no emulador (desinstale antes o APK oficial do mesmo ID, se houver, porque as chaves são diferentes):

```powershell
adb uninstall com.sofae.app
adb install build\app\outputs\flutter-apk\app-debug.apk
```

Sem `APPLICATION_ID`, o build usa o ID antigo (`com.simanplay.iptvplayer.iptv_player`, do PRIMETV).
Se o notebook ficar sem memória no build, feche o emulador e outros programas antes.
