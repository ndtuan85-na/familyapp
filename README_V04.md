# Seafood Family v0.4 — bản phát triển, CHƯA sẵn sàng quản lý tiền thật

## Thay đổi thực tế so với v0.3
- Material 3 theme xanh ngọc nhạt, nền trắng xanh, thẻ bo góc, menu đồng bộ.
- Màn hình bảng giá lẻ/sỉ theo đơn vị chuẩn, sửa giá thông qua Cloud Function `upsertMaster` (giá KHÔNG tự áp vào phiếu bán và chưa có giá riêng theo khách).
- Màn hình chọn và kiểm tra file sao lưu JSON; **chưa hỗ trợ phục hồi online**, nhằm tránh ghi đè dữ liệu kho, tiền.
- Xác nhận phiếu bán/nhập giữ cùng `idempotencyKey` khi retry trên màn hình; nếu mạng lỗi, truy vấn chứng từ từ Firestore trước khi thông báo. Vẫn cần lưu khóa xuống SQLite để chịu được app bị tắt rồi mở lại.
- Bộ dữ liệu thử giả `assets/demo_v04.json` tách biệt với danh mục 81 mặt hàng `assets/quynh_luu_seafood.csv`.
- Thêm `functions/scenario.test.js` với 3 kịch bản mô phỏng logic: cùng bán, cùng thu nợ, gửi lại khóa. Đây là test mô phỏng tuần tự, không phải Firestore Emulator/2 điện thoại thực.

## Kết quả đã thực sự chạy
- `cd functions && npm test` → **12/12 PASS**.
- `node --check functions/index.js`, `node --check functions/ledger_ops.js` cần được chạy trong quá trình nghiệm thu.
- **Chưa chạy** `flutter analyze`, `flutter test`, build APK, Xcode/iOS, Firestore emulator, kết nối 2 điện thoại do không có Flutter SDK, Firebase project và máy iOS trong môi trường này.

## Điều kiện trước khi sử dụng tiền thực tế
1. Hoàn thiện toàn bộ luồng thanh toán/hoàn tiền GUI và xử lý chứng từ trả NCC, giá bán theo từng đơn vị và khách, quản lý quyền.
2. Ghi phiếu nháp và idempotency key vào SQLite trước khi gửi máy chủ, khôi phục trạng thái gửi chưa rõ sau app crash.
3. Dùng Firebase Emulator test 2 client chạy cạnh tranh thật: cùng bán, cùng thu nợ, hoàn hàng, timeout; kiểm thử security rules.
4. Đối chiếu toàn bộ sổ phát sinh, kho, công nợ và giá vốn; kiểm tra tròn tiền/chiết khấu/hoàn từng phần.
5. Hoàn thành tính năng sao lưu có snapshot nhất quán/checksum và khôi phục có quy trình bảo trì, khóa ghi, rollback.
6. Biên dịch Android và iOS, cài trên thiết bị thật, kiểm thử offline, notifications, hiệu suất.

## Thiết lập
- Cài Flutter SDK, Android SDK; cần macOS/Xcode để build iOS.
- `flutter create --platforms=android,ios .` rồi `flutter pub get`.
- Tạo Firebase project, Auth/Firestore/Functions và cấp quyền members/{uid} với householdId; dùng `flutterfire configure`.
- `cd functions && npm install && npm test`.
- Cần triển khai `firebase deploy --only firestore:rules,functions`, nạp danh mục theo README_V03.
- Không nạp `assets/demo_v04.json` vào cơ sở dữ liệu thật.

## Cảnh báo
Không thể cam kết ứng dụng không có lỗi. Đây là bản mã nguồn nâng cấp có phần nghiệp vụ còn dang dở, **chưa được nghiệm thu sản xuất**.
