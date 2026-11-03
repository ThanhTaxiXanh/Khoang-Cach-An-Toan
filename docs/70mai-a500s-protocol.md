# Cơ chế RTSP A500S – ghi chú phát triển

Nguồn: tài liệu phân tích tĩnh XAPK 70mai 4.5.0 do người dùng cung cấp ngày 03/11/2026. **Chưa thực nghiệm với thiết bị A500S.**

## Thông tin xác định từ APK

- 70mai quốc tế: `com.banyac.midrive.app.intl`; A500S/Pro Plus+ có định danh **DR2500**.
- IJKPlayer/FFmpeg là trình phát trong ứng dụng 70mai. APK chứa `libijkplayer.so`, `libijkffmpeg.so`, `libijksdl.so`.
- URL debug trong APK: `rtsp://192.168.0.1:554/livestream/12`.
- `constants.c.w2` chọn `/livestream/13` cho một nhánh đặc biệt thuộc thiết bị HiSilicon khác. **Không phải bằng chứng về camera sau A500S**.
- Có `setwifistream.cgi` với trường `sensor`, UI chung nhắc đến `0`/ `1`. HTTP method, header, xác thực và việc DR2500 hỗ trợ điều này **chưa xác minh**.
- Các URL chung `/liveRTSP/av1`, `av2`, `av4`, `av5`, `v1` không được gán cho A500S.

## Chuỗi xử lý

Wi-Fi/hotspot -> ghép đôi hợp lệ -> IP mạng cục bộ -> RTSP DESCRIBE/SETUP/PLAY -> RTP -> FFmpeg -> MediaCodec khi tương thích -> SurfaceView.

## Cần xác minh trên camera thật

- URL host/gateway hiện tại và lỗi RTSP nếu có.
- Codec, độ phân giải, FPS, khả năng duy trì phiên; RTSP Session timeout/keepalive.
- Live rear có được firmware hỗ trợ không; nếu có thì là `sensor`, URL hay track riêng.
- Có cho phép 2 phiên cùng lúc không; không làm UI chia đôi khi chưa xác định.
- FPS hiển thị, số lần buffering, reconnect và độ trễ trong điều kiện Wi-Fi thực.

## An toàn khi vận hành

Không nhìn màn hình điện thoại khi điều khiển phương tiện. Dừng xe an toàn trước khi kiểm tra live view hoặc thay đổi cấu hình. Không dùng live view làm nguồn duy nhất cho nhận diện vật cản hoặc giữ khoảng cách; cần kiểm thử độ trễ, độ tin cậy và đồng bộ thời gian trước khi xây dựng xADAS.
