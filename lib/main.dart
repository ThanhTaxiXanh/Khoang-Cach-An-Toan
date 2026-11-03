import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

import 'src/stream_config.dart';
import 'src/vlc_profile.dart';
import 'src/wifi_bridge.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const A500SApp());
}

class A500SApp extends StatelessWidget {
  const A500SApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'TTX 70mai Live',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF008F76),
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const LivePage(),
      );
}

class LivePage extends StatefulWidget {
  const LivePage({super.key});

  @override
  State<LivePage> createState() => _LivePageState();
}

class _LivePageState extends State<LivePage> {
  final TextEditingController _host = TextEditingController(text: '192.168.0.1');
  final TextEditingController _port = TextEditingController(text: '554');
  final TextEditingController _path =
      TextEditingController(text: '/livestream/12');

  VlcPlayerController? _player;
  VoidCallback? _playerListener;
  Timer? _watchdog;
  Timer? _retryTimer;
  DateTime? _openedAt;
  DateTime? _bufferedSince;
  DateTime? _nonPlayingSince;
  DateTime? _healthySince;
  PlaybackProfile _profile = PlaybackProfile.balanced;
  bool _tcp = true;
  bool _wantPlay = false;
  bool _starting = false;
  bool _playing = false;
  bool _buffering = false;
  int _generation = 0;
  int _retryCount = 0;
  int _bufferEvents = 0;
  int _reconnections = 0;
  Duration _bufferTotal = Duration.zero;
  String _message = 'Kết nối Wi-Fi A500S rồi nhấn Phát trực tiếp.';
  String _wifiHint = 'Chưa kiểm tra Wi-Fi';

  @override
  void initState() {
    super.initState();
    _watchdog = Timer.periodic(
      const Duration(seconds: 1),
      (_) => _watch(),
    );
    unawaited(_checkWifi());
  }

  Future<void> _checkWifi() async {
    try {
      final status = await WifiBridge.status();
      if (!mounted) return;
      setState(() {
        _wifiHint = status.available
            ? 'Wi-Fi đã kết nối · Gateway: ${status.gateway ?? 'không rõ'}'
            : 'Chưa thấy kết nối Wi-Fi. Mở Cài đặt để nối A500S.';
      });
    } catch (_) {
      if (mounted) setState(() => _wifiHint = 'Không đọc được trạng thái Wi-Fi.');
    }
  }

  StreamConfig? _config() {
    final parsedPort = int.tryParse(_port.text.trim());
    if (parsedPort == null) {
      setState(() => _message = 'Cổng RTSP phải là số.');
      return null;
    }
    final config = StreamConfig(
      host: _host.text,
      port: parsedPort,
      path: _path.text,
      tcp: _tcp,
      profile: _profile,
    );
    final err = config.validationError;
    if (err != null) {
      setState(() => _message = err);
      return null;
    }
    return config;
  }

  Future<void> _start({bool reconnect = false}) async {
    final config = _config();
    if (config == null || _starting) return;
    _wantPlay = true;
    _retryTimer?.cancel();
    _retryTimer = null;
    final ticket = ++_generation;

    setState(() {
      _starting = true;
      _playing = false;
      _buffering = false;
      _message = reconnect ? 'Đang khôi phục kết nối...' : 'Đang kết nối...';
    });

    try {
      if (!await WifiBridge.bind()) {
        throw StateError(
          'Không tìm thấy Wi-Fi. Kết nối điện thoại với hotspot 70mai A500S.',
        );
      }
      await WifiBridge.keepAwake(true);
      final old = _player;
      if (old != null && _playerListener != null) {
        old.removeListener(_playerListener!);
      }
      _player = null;
      _playerListener = null;
      if (old != null) await old.dispose();
      if (!mounted || !_wantPlay || ticket != _generation) return;

      final controller = VlcPlayerController.network(
        config.url,
        hwAcc: HwAcc.auto,
        autoPlay: true,
        options: buildVlcOptions(config),
      );
      void listener() => _onPlayerValue(controller, ticket);
      _player = controller;
      _playerListener = listener;
      controller.addListener(listener);
      _openedAt = DateTime.now();
      _bufferedSince = null;
      _nonPlayingSince = _openedAt;
      _healthySince = null;
      if (mounted) {
        setState(() {
          _starting = false;
          _message = 'Đang chờ luồng video từ ${config.url}';
        });
      }
      await _checkWifi();
    } catch (error) {
      if (!mounted || !_wantPlay || ticket != _generation) return;
      setState(() {
        _starting = false;
        _message = 'Không kết nối được: $error';
      });
      _scheduleRetry();
    }
  }

