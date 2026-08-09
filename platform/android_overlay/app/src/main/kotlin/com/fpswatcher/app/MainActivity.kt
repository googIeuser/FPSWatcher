package com.fpswatcher.app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import androidx.annotation.NonNull
import com.fpswatcher.app.shizuku.ShizukuClient
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val executor = Executors.newSingleThreadExecutor()
    private lateinit var collector: TelemetryCollector
    private var pendingExport: PendingExport? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ShizukuClient.init(applicationContext)
        NativeSessionStore.init(applicationContext)
        collector = TelemetryCollector(applicationContext)
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result -> handleCall(call, result) }
    }

    private fun handleCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "collectSnapshot" -> {
                val mode = call.argument<String>("mode") ?: "shizuku"
                executor.execute {
                    runCatching {
                        TelemetrySnapshotCache.get(mode, 90L)
                            ?: collector.collect(mode).also { TelemetrySnapshotCache.put(mode, it) }
                    }
                        .onSuccess { data -> runOnUiThread { result.success(FlutterChannelValue.sanitize(data)) } }
                        .onFailure { error ->
                            runOnUiThread {
                                result.error(
                                    "collect_failed",
                                    error.message ?: error.javaClass.simpleName,
                                    null,
                                )
                            }
                        }
                }
            }

            "getAccessMode" -> {
                val saved = getSharedPreferences(APP_PREFERENCES, MODE_PRIVATE)
                    .getString(KEY_ACCESS_MODE, "shizuku")
                    ?.takeIf { it == "root" || it == "shizuku" }
                    ?: "shizuku"
                result.success(saved)
            }

            "setAccessMode" -> {
                val mode = call.argument<String>("mode")
                    ?.takeIf { it == "root" || it == "shizuku" }
                    ?: "shizuku"
                getSharedPreferences(APP_PREFERENCES, MODE_PRIVATE)
                    .edit()
                    .putString(KEY_ACCESS_MODE, mode)
                    .apply()
                TelemetrySnapshotCache.clear()
                result.success(null)
            }

            "getStatus" -> executor.execute {
                runCatching { collector.status() }
                    .onSuccess { data -> runOnUiThread { result.success(FlutterChannelValue.sanitize(data)) } }
                    .onFailure { error ->
                        runOnUiThread { result.error("status_failed", error.message, null) }
                    }
            }

            "openUsageSettings" -> {
                startActivity(
                    Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                )
                result.success(null)
            }

            "openOverlaySettings" -> {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName"),
                )
                startActivity(intent)
                result.success(null)
            }

            "requestNotificationPermission" -> {
                if (
                    Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                    checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
                    PackageManager.PERMISSION_GRANTED
                ) {
                    requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 993)
                }
                result.success(null)
            }

            "requestRootPermission" -> executor.execute {
                val granted = RootShell.requestAccess()
                runOnUiThread { result.success(granted) }
            }

            "requestShizukuPermission" -> {
                ShizukuClient.requestPermission()
                result.success(null)
            }

            "openShizuku" -> {
                val launchIntent =
                    packageManager.getLaunchIntentForPackage("moe.shizuku.privileged.api")
                if (launchIntent != null) {
                    startActivity(launchIntent)
                    result.success(null)
                } else {
                    result.error("shizuku_missing", "Shizuku is not installed.", null)
                }
            }

            "startOverlay" -> {
                if (!Settings.canDrawOverlays(this)) {
                    result.error(
                        "overlay_permission",
                        "Display over other apps permission is required.",
                        null,
                    )
                    return
                }
                val mode = call.argument<String>("mode") ?: "shizuku"
                executor.execute {
                    val operational = backendOperational(mode)
                    val error = if (operational) null else backendError(mode)
                    runOnUiThread {
                        if (!operational) {
                            result.error("backend_unavailable", error, null)
                            return@runOnUiThread
                        }
                        startMonitorService(
                            Intent(this, OverlayService::class.java)
                                .putExtra(OverlayService.EXTRA_MODE, mode)
                                .putExtra(
                                    OverlayService.EXTRA_OVERLAY_ACTION,
                                    OverlayService.OVERLAY_SHOW,
                                ),
                        )
                        result.success(null)
                    }
                }
            }

            "stopOverlay" -> {
                startMonitorService(
                    Intent(this, OverlayService::class.java)
                        .putExtra(
                            OverlayService.EXTRA_OVERLAY_ACTION,
                            OverlayService.OVERLAY_HIDE,
                        ),
                )
                result.success(null)
            }

            "startRecording" -> {
                val mode = call.argument<String>("mode") ?: "shizuku"
                executor.execute {
                    val operational = backendOperational(mode)
                    val error = if (operational) null else backendError(mode)
                    runOnUiThread {
                        if (!operational) {
                            result.error("backend_unavailable", error, null)
                            return@runOnUiThread
                        }
                        NativeSessionStore.start()
                        startMonitorService(
                            Intent(this, OverlayService::class.java)
                                .putExtra(OverlayService.EXTRA_MODE, mode)
                                .putExtra(
                                    OverlayService.EXTRA_RECORDING_ACTION,
                                    OverlayService.RECORDING_START,
                                ),
                        )
                        result.success(null)
                    }
                }
            }

            "stopRecording" -> {
                NativeSessionStore.stop()
                startMonitorService(
                    Intent(this, OverlayService::class.java)
                        .putExtra(
                            OverlayService.EXTRA_RECORDING_ACTION,
                            OverlayService.RECORDING_STOP,
                        ),
                )
                result.success(null)
            }

            "addSessionMarker" -> {
                val label = call.argument<String>("label").orEmpty()
                NativeSessionStore.addMarker(label)
                result.success(null)
            }

            "getRecordedSamples" -> {
                val limit = call.argument<Int>("limit")
                val offset = call.argument<Int>("offset")
                executor.execute {
                    val samples = if (offset == null) {
                        NativeSessionStore.snapshot(limit)
                    } else {
                        NativeSessionStore.snapshotPage(offset, limit ?: 1_000)
                    }
                    val batch = hashMapOf<String, Any?>(
                        "samples" to samples,
                        "totalCount" to NativeSessionStore.count(),
                        "recording" to NativeSessionStore.isRecording,
                        "offset" to (offset ?: 0),
                    )
                    runOnUiThread { result.success(FlutterChannelValue.sanitize(batch)) }
                }
            }

            "getOverlayPreferences" -> {
                result.success(FlutterChannelValue.sanitize(OverlayPreferences.snapshot(applicationContext)))
            }

            "setOverlayPreferences" -> {
                @Suppress("UNCHECKED_CAST")
                OverlayPreferences.update(applicationContext, call.arguments as? Map<*, *> ?: emptyMap<Any, Any>())
                result.success(null)
            }

            "resetOverlayPosition" -> {
                OverlayPreferences.resetPosition(applicationContext)
                startMonitorService(
                    Intent(this, OverlayService::class.java)
                        .putExtra(
                            OverlayService.EXTRA_OVERLAY_ACTION,
                            OverlayService.OVERLAY_RESET_POSITION,
                        ),
                )
                result.success(null)
            }

            "saveBytes" -> saveBytes(call, result)
            else -> result.notImplemented()
        }
    }

    private fun backendOperational(mode: String): Boolean = when (mode.lowercase()) {
        "root" -> RootShell.isAvailable()
        else -> ShizukuClient.hasPermission() && ShizukuClient.isOperational()
    }

    private fun backendError(mode: String): String = when (mode.lowercase()) {
        "root" -> RootShell.lastError ?: "Root access is unavailable or denied."
        else -> ShizukuClient.lastError ?: "Shizuku UserService is unavailable."
    }

    private fun startMonitorService(intent: Intent) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun saveBytes(call: MethodCall, result: MethodChannel.Result) {
        if (pendingExport != null) {
            result.error("export_busy", "Another export is already open.", null)
            return
        }
        val bytes = call.argument<ByteArray>("bytes")
        val fileName = call.argument<String>("fileName")
        val mimeType = call.argument<String>("mimeType")
        if (bytes == null || fileName.isNullOrBlank() || mimeType.isNullOrBlank()) {
            result.error("invalid_export", "Missing export data.", null)
            return
        }
        pendingExport = PendingExport(bytes, result)
        val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType
            putExtra(Intent.EXTRA_TITLE, fileName)
        }
        startActivityForResult(intent, EXPORT_REQUEST_CODE)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != EXPORT_REQUEST_CODE) return
        val pending = pendingExport ?: return
        pendingExport = null
        if (resultCode != RESULT_OK || data?.data == null) {
            pending.result.error("export_cancelled", "Export was cancelled.", null)
            return
        }
        val uri = data.data!!
        runCatching {
            contentResolver.openOutputStream(uri, "w")?.use { stream ->
                stream.write(pending.bytes)
                stream.flush()
            } ?: error("Unable to open output stream")
        }.onSuccess {
            pending.result.success(uri.toString())
        }.onFailure { error ->
            pending.result.error("export_failed", error.message, null)
        }
    }

    override fun onDestroy() {
        runCatching { collector.close() }
        executor.shutdownNow()
        super.onDestroy()
    }

    private data class PendingExport(
        val bytes: ByteArray,
        val result: MethodChannel.Result,
    )

    companion object {
        private const val CHANNEL = "fpswatcher/native"
        private const val APP_PREFERENCES = "fpswatcher_app"
        private const val KEY_ACCESS_MODE = "access_mode"
        private const val EXPORT_REQUEST_CODE = 4421
    }
}
