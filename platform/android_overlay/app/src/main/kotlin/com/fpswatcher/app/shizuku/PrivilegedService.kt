package com.fpswatcher.app.shizuku

import android.content.Context
import java.io.BufferedReader
import java.io.InputStreamReader
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlin.system.exitProcess

class PrivilegedService : IPrivilegedService.Stub {
    constructor() : super()
    constructor(@Suppress("UNUSED_PARAMETER") context: Context) : super()

    private val ioExecutor = Executors.newCachedThreadPool()

    override fun execute(command: String): String {
        val process = ProcessBuilder("sh", "-c", command)
            .redirectErrorStream(true)
            .start()
        val outputFuture = ioExecutor.submit<String> {
            BufferedReader(InputStreamReader(process.inputStream)).use { it.readText() }
        }
        val finished = process.waitFor(12, TimeUnit.SECONDS)
        if (!finished) process.destroyForcibly()
        val output = runCatching { outputFuture.get(2, TimeUnit.SECONDS) }
            .getOrDefault("")
        return if (finished) output else "$output\nFPSWATCHER_ERROR=timeout"
    }

    override fun destroy() {
        ioExecutor.shutdownNow()
        exitProcess(0)
    }
}
