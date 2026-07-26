package com.fpswatcher.app

import android.app.ActivityManager
import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.hardware.display.DisplayManager
import android.net.TrafficStats
import android.os.BatteryManager
import android.os.Build
import android.os.Environment
import android.os.PowerManager
import android.os.StatFs
import android.os.SystemClock
import android.provider.Settings
import android.view.Display
import com.fpswatcher.app.shizuku.ShizukuClient
import java.io.File
import java.util.ArrayDeque
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.abs
import kotlin.math.ceil

class TelemetryCollector(context: Context) {
    private val context = context.applicationContext
    private var previousCpuIdle = 0L
    private var previousCpuTotal = 0L
    private var previousRx = TrafficStats.getTotalRxBytes()
    private var previousTx = TrafficStats.getTotalTxBytes()
    private var previousNetworkMs = System.currentTimeMillis()
    private var previousPrivilegedCpuIdle = 0L
    private var previousPrivilegedCpuTotal = 0L
    private var lastPrivilegedCpuDelta = 0L
    private var previousAppPid = -1
    private var previousAppTicks = 0L
    private var previousSampleElapsedMs = SystemClock.elapsedRealtime()
    private val surfaceFlingerEnabled = AtomicBoolean(false)

    private var cachedForegroundPackage: String? = null
    private var lastForegroundPollMs = 0L
    private var cachedLocalGpuRaw = ""
    private var lastLocalGpuPollMs = 0L
    private val cachedPrivileged = hashMapOf<String, Any?>()
    private var lastPrivilegedPollMs = 0L
    private var lastPrivilegedBackend = ""
    private var lastPrivilegedPackage = ""
    private var lastFramePollMs = 0L
    private var lastSlowPrivilegedPollMs = 0L

    private var cachedCpuFrequencyInfo: Map<String, Any?> = emptyMap()
    private var lastCpuFrequencyPollMs = 0L
    private var cachedRamInfo: Map<String, Any?> = emptyMap()
    private var lastRamPollMs = 0L
    private var cachedBatteryInfo: Map<String, Any?> = emptyMap()
    private var lastBatteryPollMs = 0L
    private var cachedNetworkInfo: Map<String, Any?> = emptyMap()
    private var lastNetworkPollMs = 0L
    private var cachedStorageInfo: Map<String, Any?> = emptyMap()
    private var lastStoragePollMs = 0L
    private var cachedRefreshRate: Double? = null
    private var lastRefreshRatePollMs = 0L
    private var cachedThermalStatus: Int? = null
    private var lastThermalPollMs = 0L

    private data class FrameBucket(
        val timestampMs: Long,
        val histogram: List<Pair<Double, Long>>,
    )

    private val frameBuckets = ArrayDeque<FrameBucket>()

    private val cachedGpuModel: String? by lazy<String?> {
        runCatching { GpuProbe.renderer() }.getOrNull()?.trim()?.takeIf { it.isNotBlank() }
    }

    private val discoveredGpuFiles: List<File> by lazy<List<File>> {
        val acceptedNames = (FREQUENCY_NAMES + MAX_FREQUENCY_NAMES + LOAD_NAMES)
            .map { it.substringAfterLast('/') }
            .toSet()
        val roots = listOf(
            File("/sys/class/kgsl"),
            File("/sys/class/devfreq"),
            File("/sys/class/misc/mali0"),
            File("/sys/kernel/ged/hal"),
        )
        roots.asSequence()
            .filter(File::exists)
            .flatMap { root ->
                runCatching {
                    root.walkTopDown()
                        .maxDepth(6)
                        .filter { file ->
                            file.isFile && acceptedNames.contains(file.name) && pathLooksGpu(file.absolutePath)
                        }
                        .toList()
                        .asSequence()
                }.getOrDefault(emptySequence())
            }
            .distinctBy(File::getAbsolutePath)
            .toList()
    }

