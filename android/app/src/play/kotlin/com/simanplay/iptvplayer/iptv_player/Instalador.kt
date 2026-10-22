package com.simanplay.iptvplayer.iptv_player

import android.app.Activity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** Google Play: o app não instala APK; quem atualiza é a loja. */
object Instalador {
    fun instalar(activity: Activity, call: MethodCall, result: MethodChannel.Result) =
        result.notImplemented()
}
