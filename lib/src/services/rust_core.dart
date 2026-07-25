import 'dart:convert';
import 'dart:ffi';
import 'package:ffi/ffi.dart';

final class RustCore {
  RustCore() {
    try {
      final library = DynamicLibrary.open('libfpswatcher_core.so');
      _parseSurfaceFlinger = library.lookupFunction<_ParseNative, _ParseDart>(
        'gw_parse_surfaceflinger',
      );
      _parseGpu = library.lookupFunction<_ParseNative, _ParseDart>('gw_parse_gpu');
      _sessionCsv = library.lookupFunction<_OneNative, _OneDart>('gw_session_csv');
      _free = library.lookupFunction<_FreeNative, _FreeDart>('gw_free_string');
      available = true;
    } catch (_) {
      available = false;
    }
  }

  late final _ParseDart _parseSurfaceFlinger;
  late final _ParseDart _parseGpu;
  late final _OneDart _sessionCsv;
  late final _FreeDart _free;
  late final bool available;

  Map<String, dynamic>? parseSurfaceFlinger(String raw, String packageName) {
    if (!available || raw.trim().isEmpty) return null;
    final result = _callTwo(_parseSurfaceFlinger, raw, packageName);
    if (result == null || result.isEmpty) return null;
    final decoded = jsonDecode(result);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  Map<String, dynamic>? parseGpu(String raw, String fallbackModel) {
    if (!available || raw.trim().isEmpty) return null;
    final result = _callTwo(_parseGpu, raw, fallbackModel);
    if (result == null || result.isEmpty) return null;
    final decoded = jsonDecode(result);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  String? sessionCsv(List<Map<String, dynamic>> samples) {
    if (!available) return null;
    final input = jsonEncode(samples);
    final pointer = input.toNativeUtf8();
    try {
      final output = _sessionCsv(pointer);
      if (output == nullptr) return null;
      try {
        return output.toDartString();
      } finally {
        _free(output);
      }
    } finally {
      calloc.free(pointer);
    }
  }

  String? _callTwo(_ParseDart function, String first, String second) {
    final a = first.toNativeUtf8();
    final b = second.toNativeUtf8();
    try {
      final output = function(a, b);
      if (output == nullptr) return null;
      try {
        return output.toDartString();
      } finally {
        _free(output);
      }
    } finally {
      calloc.free(a);
      calloc.free(b);
    }
  }
}

typedef _ParseNative = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _ParseDart = Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _OneNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _OneDart = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _FreeNative = Void Function(Pointer<Utf8>);
typedef _FreeDart = void Function(Pointer<Utf8>);
