package com.fpswatcher.app

import android.content.Context
import org.json.JSONObject
import java.io.BufferedWriter
import java.io.File
import java.io.FileOutputStream
import java.io.OutputStreamWriter
import java.util.ArrayDeque

object NativeSessionStore {
    private const val MAX_SAMPLES = 21_600 // Six hours at one sample per second.
    private val lock = Any()
    private val samples = ArrayDeque<HashMap<String, Any?>>()

    @Volatile
    private var initialized = false

    private var sessionFile: File? = null
    private var writer: BufferedWriter? = null

    @Volatile
    var isRecording: Boolean = false
        private set

    fun init(context: Context) {
        if (initialized) return
        synchronized(lock) {
            if (initialized) return
            sessionFile = File(context.filesDir, "fpswatcher-session.jsonl")
            loadPersistedSamples()
            initialized = true
        }
    }

    fun start() {
        synchronized(lock) {
            closeWriter()
            samples.clear()
            sessionFile?.parentFile?.mkdirs()
            writer = openWriter(append = false)
            isRecording = true
        }
    }

    fun stop() {
        synchronized(lock) {
            isRecording = false
            closeWriter()
        }
    }

    fun add(source: Map<String, Any?>) {
        if (!isRecording) return
        val cleaned = HashMap<String, Any?>(source.size).apply {
            putAll(source)
            remove("surfaceFlingerRaw")
            remove("gpuRaw")
        }
        synchronized(lock) {
            if (!isRecording) return
            samples.addLast(cleaned)
            while (samples.size > MAX_SAMPLES) samples.removeFirst()
            runCatching {
                if (writer == null) writer = openWriter(append = true)
                writer?.apply {
                    write(JSONObject(cleaned as Map<*, *>).toString())
                    newLine()
                    flush()
                }
            }
        }
    }

    fun count(): Int = synchronized(lock) { samples.size }

    fun snapshot(limit: Int? = null): List<HashMap<String, Any?>> = synchronized(lock) {
        val safeLimit = limit?.coerceAtLeast(0)
        val selected = if (safeLimit == null || safeLimit >= samples.size) {
            samples.toList()
        } else {
            samples.drop(samples.size - safeLimit)
        }
        selected.map { HashMap(it) }
    }

    private fun loadPersistedSamples() {
        val file = sessionFile ?: return
        if (!file.isFile) return
        val loaded = ArrayDeque<HashMap<String, Any?>>()
        runCatching {
            file.useLines { lines ->
                lines.filter { it.isNotBlank() }.forEach { line ->
                    val json = JSONObject(line)
                    val sample = HashMap<String, Any?>()
                    val keys = json.keys()
                    while (keys.hasNext()) {
                        val key = keys.next()
                        val value = json.opt(key)
                        sample[key] = if (value == JSONObject.NULL) null else value
                    }
                    loaded.addLast(sample)
                    while (loaded.size > MAX_SAMPLES) loaded.removeFirst()
                }
            }
        }
        samples.clear()
        samples.addAll(loaded)
        isRecording = false
    }

    private fun openWriter(append: Boolean): BufferedWriter? {
        val file = sessionFile ?: return null
        return BufferedWriter(
            OutputStreamWriter(FileOutputStream(file, append), Charsets.UTF_8),
            DEFAULT_BUFFER_SIZE,
        )
    }

    private fun closeWriter() {
        runCatching { writer?.flush() }
        runCatching { writer?.close() }
        writer = null
    }
}
