package com.example.planner

import android.app.*
import android.content.*
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat

class FocusAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val title = intent.getStringExtra("title") ?: "پایان زمان تمرکز"
        FocusAlarmScheduler.cancel(context)
        val service = Intent(context, AlarmSoundService::class.java).putExtra("title", title)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) context.startForegroundService(service) else context.startService(service)
    }
}

class AlarmActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        context.stopService(Intent(context, AlarmSoundService::class.java))
    }
}

class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) FocusAlarmScheduler.restore(context)
    }
}

class AlarmSoundService : Service() {
    private var ringtone: Ringtone? = null
    private val channelId = "focus_alarm_channel"
    override fun onCreate() { super.onCreate(); createChannel() }
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val title = intent?.getStringExtra("title") ?: "پایان زمان تمرکز"
        val stopIntent = PendingIntent.getBroadcast(this, 7320, Intent(this, AlarmActionReceiver::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val openIntent = PendingIntent.getActivity(this, 7321, Intent(this, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title).setContentText("زمان تمرکز به پایان رسید")
            .setCategory(NotificationCompat.CATEGORY_ALARM).setPriority(NotificationCompat.PRIORITY_MAX)
            .setOngoing(true).setAutoCancel(false).setContentIntent(openIntent)
            .setFullScreenIntent(openIntent, true)
            .addAction(android.R.drawable.ic_media_pause, "توقف زنگ", stopIntent).build()
        startForeground(7319, notification)
        try {
            if (ringtone?.isPlaying != true) {
                val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                ringtone = RingtoneManager.getRingtone(applicationContext, uri)
                ringtone?.audioAttributes = AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_ALARM).setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION).build()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) ringtone?.isLooping = true
                ringtone?.play()
            }
        } catch (_: Exception) { }
        return START_NOT_STICKY
    }
    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            val channel = NotificationChannel(channelId, "پایان تمرکز", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "هشدار پایان زمان تمرکز"
                setSound(null, null)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            manager.createNotificationChannel(channel)
        }
    }
    override fun onDestroy() { ringtone?.stop(); ringtone = null; stopForeground(true); super.onDestroy() }
    override fun onBind(intent: Intent?): IBinder? = null
}
