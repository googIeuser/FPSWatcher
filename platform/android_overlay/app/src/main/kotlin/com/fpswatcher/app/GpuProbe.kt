package com.fpswatcher.app

import android.opengl.EGL14
import android.opengl.GLES20

object GpuProbe {
    @Volatile
    private var attempted = false

    @Volatile
    private var cachedRenderer: String? = null

    fun renderer(): String? {
        if (attempted) return cachedRenderer
        synchronized(this) {
            if (attempted) return cachedRenderer
            cachedRenderer = queryRenderer()
            attempted = true
            return cachedRenderer
        }
    }

    private fun queryRenderer(): String? = runCatching {
        val display = EGL14.eglGetDisplay(EGL14.EGL_DEFAULT_DISPLAY)
        if (display == EGL14.EGL_NO_DISPLAY) return@runCatching null
        val version = IntArray(2)
        if (!EGL14.eglInitialize(display, version, 0, version, 1)) {
            return@runCatching null
        }

        val configAttributes = intArrayOf(
            EGL14.EGL_RENDERABLE_TYPE,
            EGL14.EGL_OPENGL_ES2_BIT,
            EGL14.EGL_SURFACE_TYPE,
            EGL14.EGL_PBUFFER_BIT,
            EGL14.EGL_RED_SIZE,
            8,
            EGL14.EGL_GREEN_SIZE,
            8,
            EGL14.EGL_BLUE_SIZE,
            8,
            EGL14.EGL_NONE,
        )
        val configs = arrayOfNulls<android.opengl.EGLConfig>(1)
        val configCount = IntArray(1)
        if (
            !EGL14.eglChooseConfig(
                display,
                configAttributes,
                0,
                configs,
                0,
                1,
                configCount,
                0,
            )
        ) {
            EGL14.eglTerminate(display)
            return@runCatching null
        }
        val config = configs[0] ?: run {
            EGL14.eglTerminate(display)
            return@runCatching null
        }
        val surfaceAttributes = intArrayOf(
            EGL14.EGL_WIDTH,
            1,
            EGL14.EGL_HEIGHT,
            1,
            EGL14.EGL_NONE,
        )
        val contextAttributes = intArrayOf(
            EGL14.EGL_CONTEXT_CLIENT_VERSION,
            2,
            EGL14.EGL_NONE,
        )
        val surface = EGL14.eglCreatePbufferSurface(
            display,
            config,
            surfaceAttributes,
            0,
        )
        val context = EGL14.eglCreateContext(
            display,
            config,
            EGL14.EGL_NO_CONTEXT,
            contextAttributes,
            0,
        )
        if (surface == EGL14.EGL_NO_SURFACE || context == EGL14.EGL_NO_CONTEXT) {
            if (surface != EGL14.EGL_NO_SURFACE) EGL14.eglDestroySurface(display, surface)
            if (context != EGL14.EGL_NO_CONTEXT) EGL14.eglDestroyContext(display, context)
            EGL14.eglTerminate(display)
            return@runCatching null
        }
        EGL14.eglMakeCurrent(display, surface, surface, context)
        val renderer = GLES20.glGetString(GLES20.GL_RENDERER)
        EGL14.eglMakeCurrent(
            display,
            EGL14.EGL_NO_SURFACE,
            EGL14.EGL_NO_SURFACE,
            EGL14.EGL_NO_CONTEXT,
        )
        EGL14.eglDestroySurface(display, surface)
        EGL14.eglDestroyContext(display, context)
        EGL14.eglTerminate(display)
        renderer
    }.getOrNull()
}
