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
import android.provider.Settings
import android.view.Display
import com.fpswatcher.app.shizuku.ShizukuClient
import java.io.File
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
    private val surfaceFlingerEnabled = AtomicBoolean(false)

    fun collect(mode: String): HashMap<String, Any?> {
        val result = hashMapOf<String, Any?>()
        val warnings = mutableListOf<String>()

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

        val backend = runCatching { privilegedExecutor(mode) }
            .onFailure { warnings += "backend: ${it.javaClass.simpleName}" }
            .getOrNull()
        result["accessModeUsed"] = backend?.name ?: "standard"
        result["backendOperational"] = backend != null || mode.equals("standard", ignoreCase = true)

        var foregroundPackage = runCatching { foregroundPackageFromUsage() }
            .onFailure { warnings += "foregroundUsage: ${it.javaClass.simpleName}" }
            .getOrNull()
        if (foregroundPackage.isNullOrBlank() && backend != null) {
            foregroundPackage = backend.execute(FOREGROUND_PACKAGE_COMMAND)
                ?.lineSequence()
                ?.map(String::trim)
                ?.firstOrNull { PACKAGE_NAME.matches(it) }
        }
        if (!foregroundPackage.isNullOrBlank()) result["foregroundPackage"] = foregroundPackage

        metric("cpuUsage") { cpuUsage() }
        metric("cpuFrequencyMhz") { cpuFrequencyMhz() }
        metric("gpuModel") { GpuProbe.renderer() }
        metrics("ram") { ramInfo() }
        metric("refreshRateHz") { refreshRate() }
        metric("thermalStatus") { thermalStatus() }
        metrics("battery") { batteryInfo() }
        metrics("network") { networkInfo() }
        metrics("storage") { storageInfo() }

        val localGpu = runCatching { localGpuProbe() }
            .onFailure { warnings += "localGpu: ${it.javaClass.simpleName}" }
            .getOrDefault("")
        if (localGpu.isNotBlank()) {
            result["gpuRaw"] = localGpu
            runCatching { applyGpuMetrics(localGpu, result) }
                .onFailure { warnings += "gpuParse: ${it.javaClass.simpleName}" }
        }

        if (backend != null) {
            val packageName = foregroundPackage.orEmpty().replace(Regex("[^A-Za-z0-9._-]"), "")
            backend.execute(privilegedSystemCommand(packageName))
                ?.takeIf { it.isNotBlank() }
                ?.let { raw ->
                    runCatching { applyPrivilegedSystemMetrics(raw, result) }
                        .onFailure { warnings += "privilegedSystem: ${it.javaClass.simpleName}" }
                }

            if (!surfaceFlingerEnabled.get()) {
                val enabled = backend.execute(
                    "dumpsys SurfaceFlinger --timestats -clear -enable >/dev/null 2>&1; echo FPSWATCHER_OK",
                )?.contains("FPSWATCHER_OK") == true
                if (enabled) surfaceFlingerEnabled.set(true)
            }
            if (packageName.isNotBlank()) {
                val surfaceRaw = backend.execute(surfaceFlingerCommand(packageName)).orEmpty()
                if (surfaceRaw.isNotBlank()) {
                    result["surfaceFlingerRaw"] = surfaceRaw
                    runCatching { applySurfaceFlingerMetrics(surfaceRaw, result) }
                        .onFailure { warnings += "surfaceFlinger: ${it.javaClass.simpleName}" }
                }
            }

            val privilegedGpu = backend.execute(PRIVILEGED_GPU_COMMAND).orEmpty()
            val combinedGpu = listOf(localGpu, privilegedGpu)
                .filter { it.isNotBlank() }
                .joinToString("\n")
            if (combinedGpu.isNotBlank()) {
                result["gpuRaw"] = combinedGpu
                runCatching { applyGpuMetrics(combinedGpu, result) }
                    .onFailure { warnings += "privilegedGpu: ${it.javaClass.simpleName}" }
            }
        }

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
        val rootInstalled = RootShell.isInstalled()
        val rootOperational = if (rootInstalled) RootShell.isAvailable() else false
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
            "standard" -> null
            "shizuku" -> shizuku() ?: root()
            "root" -> root() ?: shizuku()
            else -> shizuku() ?: root()
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

    private fun cpuFrequencyMhz(): Double? {
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
                ?.readText()?.trim()?.toDoubleOrNull()
        }
        return values.takeIf { it.isNotEmpty() }?.average()?.div(1000.0)
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
            .takeIf { it != Int.MIN_VALUE && it != 0 }
        val signedPower = if (voltageMv != null && currentUa != null) {
            currentUa.toDouble() / 1_000_000.0 * voltageMv.toDouble() / 1000.0
        } else null
        return mapOf(
            "batteryLevel" to level?.let { it / scale * 100.0 },
            "batteryTemperatureC" to intent
                ?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Int.MIN_VALUE)
                ?.takeIf { it != Int.MIN_VALUE }
                ?.div(10.0),
            "batteryPowerW" to signedPower?.let(::abs),
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
        val events = manager.queryEvents(end - 30_000L, end)
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
        return manager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, end - 120_000L, end)
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
        GpuProbe.renderer()?.takeIf { it.isNotBlank() }?.let { lines += "model=$it" }
        candidateGpuFiles(FREQUENCY_NAMES)
            .firstOrNull { it.canRead() }
            ?.let { lines += "freq=${it.readText().trim()}" }
        candidateGpuFiles(LOAD_NAMES)
            .firstOrNull { it.canRead() }
            ?.let { lines += "load=${it.readText().trim()}" }
        return lines.joinToString("\n")
    }

    private fun candidateGpuFiles(names: List<String>): List<File> {
        val roots = buildList {
            add(File("/sys/class/kgsl/kgsl-3d0"))
            add(File("/sys/class/kgsl/kgsl-3d0/devfreq"))
            add(File("/sys/class/misc/mali0/device"))
            File("/sys/class/devfreq").listFiles()
                ?.filter { pathLooksGpu(it.absolutePath) }
                ?.let(::addAll)
            File("/sys/devices/platform").listFiles()
                ?.filter { pathLooksGpu(it.absolutePath) }
                ?.let(::addAll)
        }.filter(File::exists).distinctBy(File::getAbsolutePath)
        return roots.flatMap { root -> names.map { File(root, it) } }
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
        entries["cpuFreqKHz"]?.toDoubleOrNull()?.let { result["cpuFrequencyMhz"] = it / 1000.0 }

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
        entries["appCpuInstant"]?.toDoubleOrNull()?.let { result["appCpuUsage"] = it.coerceAtLeast(0.0) }
        entries["appRamKb"]?.toDoubleOrNull()?.let { result["appRamMb"] = it / 1024.0 }
        entries["socTempMilliC"]?.toDoubleOrNull()?.let { rawTemp ->
            val celsius = if (abs(rawTemp) > 1000.0) rawTemp / 1000.0 else rawTemp
            if (celsius in -20.0..150.0) result["socTemperatureC"] = celsius
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

    private fun applySurfaceFlingerMetrics(raw: String, result: HashMap<String, Any?>) {
        Regex("averageFPS\\s*[=:]\\s*([0-9]+(?:\\.[0-9]+)?)", RegexOption.IGNORE_CASE)
            .find(raw)?.groupValues?.getOrNull(1)?.toDoubleOrNull()?.let { fps ->
                result["fps"] = fps
                if (fps > 0.0) result["frameTimeMs"] = 1000.0 / fps
            }
        Regex("totalFrames\\s*[=:]\\s*([0-9]+)", RegexOption.IGNORE_CASE)
            .find(raw)?.groupValues?.getOrNull(1)?.toLongOrNull()?.let { result["totalFrames"] = it }

        val histogram = Regex("([0-9]+)ms=([0-9]+)").findAll(raw).mapNotNull { match ->
            val milliseconds = match.groupValues.getOrNull(1)?.toLongOrNull() ?: return@mapNotNull null
            val count = match.groupValues.getOrNull(2)?.toLongOrNull() ?: return@mapNotNull null
            milliseconds to count
        }.sortedBy { it.first }.toList()
        val total = histogram.sumOf { it.second }
        percentileFps(histogram, total, 0.90)?.let { result["p90Fps"] = it }
        percentileFps(histogram, total, 0.99)?.let { result["p99Fps"] = it }
    }

    private fun percentileFps(histogram: List<Pair<Long, Long>>, total: Long, percentile: Double): Double? {
        if (total <= 0L) return null
        val target = ceil(total * percentile).toLong()
        var cumulative = 0L
        for ((milliseconds, count) in histogram) {
            cumulative += count
            if (cumulative >= target) return if (milliseconds > 0L) 1000.0 / milliseconds else null
        }
        return null
    }

    private fun applyGpuMetrics(raw: String, result: HashMap<String, Any?>) {
        val model = Regex("(?im)^\\s*(?:model|renderer|gpu)\\s*=\\s*([^\\r\\n]+)")
            .find(raw)?.groupValues?.getOrNull(1)?.trim()?.takeIf { it.isNotBlank() }
        if (result["gpuModel"] == null && model != null) result["gpuModel"] = model

        val explicitFrequency = Regex("(?im)^\\s*freq\\s*=\\s*([^\\r\\n]+)")
            .find(raw)?.groupValues?.getOrNull(1)?.let(::firstNumber)?.let(::normalizeGpuFrequency)
        val fallbackFrequency = raw.lineSequence().firstOrNull { line ->
            val lower = line.lowercase()
            lower.contains("freq") || lower.contains("clock")
        }?.let(::firstNumber)?.let(::normalizeGpuFrequency)
        (explicitFrequency ?: fallbackFrequency)?.takeIf { it in 1.0..10_000.0 }
            ?.let { result["gpuFrequencyMhz"] = it }

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

    private fun privilegedSystemCommand(packageName: String): String = """
        echo "cpuStat=${'$'}(head -n 1 /proc/stat 2>/dev/null)"
        cpu_freq=${'$'}(
          for p in /sys/devices/system/cpu/cpufreq/policy* /sys/devices/system/cpu/cpu*/cpufreq; do
            [ -d "${'$'}p" ] || continue
            for f in "${'$'}p/scaling_cur_freq" "${'$'}p/cpuinfo_cur_freq" "${'$'}p/scaling_max_freq"; do
              if [ -r "${'$'}f" ]; then cat "${'$'}f" 2>/dev/null; break; fi
            done
          done | awk '{ if (${'$'}1 + 0 > 0) { sum += ${'$'}1; count += 1 } } END { if (count > 0) print sum / count }'
        )
        [ -n "${'$'}cpu_freq" ] && echo "cpuFreqKHz=${'$'}cpu_freq"
        pkg="$packageName"
        if [ -n "${'$'}pkg" ]; then
          pid=${'$'}(pidof "${'$'}pkg" 2>/dev/null | awk '{print ${'$'}1}')
          if [ -n "${'$'}pid" ]; then
            echo "appPid=${'$'}pid"
            app_stat=${'$'}(cat "/proc/${'$'}pid/stat" 2>/dev/null)
            [ -n "${'$'}app_stat" ] && echo "appProcStat=${'$'}app_stat"
            app_ram=${'$'}(awk '/^VmRSS:/ {print ${'$'}2; exit}' "/proc/${'$'}pid/status" 2>/dev/null)
            if [ -z "${'$'}app_ram" ]; then
              app_ram=${'$'}(dumpsys meminfo "${'$'}pkg" 2>/dev/null | awk '/TOTAL PSS:/ {print ${'$'}3; exit} /^TOTAL[[:space:]]/ {print ${'$'}2; exit}')
            fi
            [ -n "${'$'}app_ram" ] && echo "appRamKb=${'$'}app_ram"
            if [ -z "${'$'}app_stat" ]; then
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
        [ "${'$'}max_temp" -gt 0 ] 2>/dev/null && echo "socTempMilliC=${'$'}max_temp"
    """.trimIndent()

    private fun surfaceFlingerCommand(packageName: String): String = """
        dumpsys SurfaceFlinger --timestats -dump 2>/dev/null | awk -v pkg="$packageName" '
          index(${'$'}0, pkg) {capture=1; lines=0}
          capture {print; lines++}
          capture && lines>=320 {exit}
        '
        dumpsys SurfaceFlinger --timestats -clear >/dev/null 2>&1
    """.trimIndent()

    companion object {
        private val PACKAGE_NAME = Regex("^[A-Za-z][A-Za-z0-9_]*(?:\\.[A-Za-z0-9_]+)+$")
        private val FREQUENCY_NAMES = listOf(
            "gpuclk", "cur_freq", "clock", "scaling_cur_freq", "devfreq/cur_freq", "current_freqency",
        )
        private val LOAD_NAMES = listOf(
            "gpubusy", "load", "utilization", "gpu_busy_percentage", "busy", "gpu_utilization",
        )

        private val FOREGROUND_PACKAGE_COMMAND = """
            dumpsys activity activities 2>/dev/null | awk '
              /mResumedActivity|topResumedActivity|ResumedActivity/ {
                for (i=1; i<=NF; i++) if (${'$'}i ~ /^[A-Za-z0-9_.]+\/[A-Za-z0-9_.$]+/) {
                  split(${'$'}i, a, "/"); print a[1]; exit
                }
              }'
            dumpsys window windows 2>/dev/null | awk '
              /mCurrentFocus|mFocusedApp/ {
                for (i=1; i<=NF; i++) if (${'$'}i ~ /^[A-Za-z0-9_.]+\/[A-Za-z0-9_.$]+/) {
                  split(${'$'}i, a, "/"); print a[1]; exit
                }
              }'
        """.trimIndent()

        private val PRIVILEGED_GPU_COMMAND = """
            model=${'$'}(getprop ro.hardware.egl 2>/dev/null)
            [ -z "${'$'}model" ] && model=${'$'}(dumpsys SurfaceFlinger 2>/dev/null | sed -n 's/.*GLES: *//p' | head -n 1)
            [ -n "${'$'}model" ] && echo "model=${'$'}model"
            for f in \
              /sys/class/kgsl/kgsl-3d0/gpuclk \
              /sys/class/kgsl/kgsl-3d0/devfreq/cur_freq \
              /sys/class/devfreq/*gpu*/cur_freq \
              /sys/class/devfreq/*mali*/cur_freq \
              /sys/devices/platform/*gpu*/devfreq/*/cur_freq \
              /sys/devices/platform/*mali*/devfreq/*/cur_freq \
              /sys/class/misc/mali0/device/clock \
              /sys/kernel/ged/hal/current_freqency; do
              if [ -r "${'$'}f" ]; then echo "freq=${'$'}(cat "${'$'}f" 2>/dev/null)"; break; fi
            done
            for f in \
              /sys/class/kgsl/kgsl-3d0/gpubusy \
              /sys/class/kgsl/kgsl-3d0/gpu_busy_percentage \
              /sys/class/devfreq/*gpu*/load \
              /sys/class/devfreq/*mali*/load \
              /sys/devices/platform/*gpu*/devfreq/*/load \
              /sys/devices/platform/*mali*/devfreq/*/load \
              /sys/class/misc/mali0/device/utilization \
              /sys/kernel/ged/hal/gpu_utilization; do
              if [ -r "${'$'}f" ]; then echo "load=${'$'}(cat "${'$'}f" 2>/dev/null)"; break; fi
            done
            dumpsys gpu 2>/dev/null | head -n 120
        """.trimIndent()
    }
}

object RootShell {
    @Volatile private var cachedAvailable = false
    @Volatile private var lastCheckMs = 0L
    private val ioExecutor = Executors.newCachedThreadPool()

    fun isInstalled(): Boolean {
        val knownPaths = arrayOf(
            "/system/bin/su", "/system/xbin/su", "/sbin/su", "/debug_ramdisk/su",
            "/data/adb/ksud", "/data/adb/ap/bin/su",
        )
        if (knownPaths.any { File(it).exists() }) return true
        return System.getenv("PATH").orEmpty().split(':').any { directory ->
            directory.isNotBlank() && File(directory, "su").exists()
        }
    }

    fun isAvailable(): Boolean {
        val now = System.currentTimeMillis()
        if (now - lastCheckMs < 5_000L) return cachedAvailable
        synchronized(this) {
            val current = System.currentTimeMillis()
            if (current - lastCheckMs < 5_000L) return cachedAvailable
            cachedAvailable = runSu("id", 4)?.let { (finished, output) ->
                finished && output.contains("uid=0")
            } ?: false
            lastCheckMs = current
            return cachedAvailable
        }
    }

    fun execute(command: String): String? = runSu(command, 15)?.takeIf { it.first }?.second

    private fun runSu(command: String, timeoutSeconds: Long): Pair<Boolean, String>? = runCatching {
        val process = ProcessBuilder("su", "-c", command)
            .redirectErrorStream(true)
            .start()
        val outputFuture = ioExecutor.submit<String> {
            process.inputStream.bufferedReader().use { it.readText() }
        }
        val finished = process.waitFor(timeoutSeconds, TimeUnit.SECONDS)
        if (!finished) process.destroyForcibly()
        val output = runCatching { outputFuture.get(2, TimeUnit.SECONDS) }.getOrDefault("")
        finished to output
    }.getOrNull()
}
