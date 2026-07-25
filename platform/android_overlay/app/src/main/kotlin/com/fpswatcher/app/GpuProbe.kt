package com.fpswatcher.app

import android.opengl.EGL14
import android.opengl.GLES20
import java.util.concurrent.TimeUnit

object GpuProbe {
    @Volatile private var attempted = false
    @Volatile private var cachedRenderer: String? = null

    fun renderer(): String? {
        if (attempted) return cachedRenderer
        synchronized(this) {
            if (attempted) return cachedRenderer
            cachedRenderer = queryRenderer()
                ?.takeIf { it.isNotBlank() }
                ?: readProperty("ro.hardware.egl")
                ?: readProperty("ro.hardware.vulkan")
            attempted = true
            return cachedRenderer
        }
    }

    private fun readProperty(name: String): String? = runCatching {
        val process = ProcessBuilder("getprop", name)
            .redirectErrorStream(true)
            .start()
        val finished = process.waitFor(700, TimeUnit.MILLISECONDS)
        if (!finished) process.destroyForcibly()
        if (!finished) return@runCatching null
        process.inputStream.bufferedReader().use { it.readText().trim() }
            .takeIf { it.isNotBlank() }
    }.getOrNull()

    private fun queryRenderer(): String? = runCatching {
        val display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        if (display == EGL14.EGL_NO_DISPLAY) return@runCatching null
        val version = IntArray(2)
        if (!EGL14.eglInitialize(display, version, 0, version, 1)) return@runCatching null

        try {
            val configAttributes = intArrayOf(
                EGL14.EGL_RENDERABLE_TYPE, EGL14.EGL_OPENGL_ES2_BIT,
                EGL14.EGL_SURFACE_TYPE, EGL14.EGL_PBUFFER_BIT,
                EGL14.EGL_RED_SIZE, 8,
                EGL14.EGL_GREEN_SIZE, 8,
                EGL14.EGL_BLUE_SIZE, 8,
                EGL14.EGL_ALPHA_SIZE, 8,
                EGL14.EGL_NONE,
            )
            val configs = arrayOfNulls<android.opengl.EGLConfig>(1)
            val count = IntArray(1)
            if (!EGL14.eglChooseConfig(display, configAttributes, 0, configs, 0, 1, count, 0)) {
                return@runCatching null
            }
            val config = configs[0] ?: return@runCatching null
            val surface = EGL14.eglCreatePbufferSurface(
                display,
                config,
                intArrayOf(EGL14.EGL_WIDTH, 1, EGL14.EGL_HEIGHT, 1, EGL14.EGL_NONE),
                0,
            )
            val glContext = EGL14.eglCreateContext(
                display,
                config,
                EGL14.EGL_NO_CONTEXT,
                intArrayOf(EGL14.EGL_CONTEXT_CLIENT_VERSION, 2, EGL14.EGL_NONE),
                0,
            )
            if (surface == EGL14.EGL_NO_SURFACE || glContext == EGL14.EGL_NO_CONTEXT) {
                if (surface != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(display, surface)
                if (glContext != EGL14.EGL_NO_CONTEXT) EGL14.eglDestroyContext(display, glContext)
                return@runCatching null
            }
            try {
                if (!EGL14.eglMakeCurrent(display, surface, surface, glContext)) return@runCatching null
                GLES20.glGetString(GLES20.GL_RENDERER)?.trim()?.takeIf { it.isNotEmpty() }
            } finally {
                EGL14.eglMakeCurrent(display, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_SURFACE, EGL14.EGL_NO_CONTEXT)
                EGL14.eglDestroySurface(display, surface)
                EGL14.eglDestroyContext(display, glContext)
            }
        } finally {
            EGL14.eglTerminate(display)
        }
    }.getOrNull()
}