    fun collect(mode: String): HashMap<String, Any?> {
        val result = hashMapOf<String, Any?>()
        val warnings = mutableListOf<String>()
        val elapsedNow = SystemClock.elapsedRealtime()
        val interval = (elapsedNow - previousSampleElapsedMs).coerceAtLeast(0L)
        previousSampleElapsedMs = elapsedNow

        fun metric(name: String, block: () -> Any?) {
            runCatching(block)
                .onSuccess { value -> if (value != null) result[name] = value }
                .onFailure { error -> warnings += "$name: ${error.javaClass.simpleName}" }
        }

        fun metrics(label: String, block: () -> Map<String, Any?>) {
            runCatching(block)
                .onSuccess { result.putAll(it.filterValues { value -> value != null }) }
                .onFailure { error -> warnings += "$label: ${error.javaClass.simpleName}" }
        }

        val requestedMode = mode.lowercase().takeIf { it == "shizuku" || it == "root" } ?: "shizuku"
        result["accessModeRequested"] = requestedMode
        val backend = runCatching { privilegedExecutor(requestedMode) }
            .onFailure { warnings += "backend: ${it.javaClass.simpleName}" }
            .getOrNull()
        result["accessModeUsed"] = backend?.name ?: requestedMode
        result["backendOperational"] = backend != null
        if (backend == null) {
            result["backendError"] = when (requestedMode) {
                "root" -> RootShell.lastError ?: "Root command unavailable or denied"
                else -> ShizukuClient.lastError ?: "Shizuku UserService unavailable"
            }
        }

        val shouldRefreshForeground =
            elapsedNow - lastForegroundPollMs >= FOREGROUND_POLL_MS || cachedForegroundPackage == null
        if (shouldRefreshForeground) {
            var detected = runCatching { foregroundPackageFromUsage() }
                .onFailure { warnings += "foregroundUsage: ${it.javaClass.simpleName}" }
                .getOrNull()
            if (detected.isNullOrBlank() && backend != null) {
                detected = backend.execute(FOREGROUND_PACKAGE_COMMAND)
                    ?.lineSequence()
                    ?.map(String::trim)
                    ?.firstOrNull { PACKAGE_NAME.matches(it) }
            }
            if (!detected.isNullOrBlank()) cachedForegroundPackage = detected
            lastForegroundPollMs = elapsedNow
        }
        val foregroundPackage = cachedForegroundPackage
        if (!foregroundPackage.isNullOrBlank()) result["foregroundPackage"] = foregroundPackage

        metric("cpuUsage") { cpuUsage() }

        if (elapsedNow - lastCpuFrequencyPollMs >= CPU_FREQUENCY_POLL_MS || cachedCpuFrequencyInfo.isEmpty()) {
            cachedCpuFrequencyInfo = runCatching { cpuFrequencyInfo() }
                .onFailure { warnings += "cpuFrequency: ${it.javaClass.simpleName}" }
                .getOrDefault(cachedCpuFrequencyInfo)
            lastCpuFrequencyPollMs = elapsedNow
        }
        result.putAll(cachedCpuFrequencyInfo)

        cachedGpuModel?.let { result["gpuModel"] = it }

        if (elapsedNow - lastRamPollMs >= RAM_POLL_MS || cachedRamInfo.isEmpty()) {
            cachedRamInfo = runCatching { ramInfo() }
                .onFailure { warnings += "ram: ${it.javaClass.simpleName}" }
                .getOrDefault(cachedRamInfo)
            lastRamPollMs = elapsedNow
        }
        result.putAll(cachedRamInfo)

        if (elapsedNow - lastRefreshRatePollMs >= REFRESH_RATE_POLL_MS || cachedRefreshRate == null) {
            cachedRefreshRate = runCatching { refreshRate() }
                .onFailure { warnings += "refreshRateHz: ${it.javaClass.simpleName}" }
                .getOrNull() ?: cachedRefreshRate
            lastRefreshRatePollMs = elapsedNow
        }
        cachedRefreshRate?.let { result["refreshRateHz"] = it }

        if (elapsedNow - lastThermalPollMs >= THERMAL_POLL_MS || cachedThermalStatus == null) {
            cachedThermalStatus = runCatching { thermalStatus() }
                .onFailure { warnings += "thermalStatus: ${it.javaClass.simpleName}" }
                .getOrNull() ?: cachedThermalStatus
            lastThermalPollMs = elapsedNow
        }
        cachedThermalStatus?.let { result["thermalStatus"] = it }

        if (elapsedNow - lastBatteryPollMs >= BATTERY_POLL_MS || cachedBatteryInfo.isEmpty()) {
            cachedBatteryInfo = runCatching { batteryInfo() }
                .onFailure { warnings += "battery: ${it.javaClass.simpleName}" }
                .getOrDefault(cachedBatteryInfo)
            lastBatteryPollMs = elapsedNow
        }
        result.putAll(cachedBatteryInfo)

        if (elapsedNow - lastNetworkPollMs >= NETWORK_POLL_MS || cachedNetworkInfo.isEmpty()) {
            cachedNetworkInfo = runCatching { networkInfo() }
                .onFailure { warnings += "network: ${it.javaClass.simpleName}" }
                .getOrDefault(cachedNetworkInfo)
            lastNetworkPollMs = elapsedNow
        }
        result.putAll(cachedNetworkInfo)

        if (elapsedNow - lastStoragePollMs >= STORAGE_POLL_MS || cachedStorageInfo.isEmpty()) {
            cachedStorageInfo = runCatching { storageInfo() }
                .onFailure { warnings += "storage: ${it.javaClass.simpleName}" }
                .getOrDefault(cachedStorageInfo)
            lastStoragePollMs = elapsedNow
        }
        result.putAll(cachedStorageInfo)

        if (elapsedNow - lastLocalGpuPollMs >= LOCAL_GPU_POLL_MS || cachedLocalGpuRaw.isBlank()) {
            cachedLocalGpuRaw = runCatching { localGpuProbe() }
                .onFailure { warnings += "localGpu: ${it.javaClass.simpleName}" }
                .getOrDefault("")
            lastLocalGpuPollMs = elapsedNow
        }
        if (cachedLocalGpuRaw.isNotBlank()) {
            result["gpuRaw"] = cachedLocalGpuRaw
            runCatching { applyGpuMetrics(cachedLocalGpuRaw, result) }
                .onFailure { warnings += "gpuParse: ${it.javaClass.simpleName}" }
            if (result["gpuLoad"] != null || result["gpuFrequencyMhz"] != null) {
                result["gpuSource"] = "public-sysfs"
            } else if (result["gpuModel"] != null) {
                result["gpuSource"] = "egl"
            }
        }

        if (backend != null) {
            val packageName = foregroundPackage.orEmpty().replace(Regex("[^A-Za-z0-9._-]"), "")
            val backendChanged = backend.name != lastPrivilegedBackend
            val packageChanged = packageName != lastPrivilegedPackage
            val needsPrivilegedPoll = backendChanged || packageChanged ||
                elapsedNow - lastPrivilegedPollMs >= PRIVILEGED_POLL_MS || cachedPrivileged.isEmpty()

            if (needsPrivilegedPoll) {
                val fresh = if (backendChanged || packageChanged) {
                    hashMapOf<String, Any?>()
                } else {
                    hashMapOf<String, Any?>().apply { putAll(cachedPrivileged) }
                }

                if (packageChanged) frameBuckets.clear()
                val includeSlowMetrics = packageChanged ||
                    elapsedNow - lastSlowPrivilegedPollMs >= SLOW_PRIVILEGED_POLL_MS
                val combinedRaw = backend.execute(
                    privilegedSystemCommand(packageName, includeSlowMetrics) +
                        "\necho __FPSWATCHER_GPU_BEGIN__\n" +
                        privilegedGpuCommand(includeSlowMetrics),
                ).orEmpty()
                if (includeSlowMetrics) lastSlowPrivilegedPollMs = elapsedNow
                if (combinedRaw.isNotBlank()) {
                    runCatching { applyPrivilegedSystemMetrics(combinedRaw, fresh) }
                        .onFailure { warnings += "privilegedSystem: ${it.javaClass.simpleName}" }
                    val combinedGpu = listOf(cachedLocalGpuRaw, combinedRaw)
                        .filter { it.isNotBlank() }
                        .joinToString("\n")
                    fresh["gpuRaw"] = combinedGpu
                    runCatching { applyGpuMetrics(combinedGpu, fresh) }
                        .onFailure { warnings += "privilegedGpu: ${it.javaClass.simpleName}" }
                    if (fresh["gpuLoad"] != null || fresh["gpuFrequencyMhz"] != null) {
                        fresh["gpuSource"] = backend.name
                    }
                } else {
                    warnings += "backendExecute: empty"
                }

                val frameDue = packageChanged || elapsedNow - lastFramePollMs >= FRAME_POLL_MS
                if (!surfaceFlingerEnabled.get()) {
                    val enabled = backend.execute(
                        "dumpsys SurfaceFlinger --timestats -clear -enable >/dev/null 2>&1; echo FPSWATCHER_OK",
                    )?.contains("FPSWATCHER_OK") == true
                    if (enabled) surfaceFlingerEnabled.set(true)
                }
                if (frameDue && packageName.isNotBlank()) {
                    FRAME_KEYS.forEach { key -> fresh.remove(key) }
                    val frameRaw = backend.execute(frameStatsCommand(packageName)).orEmpty()
                    if (frameRaw.isNotBlank()) {
                        fresh["surfaceFlingerRaw"] = frameRaw
                        runCatching { applyFrameMetrics(frameRaw, fresh) }
                            .onFailure { warnings += "frameStats: ${it.javaClass.simpleName}" }
                    }
                    lastFramePollMs = elapsedNow
                }

                cachedPrivileged.clear()
                cachedPrivileged.putAll(fresh)
                lastPrivilegedPollMs = elapsedNow
                lastPrivilegedBackend = backend.name
                lastPrivilegedPackage = packageName
            }
            result.putAll(cachedPrivileged)
        } else {
            cachedPrivileged.clear()
            frameBuckets.clear()
            lastPrivilegedBackend = ""
            lastPrivilegedPackage = ""
        }

        result["sampleIntervalMs"] = interval
        result["timestampMs"] = System.currentTimeMillis()
        if (warnings.isNotEmpty()) result["collectorWarnings"] = warnings.distinct().take(12)
        return result
    }

