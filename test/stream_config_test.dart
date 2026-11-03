import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_a500s_player/src/stream_config.dart';

void main() {
  test('Default A500S RTSP candidate is constructed correctly', () {
    const config = StreamConfig(host: '192.168.0.1');
    expect(config.url, 'rtsp://192.168.0.1:554/livestream/12');
    expect(config.validationError, isNull);
  });

  test('Path without slash is normalized', () {
    const config = StreamConfig(
      host: '192.168.0.1',
      path: 'livestream/12',
      port: 8554,
    );
    expect(config.url, 'rtsp://192.168.0.1:8554/livestream/12');
  });

  test('Invalid host, port and path are rejected', () {
    expect(const StreamConfig(host: '').validationError, isNotNull);
    expect(const StreamConfig(host: '192.168.0.1/something')
        .validationError, isNotNull);
    expect(const StreamConfig(host: '192.168.0.1', port: 0)
        .validationError, isNotNull);
    expect(const StreamConfig(host: '192.168.0.1', path: '/')
        .validationError, isNotNull);
  });

  test('Preset caching is ordered by stability', () {
    expect(PlaybackProfile.lowLatency.cacheMs,
        lessThan(PlaybackProfile.balanced.cacheMs));
    expect(PlaybackProfile.balanced.cacheMs,
        lessThan(PlaybackProfile.smooth.cacheMs));
  });
}
