import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../models/telemetry_sample.dart';
import '../services/native_bridge.dart';
import '../services/rust_core.dart';
import '../services/session_recorder.dart';

class AppController extends ChangeNotifier with WidgetsBindingObserver {
  AppController()
      : rustCore = RustCore(),
        nativeBridge = NativeBridge() {
    recorder = SessionRecorder(rustCore);
  }

  final RustCore rustCore;
  final NativeBridge nativeBridge;
  late final SessionRecorder recorder;

  AccessMode accessMode = AccessMode.auto;
  TelemetrySample? latest;
  final List<TelemetrySample> history = [];
  Timer? _timer;
  bool _collecting = false;
  bool _syncingRecording = false;
  bool overlayRunning = false;
  bool monitorServiceRunning = false;
  bool usageAccess = false;
  bool overlayPermission = false;
  bool notificationPermission = false;
  bool shizukuAvailable = false;
  bool shizukuPermission = false;
  bool shizukuOperational = false;
  bool rootInstalled = false;
  bool rootAvailable = false;
  int shizukuUid = -1;
  int pageIndex = 0;
  String? lastError;

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);
    await refreshStatus();
    if (recorder.isRecording || recorder.totalCount > 0) {
      await _syncRecordedSamples(limit: 30);
    }
    await collectNow();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => collectNow());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _startTimer();
      unawaited(refreshStatus());
      unawaited(collectNow());
    } else {
      _timer?.cancel();
      _timer = null;
    }
  }

  Future<void> refreshStatus() async {
    try {
      final status = await nativeBridge.getStatus();
      usageAccess = status['usageAccess'] == true;
      overlayPermission = status['overlayPermission'] == true;
      notificationPermission = status['notificationPermission'] == true;
      shizukuAvailable = status['shizukuAvailable'] == true;
      shizukuPermission = status['shizukuPermission'] == true;
      shizukuOperational = status['shizukuOperational'] == true;
      rootInstalled = status['rootInstalled'] == true;
      rootAvailable = status['rootAvailable'] == true;
      shizukuUid = (status['shizukuUid'] as num?)?.toInt() ?? -1;
      overlayRunning = status['overlayRunning'] == true;
      monitorServiceRunning = status['monitorServiceRunning'] == true;
      recorder.restoreState(
        recording: status['recording'] == true,
        count: (status['recordedSampleCount'] as num?)?.toInt() ?? 0,
      );
      lastError = null;
      notifyListeners();
    } catch (error) {
      lastError = 'Status could not be refreshed. Tap refresh to retry.';
      notifyListeners();
    }
  }

  Future<void> collectNow() async {
    if (_collecting) return;
    _collecting = true;
    try {
      final native = await nativeBridge.collectSnapshot(accessMode.wireName);
      var sample = TelemetrySample.fromNative(native);
      final packageName = sample.foregroundPackage ?? '';
      final fpsParsed = rustCore.parseSurfaceFlinger(
        sample.surfaceFlingerRaw ?? '',
        packageName,
      );
      final gpuParsed = rustCore.parseGpu(
        sample.gpuRaw ?? '',
        sample.gpuModel ?? '',
      );
      sample = sample.mergeParsed(fpsData: fpsParsed, gpuData: gpuParsed);
      latest = sample;
      history.add(sample);
      if (history.length > 120) history.removeAt(0);
      if (recorder.isRecording) {
        await _syncRecordedSamples(limit: 30, notify: false);
      }
      lastError = null;
      notifyListeners();
    } catch (error) {
      lastError = 'Telemetry collection was interrupted. Retrying automatically.';
      notifyListeners();
    } finally {
      _collecting = false;
    }
  }

  void setAccessMode(AccessMode mode) {
    accessMode = mode;
    notifyListeners();
    unawaited(collectNow());
  }

  void setPage(int index) {
    pageIndex = index;
    notifyListeners();
  }

  Future<void> toggleRecording() async {
    try {
      if (recorder.isRecording) {
        await nativeBridge.stopRecording();
        recorder.stop();
        await _syncRecordedSamples();
      } else {
        recorder.start();
        await nativeBridge.startRecording(accessMode.wireName);
        await _syncRecordedSamples(limit: 30);
      }
      await refreshStatus();
    } catch (error) {
      lastError = '$error';
      notifyListeners();
    }
  }

  Future<String?> exportCsv() async {
    await _syncRecordedSamples();
    final csv = recorder.createCsv();
    final stamp = _fileStamp(DateTime.now());
    return nativeBridge.saveBytes(
      bytes: Uint8List.fromList(utf8.encode(csv)),
      fileName: 'FPSWatcher-session-$stamp.csv',
      mimeType: 'text/csv',
    );
  }

  Future<String?> exportPng(Uint8List bytes) {
    final stamp = _fileStamp(DateTime.now());
    return nativeBridge.saveBytes(
      bytes: bytes,
      fileName: 'FPSWatcher-dashboard-$stamp.png',
      mimeType: 'image/png',
    );
  }

  Future<void> toggleOverlay() async {
    try {
      if (overlayRunning) {
        await nativeBridge.stopOverlay();
      } else {
        await nativeBridge.startOverlay(accessMode.wireName);
      }
      await Future<void>.delayed(const Duration(milliseconds: 150));
      await refreshStatus();
    } catch (error) {
      lastError = '$error';
      notifyListeners();
    }
  }

  Future<void> requestUsageAccess() async {
    await nativeBridge.openUsageSettings();
  }

  Future<void> requestOverlayPermission() async {
    await nativeBridge.openOverlaySettings();
  }

  Future<void> requestNotificationPermission() async {
    await nativeBridge.requestNotificationPermission();
    await refreshStatus();
  }

  Future<void> requestShizukuPermission() async {
    if (!shizukuAvailable) {
      await nativeBridge.openShizuku();
    } else {
      await nativeBridge.requestShizukuPermission();
    }
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await refreshStatus();
  }

  Future<void> _syncRecordedSamples({
    int? limit,
    bool notify = true,
  }) async {
    if (_syncingRecording) return;
    _syncingRecording = true;
    try {
      final batch = await nativeBridge.getRecordedSamples(limit: limit);
      final rawSamples = (batch['samples'] as List<dynamic>? ?? const [])
          .whereType<Map<dynamic, dynamic>>();
      final samples = rawSamples
          .map(TelemetrySample.fromNative)
          .toList(growable: false);
      recorder.replaceSamples(
        samples,
        totalCount: (batch['totalCount'] as num?)?.toInt() ?? samples.length,
        recording: batch['recording'] == true,
      );
      if (notify) notifyListeners();
    } finally {
      _syncingRecording = false;
    }
  }

  String _fileStamp(DateTime time) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${time.year}${two(time.month)}${two(time.day)}-'
        '${two(time.hour)}${two(time.minute)}${two(time.second)}';
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }
}
