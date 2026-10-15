# SEAFOOD FAMILY v0.3 – mã nguồn nâng cấp (chưa nghiệm thu sản xuất)

## Bản bàn giao
- Flutter/Dart + SQLite offline cho dữ liệu bản nháp của phiên bản gốc; Firestore realtime với sổ chứng từ v2/v3.
- Cloud Functions: `upsertMaster`, `postDocument` (nhập/bán nhiều dòng), `settleDocument` (thu/chi tiền phân bổ theo chứng từ), `returnSale` (trả một phần/toàn bộ đơn bán), `cancelPurchase` (hủy phiếu nhập đủ điều kiện).
- Firestore rules: thiết bị chỉ đọc danh mục/chứng từ, toàn bộ ghi nghiệp vụ qua Cloud Functions.
- 81 mặt hàng trong `assets/quynh_luu_seafood.csv` với **5 nhóm**: Cá, Tôm, Mực, Đồ đã chế biến, Thực phẩm khác. Nạp bằng `functions/seed_catalog.js` theo mã VÀ theo tên, không ghi đè mặt hàng đã tồn tại.
- Giao diện có lập phiếu nhiều dòng, xem sổ, nhập số tiền thu nợ theo phiếu, trả hàng chưa thu tiền, hủy phiếu nhập đủ điều kiện, xuất JSON.

## Khởi chạy
1. Cài Flutter SDK, Android SDK, Xcode trên macOS nếu build iOS.
2. Tại thư mục này: `flutter create --platforms=android,ios .` ; `flutter pub get`.
3. Tạo Firebase project, bật Auth (Email/Password), Firestore, Functions. `flutterfire configure`. Cấp quyền cho thành viên bằng tài liệu `members/{uid} = {householdId: 'ID_HO'}` (thao tác quản trị, không cho client tự thay đổi).
4. `cd functions && npm install && npm test && cd ..`
5. Đăng nhập `firebase login`, chọn project `firebase use --add`, triển khai `firebase deploy --only firestore:rules,functions`.
6. Từ máy có Firebase Admin credentials, kiểm tra trước: `node functions/seed_catalog.js`. Sau đó `node functions/seed_catalog.js --household=ID_HO --commit`.
7. `flutter run` trên Android / iOS và đăng nhập mỗi người tài khoản riêng cùng `householdId`.

## Cơ chế an toàn
- Xác nhận phiếu chỉ online, Firestore Transaction chống ghi đè tồn kho/công nợ khi tranh chấp.
- Lưu `idempotencyKey` trong các lệnh. Nhưng GUI hiện tạo UUID mới mỗi lần nhấn; cần bổ sung **lưu khóa giao dịch trong bản nháp** để thử lại an toàn khi timeout trước khi dùng thật.
- Trả hàng bán: kiểm tra không quá số lượng gốc, điều chỉnh nợ phiếu; nếu mặt hàng có thể nhập kho, hoàn tồn theo giá vốn gốc. Với đơn đã thu tiền, API yêu cầu `cashRefundVnd` chính xác; GUI hiện khóa thao tác trả cho đơn đã thu tiền, cần màn hình xem trước hoàn tiền.
- Hủy phiếu nhập: chỉ khi chưa thanh toán và chưa có vận động khác trên tất cả mặt hàng liên quan; các trường hợp đã sử dụng hàng cần chứng từ trả nhà cung cấp đặc biệt, chưa hỗ trợ.
- Thu/chi công nợ theo từng phiếu; số dư được kiểm tra trong transaction.
- SQLite v0.1 vẫn có luồng riêng, chưa đồng bộ trạng thái phiếu offline v3.
- Quy đổi đơn vị cần người dùng nhập đúng hệ số/khối lượng thực tế; sản phẩm mặc định kg, không tự giả định thùng/con.

## Giới hạn chưa hoàn thiện – không đưa vào kinh doanh thật
1. Chưa có GUI bảng giá theo khách/đơn vị, quản lý phân quyền chủ/nhân viên, khôi phục file sao lưu an toàn, phân tích lợi nhuận có kiểm soát đầy đủ, lịch giao hàng đa thiết bị.
2. Chưa hoàn thiện nghiệp vụ trả hàng nhà cung cấp sau khi đã thanh toán hoặc đã xuất kho, hoàn hàng bán đã thu tiền qua UI, bù trừ nhiều đơn trong một thao tác GUI.
3. Chưa kiểm thử đồng thời với Firestore Emulator/hai điện thoại thật; chưa có Flutter SDK trong môi trường sinh mã nên chưa xác minh `flutter analyze`, build APK/IPA hay thông báo trên iOS.
4. Chưa bảo đảm kế toán thuế, chi phí chế biến, giá vốn cho hoạt động chế biến nhiều nguyên liệu; cần module chuyển đổi nguyên liệu thành thành phẩm.
5. Chưa có tính năng thiết lập tồn đầu kỳ và import kế toán lịch sử. Nếu có số dư từ phần mềm cũ, cần nhập chứng từ đầu kỳ có kiểm toán, không sửa trực tiếp số dư.
6. Chiết khấu hoàn theo tỷ lệ có làm tròn VND cần đối chiếu ở các trường hợp chia nhỏ phức tạp; thử nghiệm trước khi sử dụng thực tế.

## Kiểm thử
- `cd functions && npm test` có 9 bài test đơn vị, bao gồm: quy đổi, chống mất lượng, kiểm tra tồn, giá vốn, thu nợ phân bổ, hoàn hàng, hàng hỏng.
- `node --check functions/index.js && node --check functions/ledger_ops.js` kiểm tra cú pháp JS.
- Cần bổ sung Firestore Emulator integration test về 2 thiết bị cùng bán/thu nợ/hoàn hàng; kiểm thử timeout và retry trùng request.

## Firebase chi phí
Cloud Functions có thể đòi bật gói Blaze và xác minh phương thức thanh toán. Hạn mức miễn phí không đồng nghĩa không bao giờ phát sinh phí. Thiết lập hạn mức ngân sách và cảnh báo chi phí trước khi triển khai.
