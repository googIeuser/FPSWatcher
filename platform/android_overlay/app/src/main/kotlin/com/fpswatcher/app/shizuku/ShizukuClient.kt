package com.fpswatcher.app.shizuku

import android.content.ComponentName
import android.content.Context
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.IBinder
import android.os.SystemClock
import com.fpswatcher.app.BuildConfig
import rikka.shizuku.Shizuku

object ShizukuClient {
    private const val REQUEST_CODE = 4317
    private const val BIND_TIMEOUT_MS = 2_500L
    private const val HEALTH_CACHE_MS = 5_000L

    @Volatile private var service: IPrivilegedService? = null
    @Volatile private var initialized = false
    @Volatile private var binding = false
    @Volatile private var lastHealthCheckMs = 0L
    @Volatile private var lastHealthResult = false
    private val serviceLock = Object()
    private lateinit var applicationContext: Context

    private val userServiceArgs by lazy {
        Shizuku.UserServiceArgs(
            ComponentName(applicationContext, PrivilegedService::class.java),
        )
            .daemon(false)
            .tag("fpswatcher-privileged-v2")
            .version(2)
            .debuggable(BuildConfig.DEBUG)
            .processNameSuffix("fpswatcher")
    }

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            synchronized(serviceLock) {
                service = IPrivilegedService.Stub.asInterface(binder)
                binding = false
                lastHealthCheckMs = 0L
                serviceLock.notifyAll()
            }
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            synchronized(serviceLock) {
                service = null
                binding = false
                lastHealthResult = false
                lastHealthCheckMs = 0L
                serviceLock.notifyAll()
            }
        }
    }

    private val binderReceivedListener = Shizuku.OnBinderReceivedListener {
        lastHealthCheckMs = 0L
        bindIfPossible()
    }

    private val binderDeadListener = Shizuku.OnBinderDeadListener {
        synchronized(serviceLock) {
            service = null
            binding = false
            lastHealthResult = false
            lastHealthCheckMs = 0L
            serviceLock.notifyAll()
        }
    }

    private val permissionListener = Shizuku.OnRequestPermissionResultListener { requestCode, grantResult ->
        if (requestCode == REQUEST_CODE) {
            lastHealthCheckMs = 0L
            if (grantResult == PackageManager.PERMISSION_GRANTED) bindIfPossible()
        }
    }

    fun init(context: Context) {
        if (initialized) return
        synchronized(this) {
            if (initialized) return
            applicationContext = context.applicationContext
            Shizuku.addBinderReceivedListenerSticky(binderReceivedListener)
            Shizuku.addBinderDeadListener(binderDeadListener)
            Shizuku.addRequestPermissionResultListener(permissionListener)
            initialized = true
        }
    }

    fun isAvailable(): Boolean = initialized && runCatching { Shizuku.pingBinder() }.getOrDefault(false)

    fun hasPermission(): Boolean = isAvailable() && runCatching {
        Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
    }.getOrDefault(false)

    fun uid(): Int = if (isAvailable()) runCatching { Shizuku.getUid() }.getOrDefault(-1) else -1

    fun requestPermission() {
        if (!isAvailable()) return
        if (!hasPermission()) {
            Shizuku.requestPermission(REQUEST_CODE)
        } else {
            bindIfPossible()
        }
    }

    fun bindIfPossible() {
        if (!initialized || !hasPermission() || service != null || binding) return
        synchronized(serviceLock) {
            if (service != null || binding) return
            binding = true
            runCatching { Shizuku.bindUserService(userServiceArgs, serviceConnection) }
                .onFailure {
                    binding = false
                    serviceLock.notifyAll()
                }
        }
    }

    private fun awaitService(timeoutMs: Long = BIND_TIMEOUT_MS): IPrivilegedService? {
        service?.let { return it }
        bindIfPossible()
        val deadline = SystemClock.elapsedRealtime() + timeoutMs
        synchronized(serviceLock) {
            while (service == null && binding) {
                val remaining = deadline - SystemClock.elapsedRealtime()
                if (remaining <= 0L) break
                runCatching { serviceLock.wait(remaining) }
            }
            return service
        }
    }

    fun execute(command: String): String? {
        if (!hasPermission()) return null
        val remote = awaitService() ?: return null
        return runCatching { remote.execute(command) }
            .onFailure {
                synchronized(serviceLock) {
                    service = null
                    binding = false
                    lastHealthResult = false
                    lastHealthCheckMs = 0L
                }
            }
            .getOrNull()
    }

    fun isOperational(): Boolean {
        if (!hasPermission()) return false
        val now = SystemClock.elapsedRealtime()
        if (now - lastHealthCheckMs < HEALTH_CACHE_MS) return lastHealthResult
        synchronized(this) {
            val current = SystemClock.elapsedRealtime()
            if (current - lastHealthCheckMs < HEALTH_CACHE_MS) return lastHealthResult
            val output = execute("id 2>/dev/null")
            lastHealthResult = output?.contains("uid=") == true
            lastHealthCheckMs = current
            return lastHealthResult
        }
    }
}