    fun status(): HashMap<String, Any?> {
        val shizukuAvailable = runCatching { ShizukuClient.isAvailable() }.getOrDefault(false)
        val shizukuPermission = runCatching { ShizukuClient.hasPermission() }.getOrDefault(false)
        val shizukuOperational = if (shizukuPermission) {
            runCatching { ShizukuClient.isOperational() }.getOrDefault(false)
        } else false
        val rootOperational = RootShell.isAvailable()
        val rootInstalled = rootOperational || RootShell.isInstalled()
        return hashMapOf(
            "usageAccess" to runCatching { hasUsageAccess() }.getOrDefault(false),
            "overlayPermission" to Settings.canDrawOverlays(context),
            "notificationPermission" to notificationPermission(),
            "shizukuAvailable" to shizukuAvailable,
            "shizukuPermission" to shizukuPermission,
            "shizukuOperational" to shizukuOperational,
            "shizukuUid" to runCatching { ShizukuClient.uid() }.getOrDefault(-1),
            "rootInstalled" to rootInstalled,
            "rootAvailable" to rootOperational,
            "rootError" to RootShell.lastError,
            "shizukuError" to ShizukuClient.lastError,
            "overlayRunning" to OverlayService.isOverlayVisible,
            "monitorServiceRunning" to OverlayService.isRunning,
            "recording" to NativeSessionStore.isRecording,
            "recordedSampleCount" to NativeSessionStore.count(),
        )
    }

    private data class Backend(val name: String, val execute: (String) -> String?)

    private fun privilegedExecutor(mode: String): Backend? {
        fun shizuku(): Backend? {
            if (!ShizukuClient.hasPermission() || !ShizukuClient.isOperational()) return null
            return Backend("shizuku") { command -> ShizukuClient.execute(command) }
        }

        fun root(): Backend? {
            if (!RootShell.isAvailable()) return null
            return Backend("root") { command -> RootShell.execute(command) }
        }

        return when (mode.lowercase()) {
            "root" -> root()
            else -> shizuku()
        }
    }

    private fun cpuUsage(): Double? {
        val line = File("/proc/stat").bufferedReader().use { it.readLine() } ?: return null
        val values = line.trim().split(Regex("\\s+")).drop(1).mapNotNull { it.toLongOrNull() }
        if (values.size < 4) return null
        val idle = values[3] + values.getOrElse(4) { 0L }
        val total = values.sum()
        if (previousCpuTotal == 0L) {
            previousCpuTotal = total
            previousCpuIdle = idle
            return null
        }
        val totalDelta = total - previousCpuTotal
        val idleDelta = idle - previousCpuIdle
        previousCpuTotal = total
        previousCpuIdle = idle
        if (totalDelta <= 0L) return null
        return ((totalDelta - idleDelta).toDouble() / totalDelta.toDouble() * 100.0)
            .coerceIn(0.0, 100.0)
    }

    private fun cpuFrequencyInfo(): Map<String, Any?> {
        val directories = buildList {
            File("/sys/devices/system/cpu/cpufreq").listFiles()
                ?.filter { it.name.startsWith("policy") }
                ?.let(::addAll)
            File("/sys/devices/system/cpu").listFiles()
                ?.filter { it.name.matches(Regex("cpu[0-9]+")) }
                ?.map { File(it, "cpufreq") }
                ?.filter(File::isDirectory)
                ?.let(::addAll)
        }.distinctBy(File::getAbsolutePath)
        val values = directories.mapNotNull { directory ->
            sequenceOf("scaling_cur_freq", "cpuinfo_cur_freq", "scaling_max_freq")
                .map { File(directory, it) }
                .firstOrNull { it.canRead() }
                ?.readText()?.trim()?.toDoubleOrNull()?.div(1000.0)
                ?.takeIf { it > 0.0 }
        }
        val governors = directories.mapNotNull { directory ->
            File(directory, "scaling_governor").takeIf { it.canRead() }
                ?.readText()?.trim()?.takeIf(String::isNotBlank)
        }.distinct()
        if (values.isEmpty()) return emptyMap()
        return mapOf(
            "cpuFrequencyMhz" to values.average(),
            "cpuFrequencyMinMhz" to values.minOrNull(),
            "cpuFrequencyMaxMhz" to values.maxOrNull(),
            "cpuCoreFrequenciesMhz" to values,
            "cpuGovernor" to governors.joinToString(" / ").takeIf(String::isNotBlank),
        )
    }

    private fun ramInfo(): Map<String, Any?> {
        val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val info = ActivityManager.MemoryInfo()
        manager.getMemoryInfo(info)
        return mapOf(
            "ramUsedMb" to (info.totalMem - info.availMem) / 1024.0 / 1024.0,
            "ramTotalMb" to info.totalMem / 1024.0 / 1024.0,
        )
    }

