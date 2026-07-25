package com.fpswatcher.app.shizuku

import android.content.ComponentName
import android.content.Context
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.IBinder
import com.fpswatcher.app.BuildConfig
import rikka.shizuku.Shizuku

object ShizukuClient {
    private const val REQUEST_CODE = 4317
    @Volatile private var service: IPrivilegedService? = null
    @Volatile private var initialized = false
    @Volatile private var binding = false
    private lateinit var applicationContext: Context

    private val userServiceArgs by lazy {
        Shizuku.UserServiceArgs(
            ComponentName(applicationContext, PrivilegedService::class.java)
        )
            .daemon(false)
            .tag("fpswatcher-privileged-v1")
            .version(1)
            .debuggable(BuildConfig.DEBUG)
            .processNameSuffix("fpswatcher")
    }

    private val serviceConnection = object : ServiceConnection {
        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
            service = IPrivilegedService.Stub.asInterface(binder)
            binding = false
        }

        override fun onServiceDisconnected(name: ComponentName?) {
            service = null
            binding = false
        }
    }

    private val binderReceivedListener = Shizuku.OnBinderReceivedListener {
        bindIfPossible()
    }

    private val binderDeadListener = Shizuku.OnBinderDeadListener {
        service = null
        binding = false
    }

    private val permissionListener = Shizuku.OnRequestPermissionResultListener { requestCode, grantResult ->
        if (requestCode == REQUEST_CODE && grantResult == PackageManager.PERMISSION_GRANTED) {
            bindIfPossible()
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

    fun isAvailable(): Boolean = runCatching { Shizuku.pingBinder() }.getOrDefault(false)

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
        binding = true
        runCatching { Shizuku.bindUserService(userServiceArgs, serviceConnection) }
            .onFailure { binding = false }
    }

    fun execute(command: String): String? {
        bindIfPossible()
        val remote = service ?: return null
        return runCatching { remote.execute(command) }
            .onFailure { service = null }
            .getOrNull()
    }
}
