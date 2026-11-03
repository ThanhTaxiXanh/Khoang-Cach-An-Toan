/// Sampled player metrics are not a sensor-to-screen latency measurement.
class LiveSample {
  const LiveSample({
    required this.time,
    required this.decodeFps,
    required this.outputFps,
    required this.cachedMs,
    required this.cachedPackets,
    this.sessionId = 0,
  });

  final DateTime time;
  final double decodeFps;
  final double outputFps;
  final int cachedMs;
  final int cachedPackets;
  final int sessionId;

  factory LiveSample.fromNative(
    DateTime time,
    Map<String, dynamic> stats,
  ) {
    double asDouble(String key) => (stats[key] as num?)?.toDouble() ?? 0;
    int asInt(String key) => (stats[key] as num?)?.toInt() ?? 0;
    return LiveSample(
      time: time,
      decodeFps: asDouble('decodeFps'),
      outputFps: asDouble('outputFps'),
      cachedMs: asInt('cachedMs'),
      cachedPackets: asInt('cachedPackets'),
      sessionId: asInt('currentSession'),
    );
  }
}

class LiveSummary {
  const LiveSummary({
    required this.count,
    required this.avgOutputFps,
    required this.avgDecodeFps,
    required this.maxCacheMs,
    required this.p95CacheMs,
    required this.lowOutputSamples,
  });

  final int count;
  final double avgOutputFps;
  final double avgDecodeFps;
  final int maxCacheMs;
  final int p95CacheMs;
  final int lowOutputSamples;

  static LiveSummary fromSamples(List<LiveSample> samples) {
    if (samples.isEmpty) {
      return const LiveSummary(
        count: 0,
        avgOutputFps: 0,
        avgDecodeFps: 0,
        maxCacheMs: 0,
        p95CacheMs: 0,
        lowOutputSamples: 0,
      );
    }
    final sorted = samples.map((s) => s.cachedMs).toList()..sort();
    final p95Index = ((sorted.length - 1) * 0.95).ceil();
    return LiveSummary(
      count: samples.length,
      avgOutputFps:
          samples.fold<double>(0, (a, s) => a + s.outputFps) / samples.length,
      avgDecodeFps:
          samples.fold<double>(0, (a, s) => a + s.decodeFps) / samples.length,
      maxCacheMs: sorted.last,
      p95CacheMs: sorted[p95Index],
      lowOutputSamples: samples.where((s) => s.outputFps < 0.5).length,
    );
  }
}
