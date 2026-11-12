package com.example.planner

import android.app.AlarmManager
import android.Manifest
import android.content.pm.PackageManager
import android.os.Bundle
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (Build.VERSION.SDK_INT >= 33 && checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 9001)
        }
        if (Build.VERSION.SDK_INT >= 27) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
    }
    private val channel = "planner/alarm"
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleFocusAlarm" -> {
                    val delay = call.argument<Number>("delayMs")?.toLong() ?: 0L
                    val title = call.argument<String>("title") ?: "پایان زمان تمرکز"
                    if (delay <= 0) { result.error("INVALID_DELAY", "زمان نامعتبر است", null); return@setMethodCallHandler }
                    try {
                        FocusAlarmScheduler.schedule(this, System.currentTimeMillis() + delay, title)
                        result.success(true)
                    } catch (e: SecurityException) {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                            startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM, Uri.parse("package:$packageName")))
                        }
                        result.error("EXACT_ALARM_PERMISSION", "اجازه آلارم دقیق لازم است", null)
                    }
                }
                "cancelFocusAlarm" -> { FocusAlarmScheduler.cancel(this); result.success(true) }
                "stopAlarmSound" -> { stopService(Intent(this, AlarmSoundService::class.java)); result.success(true) }
                else -> result.notImplemented()
            }
        }
    }
}

object FocusAlarmScheduler {
    private const val REQUEST = 7319
    private const val PREFS = "focus_alarm_state"
    fun schedule(context: Context, atMillis: Long, title: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        prefs.edit().putLong("at", atMillis).putString("title", title).apply()
        val intent = Intent(context, FocusAlarmReceiver::class.java).putExtra("title", title)
        val pi = PendingIntent.getBroadcast(context, REQUEST, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val show = PendingIntent.getActivity(context, 7318, Intent(context, MainActivity::class.java), PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        manager.setAlarmClock(AlarmManager.AlarmClockInfo(atMillis, show), pi)
    }
    fun cancel(context: Context) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = PendingIntent.getBroadcast(context, REQUEST, Intent(context, FocusAlarmReceiver::class.java), PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE)
        if (pi != null) manager.cancel(pi)
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
    }
    fun restore(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val at = prefs.getLong("at", 0L)
        if (at > System.currentTimeMillis()) schedule(context, at, prefs.getString("title", "پایان زمان تمرکز") ?: "پایان زمان تمرکز")
        else prefs.edit().clear().apply()
    }
}
