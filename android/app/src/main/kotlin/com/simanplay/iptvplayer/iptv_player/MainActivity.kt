package com.simanplay.iptvplayer.iptv_player

import android.app.UiModeManager
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.provider.Settings
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "primetv/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "androidId" ->
                        result.success(Settings.Secure.getString(contentResolver, Settings.Secure.ANDROID_ID))
                    "isTvDevice" -> {
                        // Muitas TVs/TV box nao declaram "leanback": checa tambem
                        // o modo de TV e a ausencia de tela de toque.
                        val uiMode = (getSystemService(Context.UI_MODE_SERVICE) as UiModeManager)
                            .currentModeType
                        val pm = packageManager
                        result.success(
                            uiMode == Configuration.UI_MODE_TYPE_TELEVISION ||
                            pm.hasSystemFeature("android.software.leanback") ||
                            pm.hasSystemFeature("android.hardware.type.television") ||
                            !pm.hasSystemFeature("android.hardware.touchscreen")
                        )
                    }
                    "installApk" -> {
                        try {
                            val path = call.argument<String>("path")!!
                            val uri = FileProvider.getUriForFile(this, "$packageName.provider", File(path))
                            val intent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            startActivity(intent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INSTALL_FAILED", e.message, null)
                        }
                    }
                    "keepAlive" -> {
                        try {
                            val on = call.argument<Boolean>("on") ?: false
                            val i = Intent(this, RecordingKeepAliveService::class.java)
                                .putExtra("text", call.argument<String>("text") ?: "")
                            if (on) ContextCompat.startForegroundService(this, i) else stopService(i)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("KEEP_ALIVE", e.message, null)
                        }
                    }
                    else ->
                        result.notImplemented()
                }
            }
    }
}
