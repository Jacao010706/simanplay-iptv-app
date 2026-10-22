package com.simanplay.iptvplayer.iptv_player

import android.app.Activity
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Atualizador interno (APK distribuído pelo painel): abre o instalador do sistema com o APK
 * baixado. O build da Google Play (-Ploja=play) usa src/play, sem instalador.
 */
object Instalador {
    fun instalar(activity: Activity, call: MethodCall, result: MethodChannel.Result) {
        try {
            val path = call.argument<String>("path")!!
            val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.provider", File(path))
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "application/vnd.android.package-archive")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            activity.startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("INSTALL_FAILED", e.message, null)
        }
    }
}
