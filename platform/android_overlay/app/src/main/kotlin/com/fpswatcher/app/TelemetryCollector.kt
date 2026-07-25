package com.fpswatcher.app

import android.app.ActivityManager
import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Build
import android.os.Environment
import android.os.PowerManager
import android.os.StatFs
import android.provider.Settings
import android.net.TrafficStats
import android.view.WindowManager
import com.fpswatcher.app.shizuku.ShizukuClient
import java.io.File
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean
import kotlin.math.abs

class TelemetryCollector(private val context: Context) {
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
        val foregroundPackage = foregroundPackage()
        val ram = ramInfo()
        val gpuRenderer = GpuProbe.renderer()
        val result = hashMapOf<String, Any?>(
            "foregroundPackage" to foregroundPackage,
            "cpuUsage" to cpuUsage(),
            "cpuFrequencyMhz" to cpuFrequencyMhz(),
            "gpuModel" to gpuRenderer,
            "ramUsedMb" to ram.first,
            "ramTotalMb" to ram.second,
            "refreshRateHz" to refreshRate(),
            "thermalStatus" to thermalStatus(),
        )
        result.putAll(batteryInfo())
        result.putAll(networkInfo())
        result.putAll(storageInfo())

        val localGpu = localGpuProbe()
        if (localGpu.isNotBlank()) result["gpuRaw"] = localGpu

