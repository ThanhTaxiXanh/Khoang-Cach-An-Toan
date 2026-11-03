# ThanhTaxiXanh · A500S RTSP Live (Flutter + Android IJKPlayer)

**Bản thử nghiệm V1.2**: Android Flutter/Dart + native **IJKPlayer (GSY RTSP-enabled FFmpeg)**, MediaCodec khi hỗ trợ. **Không sử dụng libVLC, ExoPlayer hoặc thư viện native lấy từ ứng dụng 70mai.**

## Kiến trúc

```text
70mai A500S hotspot (sau khi ghép đôi hợp lệ)
  -> Android Wi-Fi network binding
  -> RTSP :554/livestream/12 (ứng viên từ APK, chưa kiểm chứng firmware)
  -> IJKPlayer / FFmpeg
  -> Android MediaCodec (ưu tiên, có thể fallback)
  -> SurfaceView (Android PlatformView)
  -> Flutter UI: controls + diagnostics (không truyền frame qua Dart)
```

### Phạm vi và giới hạn thực tế

- Đã tích hợp IJKPlayer gốc và loại bỏ hoàn toàn phụ thuộc libVLC.
- Nhận RTSP TCP/UDP, cấu hình bộ đệm thấp/cân bằng/ổn định, đánh dấu buffering, reconnect theo backoff, thống kê FPS decode/output, TCP KB/s, cache.
- Android giữ tuyến lưu lượng vào Wi-Fi camera dù mạng này không có Internet.
- **Chưa xác minh A500S vật lý**: URL `rtsp://192.168.0.1:554/livestream/12` là ứng viên theo phân tích XAPK 70mai 4.5.0.
- Không gán `/livestream/13` cho camera sau. Không tự gửi `setwifistream.cgi?sensor=1` khi chưa biết định dạng/xác thực thực tế trên DR2500.
- **Chưa có thuật toán EIS chống rung hình vật lý**, chỉ tối ưu luồng truyền/phát. Không thể cam kết tuyệt đối không giật tại mọi tốc độ di chuyển. Không quảng cáo FPS giả hoặc giải mã phần cứng là luôn chắc chắn.
- Bản IJKPlayer 0.8.8 cũ (2018) có rủi ro bảo trì và codec; cần rà soát bảo mật trước khi triển khai công khai hoặc phát stream từ Internet.
- Thư viện LGPL: xem giấy phép và lưu ý phân phối mã/bản địa sửa đổi theo yêu cầu của thư viện. Không chép binary trực tiếp từ 70mai.

## Build APK (không cần máy tính)