    private fun batteryInfo(): Map<String, Any?> {
        val intent = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val manager = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val level = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)?.takeIf { it >= 0 }?.toDouble()
        val scale = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, 100)?.takeIf { it > 0 } ?: 100
        val status = intent?.getIntExtra(BatteryManager.EXTRA_STATUS, BatteryManager.BATTERY_STATUS_UNKNOWN)
        val charging = status == BatteryManager.BATTERY_STATUS_CHARGING ||
            status == BatteryManager.BATTERY_STATUS_FULL
        val voltageMv = intent?.getIntExtra(BatteryManager.EXTRA_VOLTAGE, 0)?.takeIf { it > 0 }
        val currentUa = manager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)
            .takeIf { it != Int.MIN_VALUE && kotlin.math.abs(it) >= 1_000 }
        val signedPower: Double? = if (voltageMv != null && currentUa != null) {
            currentUa.toDouble() / 1_000_000.0 * voltageMv.toDouble() / 1000.0
        } else null
        return mapOf(
            "batteryLevel" to level?.let { it / scale * 100.0 },
            "batteryTemperatureC" to intent
                ?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Int.MIN_VALUE)
                ?.takeIf { it != Int.MIN_VALUE }
                ?.div(10.0),
            "batteryPowerW" to if (charging) null else signedPower?.let { abs(it) }
                ?.takeIf { it in 0.05..100.0 },
            "batteryPowerSource" to if (charging) null else signedPower?.let { abs(it) }
                ?.takeIf { it in 0.05..100.0 }?.let { "android-api" },
            "batteryCharging" to charging,
            "batteryCurrentMa" to currentUa?.div(1000.0),
            "batteryVoltageV" to voltageMv?.div(1000.0),
        )
    }

    private fun thermalStatus(): Int? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        return (context.getSystemService(Context.POWER_SERVICE) as PowerManager).currentThermalStatus
    }

    @Suppress("DEPRECATION")
    private fun refreshRate(): Double? {
        val manager = context.getSystemService(Context.DISPLAY_SERVICE) as DisplayManager
        val display = manager.getDisplay(Display.DEFAULT_DISPLAY) ?: manager.displays.firstOrNull() ?: return null
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            display.mode.refreshRate.toDouble()
        } else {
            display.refreshRate.toDouble()
        }
    }

    private fun networkInfo(): Map<String, Any?> {
        val now = System.currentTimeMillis()
        val rx = TrafficStats.getTotalRxBytes()
        val tx = TrafficStats.getTotalTxBytes()
        val elapsedSeconds = ((now - previousNetworkMs).coerceAtLeast(1L)) / 1000.0
        val rxKbps = if (rx >= 0 && previousRx >= 0) {
            (rx - previousRx).coerceAtLeast(0L) / 1024.0 / elapsedSeconds
        } else null
        val txKbps = if (tx >= 0 && previousTx >= 0) {
            (tx - previousTx).coerceAtLeast(0L) / 1024.0 / elapsedSeconds
        } else null
        previousRx = rx
        previousTx = tx
        previousNetworkMs = now
        return mapOf("rxKbps" to rxKbps, "txKbps" to txKbps)
    }

    private fun storageInfo(): Map<String, Any?> {
        val stats = StatFs(Environment.getDataDirectory().absolutePath)
        val total = stats.totalBytes / 1024.0 / 1024.0 / 1024.0
        val free = stats.availableBytes / 1024.0 / 1024.0 / 1024.0
        return mapOf("storageUsedGb" to total - free, "storageTotalGb" to total)
    }

    private fun foregroundPackageFromUsage(): String? {
        if (!hasUsageAccess()) return null
        val manager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        val events = manager.queryEvents(end - 15_000L, end)
        val event = UsageEvents.Event()
        var current: String? = null
        var newest = 0L
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val resumed = event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
                (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
                    event.eventType == UsageEvents.Event.ACTIVITY_RESUMED)
            if (resumed && event.timeStamp >= newest) {
                newest = event.timeStamp
                current = event.packageName
            }
        }
        if (!current.isNullOrBlank()) return current
        return manager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, end - 60_000L, end)
            .filter { it.packageName != context.packageName }
            .maxByOrNull { it.lastTimeUsed }
            ?.packageName
    }

    private fun hasUsageAccess(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                context.packageName,
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                android.os.Process.myUid(),
                context.packageName,
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun notificationPermission(): Boolean =
        Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) ==
            android.content.pm.PackageManager.PERMISSION_GRANTED

    private fun localGpuProbe(): String {
        val lines = mutableListOf<String>()
        cachedGpuModel?.let { lines += "model=$it" }
        readFirstGpuValue(FREQUENCY_NAMES)?.let { lines += "freq=$it" }
        readFirstGpuValue(MAX_FREQUENCY_NAMES)?.let { lines += "max_freq=$it" }
        readFirstGpuValue(LOAD_NAMES)?.let { lines += "load=$it" }
        return lines.joinToString("\n")
    }

    private fun readFirstGpuValue(names: List<String>): String? =
        candidateGpuFiles(names).firstNotNullOfOrNull { file ->
            runCatching { file.takeIf { it.canRead() }?.readText()?.trim() }
                .getOrNull()
                ?.takeIf(String::isNotBlank)
        }

    private fun candidateGpuFiles(names: List<String>): List<File> {
        val acceptedNames = names.map { it.substringAfterLast('/') }.toSet()
        val direct = listOf(
            File("/sys/class/kgsl/kgsl-3d0"),
            File("/sys/class/kgsl/kgsl-3d0/devfreq"),
            File("/sys/class/misc/mali0/device"),
            File("/sys/kernel/ged/hal"),
        ).flatMap { root -> names.map { File(root, it) } }
        return (direct + discoveredGpuFiles.filter { acceptedNames.contains(it.name) })
            .distinctBy(File::getAbsolutePath)
    }

    private fun pathLooksGpu(path: String): Boolean {
        val lower = path.lowercase()
        return lower.contains("gpu") || lower.contains("mali") || lower.contains("kgsl") || lower.contains("pvr")
    }

    private fun applyPrivilegedSystemMetrics(raw: String, result: HashMap<String, Any?>) {
        val entries = raw.lineSequence().mapNotNull { line ->
            val separator = line.indexOf('=')
            if (separator <= 0) null else line.substring(0, separator).trim() to line.substring(separator + 1).trim()
        }.toMap()

        entries["cpuStat"]?.let { privilegedCpuUsage(it)?.let { value -> result["cpuUsage"] = value } }
        entries["cpuFreqListKHz"]?.split(',')
            ?.mapNotNull { it.trim().toDoubleOrNull()?.div(1000.0) }
            ?.filter { it > 0.0 }
            ?.takeIf { it.isNotEmpty() }
            ?.let { frequencies ->
                result["cpuFrequencyMhz"] = frequencies.average()
                result["cpuFrequencyMinMhz"] = frequencies.minOrNull()
                result["cpuFrequencyMaxMhz"] = frequencies.maxOrNull()
                result["cpuCoreFrequenciesMhz"] = frequencies
            }
        entries["cpuGovernor"]?.takeIf(String::isNotBlank)?.let { result["cpuGovernor"] = it }

        val appPid = entries["appPid"]?.toIntOrNull()
        val appTicks = entries["appProcStat"]?.let(::processTicks)
        if (appPid != null) result["appPid"] = appPid
        if (appPid != null && appTicks != null) {
            if (previousAppPid == appPid && lastPrivilegedCpuDelta > 0L) {
                val processDelta = (appTicks - previousAppTicks).coerceAtLeast(0L)
                val cores = Runtime.getRuntime().availableProcessors().coerceAtLeast(1)
                result["appCpuUsage"] =
                    (processDelta.toDouble() / lastPrivilegedCpuDelta.toDouble() * cores * 100.0)
                        .coerceIn(0.0, cores * 100.0)
            }
            previousAppPid = appPid
            previousAppTicks = appTicks
        }
        if (result["appCpuUsage"] == null) {
            entries["appCpuInstant"]?.toDoubleOrNull()
                ?.let { result["appCpuUsage"] = it.coerceAtLeast(0.0) }
        }
        entries["appRamKb"]?.toDoubleOrNull()?.let { result["appRamMb"] = it / 1024.0 }
        entries["appRssKb"]?.toDoubleOrNull()?.let { result["appRssMb"] = it / 1024.0 }
        entries["socTempRaw"]?.toDoubleOrNull()?.let(::normalizeTemperatureC)?.let { temperature ->
            if (temperature in -20.0..150.0) result["socTemperatureC"] = temperature
        }

        val status = entries["batteryStatus"]?.trim()?.lowercase()
        if (!status.isNullOrBlank()) {
            result["batteryCharging"] = status == "charging" || status == "full"
        }
        entries["batteryCapacityRaw"]?.toDoubleOrNull()?.takeIf { it in 0.0..100.0 }
            ?.let { result["batteryLevel"] = it }
        entries["batteryTempRaw"]?.toDoubleOrNull()?.let(::normalizeBatteryTemperatureC)
            ?.takeIf { it in -20.0..100.0 }
            ?.let { result["batteryTemperatureC"] = it }

        val currentMa = entries["batteryCurrentRaw"]?.toDoubleOrNull()?.let(::normalizeCurrentMa)
        val voltageV = entries["batteryVoltageRaw"]?.toDoubleOrNull()?.let(::normalizeVoltageV)
        val directPower = entries["batteryPowerRaw"]?.toDoubleOrNull()?.let(::normalizePowerW)
        currentMa?.let { result["batteryCurrentMa"] = it }
        voltageV?.let { result["batteryVoltageV"] = it }
        val calculatedPower = if (currentMa != null && voltageV != null) abs(currentMa / 1000.0 * voltageV) else null
        if (result["batteryCharging"] == true) {
            result.remove("batteryPowerW")
            result.remove("batteryPowerSource")
        } else {
            (calculatedPower ?: directPower?.let(::abs))?.takeIf { it in 0.05..100.0 }?.let {
                result["batteryPowerW"] = it
                result["batteryPowerSource"] = "sysfs"
            }
        }
    }

    private fun privilegedCpuUsage(stat: String): Double? {
        val values = stat.trim().split(Regex("\\s+")).drop(1).mapNotNull { it.toLongOrNull() }
        if (values.size < 4) return null
        val idle = values[3] + values.getOrElse(4) { 0L }
        val total = values.sum()
        if (previousPrivilegedCpuTotal == 0L) {
            previousPrivilegedCpuTotal = total
            previousPrivilegedCpuIdle = idle
            lastPrivilegedCpuDelta = 0L
            return null
        }
        val totalDelta = total - previousPrivilegedCpuTotal
        val idleDelta = idle - previousPrivilegedCpuIdle
        previousPrivilegedCpuTotal = total
        previousPrivilegedCpuIdle = idle
        lastPrivilegedCpuDelta = totalDelta.coerceAtLeast(0L)
        if (totalDelta <= 0L) return null
        return ((totalDelta - idleDelta).toDouble() / totalDelta.toDouble() * 100.0)
            .coerceIn(0.0, 100.0)
    }

    private fun processTicks(stat: String): Long? {
        val closingParen = stat.lastIndexOf(')')
        if (closingParen < 0 || closingParen + 2 >= stat.length) return null
        val fields = stat.substring(closingParen + 2).trim().split(Regex("\\s+"))
        if (fields.size <= 14) return null
        return (11..14).sumOf { index -> fields.getOrNull(index)?.toLongOrNull() ?: 0L }
    }

    private fun applyFrameMetrics(raw: String, result: HashMap<String, Any?>) {
        if (raw.contains("__FPSWATCHER_SOURCE=gfxinfo")) {
            applyGfxInfoMetrics(raw, result)
            return
        }
        result["fpsSource"] = "surfaceflinger"
        Regex("averageFPS\\s*[=:]\\s*([0-9]+(?:\\.[0-9]+)?)", RegexOption.IGNORE_CASE)
            .find(raw)?.groupValues?.getOrNull(1)?.toDoubleOrNull()?.let { fps ->
                result["fps"] = fps
                if (fps > 0.0) result["frameTimeMs"] = 1000.0 / fps
            }
        Regex("totalFrames\\s*[=:]\\s*([0-9]+)", RegexOption.IGNORE_CASE)
            .find(raw)?.groupValues?.getOrNull(1)?.toLongOrNull()?.let { result["totalFrames"] = it }

        val histogram = Regex("([0-9]+)ms=([0-9]+)").findAll(raw).mapNotNull { match ->
            val milliseconds = match.groupValues.getOrNull(1)?.toDoubleOrNull() ?: return@mapNotNull null
            val count = match.groupValues.getOrNull(2)?.toLongOrNull() ?: return@mapNotNull null
            if (milliseconds <= 0.0 || count <= 0L) null else milliseconds to count
        }.sortedBy { it.first }.toList()
        val total = histogram.sumOf { it.second }
        weightedMeanMs(histogram)?.let { mean ->
            result["frameTimeMs"] = mean
            if (result["fps"] == null && mean > 0.0) result["fps"] = 1000.0 / mean
        }
        val rolling = rollingHistogram(histogram)
        val rollingTotal = rolling.sumOf { it.second }
        if (rollingTotal >= 100L) {
            tailLowFps(rolling, rollingTotal, 0.01)?.let { result["onePercentLowFps"] = it }
        }
        if (rollingTotal >= 1_000L) {
            tailLowFps(rolling, rollingTotal, 0.001)?.let { result["pointOnePercentLowFps"] = it }
        }
        percentileMs(rolling, rollingTotal, 0.95)?.let { result["frameTimeP95Ms"] = it }
        percentileMs(rolling, rollingTotal, 0.99)?.let { result["frameTimeP99Ms"] = it }
        if (result["totalFrames"] == null && total > 0L) result["totalFrames"] = total
        result["frameWindowFrames"] = rollingTotal
    }

    private fun applyGfxInfoMetrics(raw: String, result: HashMap<String, Any?>) {
        val durations = raw.lineSequence().mapNotNull { line ->
            val trimmed = line.trim()
            if (!trimmed.contains(',') || trimmed.startsWith('#')) return@mapNotNull null
            val values = trimmed.split(',').mapNotNull { it.trim().toLongOrNull() }
            if (values.size < 17 || values[0] != 0L) return@mapNotNull null
            val duration = (values[16] - values[1]).toDouble() / 1_000_000.0
            duration.takeIf { it in 0.01..5000.0 }
        }.sorted().toList()
        if (durations.isEmpty()) return
        val histogram = durations.map { it to 1L }
        val total = durations.size.toLong()
        val averageMs = durations.average()
        result["fpsSource"] = "gfxinfo"
        result["fps"] = (1000.0 / averageMs).coerceIn(0.0, 1000.0)
        result["frameTimeMs"] = averageMs
        result["totalFrames"] = total
        val rolling = rollingHistogram(histogram)
        val rollingTotal = rolling.sumOf { it.second }
        if (rollingTotal >= 100L) {
            tailLowFps(rolling, rollingTotal, 0.01)?.let { result["onePercentLowFps"] = it }
        }
        if (rollingTotal >= 1_000L) {
            tailLowFps(rolling, rollingTotal, 0.001)?.let { result["pointOnePercentLowFps"] = it }
        }
        percentileMs(rolling, rollingTotal, 0.95)?.let { result["frameTimeP95Ms"] = it }
        percentileMs(rolling, rollingTotal, 0.99)?.let { result["frameTimeP99Ms"] = it }
        result["frameWindowFrames"] = rollingTotal
    }

    private fun rollingHistogram(current: List<Pair<Double, Long>>): List<Pair<Double, Long>> {
        val now = SystemClock.elapsedRealtime()
        if (current.isNotEmpty()) frameBuckets.addLast(FrameBucket(now, current))
        while (frameBuckets.isNotEmpty() && now - frameBuckets.first().timestampMs > FRAME_WINDOW_MS) {
            frameBuckets.removeFirst()
        }
        val merged = sortedMapOf<Double, Long>()
        frameBuckets.forEach { bucket ->
            bucket.histogram.forEach { (milliseconds, count) ->
                merged[milliseconds] = (merged[milliseconds] ?: 0L) + count
            }
        }
        return merged.map { it.key to it.value }
    }

    private fun weightedMeanMs(histogram: List<Pair<Double, Long>>): Double? {
        val total = histogram.sumOf { it.second }
        if (total <= 0L) return null
        return histogram.sumOf { it.first * it.second.toDouble() } / total.toDouble()
    }

    private fun percentileMs(
        histogram: List<Pair<Double, Long>>,
        total: Long,
        percentile: Double,
    ): Double? {
        if (total <= 0L) return null
        val target = ceil(total * percentile).toLong().coerceAtLeast(1L)
        var cumulative = 0L
        for ((milliseconds, count) in histogram) {
            cumulative += count
            if (cumulative >= target) return milliseconds
        }
        return histogram.lastOrNull()?.first
    }

    private fun tailLowFps(
        histogram: List<Pair<Double, Long>>,
        total: Long,
        fraction: Double,
    ): Double? {
        if (total <= 0L) return null
        var remaining = ceil(total * fraction).toLong().coerceAtLeast(1L)
        var selected = 0L
        var weightedMilliseconds = 0.0
        for ((milliseconds, count) in histogram.asReversed()) {
            if (remaining <= 0L) break
            val take = minOf(count, remaining)
            weightedMilliseconds += milliseconds * take.toDouble()
            selected += take
            remaining -= take
        }
        if (selected <= 0L || weightedMilliseconds <= 0.0) return null
        return 1000.0 / (weightedMilliseconds / selected.toDouble())
    }

    private fun applyGpuMetrics(raw: String, result: HashMap<String, Any?>) {
        val model = Regex("(?im)^\\s*(?:model|renderer|gpu)\\s*=\\s*([^\\r\\n]+)")
            .find(raw)?.groupValues?.getOrNull(1)?.trim()?.takeIf { it.isNotBlank() }
        if (result["gpuModel"] == null && model != null) result["gpuModel"] = model

        val explicitFrequency = Regex("(?im)^\\s*freq\\s*=\\s*([^\\r\\n]+)")
            .find(raw)?.groupValues?.getOrNull(1)?.let(::firstNumber)?.let(::normalizeGpuFrequency)
        val explicitMaxFrequency = Regex("(?im)^\\s*max_freq\\s*=\\s*([^\\r\\n]+)")
            .find(raw)?.groupValues?.getOrNull(1)?.let(::firstNumber)?.let(::normalizeGpuFrequency)
        val fallbackFrequency = raw.lineSequence().firstOrNull { line ->
            val lower = line.lowercase()
            (lower.contains("freq") || lower.contains("clock")) && !lower.contains("max")
        }?.let(::firstNumber)?.let(::normalizeGpuFrequency)
        (explicitFrequency ?: fallbackFrequency)?.takeIf { it in 1.0..10_000.0 }
            ?.let { result["gpuFrequencyMhz"] = it }
        explicitMaxFrequency?.takeIf { it in 1.0..10_000.0 }
            ?.let { result["gpuFrequencyMaxMhz"] = it }

        val explicitLoad = Regex("(?im)^\\s*load\\s*=\\s*([^\\r\\n]+)")
            .find(raw)?.groupValues?.getOrNull(1)?.let(::gpuLoadPercent)
        val fallbackLoad = raw.lineSequence().firstOrNull { line ->
            val lower = line.lowercase()
            lower.contains("load") || lower.contains("util") || lower.contains("busy")
        }?.let(::gpuLoadPercent)
        (explicitLoad ?: fallbackLoad)?.let { result["gpuLoad"] = it.coerceIn(0.0, 100.0) }
    }

    private fun firstNumber(value: String): Double? =
        Regex("-?[0-9]+(?:\\.[0-9]+)?").find(value)?.value?.toDoubleOrNull()

    private fun normalizeGpuFrequency(value: Double): Double = when {
        value >= 10_000_000.0 -> value / 1_000_000.0
        value >= 10_000.0 -> value / 1_000.0
        else -> value
    }

    private fun gpuLoadPercent(value: String): Double? {
        val numbers = Regex("-?[0-9]+(?:\\.[0-9]+)?")
            .findAll(value).mapNotNull { it.value.toDoubleOrNull() }.toList()
        if (numbers.isEmpty()) return null
        return if (numbers.size >= 2 && !value.contains('%') && numbers[1] > 0.0) {
            numbers[0] / numbers[1] * 100.0
        } else numbers[0]
    }

    private fun normalizeTemperatureC(raw: Double): Double = when {
        abs(raw) >= 10_000.0 -> raw / 1000.0
        abs(raw) >= 200.0 -> raw / 10.0
        else -> raw
    }

    private fun normalizeBatteryTemperatureC(raw: Double): Double = when {
        abs(raw) >= 10_000.0 -> raw / 1000.0
        abs(raw) >= 100.0 -> raw / 10.0
        else -> raw
    }

    private fun normalizeCurrentMa(raw: Double): Double = when {
        abs(raw) >= 10_000.0 -> raw / 1000.0
        else -> raw
    }

    private fun normalizeVoltageV(raw: Double): Double = when {
        abs(raw) >= 100_000.0 -> raw / 1_000_000.0
        abs(raw) >= 1000.0 -> raw / 1000.0
        else -> raw
    }

    private fun normalizePowerW(raw: Double): Double = when {
        abs(raw) >= 100_000.0 -> raw / 1_000_000.0
        abs(raw) >= 1000.0 -> raw / 1000.0
        else -> raw
    }

    private fun privilegedSystemCommand(packageName: String, includeSlowMetrics: Boolean): String = """
        echo "cpuStat=${'$'}(head -n 1 /proc/stat 2>/dev/null)"
        cpu_freqs=${'$'}(
          for p in /sys/devices/system/cpu/cpufreq/policy* /sys/devices/system/cpu/cpu*/cpufreq; do
            [ -d "${'$'}p" ] || continue
            for f in "${'$'}p/scaling_cur_freq" "${'$'}p/cpuinfo_cur_freq" "${'$'}p/scaling_max_freq"; do
              if [ -r "${'$'}f" ]; then cat "${'$'}f" 2>/dev/null; break; fi
            done
          done | awk 'BEGIN { first=1 } ${'$'}1 + 0 > 0 { if (!first) printf ","; printf "%s", ${'$'}1; first=0 } END { print "" }'
        )
        [ -n "${'$'}cpu_freqs" ] && echo "cpuFreqListKHz=${'$'}cpu_freqs"
        cpu_governor=${'$'}(for f in /sys/devices/system/cpu/cpufreq/policy*/scaling_governor; do [ -r "${'$'}f" ] && cat "${'$'}f"; done | sort -u | paste -sd/ -)
        [ -n "${'$'}cpu_governor" ] && echo "cpuGovernor=${'$'}cpu_governor"

        pkg="$packageName"
        if [ -n "${'$'}pkg" ]; then
          pid=${'$'}(pidof "${'$'}pkg" 2>/dev/null | awk '{print ${'$'}1}')
          if [ -n "${'$'}pid" ]; then
            echo "appPid=${'$'}pid"
            app_stat=${'$'}(cat "/proc/${'$'}pid/stat" 2>/dev/null)
            [ -n "${'$'}app_stat" ] && echo "appProcStat=${'$'}app_stat"
            app_rss=${'$'}(awk '/^VmRSS:/ {print ${'$'}2; exit}' "/proc/${'$'}pid/status" 2>/dev/null)
            [ -n "${'$'}app_rss" ] && echo "appRssKb=${'$'}app_rss"
            if [ "${if (includeSlowMetrics) 1 else 0}" = "1" ]; then
              app_pss=${'$'}(dumpsys meminfo "${'$'}pkg" 2>/dev/null | awk '/TOTAL PSS:/ {print ${'$'}3; exit} /^TOTAL[[:space:]]/ {print ${'$'}2; exit}')
              [ -z "${'$'}app_pss" ] && app_pss=${'$'}app_rss
              [ -n "${'$'}app_pss" ] && echo "appRamKb=${'$'}app_pss"
              app_cpu=${'$'}(dumpsys cpuinfo 2>/dev/null | awk -v pkg="${'$'}pkg" 'index(${'$'}0, pkg) {gsub(/%/, "", ${'$'}1); print ${'$'}1; exit}')
              [ -n "${'$'}app_cpu" ] && echo "appCpuInstant=${'$'}app_cpu"
            fi
          fi
        fi

        max_temp=0
        for z in /sys/class/thermal/thermal_zone*; do
          [ -r "${'$'}z/temp" ] || continue
          zone_type=${'$'}(cat "${'$'}z/type" 2>/dev/null | tr '[:upper:]' '[:lower:]')
          case "${'$'}zone_type" in *battery*|*charger*|*usb*) continue ;; esac
          value=${'$'}(cat "${'$'}z/temp" 2>/dev/null)
          case "${'$'}value" in ''|*[!0-9-]*) continue ;; esac
          if [ "${'$'}value" -gt "${'$'}max_temp" ] 2>/dev/null; then max_temp=${'$'}value; fi
        done
        [ "${'$'}max_temp" -gt 0 ] 2>/dev/null && echo "socTempRaw=${'$'}max_temp"

        battery=/sys/class/power_supply/battery
        [ -r "${'$'}battery/status" ] && echo "batteryStatus=${'$'}(cat "${'$'}battery/status" 2>/dev/null)"
        [ -r "${'$'}battery/capacity" ] && echo "batteryCapacityRaw=${'$'}(cat "${'$'}battery/capacity" 2>/dev/null)"
        [ -r "${'$'}battery/temp" ] && echo "batteryTempRaw=${'$'}(cat "${'$'}battery/temp" 2>/dev/null)"
        for f in "${'$'}battery/current_now" "${'$'}battery/batt_current_ua_now"; do
          if [ -r "${'$'}f" ]; then echo "batteryCurrentRaw=${'$'}(cat "${'$'}f" 2>/dev/null)"; break; fi
        done
        for f in "${'$'}battery/voltage_now" "${'$'}battery/batt_vol"; do
          if [ -r "${'$'}f" ]; then echo "batteryVoltageRaw=${'$'}(cat "${'$'}f" 2>/dev/null)"; break; fi
        done
        for f in "${'$'}battery/power_now" "${'$'}battery/power_avg"; do
          if [ -r "${'$'}f" ]; then echo "batteryPowerRaw=${'$'}(cat "${'$'}f" 2>/dev/null)"; break; fi
        done
    """.trimIndent()

    private fun frameStatsCommand(packageName: String): String = """
        sf=${'$'}(dumpsys SurfaceFlinger --timestats -dump 2>/dev/null | awk -v pkg="$packageName" '
          index(${'$'}0, pkg) {capture=1; lines=0}
          capture {print; lines++}
          capture && lines>=420 {exit}
        ')
        if [ -n "${'$'}sf" ]; then
          echo "__FPSWATCHER_SOURCE=surfaceflinger"
          printf "%s\n" "${'$'}sf"
        else
          echo "__FPSWATCHER_SOURCE=gfxinfo"
          dumpsys gfxinfo "$packageName" framestats 2>/dev/null
          dumpsys gfxinfo "$packageName" reset >/dev/null 2>&1
        fi
        dumpsys SurfaceFlinger --timestats -clear >/dev/null 2>&1
    """.trimIndent()

    companion object {
        private const val FOREGROUND_POLL_MS = 250L
        private const val CPU_FREQUENCY_POLL_MS = 200L
        private const val RAM_POLL_MS = 500L
        private const val BATTERY_POLL_MS = 250L
        private const val NETWORK_POLL_MS = 250L
        private const val THERMAL_POLL_MS = 750L
        private const val REFRESH_RATE_POLL_MS = 1_000L
        private const val STORAGE_POLL_MS = 5_000L
        private const val LOCAL_GPU_POLL_MS = 200L
        private const val PRIVILEGED_POLL_MS = 200L
        private const val SLOW_PRIVILEGED_POLL_MS = 1_500L
        private const val FRAME_POLL_MS = 1_000L
        private const val FRAME_WINDOW_MS = 30_000L
        private val FRAME_KEYS = setOf(
            "surfaceFlingerRaw", "fpsSource", "fps", "onePercentLowFps",
            "pointOnePercentLowFps", "frameTimeMs", "frameTimeP95Ms",
            "frameTimeP99Ms", "totalFrames", "frameWindowFrames",
        )
        private val PACKAGE_NAME = Regex("^[A-Za-z][A-Za-z0-9_]*(?:\\.[A-Za-z0-9_]+)+$")
        private val FREQUENCY_NAMES = listOf(
            "gpuclk", "cur_freq", "clock", "scaling_cur_freq", "devfreq/cur_freq", "current_freqency",
        )
        private val MAX_FREQUENCY_NAMES = listOf(
            "max_gpuclk", "max_freq", "scaling_max_freq", "devfreq/max_freq",
        )
        private val LOAD_NAMES = listOf(
            "gpubusy", "load", "utilization", "gpu_busy_percentage", "busy", "gpu_utilization",
        )

        private val FOREGROUND_PACKAGE_COMMAND = """
            dumpsys activity activities 2>/dev/null | awk '
              /mResumedActivity|topResumedActivity|ResumedActivity/ {
                for (i=1; i<=NF; i++) if (${'$'}i ~ /^[A-Za-z0-9_.]+\/[A-Za-z0-9_.${'$'}]+/) {
                  split(${'$'}i, a, "/"); print a[1]; exit
                }
              }'
            dumpsys window windows 2>/dev/null | awk '
              /mCurrentFocus|mFocusedApp/ {
                for (i=1; i<=NF; i++) if (${'$'}i ~ /^[A-Za-z0-9_.]+\/[A-Za-z0-9_.${'$'}]+/) {
                  split(${'$'}i, a, "/"); print a[1]; exit
                }
              }'
        """.trimIndent()

        private fun privilegedGpuCommand(includeSlowMetrics: Boolean): String = """
            if [ "${if (includeSlowMetrics) 1 else 0}" = "1" ]; then
              model=${'$'}(dumpsys SurfaceFlinger 2>/dev/null | sed -n 's/.*GLES: *//p' | head -n 1)
              [ -z "${'$'}model" ] && model=${'$'}(getprop ro.hardware.egl 2>/dev/null)
              [ -n "${'$'}model" ] && echo "model=${'$'}model"
            fi
            for f in \
              /sys/class/kgsl/kgsl-3d0/gpuclk \
              /sys/class/kgsl/kgsl-3d0/devfreq/cur_freq \
              /sys/class/devfreq/*kgsl*/cur_freq \
              /sys/class/devfreq/*gpu*/cur_freq \
              /sys/class/devfreq/*mali*/cur_freq \
              /sys/devices/platform/*gpu*/devfreq/*/cur_freq \
              /sys/devices/platform/*mali*/devfreq/*/cur_freq \
              /sys/class/misc/mali0/device/clock \
              /sys/kernel/ged/hal/current_freqency; do
              if [ -r "${'$'}f" ]; then echo "freq=${'$'}(cat "${'$'}f" 2>/dev/null)"; break; fi
            done
            for f in \
              /sys/class/kgsl/kgsl-3d0/max_gpuclk \
              /sys/class/kgsl/kgsl-3d0/devfreq/max_freq \
              /sys/class/devfreq/*kgsl*/max_freq \
              /sys/class/devfreq/*gpu*/max_freq \
              /sys/class/devfreq/*mali*/max_freq \
              /sys/devices/platform/*gpu*/devfreq/*/max_freq \
              /sys/devices/platform/*mali*/devfreq/*/max_freq; do
              if [ -r "${'$'}f" ]; then echo "max_freq=${'$'}(cat "${'$'}f" 2>/dev/null)"; break; fi
            done
            for f in \
              /sys/class/kgsl/kgsl-3d0/gpubusy \
              /sys/class/kgsl/kgsl-3d0/gpu_busy_percentage \
              /sys/class/kgsl/kgsl-3d0/devfreq/load \
              /sys/class/devfreq/*kgsl*/load \
              /sys/class/devfreq/*gpu*/load \
              /sys/class/devfreq/*mali*/load \
              /sys/devices/platform/*gpu*/devfreq/*/load \
              /sys/devices/platform/*mali*/devfreq/*/load \
              /sys/class/misc/mali0/device/utilization \
              /sys/kernel/ged/hal/gpu_utilization \
              /sys/kernel/debug/kgsl/kgsl-3d0/gpubusy \
              /d/kgsl/kgsl-3d0/gpubusy; do
              if [ -r "${'$'}f" ]; then echo "load=${'$'}(cat "${'$'}f" 2>/dev/null)"; break; fi
            done
            if [ "${if (includeSlowMetrics) 1 else 0}" = "1" ]; then
              dumpsys gpu 2>/dev/null | head -n 160
            fi
        """.trimIndent()
    }
}

