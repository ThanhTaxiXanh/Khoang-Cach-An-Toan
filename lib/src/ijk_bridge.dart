import 'package:flutter/services.dart';

/// Thin Flutter control plane; the actual RTP/H.264 frames stay in Android.
/// Video is rendered by the native SurfaceView owned by IJKPlayer.
class IjkBridge {
  static const MethodChannel _control =
      MethodChannel('vn.thanhtaxixanh.a500s/ijk_control');
  static const EventChannel _events =
      EventChannel('vn.thanhtaxixanh.a500s/ijk_events');

  static Stream<Map<String, dynamic>> get events => _events
      .receiveBroadcastStream()
      .where((dynamic event) => event is Map)
      .map((dynamic event) =>
          Map<String, dynamic>.from(event as Map));

  static Future<Map<String, dynamic>> wifiStatus() async {
    final result = await _control.invokeMapMethod<String, dynamic>('wifiStatus');
    return result ?? <String, dynamic>{};
  }

  /// Sends read-only RTSP OPTIONS/DESCRIBE to the camera over its Wi-Fi network.
  /// No authentication bypass or private control endpoint is involved.
  static Future<Map<String, dynamic>> probeRtsp(String url) async {
    final data = await _control.invokeMapMethod<String, dynamic>(
      'probeRtsp',
      <String, dynamic>{'url': url},
    );
    return data ?? <String, dynamic>{};
  }

  static Future<void> open({
    required int viewId,
    required String url,
    required String transport,
    required String profile,
  }) async {
    await _control.invokeMethod<void>('open', <String, dynamic>{
      'viewId': viewId,
      'url': url,
      'transport': transport,
      'profile': profile,
    });
  }

  static Future<void> close({required int viewId}) =>
      _control.invokeMethod<void>('close', <String, dynamic>{
        'viewId': viewId,
      });

  static Future<Map<String, dynamic>> stats(int viewId) async {
    final map = await _control.invokeMapMethod<String, dynamic>(
      'stats',
      <String, dynamic>{'viewId': viewId},
    );
    return map ?? <String, dynamic>{};
  }
}
