package com.simanplay.iptvplayer.iptv_player

import android.app.UiModeManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.os.Build
import android.provider.Settings
import java.security.MessageDigest
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
                    "apkInfo" -> {
                        // Sem "path": dados do app instalado. Com "path": do APK baixado,
                        // mais o SHA-256 do arquivo. O atualizador compara os dois antes de instalar.
                        try {
                            val path = call.argument<String>("path")
                            result.success(if (path == null) infoInstalado() else infoArquivo(path))
                        } catch (e: Exception) {
                            result.error("APK_INFO", e.message, null)
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

    private fun sha256Hex(bytes: ByteArray): String =
        MessageDigest.getInstance("SHA-256").digest(bytes).joinToString("") { "%02x".format(it) }

    private fun sha256Arquivo(f: File): String {
        val md = MessageDigest.getInstance("SHA-256")
        f.inputStream().use { s ->
            val buf = ByteArray(1 shl 16)
            while (true) {
                val n = s.read(buf)
                if (n < 0) break
                md.update(buf, 0, n)
            }
        }
        return md.digest().joinToString("") { "%02x".format(it) }
    }

    @Suppress("DEPRECATION")
    private fun certificados(pi: PackageInfo?): List<String> {
        if (pi == null) return emptyList()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val si = pi.signingInfo
            if (si != null) {
                val sigs = if (si.hasMultipleSigners()) si.apkContentsSigners else si.signingCertificateHistory
                if (!sigs.isNullOrEmpty()) return sigs.map { sha256Hex(it.toByteArray()) }
            }
        }
        return (pi.signatures ?: emptyArray()).map { sha256Hex(it.toByteArray()) }
    }

    @Suppress("DEPRECATION")
    private fun flagsAssinatura(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P)
            PackageManager.GET_SIGNING_CERTIFICATES or PackageManager.GET_SIGNATURES
        else PackageManager.GET_SIGNATURES

    @Suppress("DEPRECATION")
    private fun versao(pi: PackageInfo): Long =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) pi.longVersionCode else pi.versionCode.toLong()

    private fun infoInstalado(): Map<String, Any?> {
        val pi = packageManager.getPackageInfo(packageName, flagsAssinatura())
        return mapOf("package" to packageName, "versionCode" to versao(pi), "certs" to certificados(pi))
    }

    private fun infoArquivo(path: String): Map<String, Any?> {
        val f = File(path)
        val pi = packageManager.getPackageArchiveInfo(path, flagsAssinatura())
        return mapOf(
            "package" to pi?.packageName,
            "versionCode" to (pi?.let { versao(it) } ?: 0L),
            "certs" to certificados(pi),
            "sha256" to sha256Arquivo(f),
        )
    }
}