  void _onPlayerValue(VlcPlayerController controller, int ticket) {
    if (!mounted || !_wantPlay || ticket != _generation) return;
    final value = controller.value;
    final now = DateTime.now();
    if (value.hasError) {
      _message = 'Lỗi trình phát: ${value.errorDescription}';
      _scheduleRetry();
    }
    if (value.isBuffering && !_buffering) {
      _bufferEvents++;
      _bufferedSince = now;
    } else if (!value.isBuffering && _buffering) {
      _closeBuffering(now);
    }
    if (value.isPlaying) {
      _nonPlayingSince = null;
      _healthySince ??= now;
      if (now.difference(_healthySince!) > const Duration(seconds: 10)) {
        _retryCount = 0;
      }
    } else {
      _nonPlayingSince ??= now;
      _healthySince = null;
    }
    if (value.isPlaying != _playing || value.isBuffering != _buffering) {
      setState(() {
        _playing = value.isPlaying;
        _buffering = value.isBuffering;
        if (value.isPlaying) _message = 'Đang phát RTSP trực tiếp';
      });
    }
  }

  void _closeBuffering(DateTime now) {
    if (_bufferedSince != null) {
      _bufferTotal += now.difference(_bufferedSince!);
      _bufferedSince = null;
    }
  }

  void _watch() {
    if (!mounted) return;
    if (_wantPlay && !_starting && _retryTimer == null) {
      final now = DateTime.now();
      final startupTooLong = _openedAt != null &&
          _nonPlayingSince != null &&
          now.difference(_openedAt!) > const Duration(seconds: 12);
      final stalledBuffer = _bufferedSince != null &&
          now.difference(_bufferedSince!) > const Duration(seconds: 7);
      final stoppedTooLong = _nonPlayingSince != null &&
          now.difference(_nonPlayingSince!) > const Duration(seconds: 8);
      if (startupTooLong || stalledBuffer || stoppedTooLong) {
        _scheduleRetry();
      }
    }
    setState(() {}); // Once per second for the diagnostic counters only.
  }

  void _scheduleRetry() {
    if (!_wantPlay || _retryTimer != null || _starting) return;
    final delay = math.min(16, 1 << math.min(_retryCount, 4));
    _retryCount++;
    setState(() => _message =
        'Gián đoạn kết nối · Thử lại sau $delay giây (lần $_retryCount)');
    _retryTimer = Timer(Duration(seconds: delay), () {
      _retryTimer = null;
      if (_wantPlay && mounted) {
        _reconnections++;
        unawaited(_start(reconnect: true));
      }
    });
  }

  Future<void> _stop() async {
    _wantPlay = false;
    _generation++;
    _retryTimer?.cancel();
    _retryTimer = null;
    _closeBuffering(DateTime.now());
    final old = _player;
    if (old != null && _playerListener != null) {
      old.removeListener(_playerListener!);
    }
    _player = null;
    _playerListener = null;
    if (mounted) {
      setState(() {
        _starting = false;
        _playing = false;
        _buffering = false;
        _message = 'Đã dừng phát.';
      });
    }
    try {
      if (old != null) await old.dispose();
      await WifiBridge.keepAwake(false);
      await WifiBridge.unbind();
    } catch (_) {
      // Disconnection can race with the Android activity lifecycle.
    }
  }

