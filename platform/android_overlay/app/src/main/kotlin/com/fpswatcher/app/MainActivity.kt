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
                val mode = call.argument<String>("mode") ?: "auto"
                executor.execute {
                    runCatching { collector.collect(mode) }
                        .onSuccess { data -> runOnUiThread { result.success(data) } }
                        .onFailure { error ->
                            runOnUiThread { result.error("collect_failed", error.message, null) }
                        }
                }
            }

            "getStatus" -> executor.execute {
                runCatching { collector.status() }
                    .onSuccess { data -> runOnUiThread { result.success(data) } }
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
                val mode = call.argument<String>("mode") ?: "auto"
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
                val mode = call.argument<String>("mode") ?: "auto"
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

            "getRecordedSamples" -> {
                val limit = call.argument<Int>("limit")
                executor.execute {
                    val batch = hashMapOf<String, Any?>(
                        "samples" to NativeSessionStore.snapshot(limit),
                        "totalCount" to NativeSessionStore.count(),
                        "recording" to NativeSessionStore.isRecording,
                    )
                    runOnUiThread { result.success(batch) }
                }
            }

            "saveBytes" -> saveBytes(call, result)
            else -> result.notImplemented()
        }
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
        executor.shutdownNow()
        super.onDestroy()
    }

    private data class PendingExport(
        val bytes: ByteArray,
        val result: MethodChannel.Result,
    )

    companion object {
        private const val CHANNEL = "fpswatcher/native"
        private const val EXPORT_REQUEST_CODE = 4421
    }
}
