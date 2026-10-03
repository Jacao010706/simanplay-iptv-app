package com.simanplay.iptvplayer.iptv_player

import android.content.Intent
import android.provider.Settings
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
                    "isTvDevice" ->
                        result.success(packageManager.hasSystemFeature("android.software.leanback"))
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
                    else ->
                        result.notImplemented()
                }
            }
    }
}