  @override
  void dispose() {
    _wantPlay = false;
    _generation++;
    _watchdog?.cancel();
    _retryTimer?.cancel();
    if (_player != null && _playerListener != null) {
      _player!.removeListener(_playerListener!);
    }
    if (_player != null) unawaited(_player!.dispose());
    unawaited(WifiBridge.keepAwake(false));
    unawaited(WifiBridge.unbind());
    _host.dispose();
    _port.dispose();
    _path.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bufferNow = _bufferedSince == null
        ? Duration.zero
        : DateTime.now().difference(_bufferedSince!);
    final buffered = _bufferTotal + bufferNow;
    return Scaffold(
      appBar: AppBar(
        title: const Text('TTX · 70mai A500S Live'),
        actions: [
          IconButton(
            tooltip: 'Kiểm tra Wi-Fi',
            onPressed: _checkWifi,
            icon: const Icon(Icons.wifi_find),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ColoredBox(
                color: Colors.black,
                child: _player == null
                    ? const Center(
                        child: Icon(Icons.videocam_outlined,
                            color: Colors.white54, size: 64),
                      )
                    : VlcPlayer(
                        key: ValueKey(_generation),
                        controller: _player!,
                        aspectRatio: 16 / 9,
                        placeholder: const Center(
                            child: CircularProgressIndicator()),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text(_message, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 6),
            Text(_wifiHint, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _host,
                  enabled: !_wantPlay,
                  decoration: const InputDecoration(
                    labelText: 'IP / host camera',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _port,
                  enabled: !_wantPlay,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: _path,
              enabled: !_wantPlay,
              decoration: const InputDecoration(
                labelText: 'Đường dẫn RTSP (chưa xác minh trên mọi A500S)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<PlaybackProfile>(
              value: _profile,
              decoration: const InputDecoration(
                  labelText: 'Bộ đệm / ưu tiên',
                  border: OutlineInputBorder()),
              items: PlaybackProfile.values
                  .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text('${p.label} · ${p.cacheMs} ms')))
                  .toList(),
              onChanged: _wantPlay ? null : (v) {
                if (v != null) setState(() => _profile = v);
              },
            ),
            SwitchListTile(
              title: const Text('RTP qua RTSP/TCP'),
              subtitle: const Text('Ưu tiên cho Wi-Fi không ổn định; thử UDP nếu TCP khựng.'),
              value: _tcp,
              onChanged: _wantPlay ? null : (v) => setState(() => _tcp = v),
            ),
            FilledButton.icon(
              onPressed: _starting ? null : (_wantPlay ? _stop : _start),
              icon: Icon(_wantPlay ? Icons.stop_circle : Icons.play_arrow),
              label: Text(_wantPlay ? 'Dừng' : 'Phát trực tiếp'),
            ),
            const SizedBox(height: 14),
            Wrap(spacing: 14, runSpacing: 4, children: [
              Chip(label: Text(_playing ? 'ĐANG PHÁT' : 'CHƯA PHÁT')),
              Chip(label: Text(_buffering ? 'ĐANG ĐỆM' : 'KHÔNG ĐỆM')),
              Chip(label: Text('Lượt đệm: $_bufferEvents')),
              Chip(label: Text('Tổng đệm: ${buffered.inSeconds}s')),
              Chip(label: Text('Tự nối lại: $_reconnections')),
            ]),
            const SizedBox(height: 8),
            const Text(
              'Thống kê trên phản ánh trạng thái bộ đệm của libVLC, '
              'KHÔNG phải FPS hay số frame rơi thực tế. '
              'Đường dẫn /livestream/12 là ứng viên từ APK 70mai; '
              'không mặc định /13 là camera sau. '
              'Ổn định rung vật lý chưa bật trong luồng trực tiếp.',
            ),
          ],
        ),
      ),
    );
  }
}
