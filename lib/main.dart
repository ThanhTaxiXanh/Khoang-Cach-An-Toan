import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/ijk_bridge.dart';
import 'src/stream_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TtxLiveApp());
}

class TtxLiveApp extends StatelessWidget {
  const TtxLiveApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'TTX · A500S Live',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1A9D87),
            brightness: Brightness.dark,
          ),
        ),
        home: const LiveScreen(),
      );
}

class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

class _LiveScreenState extends State<LiveScreen> {
  final _host = TextEditingController(text: '192.168.0.1');
  final _port = TextEditingController(text: '554');
  final _path = TextEditingController(text: '/livestream/12');
  StreamSubscription<Map<String, dynamic>>? _subscription;
  Timer? _ticker;
  int? _viewId;
  bool _requested = false;
  bool _busy = false;
  String _state = 'idle';
  String _message = 'Kết nối Wi-Fi camera và nhấn Phát.';
  String _wifiMessage = 'Đang kiểm tra Wi-Fi...';
  RtspTransport _transport = RtspTransport.tcp;
  PlaybackProfile _profile = PlaybackProfile.balanced;
  Map<String, dynamic> _stats = <String, dynamic>{};

  @override
  void initState() {
    super.initState();
    _subscription = IjkBridge.events.listen(_onNativeEvent, onError: (Object e) {
      if (mounted) setState(() => _message = 'Không nhận được trạng thái: $e');
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _pollStats());
    _checkWifi();
  }

  void _onNativeEvent(Map<String, dynamic> event) {
    if (!mounted || event['viewId'] != _viewId) return;
    setState(() {
      _state = event['state'] as String? ?? _state;
      _message = event['message'] as String? ?? _message;
    });
  }

  Future<void> _checkWifi() async {
    try {
      final result = await IjkBridge.wifiStatus();
      if (!mounted) return;
      final found = result['available'] == true;
      setState(() {
        _wifiMessage = found
            ? 'Wi-Fi: ${result['gateway'] ?? 'đã kết nối'}'
            : 'Chưa có Wi-Fi. Hãy nối hotspot 70mai trên điện thoại.';
      });
    } on PlatformException catch (e) {
      if (mounted) setState(() => _wifiMessage = 'Wi-Fi: ${e.message}');
    }
  }

  Future<void> _pollStats() async {
    final id = _viewId;
    if (!_requested || id == null || _busy) return;
    try {
      final stats = await IjkBridge.stats(id);
      if (mounted && id == _viewId) setState(() => _stats = stats);
    } catch (_) {
      // Keep the control UI responsive if the native view has been disposed.
    }
  }

  Future<void> _open() async {
    if (_busy) return;
    final port = int.tryParse(_port.text.trim());
    if (port == null) {
      setState(() => _message = 'Cổng RTSP phải là một số nguyên.');
      return;
    }
    final config = StreamConfig(
      host: _host.text,
      port: port,
      path: _path.text,
      transport: _transport,
      profile: _profile,
    );
    if (config.validationError != null) {
      setState(() => _message = config.validationError!);
      return;
    }
    final id = _viewId;
    if (id == null) {
      setState(() => _message = 'Chưa khởi tạo màn hình video.');
      return;
    }
    setState(() {
      _busy = true;
      _requested = true;
      _message = 'Đang yêu cầu IJKPlayer mở RTSP...';
    });
    try {
      await IjkBridge.open(
        viewId: id,
        url: config.url,
        transport: config.transport.value,
        profile: config.profile.value,
      );
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _requested = false;
        _state = 'error';
        _message = 'Không phát được: ${e.message}';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final id = _viewId;
      if (id != null) await IjkBridge.close(viewId: id);
    } catch (_) {
      // The platform view can disappear during navigation.
    } finally {
      if (mounted) {
        setState(() {
          _requested = false;
          _busy = false;
          _state = 'stopped';
          _stats = <String, dynamic>{};
          _message = 'Đã dừng video.';
        });
      }
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _subscription?.cancel();
    final id = _viewId;
    if (id != null) unawaited(IjkBridge.close(viewId: id));
    _host.dispose();
    _port.dispose();
    _path.dispose();
    super.dispose();
  }

  String _displayNum(String key, {int decimals = 1}) {
    final v = _stats[key];
    if (v is num) return v.toStringAsFixed(decimals);
    return '--';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('ThanhTaxiXanh · 70mai Live'),
        actions: [
          IconButton(
            onPressed: _checkWifi,
            tooltip: 'Kiểm tra Wi-Fi',
            icon: const Icon(Icons.wifi),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(14),
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: DecoratedBox(
                decoration: const BoxDecoration(color: Colors.black),
                child: AndroidView(
                  viewType: 'vn.thanhtaxixanh.a500s/ijk_surface',
                  onPlatformViewCreated: (int id) {
                    if (!mounted) return;
                    setState(() => _viewId = id);
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(_message,
                style: TextStyle(
                    color: _state == 'error' ? colors.error : colors.onSurface,
                    fontWeight: FontWeight.w600)),
            Text(_wifiMessage, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _host,
                  enabled: !_requested,
                  decoration: const InputDecoration(
                      labelText: 'IP camera', border: OutlineInputBorder()),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _port,
                  enabled: !_requested,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                      labelText: 'Cổng', border: OutlineInputBorder()),
                ),
              ),
            ]),
            const SizedBox(height: 10),
            TextField(
              controller: _path,
              enabled: !_requested,
              decoration: const InputDecoration(
                  labelText: 'Đường dẫn RTSP',
                  helperText: '/12 là ứng viên tìm được trong APK 70mai',
                  border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<RtspTransport>(
              value: _transport,
              decoration: const InputDecoration(
                  labelText: 'Giao thức', border: OutlineInputBorder()),
              items: RtspTransport.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.label)))
                  .toList(),
              onChanged: _requested
                  ? null
                  : (t) {
                      if (t != null) setState(() => _transport = t);
                    },
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<PlaybackProfile>(
              value: _profile,
              decoration: const InputDecoration(
                  labelText: 'Hồ sơ bộ đệm', border: OutlineInputBorder()),
              items: PlaybackProfile.values
                  .map((p) => DropdownMenuItem(value: p, child: Text(p.label)))
                  .toList(),
              onChanged: _requested
                  ? null
                  : (p) {
                      if (p != null) setState(() => _profile = p);
                    },
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _busy ? null : (_requested ? _close : _open),
              icon: Icon(_requested ? Icons.stop : Icons.play_arrow),
              label: Text(_requested ? 'Dừng phát' : 'Phát RTSP trực tiếp'),
            ),
            const SizedBox(height: 12),
            Text('Chẩn đoán IJKPlayer',
                style: Theme.of(context).textTheme.titleMedium),
            Wrap(spacing: 7, runSpacing: 4, children: [
              Chip(label: Text('Trạng thái: $_state')),
              Chip(label: Text('FPS decode: ${_displayNum('decodeFps')}')),
              Chip(label: Text('FPS output: ${_displayNum('outputFps')}')),
              Chip(label: Text('TCP: ${_displayNum('tcpKbps', decimals: 0)} KB/s')),
              Chip(label: Text('Đệm: ${_displayNum('cachedMs', decimals: 0)} ms')),
              Chip(label: Text('Buffer: ${_stats['bufferEvents'] ?? 0}')),
              Chip(label: Text('Nối lại: ${_stats['retries'] ?? 0}')),
            ]),
            const SizedBox(height: 10),
            const Text(
              'Camera trước/sau: A500S chưa xác minh được live rear hoặc '
              'hai luồng đồng thời. Không mặc định /livestream/13 là camera sau. '
              'Phần mềm không thể đảm bảo không giật ở mọi tốc độ xe. '
              'Chống rung vật lý (EIS) chưa được triển khai; không có quảng cáo tính năng giả.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
