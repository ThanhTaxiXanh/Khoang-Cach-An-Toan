# ThanhTaxiXanh · A500S RTSP Live (Flutter + Android IJKPlayer)

**Bản thử nghiệm V1.1**: Android Flutter/Dart + native **IjkMediaPlayer 0.8.8**, FFmpeg, MediaCodec khi hỗ trợ. **Không sử dụng libVLC, ExoPlayer hoặc thư viện native lấy từ ứng dụng 70mai.**

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
