package com.fpswatcher.app

import android.os.SystemClock

/**
 * Process-local cache shared by the Flutter activity and overlay service.
 * This prevents both surfaces from launching duplicate dumpsys/sysfs probes.
 */
object TelemetrySnapshotCache {
    private val lock = Any()
    private var mode: String? = null
    private var capturedAtElapsedMs: Long = 0L
    private var snapshot: HashMap<String, Any?>? = null

    fun put(accessMode: String, value: Map<String, Any?>) {
        synchronized(lock) {
            mode = accessMode
            capturedAtElapsedMs = SystemClock.elapsedRealtime()
            snapshot = HashMap(value)
        }
    }

    fun get(accessMode: String, maxAgeMs: Long): HashMap<String, Any?>? = synchronized(lock) {
        val current = snapshot ?: return@synchronized null
        if (mode != accessMode) return@synchronized null
        if (SystemClock.elapsedRealtime() - capturedAtElapsedMs > maxAgeMs) return@synchronized null
        HashMap(current)
    }

    fun clear() {
        synchronized(lock) {
            mode = null
            capturedAtElapsedMs = 0L
            snapshot = null
        }
    }
}
