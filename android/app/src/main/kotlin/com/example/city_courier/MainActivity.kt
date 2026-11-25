package com.example.city_courier

import android.app.KeyguardManager
import android.content.Context
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val VOICE_CALL_CHANNEL = "city_courier/voice_call_native"
    }

    private var activeRingtone: Ringtone? = null
    private var activeWakeLock: PowerManager.WakeLock? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VOICE_CALL_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startIncomingRingtone" -> {
                        enableCallWindowFlags(true)
                        startRingtoneAndVibration()
                        result.success(true)
                    }
                    "stopRingtone" -> {
                        stopRingtoneAndVibration()
                        result.success(true)
                    }
                    "startCallService" -> {
                        val title = call.argument<String>("title") ?: "Panggilan Suara"
                        val subtitle = call.argument<String>("subtitle") ?: "Tersambung di City Courier"
                        enableCallWindowFlags(true)
                        stopRingtoneAndVibration()
                        setCommunicationAudioMode(true)
                        acquireProximityOrPartialWakeLock()
                        VoiceCallForegroundService.start(applicationContext, title, subtitle)
                        result.success(true)
                    }
                    "stopCallService" -> {
                        stopRingtoneAndVibration()
                        VoiceCallForegroundService.stop(applicationContext)
                        setCommunicationAudioMode(false)
                        releaseWakeLock()
                        enableCallWindowFlags(false)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun enableCallWindowFlags(enable: Boolean) {
        runOnUiThread {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                setShowWhenLocked(enable)
                setTurnScreenOn(enable)
                if (enable) {
                    val km = getSystemService(Context.KEYGUARD_SERVICE) as? KeyguardManager
                    km?.requestDismissKeyguard(this, null)
                }
            } else {
                @Suppress("DEPRECATION")
                if (enable) {
                    window.addFlags(
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                    )
                } else {
                    window.clearFlags(
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
                    )
                }
            }
            if (enable) {
                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
        }
    }

    private fun startRingtoneAndVibration() {
        stopRingtoneAndVibration()
        try {
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            val ringtone = RingtoneManager.getRingtone(applicationContext, uri)
            if (ringtone != null) {
                ringtone.audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                    ringtone.isLooping = true
                }
                ringtone.play()
                activeRingtone = ringtone
            }
        } catch (_: Throwable) {}

        try {
            val pattern = longArrayOf(0, 700, 500, 700, 1200)
            val vibrator = getAppVibrator()
            if (vibrator != null && vibrator.hasVibrator()) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    vibrator.vibrate(VibrationEffect.createWaveform(pattern, 0))
                } else {
                    @Suppress("DEPRECATION")
                    vibrator.vibrate(pattern, 0)
                }
            }
        } catch (_: Throwable) {}
    }

    private fun stopRingtoneAndVibration() {
        try {
            activeRingtone?.stop()
        } catch (_: Throwable) {}
        activeRingtone = null

        try {
            getAppVibrator()?.cancel()
        } catch (_: Throwable) {}
    }

    private fun getAppVibrator(): Vibrator? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager
            vm?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    private fun setCommunicationAudioMode(inCall: Boolean) {
        try {
            val am = getSystemService(Context.AUDIO_SERVICE) as? AudioManager ?: return
            am.mode = if (inCall) AudioManager.MODE_IN_COMMUNICATION else AudioManager.MODE_NORMAL
        } catch (_: Throwable) {}
    }

    private fun acquireProximityOrPartialWakeLock() {
        releaseWakeLock()
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as? PowerManager ?: return
            val wl = pm.newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "CityCourier::VoiceCallWakeLock")
            wl.acquire(4 * 60 * 60 * 1000L)
            activeWakeLock = wl
        } catch (_: Throwable) {}
    }

    private fun releaseWakeLock() {
        try {
            if (activeWakeLock?.isHeld == true) {
                activeWakeLock?.release()
            }
        } catch (_: Throwable) {}
        activeWakeLock = null
    }

    override fun onDestroy() {
        stopRingtoneAndVibration()
        releaseWakeLock()
        super.onDestroy()
    }
}