1. Mở [Actions](https://github.com/ThanhTaxiXanh/Khoang-Cach-An-Toan/actions/workflows/android-ijkplayer.yml).
2. Chọn `Run workflow` trên branch `feature/a500s-live-rtsp-v1` (hoặc chờ workflow push/PR).
3. Sau khi build **thành công**, mở workflow run -> Artifacts -> `TTX-A500S-IJKPlayer-APK` để tải.
4. Giải nén artifact trên điện thoại, cài file `app-arm64-v8a-release.apk` cho Android ARM64.

Quy trình GitHub Actions tự tạo Android Flutter scaffold, kiểm tra `flutter analyze`, `flutter test` và build bản APK. Dependency IJKPlayer gốc 0.8.8 từng phát hành qua JCenter; workflow sử dụng **mirror Aliyun** có giới hạn nhóm dependency. Nếu mirror không cung cấp AAR hoặc không kết nối được, build sẽ thất bại và cần chọn nguồn phân phối hợp pháp khác. Không khẳng định build đạt khi chưa có kết quả CI.

## Thử trên A500S

1. Kết nối điện thoại vào Wi-Fi hotspot của A500S, hoàn thành ghép đôi trong ứng dụng 70mai.
2. Đóng màn hình live của app 70mai (camera có thể giới hạn 1 phiên RTSP).
3. Chạy TTX 70mai Live, kiểm tra gateway/IP thực tế. Điền IP camera, port 554, path `/livestream/12`.
4. Bấm Phát, xem trạng thái và số FPS decode/output, buffering, reconnect.
5. Thử TCP trước, đổi sang UDP khi đã có lý do kỹ thuật. Đối chiếu 3 hồ sơ bộ đệm với camera thật.
6. Thu thập firmware A500S và kết quả quan sát camera sau; đừng giả định xem đồng thời 2 góc.

## Tài liệu giao thức

Xem `docs/70mai-a500s-protocol.md`. Mã nguồn tuân thủ nguyên tắc **không vượt ghép đôi/ủy quyền**, không sao chép thư viện đóng gói của ứng dụng gốc.


## Khắc phục lỗi Android báo «gói không hợp lệ» (03/11/2026)

Các artifact ban đầu từ build #13/#14 có thể **chưa được ký số** vì Gradle không khai báo signing config cho `release`. Dù CI báo Success, Android không cài đặt được APK unsigned. Bản `1.1.1+3` khắc phục bằng **chữ ký Android debug dành riêng cho TEST** khi biên dịch `release`. CI bây giờ chạy `apksigner verify` cho từng APK và kiểm tra bộ thư viện IJKPlayer native nằm đúng thư mục ABI, rồi mới upload artifact `TTX-A500S-IJKPlayer-SIGNED-TEST-APK`.

- Dành cho điện thoại ARM64: cài `app-arm64-v8a-release.apk`; ARM32: `app-armeabi-v7a-release.apk`. Không phát hành APK x86_64 vì gói IJKPlayer gốc đang cấu hình không có thư viện native x86_64.
- Vì khóa debug của GitHub Actions thay đổi theo runner, có thể cần **gỡ ứng dụng test cũ trước khi cài bản mới** nếu hệ điều hành báo không thể cập nhật do chữ ký khác nhau. Gỡ ứng dụng sẽ xóa dữ liệu ứng dụng lưu cục bộ. Đừng gỡ nếu đang có dữ liệu quan trọng chưa sao lưu.
- Cấu hình ký kiểu debug chỉ dùng cho **APK thử nghiệm nội bộ**; bản phát hành chính thức phải ký bằng keystore riêng, bảo quản an toàn (ví dụ GitHub Actions Secrets). Chữ ký hợp lệ không chứng minh video RTSP đã hoạt động trên A500S.


## JNI_OnLoad failed on `libijksdl.so` (A500S live test, 03/11/2026)

- Symptom: screen black; `JNI_OnLoad failed on a previous attempt to load libijksdl.so`; identical with RTSP TCP/UDP, FPS decode 0.
- This failure happens while initializing IJK native libraries **before** any RTSP negotiation. Testing `/livestream/13` or changing transport cannot fix it.
- Most likely fault: R8 obfuscating/removing classes accessed via JNI's `FindClass`, `GetMethodID` or `RegisterNatives` in the original IJK 0.8.8 native binary.
- Mitigation V1.1.2: add broad IJK `-keep` rules (including all JNI fields/methods), configure release `proguardFiles`, verify post-R8 DEX descriptors for `IjkMediaPlayer`, `IMediaDataSource`, `IAndroidIO`.
- Kotlin now treats a `LinkageError` as **fatal for this process**, stops RTSP reconnection and displays an actionable message. Network binding is released.
- **Evidence required before calling this fixed:** install the new ABI-matched APK on the same phone, open the player and verify no further `JNI_OnLoad` errors. CI build success only validates compilation, signing and DEX packaging; it cannot run your 70mai hardware.
- Diagnostic if persistent: Android `logcat` immediately before the *first* `JNI_OnLoad` failure, especially `J4A`, `NoSuchMethodError`, `NoSuchFieldError`, `UnsatisfiedLinkError` or unsupported library linkage.
- Original IJKPlayer issue: https://github.com/bilibili/ijkplayer/issues/1656


## V1.2: H264 RTSP trong FFmpeg + chẩn đoán camera (03/11/2026)
- Ảnh A500S của người dùng ghi nhận JNI chạy nhưng `IJK error: what=-10000 extra=0`, không nhận video (0 FPS/0 KBps) ở cả TCP/UDP.
- Mã `-10000` là lỗi player tổng quát: không tự kết luận rằng RTSP URL sai.
- Prebuilt `tv.danmaku.ijk.media:ijkplayer-*:0.8.8` sử dụng profile FFmpeg lite thiếu RTSP/RTP. Vì thế thay Java và native đồng bộ:
  - `io.github.carguo:gsyijkjava:1.0.0`
  - `io.github.carguo:gsyvideoplayer-ex_so:13.2.1` (khai báo hỗ trợ RTSP)
- Vẫn là **IJKPlayer**, không phải libVLC hoặc ExoPlayer. Giữ Flutter -> native Android IJKPlayer -> SurfaceView.
- Màn hình có nút **Kiểm tra RTSP (OPTIONS / DESCRIBE)**; truy vấn đọc (không đổi cấu hình camera) từ mạng Wi-Fi hiện tại, hiển thị status 200/401/404, Content-Base, SDP codec và track.
- Nếu thất bại trước frame đầu, dừng sau ba lần nối lại để tránh vòng lặp vô ích.
- Báo cáo `DESCRIBE 200` của A500S và `Content-Base` mang mã phiên động không có nghĩa `/livestream/12` sai: dùng URL ban đầu để DESCRIBE, xử lý Content-Base ở trình phát RTSP.
- Kiểm tra camera trực tiếp sau khi dừng xe an toàn. Gỡ bản cài có chữ ký khác nếu Android từ chối cập nhật; sao lưu dữ liệu trước khi gỡ.
- Cần xác nhận mã từ CI và trên A500S vật lý; không đánh đồng APK build success với video chạy được.


## V1.3 – RTSP session diagnostic (A500S, 03/11/2026)

Camera screenshots prove `OPTIONS 200`, `DESCRIBE 200`, dynamic `Content-Base` (e.g. `/0000000C/`, `/00000012/`), and `a=control:track1`. These responses alone do **not** prove `SETUP`/`PLAY` or RTP payload was received.

- The probe now uses a **single RTSP connection** for OPTIONS, DESCRIBE, SETUP and PLAY, derives the track URL from the **current** `Content-Base` and SDP `a=control`, and captures up to 5 seconds of RTP data over **selected TCP or UDP**.
- For UDP the app reserves a consecutive even/odd RTP/RTCP port pair on the camera Wi-Fi network. For TCP, it reads RTSP interleaved RTP on channel 0.
- Displays SETUP URL, selected and server transports, RTSP response codes, frame codec as `a=rtpmap:96 H264/90000`, whether an RTSP Session was issued, packet/byte counts and whether H.264 IDR was seen.
- Attempts TEARDOWN of the short diagnostic session. **Stop playback before running the probe**: the camera may not allow concurrent RTSP sessions.
- For live playback IJK uses `packet-buffering=0` across profiles to prevent prolonged buffering start when stream is active, with frameskip still available. This is a test preset, not proof that all video stalls have been fixed.
- If `SETUP` fails (461 etc.), test alternate transport; if `PLAY 200` but zero RTP, investigate camera session/firmware and Wi-Fi; if RTP arrives but IJK shows 0 FPS, focus on IJK demux, buffering or H.264 decoder.
- Do not replace the original `/livestream/12` DESCRIBE URL with the dynamic `Content-Base`; the latter is scoped to a specific SDP session.
- No recording, upload, auth bypass, or camera configuration writes. All probing is limited to the camera Wi-Fi network already joined by the user.


## V1.4 – Experiment: reduce ~3-second end-to-end live delay

On-camera test confirmed that **V1.3 renders A500S live RTSP**; viewer estimated ~3 s lag versus camera. This is an empirical observation, not an instrumented measurement.

V1.4 **retains the V1.3 'Cân bằng' and 'Ưu tiên ổn định' presets unchanged** and adds an opt-in `Thử trễ tối thiểu (dễ giật)` profile:
- Reduced FFmpeg `analyzeduration`, `probesize` for faster startup;
- `fflags=nobuffer`, `max_delay=100000` µs and `reorder_queue_size=0` for lower buffering/reordering;
- IJK `min-frames=1`, `max_cached_duration=120`, `framedrop=3` for aggressive frame presentation;
- Native telemetry adds startup first-frame milliseconds and video dimensions. **First-frame startup time is not an end-to-end latency measurement.**

Settings apply only after stopping and reopening playback. If the experimental profile becomes choppy, return to the working balanced profile. Increasing driving speed does not inherently make RTP faster or slower; Wi-Fi signal, encoder backlog, decoder FPS, buffering and thermal throttling matter. Do not assume a 3-second-old video feed is safe for live collision alerts.

### Repeatable latency test (parked vehicle)

With a second phone recording both the dashcam's own live preview and the TTX phone in one shot, make a clear hand movement in view. Measure the time between the same visual event on both displays. Repeat at 0, 2 and 10 minutes for baseline and experimental, using the same transport. Note lag (seconds), FPS output, reconnect and buffering counts. **Camera screen may itself be delayed; this measures the gap between the two displays, not necessarily sensor-to-phone latency.**


## V1.5 – Diagnose a fixed ~3-second delay, WITHOUT changing working playback

On-device test report: V1.4 plays smoothly for minutes without freezing, but the observed lag remains about 3 seconds across TCP/UDP and all four buffering presets. This strongly reduces the likelihood that the preset network/packet buffer is the sole source of delay. A camera-side encoder pipeline, RTP timestamps, decoder scheduling or the reference display may be responsible. No causal conclusion yet.

Changes:
- **All V1.4 IJK playback options are UNCHANGED.** This version is safe to compare against the already working baseline.
- Native metrics: actual decoder backend (MediaCodec vs FFmpeg/AVCodec), IJK video queued packet count and cached byte count, alongside existing FPS/cache metrics.
- Flutter gathers at most 600 one-second samples (10 minutes), computes average FPS and cache maximum/P95; does NOT copy raw video frames.
- The user can manually record observed lag, select its reference (scene, camera screen, official 70mai app) and tap **Sao chép báo cáo IJKPlayer**. Clipboard only; no remote logging.
- A first-frame start time is NOT end-to-end latency, and queue duration is only one subset of the total delay.
- Next step: compare measured lag and queue occupancy. If displayed image lags 3 s while the IJK queue is short, further adjustment of `min-frames` / `max_cached_duration` alone is unlikely to solve it; investigate camera encoder/GOP, RTP PTS and external reference.
- Never use ~3 s delayed feed as the only input for live collision warnings. Test while parked.


## V1.5.1: Fix native Surface lost during scrolling (user screen-recording evidence)

A ~63-second user screen recording demonstrated that `MediaCodec` decoded 640x480 at approximately 29.6 FPS around 16 seconds, but scrolling the controls caused `SurfaceView` to disappear (`waiting_surface`) and the player to stop; when scrolling back up the video was reinitialized. Consequently the V1.5 report showing 21 FPS on average, five zero-FPS samples and decoder `--` was contaminated by the surface lifecycle rather than a sustained RTSP throughput failure.

Changes:
- Move native `IjkSurface` out of the scrollable `ListView` into a permanently mounted player panel at the top of the page; only settings and diagnostics scroll inside `Expanded(ListView)`. This avoids lazily removing the native platform view when it leaves the viewport.
- Count `waiting_surface` lifecycle events, and retain the last valid native decoder/queue snapshot for copyable reports if the surface is later lost.
- Ignore non-playing, non-decoding time with no video dimensions in mean FPS calculations, rather than labeling view destruction as video frame drops.
- Keep V1.4 IJK options and RTSP host/path unchanged. This release addresses UI lifecycle, not the remaining ~3 seconds of real-world sensor-to-screen delay.
- No new stabilizer, frame filters, frame copying or network uploading.


## V1.6 – Diagnose the four reconnects without changing proven playback

A500S field test (2026-11-03 21:52): 163 s uptime, `Surface lost 0`, 158 FPS samples, MediaCodec 640x480, FPS decode 22.0/output 21.3 mean, queue P95 6 ms, 0 IJK buffer-start notifications, 4 reconnects, approx 3-second scene-to-screen delay.

The 4 reconnects are not explained by Surface destruction or IJK buffer events. They may represent RTSP errors, server session timeouts, missing frames, or other native failures. Do **not** infer an exact root cause without native event codes and their timings.

V1.6 only changes diagnostics:
- Record a 48-entry native in-memory event ring with elapsed time and session ID. Every reconnect stores the pre-release native state, session age, active-video age, FPS, IJK video cache and original IJK error or watchdog reason.
- Count native session attempts and successful first-frame sessions. Summarize decoder FPS and cached duration **per session** to avoid averaging reconnect downtime with steady playback.
- Expose native reconnect reason and session ID in the Flutter UI; copied report includes the last 20 timed events and last eight per-session summaries.
- Keep all video decode, MediaCodec, RTSP, player buffering, network binding, rendering and reconnect policies **identical to V1.5.1**. No additional polling/RTSP requests.
- Logging is local only; clipboard report is shared only by explicit user action.
- Continue using parked-vehicle tests. A three-second-delayed live image cannot reliably serve as the sole input to collision avoidance or safety-critical decisions.

Next: collect a 5-10-minute V1.6 report. If reconnects occur at near-regular intervals, investigate server RTSP keepalive/Session timeout; if associated with a particular IJK error, address that code. If no reconnects and a persistent ~3-second lag remains, investigate encoder-side buffering and RTP/PTS timing, not IJK cached packet duration alone.