object RootShell {
    @Volatile private var cachedAvailable = false
    @Volatile private var lastCheckMs = 0L
    @Volatile var lastError: String? = null
        private set
    private val ioExecutor = Executors.newCachedThreadPool()

    private fun candidates(): List<String> = buildList {
        listOf(
            "/system/bin/su",
            "/system/xbin/su",
            "/sbin/su",
            "/debug_ramdisk/su",
            "/data/adb/ap/bin/su",
        ).filterTo(this) { File(it).exists() }
        add("su")
    }.distinct()

    fun isInstalled(): Boolean {
        if (candidates().any { it != "su" }) return true
        return System.getenv("PATH").orEmpty().split(':').any { directory ->
            directory.isNotBlank() && File(directory, "su").exists()
        }
    }

    fun requestAccess(): Boolean {
        lastCheckMs = 0L
        cachedAvailable = false
        val result = runSu("id", 20)
        cachedAvailable = result?.let { (finished, output) ->
            finished && output.contains("uid=0")
        } ?: false
        lastCheckMs = System.currentTimeMillis()
        if (cachedAvailable) lastError = null
        return cachedAvailable
    }

    fun isAvailable(force: Boolean = false): Boolean {
        val now = System.currentTimeMillis()
        if (!force && now - lastCheckMs < 1_500L) return cachedAvailable
        synchronized(this) {
            val current = System.currentTimeMillis()
            if (!force && current - lastCheckMs < 1_500L) return cachedAvailable
            val result = runSu("id", if (force) 15 else 5)
            cachedAvailable = result?.let { (finished, output) ->
                finished && output.contains("uid=0")
            } ?: false
            lastCheckMs = current
            if (cachedAvailable) lastError = null
            return cachedAvailable
        }
    }

