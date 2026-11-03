enum PlaybackProfile {
  lowLatency('Ưu tiên độ trễ thấp', 'low'),
  balanced('Cân bằng', 'balanced'),
  smooth('Ưu tiên ổn định', 'smooth');

  const PlaybackProfile(this.label, this.value);
  final String label;
  final String value;
}

enum RtspTransport {
  tcp('TCP · truyền tin cậy', 'tcp'),
  udp('UDP · thử khi TCP không phù hợp', 'udp');

  const RtspTransport(this.label, this.value);
  final String label;
  final String value;
}

class StreamConfig {
  const StreamConfig({
    required this.host,
    this.port = 554,
    this.path = '/livestream/12',
    this.transport = RtspTransport.tcp,
    this.profile = PlaybackProfile.balanced,
  });

  final String host;
  final int port;
  final String path;
  final RtspTransport transport;
  final PlaybackProfile profile;

  String get normalizedPath =>
      path.startsWith('/') ? path.trim() : '/${path.trim()}';

  String get url => Uri(
        scheme: 'rtsp',
        host: host.trim(),
        port: port,
        path: normalizedPath,
      ).toString();

  String? get validationError {
    final h = host.trim();
    if (h.isEmpty || h.contains(RegExp(r'[/\\\s:@?#]'))) {
      return 'IP camera phải là địa chỉ IP hoặc hostname hợp lệ.';
    }
    if (Uri.tryParse('rtsp://$h')?.host.isEmpty ?? true) {
      return 'Không phân tích được địa chỉ camera.';
    }
    if (port < 1 || port > 65535) return 'Cổng RTSP phải từ 1 đến 65535.';
    if (normalizedPath == '/' ||
        normalizedPath.contains(' ') ||
        normalizedPath.contains('?') ||
        normalizedPath.contains('#')) {
      return 'Đường dẫn RTSP không hợp lệ.';
    }
    return null;
  }
}
