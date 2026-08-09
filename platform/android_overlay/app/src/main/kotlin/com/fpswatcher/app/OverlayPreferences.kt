package com.fpswatcher.app

import android.content.Context
import android.content.SharedPreferences

object OverlayPreferences {
    private const val PREFS = "fpswatcher_overlay"
    private const val KEY_REVISION = "revision"
    private const val KEY_X = "x"
    private const val KEY_Y = "y"

    private fun prefs(context: Context): SharedPreferences =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun snapshot(context: Context): Map<String, Any> {
        val p = prefs(context)
        val result = linkedMapOf<String, Any>(
            "textSizeSp" to p.getFloat("textSizeSp", 13f).toDouble(),
            "opacity" to p.getFloat("opacity", 0.92f).toDouble(),
            "paddingDp" to p.getInt("paddingDp", 10),
            "refreshIntervalMs" to p.getInt("refreshIntervalMs", 100),
            "textColorValue" to (p.getInt("textColorValue", -1).toLong() and 0xFFFFFFFFL),
            "layoutMode" to (p.getString("layoutMode", "vertical") ?: "vertical"),
            "revision" to p.getLong(KEY_REVISION, 0L),
        )
        BOOLEAN_DEFAULTS.forEach { (key, fallback) -> result[key] = p.getBoolean(key, fallback) }
        return result
    }

    fun update(context: Context, values: Map<*, *>) {
        val p = prefs(context)
        val editor = p.edit()
        values["textSizeSp"].asDouble()?.let { editor.putFloat("textSizeSp", it.coerceIn(10.0, 24.0).toFloat()) }
        values["opacity"].asDouble()?.let { editor.putFloat("opacity", it.coerceIn(0.15, 1.0).toFloat()) }
        values["paddingDp"].asInt()?.let { editor.putInt("paddingDp", it.coerceIn(0, 24)) }
        values["refreshIntervalMs"].asInt()?.let { value ->
            editor.putInt("refreshIntervalMs", ALLOWED_REFRESH.minBy { kotlin.math.abs(it - value) })
        }
        values["textColorValue"].asInt()?.let { value ->
            editor.putInt("textColorValue", value.takeIf(ALLOWED_TEXT_COLORS::contains) ?: -1)
        }
        (values["layoutMode"] as? String)?.lowercase()?.let { value ->
            editor.putString("layoutMode", if (value == "horizontal") "horizontal" else "vertical")
        }
        BOOLEAN_DEFAULTS.keys.forEach { key ->
            (values[key] as? Boolean)?.let { editor.putBoolean(key, it) }
        }
        editor.putLong(KEY_REVISION, p.getLong(KEY_REVISION, 0L) + 1L)
        editor.apply()
    }

    fun revision(context: Context): Long = prefs(context).getLong(KEY_REVISION, 0L)

    fun position(context: Context): Pair<Int, Int>? {
        val p = prefs(context)
        if (!p.contains(KEY_X) || !p.contains(KEY_Y)) return null
        return p.getInt(KEY_X, 0) to p.getInt(KEY_Y, 0)
    }

    fun savePosition(context: Context, x: Int, y: Int) {
        prefs(context).edit().putInt(KEY_X, x).putInt(KEY_Y, y).apply()
    }

    fun resetPosition(context: Context) {
        prefs(context).edit().remove(KEY_X).remove(KEY_Y).apply()
    }

    private fun Any?.asDouble(): Double? = when (this) {
        is Number -> toDouble()
        is String -> toDoubleOrNull()
        else -> null
    }

    private fun Any?.asInt(): Int? = when (this) {
        is Number -> toInt()
        is String -> toIntOrNull()
        else -> null
    }

    private val ALLOWED_REFRESH = listOf(100, 200, 500)
    private val ALLOWED_TEXT_COLORS = setOf(-1, 0xFF39E7D0.toInt(), 0xFF7CFF84.toInt(), 0xFFFFD65A.toInt())

    private val BOOLEAN_DEFAULTS = linkedMapOf(
        "adaptiveColors" to true,
        "showFps" to true,
        "showFivePercentLow" to false,
        "showLows" to true,
        "showFrameTime" to true,
        "showStability" to true,
        "showDroppedFrames" to false,
        "showSystemCpu" to true,
        "showAppCpu" to true,
        "showCpuFrequency" to true,
        "showCpuCores" to false,
        "showCpuThrottle" to true,
        "showGpuLoad" to true,
        "showGpuFrequency" to true,
        "showGpuThrottle" to true,
        "showGameRam" to true,
        "showMemory" to false,
        "showProcessDetails" to false,
        "showPower" to true,
        "showEfficiency" to false,
        "showBatteryDrain" to false,
        "showBatteryTemperature" to true,
        "showSocTemperature" to false,
        "showThermalStatus" to true,
        "showNetwork" to false,
        "showWifi" to false,
        "showMonitorOverhead" to false,
        "showOnlyWhenGameDetected" to true,
    )
}
