import 'package:flutter/services.dart';

class NativeBridge {
  static const MethodChannel _channel = MethodChannel('fpswatcher/native');

  Future<Map<dynamic, dynamic>> collectSnapshot(String mode) async {
    return (await _channel.invokeMethod<Map<dynamic, dynamic>>(
          'collectSnapshot',
          {'mode': mode},
        )) ??
        <dynamic, dynamic>{};
  }


  Future<String> getAccessMode() async =>
      (await _channel.invokeMethod<String>('getAccessMode')) ?? 'shizuku';

  Future<void> setAccessMode(String mode) =>
      _channel.invokeMethod('setAccessMode', {'mode': mode});

  Future<Map<dynamic, dynamic>> getStatus() async {
    return (await _channel.invokeMethod<Map<dynamic, dynamic>>('getStatus')) ??
        <dynamic, dynamic>{};
  }

  Future<void> openUsageSettings() =>
      _channel.invokeMethod('openUsageSettings');
  Future<void> openOverlaySettings() =>
      _channel.invokeMethod('openOverlaySettings');
  Future<void> requestNotificationPermission() =>
      _channel.invokeMethod('requestNotificationPermission');
  Future<bool> requestRootPermission() async =>
      (await _channel.invokeMethod<bool>('requestRootPermission')) ?? false;
  Future<void> requestShizukuPermission() =>
      _channel.invokeMethod('requestShizukuPermission');
  Future<void> openShizuku() => _channel.invokeMethod('openShizuku');

  Future<void> startOverlay(String mode) =>
      _channel.invokeMethod('startOverlay', {'mode': mode});
  Future<void> stopOverlay() => _channel.invokeMethod('stopOverlay');

  Future<Map<dynamic, dynamic>> getOverlayPreferences() async {
    return (await _channel.invokeMethod<Map<dynamic, dynamic>>(
          'getOverlayPreferences',
        )) ??
        <dynamic, dynamic>{};
  }

  Future<void> setOverlayPreferences(Map<String, dynamic> preferences) =>
      _channel.invokeMethod('setOverlayPreferences', preferences);

  Future<void> resetOverlayPosition() =>
      _channel.invokeMethod('resetOverlayPosition');

  Future<void> startRecording(String mode) =>
      _channel.invokeMethod('startRecording', {'mode': mode});
  Future<void> stopRecording() => _channel.invokeMethod('stopRecording');
  Future<void> addSessionMarker(String label) =>
      _channel.invokeMethod('addSessionMarker', {'label': label});

  Future<Map<dynamic, dynamic>> getRecordedSamples({int? limit, int? offset}) async {
    final arguments = <String, dynamic>{
      if (limit != null) 'limit': limit,
      if (offset != null) 'offset': offset,
    };
    final result = await _channel.invokeMapMethod<dynamic, dynamic>(
      'getRecordedSamples',
      arguments.isEmpty ? null : arguments,
    );
    return result ?? <dynamic, dynamic>{};
  }

  Future<String?> saveBytes({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
  }) {
    return _channel.invokeMethod<String>('saveBytes', {
      'bytes': bytes,
      'fileName': fileName,
      'mimeType': mimeType,
    });
  }
}
