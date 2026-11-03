import 'package:flutter/services.dart';

class WifiStatus {
  const WifiStatus({
    required this.available,
    required this.gateway,
    required this.bound,
  });

  final bool available;
  final String? gateway;
  final bool bound;

  factory WifiStatus.fromMap(Map<dynamic, dynamic> map) => WifiStatus(
        available: map['available'] == true,
        gateway: map['gateway'] as String?,
        bound: map['bound'] == true,
      );
}

/// Keeps local camera packets on Wi-Fi even if Android uses cellular for Internet.
/// Android-only; the app never scans, joins, or authenticates the Wi-Fi network.
class WifiBridge {
  static const MethodChannel _channel =
      MethodChannel('vn.thanhtaxixanh.a500s/network');

  static Future<WifiStatus> status() async {
    final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('status');
    return WifiStatus.fromMap(result ?? <dynamic, dynamic>{});
  }

  static Future<bool> bind() async =>
      (await _channel.invokeMethod<bool>('bindWifi')) ?? false;

  static Future<void> unbind() async =>
      _channel.invokeMethod<void>('unbindWifi');

  static Future<void> keepAwake(bool enabled) async =>
      _channel.invokeMethod<void>(
        'keepAwake',
        <String, dynamic>{'enabled': enabled},
      );
}
