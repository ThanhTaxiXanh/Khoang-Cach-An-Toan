import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_a500s_player/src/stream_config.dart';

// Keep this file in Git: flutter create otherwise generates its starter MyApp test.
void main() {
  test('A500S stream configuration has a valid default', () {
    const config = StreamConfig(host: '192.168.0.1');
    expect(config.validationError, isNull);
    expect(config.path, '/livestream/12');
  });
}
