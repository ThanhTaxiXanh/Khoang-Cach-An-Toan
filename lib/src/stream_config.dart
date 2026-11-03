/// A500S candidates must be verified against the actual device/firmware.
enum PlaybackProfile {
  lowLatency('Độ trễ thấp', 200),
  balanced('Cân bằng', 450),
  smooth('Ưu tiên mượt', 900);

  const PlaybackProfile(this.label, this.cacheMs);

  final String label;
  final int cacheMs;
}

class StreamConfig {
  const StreamConfig({
    required this.host,
    this.port = 554,
    this.path = '/livestream/12',
    this.tcp = true,
    this.profile = PlaybackProfile.balanced,
  });

  final String host;
  final int port;
  final String path;
  final bool tcp;
  final PlaybackProfile profile;

  String get url => Uri(
        scheme: 'rtsp',
        host: host.trim(),
        port: port,
        path: normalizedPath,
      ).toString();

  String get normalizedPath =>
      path.trim().startsWith('/') ? path.trim() : '/${path.trim()}';

  String? get validationError {
    final name = host.trim();
    if (name.isEmpty) return 'Nhập IP hoặc hostname của camera.';
    if (name.contains(RegExp(r'[/\\\s:@?#]'))) {
      return 'Host không hợp lệ (không chứa URL hoặc ký tự đặc biệt).';
    }
    if (Uri.tryParse('rtsp://$name')?.host.isEmpty ?? true) {
      return 'Địa chỉ camera không hợp lệ.';
    }
    if (port < 1 || port > 65535) return 'Cổng phải từ 1 đến 65535.';
    if (!normalizedPath.startsWith('/') ||
        normalizedPath.contains(' ') ||
        normalizedPath.contains('?') ||
        normalizedPath.contains('#') ||
        normalizedPath == '/') {
      return 'Đường dẫn RTSP không hợp lệ.';
    }
    return null;
  }

  StreamConfig copyWith({
    String? host,
    int? port,
    String? path,
    bool? tcp,
    PlaybackProfile? profile,
  }) =>
      StreamConfig(
        host: host ?? this.host,
        port: port ?? this.port,
        path: path ?? this.path,
        tcp: tcp ?? this.tcp,
        profile: profile ?? this.profile,
      );
}
