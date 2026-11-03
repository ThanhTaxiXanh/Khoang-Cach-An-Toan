import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_a500s_player/src/stream_config.dart';

void main() {
  test('Expected RTSP candidate from 70mai static analysis', () {
    const c = StreamConfig(host: '192.168.0.1');
    expect(c.url, 'rtsp://192.168.0.1:554/livestream/12');
    expect(c.validationError, isNull);
  });

  test('Path normalization and non-default port', () {
    const c = StreamConfig(
      host: '192.168.0.1',
      port: 8554,
      path: 'livestream/12',
    );
    expect(c.url, 'rtsp://192.168.0.1:8554/livestream/12');
  });

  test('Reject incorrect inputs before native connection', () {
    expect(const StreamConfig(host: '').validationError, isNotNull);
    expect(
      const StreamConfig(host: '192.168.0.1/bad').validationError,
      isNotNull,
    );
    expect(
      const StreamConfig(host: '192.168.0.1', port: 0).validationError,
      isNotNull,
    );
    expect(
      const StreamConfig(host: '192.168.0.1', path: '/').validationError,
      isNotNull,
    );
  });

  test('Profiles have stable serializable names', () {
    expect(PlaybackProfile.balanced.value, 'balanced');
    expect(RtspTransport.tcp.value, 'tcp');
  });
}