        val privileged = privilegedExecutor(mode)
        result["accessModeUsed"] = privileged?.first ?: "standard"
        if (privileged != null) {
            val executor = privileged.second
            val packageName = foregroundPackage.orEmpty().replace(Regex("[^A-Za-z0-9._-]"), "")
            val systemRaw = executor(privilegedSystemCommand(packageName)).orEmpty()
            if (systemRaw.isNotBlank()) applyPrivilegedSystemMetrics(systemRaw, result)

            if (!surfaceFlingerEnabled.get()) {
                val enableResult = executor(
                    "dumpsys SurfaceFlinger --timestats -clear -enable >/dev/null 2>&1 || true",
                )
                if (enableResult != null) surfaceFlingerEnabled.set(true)
            }
            if (packageName.isNotBlank()) {
                val sfCommand = "{ dumpsys SurfaceFlinger --timestats -dump 2>/dev/null | " +
                    "grep -F -A 220 '$packageName' | head -n 260; " +
                    "dumpsys SurfaceFlinger --timestats -clear >/dev/null 2>&1; }"
                val surfaceRaw = executor(sfCommand).orEmpty()
                if (surfaceRaw.isNotBlank()) {
                    result["surfaceFlingerRaw"] = surfaceRaw
                    applySurfaceFlingerMetrics(surfaceRaw, result)
                }
            }
            val gpuRaw = executor(PRIVILEGED_GPU_COMMAND).orEmpty()
            if (gpuRaw.isNotBlank()) {
                val combinedGpu = listOf(localGpu, gpuRaw).filter { it.isNotBlank() }.joinToString("\n")
                result["gpuRaw"] = combinedGpu
                applyGpuMetrics(combinedGpu, result)
            }
        } else if (localGpu.isNotBlank()) {
            applyGpuMetrics(localGpu, result)
        }
        result["timestampMs"] = System.currentTimeMillis()
        return result
    }


    private fun applySurfaceFlingerMetrics(raw: String, result: HashMap<String, Any?>) {
        Regex("averageFPS\\s*[=:]\\s*([0-9]+(?:\\.[0-9]+)?)", RegexOption.IGNORE_CASE)
            .find(raw)?.groupValues?.getOrNull(1)?.toDoubleOrNull()?.let { fps ->
                result["fps"] = fps
                if (fps > 0.0) result["frameTimeMs"] = 1000.0 / fps
            }
        Regex("totalFrames\\s*[=:]\\s*([0-9]+)", RegexOption.IGNORE_CASE)
            .find(raw)?.groupValues?.getOrNull(1)?.toLongOrNull()?.let { result["totalFrames"] = it }

        val histogram = Regex("([0-9]+)ms=([0-9]+)")
            .findAll(raw)
            .mapNotNull { match ->
                val milliseconds = match.groupValues.getOrNull(1)?.toLongOrNull() ?: return@mapNotNull null
                val count = match.groupValues.getOrNull(2)?.toLongOrNull() ?: return@mapNotNull null
                milliseconds to count
            }
            .sortedBy { it.first }
            .toList()
        val total = histogram.sumOf { it.second }
        percentileFps(histogram, total, 0.90)?.let { result["p90Fps"] = it }
        percentileFps(histogram, total, 0.99)?.let { result["p99Fps"] = it }
    }

    private fun percentileFps(histogram: List<Pair<Long, Long>>, total: Long, percentile: Double): Double? {
        if (total <= 0L) return null
        val target = kotlin.math.ceil(total * percentile).toLong()
        var cumulative = 0L
        for ((milliseconds, count) in histogram) {
            cumulative += count
            if (cumulative >= target) return if (milliseconds > 0L) 1000.0 / milliseconds else null
        }
        return null
    }

    private fun applyGpuMetrics(raw: String, result: HashMap<String, Any?>) {
        val explicitFrequency = Regex("(?im)^\\s*freq\\s*=\\s*([^\\r\\n]+)")
            .find(raw)?.groupValues?.getOrNull(1)?.let(::firstNumber)?.let(::normalizeGpuFrequency)
        val fallbackFrequency = raw.lineSequence()
            .firstOrNull { line ->
                val lower = line.lowercase()
                lower.contains("freq") || lower.contains("clock")
            }
            ?.let(::firstNumber)?.let(::normalizeGpuFrequency)
        (explicitFrequency ?: fallbackFrequency)?.let { result["gpuFrequencyMhz"] = it }

        val explicitLoad = Regex("(?im)^\\s*load\\s*=\\s*([^\\r\\n]+)")
            .find(raw)?.groupValues?.getOrNull(1)?.let(::gpuLoadPercent)
        val fallbackLoad = raw.lineSequence()
            .firstOrNull { line ->
                val lower = line.lowercase()
                lower.contains("load") || lower.contains("util") || lower.contains("busy")
            }
            ?.let(::gpuLoadPercent)
        (explicitLoad ?: fallbackLoad)?.let {
            result["gpuLoad"] = it.coerceIn(0.0, 100.0)
        }
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
        } else {
            numbers[0]
        }
    }

    private fun applyPrivilegedSystemMetrics(raw: String, result: HashMap<String, Any?>) {
        val entries = raw.lineSequence()
            .mapNotNull { line ->
                val separator = line.indexOf('=')
                if (separator <= 0) null else line.substring(0, separator).trim() to line.substring(separator + 1).trim()
            }
            .toMap()

        entries["cpuStat"]?.let { stat ->
            privilegedCpuUsage(stat)?.let { result["cpuUsage"] = it }
        }
        entries["cpuFreqKHz"]?.toDoubleOrNull()?.let { result["cpuFrequencyMhz"] = it / 1000.0 }

        val appPid = entries["appPid"]?.toIntOrNull()
        val appTicks = entries["appProcStat"]?.let(::processTicks)
        if (appPid != null && appTicks != null) {
            if (previousAppPid == appPid && lastPrivilegedCpuDelta > 0L) {
                val processDelta = (appTicks - previousAppTicks).coerceAtLeast(0L)
                val cores = Runtime.getRuntime().availableProcessors().coerceAtLeast(1)
                result["appCpuUsage"] = (processDelta.toDouble() / lastPrivilegedCpuDelta.toDouble() * cores * 100.0)
                    .coerceIn(0.0, cores * 100.0)
            }
            previousAppPid = appPid
            previousAppTicks = appTicks
            result["appPid"] = appPid
        }
        entries["appCpuInstant"]?.toDoubleOrNull()?.let {
            result["appCpuUsage"] = it.coerceAtLeast(0.0)
        }
        entries["appRamKb"]?.toDoubleOrNull()?.let { result["appRamMb"] = it / 1024.0 }
        entries["socTempMilliC"]?.toDoubleOrNull()?.let { value ->
            val celsius = if (value > 1000.0) value / 1000.0 else value
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

    private fun privilegedSystemCommand(packageName: String): String = """
        echo "cpuStat=${'$'}(head -n 1 /proc/stat 2>/dev/null)"
        cpu_freq=${'$'}(
          for p in /sys/devices/system/cpu/cpufreq/policy*; do
            for f in "${'$'}p/scaling_cur_freq" "${'$'}p/cpuinfo_cur_freq" "${'$'}p/scaling_max_freq"; do
              if [ -r "${'$'}f" ]; then cat "${'$'}f" 2>/dev/null; break; fi
            done
          done | awk '{ if (${ '$' }1 + 0 > 0) { sum += ${ '$' }1; count += 1 } } END { if (count > 0) print sum / count }'
        )
        [ -n "${'$'}cpu_freq" ] && echo "cpuFreqKHz=${'$'}cpu_freq"
        pkg="$packageName"
        if [ -n "${'$'}pkg" ]; then
          pid=${'$'}(pidof "${'$'}pkg" 2>/dev/null | awk '{print ${ '$' }1}')
          if [ -n "${'$'}pid" ]; then
            echo "appPid=${'$'}pid"
            app_stat=${'$'}(cat "/proc/${'$'}pid/stat" 2>/dev/null)
            [ -n "${'$'}app_stat" ] && echo "appProcStat=${'$'}app_stat"
            app_ram=${'$'}(awk '/^VmRSS:/ {print ${ '$' }2; exit}' "/proc/${'$'}pid/status" 2>/dev/null)
            if [ -z "${'$'}app_ram" ]; then
              app_ram=${'$'}(dumpsys meminfo "${'$'}pkg" 2>/dev/null | awk '/TOTAL PSS:/ {print ${ '$' }3; exit} /^TOTAL[[:space:]]/ {print ${ '$' }2; exit}')
            fi
            [ -n "${'$'}app_ram" ] && echo "appRamKb=${'$'}app_ram"
            if [ -z "${'$'}app_stat" ]; then
              app_cpu=${'$'}(dumpsys cpuinfo 2>/dev/null | awk -v pkg="${'$'}pkg" 'index(${ '$' }0, pkg) {gsub(/%/, "", ${ '$' }1); print ${ '$' }1; exit}')
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

    fun status(): HashMap<String, Any?> {
        return hashMapOf(
            "usageAccess" to hasUsageAccess(),
            "overlayPermission" to Settings.canDrawOverlays(context),
            "notificationPermission" to notificationPermission(),
            "shizukuAvailable" to ShizukuClient.isAvailable(),
            "shizukuPermission" to ShizukuClient.hasPermission(),
            "shizukuUid" to ShizukuClient.uid(),
            "rootAvailable" to RootShell.isInstalled(),
            "overlayRunning" to OverlayService.isOverlayVisible,
            "monitorServiceRunning" to OverlayService.isRunning,
            "recording" to NativeSessionStore.isRecording,
            "recordedSampleCount" to NativeSessionStore.count(),
        )
    }

    private fun privilegedExecutor(mode: String): Pair<String, (String) -> String?>? {
        fun shizuku(): Pair<String, (String) -> String?>? {
            if (!ShizukuClient.hasPermission()) return null
            ShizukuClient.bindIfPossible()
            return "shizuku" to { command -> ShizukuClient.execute(command) }
        }
        fun root(): Pair<String, (String) -> String?>? {
            if (!RootShell.isAvailable()) return null
            return "root" to { command -> RootShell.execute(command) }
        }
        return when (mode.lowercase()) {
            "shizuku" -> shizuku()
            "root" -> root()
            "standard" -> null
            else -> shizuku()
        }
    }

    private fun cpuUsage(): Double? {
        val line = runCatching { File("/proc/stat").bufferedReader().use { it.readLine() } }.getOrNull()
            ?: return null
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
        val base = File("/sys/devices/system/cpu/cpufreq")
        val frequencies = base.listFiles()
            ?.filter { it.name.startsWith("policy") }
            ?.mapNotNull { policy ->
                sequenceOf("scaling_cur_freq", "cpuinfo_cur_freq", "scaling_max_freq")
                    .map { File(policy, it) }
                    .firstOrNull { it.canRead() }
                    ?.readText()?.trim()?.toDoubleOrNull()
            }
            .orEmpty()
        if (frequencies.isEmpty()) return null
        return frequencies.average() / 1000.0
    }

    private fun ramInfo(): Pair<Double?, Double?> {
        val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val info = ActivityManager.MemoryInfo()
        manager.getMemoryInfo(info)
        val total = info.totalMem / 1024.0 / 1024.0
        val used = (info.totalMem - info.availMem) / 1024.0 / 1024.0
        return used to total
    }

    private fun batteryInfo(): Map<String, Any?> {
        val intent = context.registerReceiver(null, IntentFilter(Intent.ACTION_BATTERY_CHANGED))
        val manager = context.getSystemService(Context.BATTERY_SERVICE) as BatteryManager
        val level = intent?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)?.takeIf { it >= 0 }?.toDouble()
        val scale = intent?.getIntExtra(BatteryManager.EXTRA_SCALE, 100)?.takeIf { it > 0 } ?: 100
        val percent = level?.let { it / scale * 100.0 }
        val temperature = intent?.getIntExtra(BatteryManager.EXTRA_TEMPERATURE, Int.MIN_VALUE)
            ?.takeIf { it != Int.MIN_VALUE }?.div(10.0)
        val voltageMv = intent?.getIntExtra(BatteryManager.EXTRA_VOLTAGE, 0)?.takeIf { it > 0 }
        val currentUa = manager.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)
            .takeIf { it != Int.MIN_VALUE && it != 0 }
        val power = if (voltageMv != null && currentUa != null) {
            abs(currentUa.toDouble()) / 1_000_000.0 * voltageMv.toDouble() / 1000.0
        } else null
        return mapOf(
            "batteryLevel" to percent,
            "batteryTemperatureC" to temperature,
            "batteryPowerW" to power,
        )
    }

    private fun thermalStatus(): Int? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return null
        val manager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        return manager.currentThermalStatus
    }

    @Suppress("DEPRECATION")
    private fun refreshRate(): Double? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            context.display?.refreshRate?.toDouble()
        } else {
            (context.getSystemService(Context.WINDOW_SERVICE) as WindowManager)
                .defaultDisplay.refreshRate.toDouble()
        }
    }

    private fun networkInfo(): Map<String, Any?> {
        val now = System.currentTimeMillis()
        val rx = TrafficStats.getTotalRxBytes()
        val tx = TrafficStats.getTotalTxBytes()
        val elapsedSeconds = ((now - previousNetworkMs).coerceAtLeast(1L)) / 1000.0
        val rxKbps = if (rx >= 0 && previousRx >= 0) (rx - previousRx).coerceAtLeast(0L) / 1024.0 / elapsedSeconds else null
        val txKbps = if (tx >= 0 && previousTx >= 0) (tx - previousTx).coerceAtLeast(0L) / 1024.0 / elapsedSeconds else null
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

    private fun foregroundPackage(): String? {
        if (!hasUsageAccess()) return null
        val manager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        val events = manager.queryEvents(end - 15_000L, end)
        val event = UsageEvents.Event()
        var current: String? = null
        var newest = 0L
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if ((event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
                        (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && event.eventType == UsageEvents.Event.ACTIVITY_RESUMED)) &&
                event.timeStamp >= newest
            ) {
                newest = event.timeStamp
                current = event.packageName
            }
        }
        if (current != null) return current
        return manager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, end - 60_000L, end)
            .maxByOrNull { it.lastTimeUsed }?.packageName
    }

    private fun hasUsageAccess(): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), context.packageName)
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, android.os.Process.myUid(), context.packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun notificationPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) == android.content.pm.PackageManager.PERMISSION_GRANTED
    }

    private fun localGpuProbe(): String {
        val lines = mutableListOf<String>()
        val renderer = GpuProbe.renderer()
        if (!renderer.isNullOrBlank()) lines += "model=$renderer"
        val frequencyFiles = candidateGpuFiles(
            listOf("gpuclk", "cur_freq", "clock", "scaling_cur_freq")
        )
        frequencyFiles.firstOrNull { it.canRead() }?.let { lines += "freq=${it.readText().trim()}" }
        val loadFiles = candidateGpuFiles(
            listOf("gpubusy", "load", "utilization", "gpu_busy_percentage")
        )
        loadFiles.firstOrNull { it.canRead() }?.let { lines += "load=${it.readText().trim()}" }
        return lines.joinToString("\n")
    }

    private fun candidateGpuFiles(names: List<String>): List<File> {
        val fixed = listOf(
            File("/sys/class/kgsl/kgsl-3d0"),
            File("/sys/class/misc/mali0/device"),
        )
        val devfreq = File("/sys/class/devfreq").listFiles()?.filter {
            val lower = it.name.lowercase()
            lower.contains("gpu") || lower.contains("mali") || lower.contains("kgsl")
        }.orEmpty()
        return (fixed + devfreq).flatMap { directory -> names.map { File(directory, it) } }
    }

    companion object {
        private val PRIVILEGED_GPU_COMMAND = """
            echo "model=${'$'}(getprop ro.hardware.egl 2>/dev/null)"
            found_freq=0
            found_load=0
            for f in /sys/class/kgsl/kgsl-3d0/gpuclk /sys/class/kgsl/kgsl-3d0/devfreq/cur_freq /sys/class/devfreq/*gpu*/cur_freq /sys/class/devfreq/*mali*/cur_freq /sys/class/misc/mali0/device/clock; do
              if [ -r "${'$'}f" ]; then echo "freq=${'$'}(cat "${'$'}f" 2>/dev/null)"; found_freq=1; break; fi
            done
            for f in /sys/class/kgsl/kgsl-3d0/gpubusy /sys/class/kgsl/kgsl-3d0/gpu_busy_percentage /sys/class/devfreq/*gpu*/load /sys/class/devfreq/*mali*/load /sys/class/misc/mali0/device/utilization; do
              if [ -r "${'$'}f" ]; then echo "load=${'$'}(cat "${'$'}f" 2>/dev/null)"; found_load=1; break; fi
            done
            if [ "${'$'}found_freq" -eq 0 ] || [ "${'$'}found_load" -eq 0 ]; then
              dumpsys gpu 2>/dev/null | head -n 120
            fi
        """.trimIndent()
    }
}

object RootShell {
    @Volatile private var cachedAvailable = false
    @Volatile private var lastCheckMs = 0L
    private val ioExecutor = Executors.newCachedThreadPool()

    fun isInstalled(): Boolean {
        val knownPaths = arrayOf(
            "/system/bin/su",
            "/system/xbin/su",
            "/sbin/su",
            "/debug_ramdisk/su",
            "/data/adb/ksud",
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
            if (now - lastCheckMs < 5_000L) return cachedAvailable
            cachedAvailable = runSu("id", 2)?.let { (finished, output) ->
                finished && output.contains("uid=0")
            } ?: false
            lastCheckMs = now
            return cachedAvailable
        }
    }

    fun execute(command: String): String? = runSu(command, 12)?.second

    private fun runSu(command: String, timeoutSeconds: Long): Pair<Boolean, String>? = runCatching {
        val process = ProcessBuilder("su", "-c", command)
            .redirectErrorStream(true)
            .start()
        val outputFuture = ioExecutor.submit<String> {
            process.inputStream.bufferedReader().use { it.readText() }
        }
        val finished = process.waitFor(timeoutSeconds, TimeUnit.SECONDS)
        if (!finished) process.destroyForcibly()
        val output = runCatching { outputFuture.get(2, TimeUnit.SECONDS) }
            .getOrDefault("")
        finished to output
    }.getOrNull()
}
