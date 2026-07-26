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
        return mapOf(
            "textSizeSp" to p.getFloat("textSizeSp", 13f).toDouble(),
            "opacity" to p.getFloat("opacity", 0.92f).toDouble(),
            "paddingDp" to p.getInt("paddingDp", 10),
            "refreshIntervalMs" to p.getInt("refreshIntervalMs", 100),
            "textColorValue" to (p.getInt("textColorValue", -1).toLong() and 0xFFFFFFFFL),
            "showFps" to p.getBoolean("showFps", true),
            "showLows" to p.getBoolean("showLows", true),
            "showFrameTime" to p.getBoolean("showFrameTime", true),
            "showSystemCpu" to p.getBoolean("showSystemCpu", true),
            "showAppCpu" to p.getBoolean("showAppCpu", true),
            "showCpuFrequency" to p.getBoolean("showCpuFrequency", true),
            "showGpuLoad" to p.getBoolean("showGpuLoad", true),
            "showGpuFrequency" to p.getBoolean("showGpuFrequency", true),
            "showGameRam" to p.getBoolean("showGameRam", true),
            "showPower" to p.getBoolean("showPower", true),
            "showBatteryTemperature" to p.getBoolean("showBatteryTemperature", true),
            "showSocTemperature" to p.getBoolean("showSocTemperature", false),
            "revision" to p.getLong(KEY_REVISION, 0L),
        )
    }

    fun update(context: Context, values: Map<*, *>) {
        val p = prefs(context)
        val editor = p.edit()
        values["textSizeSp"].asDouble()?.let { editor.putFloat("textSizeSp", it.coerceIn(10.0, 24.0).toFloat()) }
        values["opacity"].asDouble()?.let { editor.putFloat("opacity", it.coerceIn(0.25, 1.0).toFloat()) }
        values["paddingDp"].asInt()?.let { editor.putInt("paddingDp", it.coerceIn(0, 24)) }
        values["refreshIntervalMs"].asInt()?.let { editor.putInt("refreshIntervalMs", it.coerceIn(100, 1000)) }
        values["textColorValue"].asInt()?.let { editor.putInt("textColorValue", it) }
        BOOLEAN_KEYS.forEach { key ->
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

    private val BOOLEAN_KEYS = listOf(
        "showFps",
        "showLows",
        "showFrameTime",
        "showSystemCpu",
        "showAppCpu",
        "showCpuFrequency",
        "showGpuLoad",
        "showGpuFrequency",
        "showGameRam",
        "showPower",
        "showBatteryTemperature",
        "showSocTemperature",
    )
}
