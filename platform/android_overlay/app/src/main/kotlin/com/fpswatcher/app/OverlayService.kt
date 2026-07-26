package com.fpswatcher.app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.TextView
import com.fpswatcher.app.shizuku.ShizukuClient
import java.util.Locale
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.roundToInt

class OverlayService : Service() {
    private lateinit var windowManager: WindowManager
    private var overlayView: TextView? = null
    private var layoutParams: WindowManager.LayoutParams? = null
    private lateinit var collector: TelemetryCollector
    private val executor = Executors.newSingleThreadExecutor()
    private val handler = Handler(Looper.getMainLooper())
    private val updating = AtomicBoolean(false)
    private var mode = "auto"
    private var lastRecordedMs = 0L

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        ShizukuClient.init(applicationContext)
        NativeSessionStore.init(applicationContext)
        collector = TelemetryCollector(applicationContext)
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        scheduleUpdate()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        mode = intent?.getStringExtra(EXTRA_MODE) ?: mode

        when (intent?.getStringExtra(EXTRA_RECORDING_ACTION)) {
            RECORDING_START -> if (!NativeSessionStore.isRecording) NativeSessionStore.start()
            RECORDING_STOP -> if (NativeSessionStore.isRecording) NativeSessionStore.stop()
        }
        when (intent?.getStringExtra(EXTRA_OVERLAY_ACTION)) {
            OVERLAY_SHOW -> showOverlay()
            OVERLAY_HIDE -> hideOverlay()
        }

