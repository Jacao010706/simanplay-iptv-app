package com.simanplay.iptvplayer.iptv_player

import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // ID estável do aparelho (ANDROID_ID): a licença reconhece o aparelho
        // mesmo se o app for reinstalado, sem reiniciar o teste grátis.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "primetv/device")
            .setMethodCallHandler { call, result ->
                if (call.method == "androidId") {
                    result.success(Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID))
                } else {
                    result.notImplemented()
                }
            }
    }
}
