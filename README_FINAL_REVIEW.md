# Seafood Family – bản mã nguồn rà soát v1.0 RC (CHƯA nghiệm thu thực tế)

## Thay đổi đã thực hiện trong lượt này
- Màn hình khách hàng cục bộ: bộ lọc theo tên hoặc số điện thoại, không phân biệt chữ hoa, có/không dấu, chấp nhận chuỗi số một phần (tối thiểu 3 chữ số).
- Màn hình tạo phiếu bán online: nút chọn khách hàng với ô tìm kiếm tên/số điện thoại thay vì danh sách thả xuống quá dài; hiển thị số điện thoại của khách.
- Cloud Function `postDocument`: lưu dấu SHA-256 nội dung yêu cầu và từ chối sử dụng lại cùng idempotencyKey cho nội dung khác; không làm thay đổi ý nghĩa khóa của chứng từ cũ.
- Bổ sung 3 bài kiểm thử logic: đối chiếu giá vốn/tồn/kho/công nợ, 1.000 đơn giả lập gửi lặp, và hàng trả lại có/không nhập kho.

## Kết quả có bằng chứng
- Node.js v22, `node --check functions/index.js`: đạt.
- `cd functions && npm test`: 15/15 đạt; xem `seafood_family_v10_test_results.txt`.
- Tình huống đồng thời ở đây là **mô phỏng logic tuần tự**, chưa chạy giao dịch cạnh tranh Firestore thật.

## Chưa làm được, bắt buộc trước khi quản lý tiền thật
1. Cần môi trường Flutter SDK để chạy `flutter analyze`, `flutter test` và xây dựng APK; để kiểm thử iOS cần macOS/Xcode và thiết bị hoặc simulator.
2. Cần dự án Firebase thử nghiệm để chạy Firestore Emulator cùng rules và Functions, kiểm chứng nhiều máy đồng thời, timeout và offline.
3. Cần hoàn thiện luồng UI hoàn tiền đơn đã thanh toán, đồng bộ sổ giao dịch (màn hình cũ có dữ liệu SQLite riêng), khôi phục backup trực tuyến có kiểm soát.
4. Cần lưu idempotency key và payload nháp qua lần tắt/mở ứng dụng; hiện chỉ giữ cố định trong vòng đời màn hình.
5. Cần rà soát kỹ các giới hạn công nợ, hoàn/đảo giao dịch và phân quyền trước khi nhận tiền thật.

## Cài thử khi đã có môi trường
```bash
flutter create --platforms=android,ios .
flutter pub get
flutter analyze
flutter test
cd functions && npm install && npm test
```
Chỉ kết nối Firebase test, không sử dụng dữ liệu kinh doanh thật trong giai đoạn này.
