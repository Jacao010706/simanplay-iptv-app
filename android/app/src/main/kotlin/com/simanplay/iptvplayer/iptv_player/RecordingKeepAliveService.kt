package com.simanplay.iptvplayer.iptv_player

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.net.wifi.WifiManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat

/**
 * Mantem o app rodando enquanto ha gravacao em andamento ou agendada:
 * servico em primeiro plano (o Android nao encerra o app) + CPU e Wi-Fi
 * acordados mesmo com a tela da TV apagada ou o usuario em outro app.
 * Quem grava de fato e o codigo Flutter (RecordingService).
 */
class RecordingKeepAliveService : Service() {
    private var wakeLock: PowerManager.WakeLock? = null
    private var wifiLock: WifiManager.WifiLock? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val text = intent?.getStringExtra("text")?.takeIf { it.isNotEmpty() }
            ?: "Gravacao em andamento"
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "Gravacoes", NotificationManager.IMPORTANCE_LOW)
            )
        }
        var flagsPi = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) flagsPi = flagsPi or PendingIntent.FLAG_IMMUTABLE
        val open = packageManager.getLaunchIntentForPackage(packageName)
        val pi = if (open != null) PendingIntent.getActivity(this, 0, open, flagsPi) else null
        val notification = NotificationCompat.Builder(this, CHANNEL)
            .setContentTitle(applicationInfo.loadLabel(packageManager))
            .setContentText(text)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setContentIntent(pi)
            .build()
        val type = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
            ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC else 0
        ServiceCompat.startForeground(this, NOTIF_ID, notification, type)

        if (wakeLock == null) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "simanplay:gravacao").apply {
                setReferenceCounted(false)
                acquire()
            }
        }
        if (wifiLock == null) {
            val wm = applicationContext.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            @Suppress("DEPRECATION")
            wifiLock = wm?.createWifiLock(WifiManager.WIFI_MODE_FULL_HIGH_PERF, "simanplay:gravacao")?.apply {
                setReferenceCounted(false)
                acquire()
            }
        }
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        try { wakeLock?.release() } catch (e: Exception) {}
        try { wifiLock?.release() } catch (e: Exception) {}
        wakeLock = null
        wifiLock = null
        super.onDestroy()
    }

    companion object {
        const val CHANNEL = "gravacoes"
        const val NOTIF_ID = 4021
    }
}
