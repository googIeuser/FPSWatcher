package com.fpswatcher.app

import android.content.Context
import org.json.JSONObject
import java.io.BufferedWriter
import java.io.File
import java.io.FileOutputStream
import java.io.OutputStreamWriter
import java.util.ArrayDeque

object NativeSessionStore {
    private const val MAX_SAMPLES = 43_200 // Six hours at two recorded samples per second.
    private const val FLUSH_EVERY_SAMPLES = 10
    private const val FLUSH_EVERY_MS = 3_000L
    private const val MAX_FILE_BYTES = 64L * 1024L * 1024L
    private val lock = Any()
    private val samples = ArrayDeque<HashMap<String, Any?>>()

    @Volatile
    private var initialized = false

    private var sessionFile: File? = null
    private var writer: BufferedWriter? = null
    private var pendingWrites = 0
    private var lastFlushMs = 0L

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
            pendingWrites = 0
            lastFlushMs = System.currentTimeMillis()
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
        val cleaned = FlutterChannelValue.stringMap(source).apply {
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
                    write(JSONObject(cleaned).toString())
                    newLine()
                    pendingWrites += 1
                    val now = System.currentTimeMillis()
                    if (pendingWrites >= FLUSH_EVERY_SAMPLES || now - lastFlushMs >= FLUSH_EVERY_MS) {
                        flush()
                        pendingWrites = 0
                        lastFlushMs = now
                    }
                }
            }.onFailure {
                closeWriter()
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

    fun snapshotPage(offset: Int, limit: Int): List<HashMap<String, Any?>> = synchronized(lock) {
        val safeOffset = offset.coerceIn(0, samples.size)
        val safeLimit = limit.coerceIn(1, 2_000)
        samples.drop(safeOffset).take(safeLimit).map { HashMap(it) }
    }

    private fun loadPersistedSamples() {
        val file = sessionFile ?: return
        if (!file.isFile) return
        val loaded = ArrayDeque<HashMap<String, Any?>>()
        runCatching {
            file.useLines { lines ->
                lines.filter { it.isNotBlank() }.forEach { line ->
                    runCatching {
                        val json = JSONObject(line)
                        val sample = HashMap<String, Any?>()
                        val keys = json.keys()
                        while (keys.hasNext()) {
                            val key = keys.next()
                            sample[key] = FlutterChannelValue.sanitize(json.opt(key))
                        }
                        loaded.addLast(sample)
                        while (loaded.size > MAX_SAMPLES) loaded.removeFirst()
                    }
                }
            }
        }
        samples.clear()
        samples.addAll(loaded)
        isRecording = false
        if (file.length() > MAX_FILE_BYTES) rewritePersistedSamples()
    }

    private fun rewritePersistedSamples() {
        val file = sessionFile ?: return
        val temporary = File(file.parentFile, "${file.name}.tmp")
        runCatching {
            temporary.bufferedWriter(Charsets.UTF_8).use { output ->
                samples.forEach { sample ->
                    output.write(JSONObject(sample).toString())
                    output.newLine()
                }
            }
            if (!temporary.renameTo(file)) {
                temporary.copyTo(file, overwrite = true)
                temporary.delete()
            }
        }.onFailure {
            temporary.delete()
        }
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
        pendingWrites = 0
        lastFlushMs = 0L
    }
}
