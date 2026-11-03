import 'package:flutter_test/flutter_test.dart';
import 'package:ttx_a500s_player/src/live_diagnostics.dart';

void main() {
  test('empty player samples summarize without errors', () {
    final summary = LiveSummary.fromSamples(const []);
    expect(summary.count, 0);
    expect(summary.p95CacheMs, 0);
    expect(summary.avgDecodeFps, 0);
  });

  test('decoder samples preserve FPS and native queue measurements', () {
    final t = DateTime(2026, 11, 3);
    final s = LiveSample.fromNative(t, {
      'decodeFps': 29.5,
      'outputFps': 30,
      'cachedMs': 160,
      'cachedPackets': 7,
      'currentSession': 3,
    });
    expect(s.outputFps, 30);
    expect(s.cachedPackets, 7);
    expect(s.sessionId, 3);
    expect(s.cachedMs, 160);
    expect(s.time, t);
  });

  test('FPS averages and P95 queue statistics', () {
    final t = DateTime(2026, 11, 3);
    final a = [
      LiveSample(time: t, decodeFps: 30, outputFps: 29, cachedMs: 100, cachedPackets: 2),
      LiveSample(time: t, decodeFps: 30, outputFps: 30, cachedMs: 200, cachedPackets: 3),
      LiveSample(time: t, decodeFps: 0, outputFps: 0, cachedMs: 400, cachedPackets: 5),
    ];
    final x = LiveSummary.fromSamples(a);
    expect(x.count, 3);
    expect(x.avgOutputFps, closeTo(19.6667, 0.001));
    expect(x.avgDecodeFps, 20);
    expect(x.maxCacheMs, 400);
    expect(x.p95CacheMs, 400);
    expect(x.lowOutputSamples, 1);
  });
}
