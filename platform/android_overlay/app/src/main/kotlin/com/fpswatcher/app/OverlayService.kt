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
import android.graphics.drawable.GradientDrawable
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
    private var mode = "shizuku"
    private var lastRecordedMs = 0L
    private var styleRevision = -1L
    private var overlayConfig: Map<String, Any> = emptyMap()
    @Volatile private var destroyed = false

    override fun onCreate() {
        super.onCreate()
        isRunning = true
        ShizukuClient.init(applicationContext)
        NativeSessionStore.init(applicationContext)
        collector = TelemetryCollector(applicationContext)
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, createNotification())
        scheduleUpdate(80L)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        mode = intent?.getStringExtra(EXTRA_MODE)?.takeIf { it == "root" || it == "shizuku" } ?: mode

        when (intent?.getStringExtra(EXTRA_RECORDING_ACTION)) {
            RECORDING_START -> if (!NativeSessionStore.isRecording) NativeSessionStore.start()
            RECORDING_STOP -> if (NativeSessionStore.isRecording) NativeSessionStore.stop()
        }
        when (intent?.getStringExtra(EXTRA_OVERLAY_ACTION)) {
            OVERLAY_SHOW -> showOverlay()
            OVERLAY_HIDE -> hideOverlay()
            OVERLAY_RESET_POSITION -> resetOverlayPosition()
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
            text = "FPS —\nFRAME — ms\nCPU —%\nGPU —%\nPWR — W"
            setTextColor(Color.WHITE)
            textSize = 13f
            typeface = Typeface.create(Typeface.MONOSPACE, Typeface.BOLD)
            includeFontPadding = false
            setOnTouchListener(DragTouchListener())
        }
        val savedPosition = OverlayPreferences.position(this)
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
            x = savedPosition?.first ?: dp(18)
            y = savedPosition?.second ?: dp(88)
        }
        runCatching { windowManager.addView(view, params) }
            .onSuccess {
                overlayView = view
                layoutParams = params
                isOverlayVisible = true
                applyOverlayStyle(force = true)
                view.post {
                    clampToScreen(params, view)
                    runCatching { windowManager.updateViewLayout(view, params) }
                }
            }
    }

    private fun hideOverlay() {
        val view = overlayView ?: return
        runCatching { windowManager.removeView(view) }
        overlayView = null
        layoutParams = null
        isOverlayVisible = false
    }

    private fun resetOverlayPosition() {
        OverlayPreferences.resetPosition(this)
        layoutParams?.let { params ->
            params.x = dp(18)
            params.y = dp(88)
            overlayView?.let { runCatching { windowManager.updateViewLayout(it, params) } }
        }
    }

    private fun scheduleUpdate(delayMs: Long) {
        if (destroyed) return
        handler.postDelayed({
            if (destroyed) return@postDelayed
            applyOverlayStyle()
            if (updating.compareAndSet(false, true)) {
                executor.execute {
                    val snapshot = runCatching {
                        TelemetrySnapshotCache.get(mode, 90L)
                            ?: collector.collect(mode).also { TelemetrySnapshotCache.put(mode, it) }
                    }.getOrNull()
                    if (snapshot != null && NativeSessionStore.isRecording) {
                        val now = System.currentTimeMillis()
                        if (now - lastRecordedMs >= 500L) {
                            NativeSessionStore.add(snapshot)
                            lastRecordedMs = now
                        }
                    }
                    handler.post {
                        if (destroyed) return@post
                        if (snapshot != null && overlayView != null) {
                            updateOverlayVisibility(snapshot)
                            updateText(snapshot)
                        }
                        updating.set(false)
                        scheduleUpdate(refreshInterval().toLong())
                    }
                }
            } else {
                scheduleUpdate(refreshInterval().toLong())
            }
        }, delayMs)
    }

    private fun refreshInterval(): Int {
        val requested = (overlayConfig["refreshIntervalMs"] as? Number)?.toInt() ?: 100
        return listOf(100, 200, 500).minBy { kotlin.math.abs(it - requested) }
    }

    private fun applyOverlayStyle(force: Boolean = false) {
        val revision = OverlayPreferences.revision(this)
        if (!force && revision == styleRevision) return
        styleRevision = revision
        overlayConfig = OverlayPreferences.snapshot(this)
        val view = overlayView ?: return
        val padding = dp((overlayConfig["paddingDp"] as? Number)?.toInt() ?: 10)
        view.setPadding(padding, padding, padding, padding)
        view.textSize = (overlayConfig["textSizeSp"] as? Number)?.toFloat() ?: 13f
        val backgroundOpacity =
            (overlayConfig["opacity"] as? Number)?.toFloat()?.coerceIn(0.15f, 1f) ?: 0.92f
        view.alpha = 1f
        view.setTextColor((overlayConfig["textColorValue"] as? Number)?.toInt() ?: Color.WHITE)
        view.background = GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            cornerRadius = 0f
            setColor(Color.argb((255f * backgroundOpacity).roundToInt(), 7, 16, 24))
            setStroke(dp(1), Color.argb(135, 57, 231, 208))
        }
    }

    private fun enabled(key: String, fallback: Boolean = true): Boolean =
        overlayConfig[key] as? Boolean ?: fallback

    private fun updateOverlayVisibility(data: Map<String, Any?>) {
        val foreground = data["foregroundPackage"] as? String
        val showOnlyWithForeground = enabled("showOnlyWhenGameDetected", true)
        val foregroundIsGame = data["foregroundIsGame"] as? Boolean
        val shouldHide = data["backendOperational"] == false ||
            (showOnlyWithForeground && (foreground.isNullOrBlank() || foregroundIsGame == false)) ||
            foreground == packageName ||
            foreground == "com.android.settings" ||
            foreground == "com.android.systemui" ||
            foreground?.startsWith("com.android.permissioncontroller") == true
        overlayView?.visibility = if (shouldHide) View.GONE else View.VISIBLE
    }

    private fun updateText(data: Map<String, Any?>) {
        val lines = mutableListOf<String>()

        if (enabled("showFps") || enabled("showLows") || enabled("showFivePercentLow")) {
            val parts = mutableListOf<String>()
            if (enabled("showFps")) parts += "FPS ${decimal(data["fps"])}"
            if (enabled("showFivePercentLow")) parts += "5% ${decimal(data["fivePercentLowFps"])}"
            if (enabled("showLows")) {
                parts += "1% ${decimal(data["onePercentLowFps"])}"
                parts += "0.1% ${decimal(data["pointOnePercentLowFps"])}"
            }
            if (parts.isNotEmpty()) lines += parts.joinToString("  ")
        }
        if (enabled("showFrameTime")) {
            lines += "FRAME ${decimal2(data["frameTimeMs"])} ms  P95 ${decimal2(data["frameTimeP95Ms"])}  P99 ${decimal2(data["frameTimeP99Ms"])}"
        }
        if (enabled("showStability") || enabled("showDroppedFrames")) {
            val parts = mutableListOf<String>()
            if (enabled("showStability")) {
                parts += "STAB ${decimal(data["frameStabilityScore"])}%"
                parts += "PACE ${decimal(data["framePacingScore"])}%"
            }
            if (enabled("showDroppedFrames")) parts += "DROP ${number(data["estimatedDroppedFrames"])}"
            parts += "S25 ${number(data["stutter25msCount"])}"
            val frozen = (data["frozenFrameCount"] as? Number)?.toLong() ?: 0L
            if (frozen > 0) parts += "FROZEN $frozen"
            if (parts.isNotEmpty()) lines += parts.joinToString("  ")
        }
        if (enabled("showSystemCpu") || enabled("showAppCpu") || enabled("showCpuFrequency") || enabled("showCpuThrottle")) {
            val parts = mutableListOf<String>()
            if (enabled("showSystemCpu")) parts += "CPU ${decimal(data["cpuUsage"])}%"
            if (enabled("showCpuFrequency")) parts += "${number(data["cpuFrequencyMhz"])} MHz"
            if (enabled("showAppCpu")) parts += "APP ${decimal(data["appCpuUsage"])}%"
            if (enabled("showCpuThrottle")) parts += if (data["cpuThrottled"] == true) "CPU THR" else "CPU OK"
            if (parts.isNotEmpty()) lines += parts.joinToString("  ")
        }
        if (enabled("showCpuCores")) {
            val usages = (data["cpuCoreUsagePercent"] as? List<*>)?.mapNotNull { (it as? Number)?.toDouble() }.orEmpty()
            val freqs = (data["cpuCoreFrequenciesMhz"] as? List<*>)?.mapNotNull { (it as? Number)?.toDouble() }.orEmpty()
            val count = maxOf(usages.size, freqs.size).coerceAtMost(12)
            if (count > 0) {
                lines += (0 until count).joinToString("  ") { index ->
                    val usage = usages.getOrNull(index)?.let { String.format(Locale.US, "%.0f", it) } ?: "—"
                    val freq = freqs.getOrNull(index)?.roundToInt()?.toString() ?: "—"
                    "C$index $usage%/$freq"
                }
            }
        }
        if (enabled("showGpuLoad") || enabled("showGpuFrequency") || enabled("showGpuThrottle")) {
            val parts = mutableListOf<String>()
            if (enabled("showGpuLoad")) parts += "GPU ${decimal(data["gpuLoad"])}%"
            if (enabled("showGpuFrequency")) parts += "${number(data["gpuFrequencyMhz"])} MHz"
            if (enabled("showGpuThrottle")) parts += if (data["gpuThrottled"] == true) "GPU THR" else "GPU OK"
            if (parts.isNotEmpty()) lines += parts.joinToString("  ")
        }
        if (enabled("showGameRam")) {
            lines += "RAM ${number(data["appRamMb"])} MB  RSS ${number(data["appRssMb"])} MB"
        }
        if (enabled("showMemory")) {
            lines += "SWAP ${number(data["swapUsedMb"])} MB  ZRAM ${number(data["zramUsedMb"])} MB  PSI ${decimal2(data["memoryPressureAvg10"])}"
        }
        if (enabled("showProcessDetails")) {
            lines += "PID ${number(data["appPid"])}  THR ${number(data["appThreadCount"])}  NICE ${number(data["appNice"])}  UCLAMP ${decimal(data["appUclampMin"])}-${decimal(data["appUclampMax"])}"
            val scheduling = listOfNotNull(
                (data["appSchedulerPolicy"] as? String)?.takeIf { it.isNotBlank() },
                (data["appCpuAffinity"] as? String)?.takeIf { it.isNotBlank() }?.let { "AFF $it" },
                (data["graphicsApi"] as? String)?.takeIf { it.isNotBlank() },
            )
            if (scheduling.isNotEmpty()) lines += scheduling.joinToString("  ")
        }
        if (enabled("showPower") || enabled("showBatteryTemperature") || enabled("showSocTemperature") || enabled("showEfficiency") || enabled("showBatteryDrain")) {
            val parts = mutableListOf<String>()
            if (enabled("showPower")) {
                parts += if (data["batteryCharging"] == true) "PWR CHG" else "PWR ${decimal2(data["batteryPowerW"])} W"
            }
            if (enabled("showEfficiency")) parts += "EFF ${decimal2(data["fpsPerWatt"])} FPS/W"
            if (enabled("showBatteryDrain")) parts += "DRAIN ${decimal2(data["batteryDrainPercentPerHour"])} %/h"
            if (enabled("showBatteryTemperature")) parts += "BAT ${decimal(data["batteryTemperatureC"])}°C"
            if (enabled("showSocTemperature")) {
                parts += "SOC ${decimal(data["socTemperatureC"])}°C"
                if (data["cpuTemperatureC"] != null || data["gpuTemperatureC"] != null) {
                    parts += "CPU/GPU ${decimal(data["cpuTemperatureC"])}°/${decimal(data["gpuTemperatureC"])}°"
                }
            }
            if (parts.isNotEmpty()) lines += parts.joinToString("  ")
        }
        if (enabled("showThermalStatus")) {
            lines += "THERM ${thermalLabel(data["thermalStatus"])}  SCORE ${decimal(data["thermalStabilityScore"])}%${if (data["thermalThrottling"] == true) "  THROTTLING" else ""}"
        }
        if (enabled("showNetwork")) {
            lines += "NET ${data["networkType"] ?: "—"}  PING ${decimal(data["networkPingMs"])} ms  JIT ${decimal(data["networkJitterMs"])}  LOSS ${decimal(data["networkPacketLossPercent"])}%"
        }
        if (enabled("showWifi")) {
            lines += "WIFI ${number(data["wifiRssiDbm"])} dBm  ${number(data["wifiLinkSpeedMbps"])} Mbps  ${number(data["wifiFrequencyMhz"])} MHz"
        }
        if (enabled("showMonitorOverhead")) {
            lines += "WATCHER ${decimal(data["monitorCpuUsage"])}% CPU  ${decimal(data["monitorRamMb"])} MB  ${decimal2(data["collectorLatencyMs"])} ms"
        }

        val separator = if ((overlayConfig["layoutMode"] as? String) == "horizontal") "   |   " else "\n"
        overlayView?.text = lines.takeIf { it.isNotEmpty() }?.joinToString(separator) ?: "FPSWatcher"
        if (enabled("adaptiveColors")) updateAdaptiveColor(data)
    }

    private fun updateAdaptiveColor(data: Map<String, Any?>) {
        val view = overlayView ?: return
        val configured = (overlayConfig["textColorValue"] as? Number)?.toInt() ?: Color.WHITE
        val severe = data["thermalThrottling"] == true ||
            ((data["batteryTemperatureC"] as? Number)?.toDouble() ?: 0.0) >= 45.0 ||
            ((data["socTemperatureC"] as? Number)?.toDouble() ?: 0.0) >= 55.0
        val warning = ((data["frameStabilityScore"] as? Number)?.toDouble() ?: 100.0) < 70.0 ||
            ((data["networkPacketLossPercent"] as? Number)?.toDouble() ?: 0.0) >= 3.0
        view.setTextColor(
            when {
                severe -> Color.rgb(255, 107, 122)
                warning -> Color.rgb(255, 214, 90)
                else -> configured
            },
        )
    }

    private fun thermalLabel(value: Any?): String = when ((value as? Number)?.toInt()) {
        0 -> "NONE"
        1 -> "LIGHT"
        2 -> "MODERATE"
        3 -> "SEVERE"
        4 -> "CRITICAL"
        5 -> "EMERGENCY"
        6 -> "SHUTDOWN"
        else -> "—"
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
        destroyed = true
        handler.removeCallbacksAndMessages(null)
        runCatching { collector.close() }
        executor.shutdownNow()
        hideOverlay()
        isRunning = false
        super.onDestroy()
    }

    private fun clampToScreen(params: WindowManager.LayoutParams, view: View) {
        val metrics = resources.displayMetrics
        val maxX = (metrics.widthPixels - view.measuredWidth).coerceAtLeast(0)
        val maxY = (metrics.heightPixels - view.measuredHeight).coerceAtLeast(0)
        params.x = params.x.coerceIn(0, maxX)
        params.y = params.y.coerceIn(0, maxY)
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
                    clampToScreen(params, view)
                    overlayView?.let { runCatching { windowManager.updateViewLayout(it, params) } }
                    return true
                }

                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    clampToScreen(params, view)
                    OverlayPreferences.savePosition(this@OverlayService, params.x, params.y)
                    if (event.actionMasked == MotionEvent.ACTION_UP) view.performClick()
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
        const val OVERLAY_RESET_POSITION = "reset_position"
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