    fun execute(command: String): String? {
        if (!isAvailable()) return null
        val result = runSu(command, 15) ?: return null
        return result.takeIf { it.first }?.second
    }

    private fun runSu(command: String, timeoutSeconds: Long): Pair<Boolean, String>? {
        var latestError: String? = null
        for (binary in candidates()) {
            val attempt = runCatching {
                val process = ProcessBuilder(binary, "-c", command)
                    .redirectErrorStream(true)
                    .start()
                val outputFuture = ioExecutor.submit<String> {
                    process.inputStream.bufferedReader().use { it.readText() }
                }
                val finished = process.waitFor(timeoutSeconds, TimeUnit.SECONDS)
                if (!finished) process.destroyForcibly()
                val output = runCatching { outputFuture.get(2, TimeUnit.SECONDS) }.getOrDefault("")
                if (!finished) {
                    latestError = "Root command timed out"
                } else if (output.contains("denied", ignoreCase = true) ||
                    output.contains("not allowed", ignoreCase = true)) {
                    latestError = output.trim().take(180).ifBlank { "Root access denied" }
                }
                finished to output
            }.onFailure { error ->
                latestError = error.message ?: error.javaClass.simpleName
            }.getOrNull()
            if (attempt != null && attempt.first &&
                (command != "id" || attempt.second.contains("uid=0"))) {
                lastError = null
                return attempt
            }
        }
        lastError = latestError ?: "su executable was not found or permission was denied"
        return null
    }
}