        updateNotification()
        if (!isOverlayVisible && !NativeSessionStore.isRecording) {
            stopSelf()
            return START_NOT_STICKY
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun showOverlay() {
        if (overlayView != null || !Settings.canDrawOverlays(this)) return
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val view = TextView(this).apply {
            text = "FPS —  1% —  0.1% —\nFRAME — ms\nCPU —  APP —\nGPU —  PWR — W"
            setTextColor(Color.WHITE)
            textSize = 13f
            typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
            setPadding(dp(14), dp(10), dp(14), dp(10))
            setBackgroundResource(R.drawable.overlay_background)
            alpha = 0.94f
            setOnTouchListener(DragTouchListener())
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.WRAP_CONTENT,
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
            x = dp(18)
            y = dp(88)
        }
        runCatching { windowManager.addView(view, params) }
            .onSuccess {
                overlayView = view
                layoutParams = params
                isOverlayVisible = true
            }
    }

    private fun hideOverlay() {
        val view = overlayView ?: return
        runCatching { windowManager.removeView(view) }
        overlayView = null
        layoutParams = null
        isOverlayVisible = false
    }

    private fun scheduleUpdate() {
        handler.postDelayed(object : Runnable {
            override fun run() {
                if (updating.compareAndSet(false, true)) {
                    executor.execute {
                        val snapshot = runCatching { collector.collect(mode) }.getOrNull()
                        if (snapshot != null && NativeSessionStore.isRecording) {
                            val now = System.currentTimeMillis()
                            if (now - lastRecordedMs >= 500L) {
                                NativeSessionStore.add(snapshot)
                                lastRecordedMs = now
                            }
                        }
                        handler.post {
                            if (snapshot != null && overlayView != null) {
                                updateOverlayVisibility(snapshot)
                                updateText(snapshot)
                            }
                            updating.set(false)
                        }
                    }
                }
                handler.postDelayed(this, 200L)
            }
        }, 100L)
    }

    private fun updateOverlayVisibility(data: Map<String, Any?>) {
        val foreground = data["foregroundPackage"] as? String
        val shouldHide = foreground == packageName ||
            foreground == "com.android.settings" ||
            foreground?.startsWith("com.android.permissioncontroller") == true
        overlayView?.visibility = if (shouldHide) View.GONE else View.VISIBLE
    }

    private fun updateText(data: Map<String, Any?>) {
        val fps = decimal(data["fps"])
        val low1 = decimal(data["onePercentLowFps"])
        val low01 = decimal(data["pointOnePercentLowFps"])
        val frame = decimal2(data["frameTimeMs"])
        val cpu = number(data["cpuUsage"])
        val appCpu = decimal(data["appCpuUsage"])
        val appRam = number(data["appRamMb"])
        val cpuFreq = number(data["cpuFrequencyMhz"])
        val gpuLoad = number(data["gpuLoad"])
        val gpuFreq = number(data["gpuFrequencyMhz"])
        val power = decimal2(data["batteryPowerW"])
        val temp = decimal(data["batteryTemperatureC"])
        val access = (data["accessModeUsed"] as? String)?.uppercase(Locale.US) ?: "STANDARD"
        val requested = (data["accessModeRequested"] as? String)?.uppercase(Locale.US) ?: "AUTO"
        val accessLabel = if (access == "STANDARD" && requested != "STANDARD") "$access!" else access
        overlayView?.text = buildString {
            append("FPS $fps  1% $low1  0.1% $low01  $accessLabel")
            append("\nFRAME $frame ms")
            append("\nCPU $cpu%  $cpuFreq MHz  APP $appCpu%")
            append("\nGPU $gpuLoad%  $gpuFreq MHz  RAM $appRam MB")
            append("\nPWR $power W  BAT $temp°C")
        }
    }

    private fun number(value: Any?): String =
        (value as? Number)?.toDouble()?.roundToInt()?.toString() ?: "—"

    private fun decimal(value: Any?): String =
        (value as? Number)?.toDouble()?.let { String.format(Locale.US, "%.1f", it) } ?: "—"

    private fun decimal2(value: Any?): String =
        (value as? Number)?.toDouble()?.let { String.format(Locale.US, "%.2f", it) } ?: "—"

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "FPSWatcher monitor", NotificationManager.IMPORTANCE_LOW).apply {
                    description = "Keeps FPSWatcher telemetry and session recording active."
                    setShowBadge(false)
                },
            )
        }
    }

    private fun createNotification(): Notification {
        val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            launchIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(this)
        }
        val state = when {
            NativeSessionStore.isRecording && isOverlayVisible -> "Overlay and session recording are active."
            NativeSessionStore.isRecording -> "Session recording is active."
            isOverlayVisible -> "Live performance overlay is active."
            else -> "Performance monitor is active."
        }
        return builder
            .setSmallIcon(R.drawable.ic_stat_fpswatcher)
            .setContentTitle("FPSWatcher")
            .setContentText(state)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    private fun updateNotification() {
        getSystemService(NotificationManager::class.java).notify(NOTIFICATION_ID, createNotification())
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        executor.shutdownNow()
        hideOverlay()
        isRunning = false
        super.onDestroy()
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).roundToInt()

    private inner class DragTouchListener : View.OnTouchListener {
        private var initialX = 0
        private var initialY = 0
        private var initialTouchX = 0f
        private var initialTouchY = 0f

        override fun onTouch(view: View, event: MotionEvent): Boolean {
            val params = layoutParams ?: return false
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    initialX = params.x
                    initialY = params.y
                    initialTouchX = event.rawX
                    initialTouchY = event.rawY
                    return true
                }

                MotionEvent.ACTION_MOVE -> {
                    params.x = initialX + (event.rawX - initialTouchX).roundToInt()
                    params.y = initialY + (event.rawY - initialTouchY).roundToInt()
                    overlayView?.let { windowManager.updateViewLayout(it, params) }
                    return true
                }

                MotionEvent.ACTION_UP -> {
                    view.performClick()
                    return true
                }
            }
            return false
        }
    }

    companion object {
        const val EXTRA_MODE = "mode"
        const val EXTRA_OVERLAY_ACTION = "overlay_action"
        const val EXTRA_RECORDING_ACTION = "recording_action"
        const val OVERLAY_SHOW = "show"
        const val OVERLAY_HIDE = "hide"
        const val RECORDING_START = "start"
        const val RECORDING_STOP = "stop"
        private const val CHANNEL_ID = "fpswatcher_monitor"
        private const val NOTIFICATION_ID = 7401

        @Volatile
        var isRunning: Boolean = false

        @Volatile
        var isOverlayVisible: Boolean = false
    }
}
