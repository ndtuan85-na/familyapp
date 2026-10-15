# Seafood Family 0.2 — bàn giao mã nguồn phát triển (CHƯA sẵn sàng sử dụng thực tế)

## Tình trạng triển khai
- Có: `functions/postDocument` xác nhận phiếu nhập/bán nhiều dòng, thanh toán khách hàng/nhà cung cấp theo transaction Firestore, giá vốn bình quân, kiểm tra tồn và idempotency key.
- Có: nhập phiếu nhiều dòng Flutter (`lib/v2_screen.dart`), đọc sổ online, xuất bản sao lưu JSON qua Share Sheet.
- Có: danh mục 47 mặt hàng vùng biển Quỳnh Lưu mở rộng (`assets/quynh_luu_seafood.csv`), file seed không gán giá hay trọng lượng thùng cố định.
- Chưa có đầy đủ: hoàn/hủy chứng từ đã xác nhận, trả hàng một phần, khôi phục sao lưu an toàn, UI quản lý quy đổi theo lô, UI thu nợ, UI phân quyền quản trị, bản nháp offline nhiều dòng, kiểm thử giao dịch thực tế 2 điện thoại, các báo cáo mới trên sổ online, build APK/IPA.
- **Không nhập dữ liệu kinh doanh thật khi chưa hoàn thiện và thử nghiệm đủ**. Màn hình tổng quan MVP 0.1 vẫn hiển thị sổ cũ, không phản ánh chứng từ Firebase 0.2. Không được dùng kết quả đó để quyết toán.

## An toàn giao dịch
Chứng từ tài chính **chỉ xác nhận khi online**. Clients không có quyền ghi Firestore trực tiếp (firestore.rules); chỉ Admin SDK trong Cloud Functions thực hiện transaction. Trường `idempotencyKey` phải được lưu cùng bản nháp và tái sử dụng khi retry; UI hiện tạo key khi bấm xác nhận, chưa lưu key qua phiên khởi động lại. Không khẳng định chống trùng hoàn toàn qua vòng đời ứng dụng.

## Đơn vị tính
Sản phẩm có `baseUnit` ví dụ `kg`, `units` dạng `{"khay":2500, "thùng":-1}`. Hệ số 2500 có nghĩa 1 khay = 2.5 kg; -1 cho phép khối lượng thực tế theo từng phiếu (ví dụ 12.5 kg/thùng => 12500). Với `con` không rõ trọng lượng, người dùng phải ghi khối lượng thực tế; không mặc định số con bằng kg. Số lượng mỗi dòng `quantityMilli` là 1/1000 đơn vị giao dịch; `factorMilli` là 1/1000 đơn vị chuẩn / đơn vị giao dịch. Phép nhân phải chia hết cho 1000 ở mức số lượng nhỏ nhất.

## Thiết lập
1. Cài Flutter/Dart, Android SDK; riêng iOS cần macOS, Xcode và Apple signing.
2. `flutter create --platforms=android,ios .` rồi `flutter pub get`.
3. Tạo Firebase project, bật Authentication Email/Password, Firestore, Cloud Functions. Functions có thể yêu cầu bật Blaze/billing, **không đảm bảo hoàn toàn miễn phí**.
4. `flutterfire configure` và chỉnh `Firebase.initializeApp` phù hợp với firebase_options.dart đã sinh.
5. Trong Firebase Admin Console tạo `members/{firebaseAuthUid}` với `{householdId:"family01"}` bằng tài khoản quản trị tin cậy. Tuyệt đối không cho user tự ghi members.
6. `firebase deploy --only firestore:rules,functions` (cần `npm install` trong thư mục functions).
7. Chạy `cd functions && node seed_catalog.js --household=family01` xem trước; `node seed_catalog.js --household=family01 --commit` khi đã cấu hình GOOGLE_APPLICATION_CREDENTIALS đủ quyền. Seed thêm sản phẩm chưa có, không ghi đè.
8. `flutter run` để kiểm tra giao diện (chưa được kiểm chứng trong môi trường tạo mã nguồn này).
9. `cd functions && node --test` để chạy kiểm tra số học thuần; chưa phải bài test integration Firestore.

## Lưu ý về dữ liệu cũ
Sổ v0.1 ghi SQLite và đồng bộ thẳng /entries; v0.2 cố tình khóa ghi /entries để tránh hai nguồn sự thật. Cần xây dựng công cụ chuyển dữ liệu v0.1 sang chứng từ v0.2 sau khi rà soát trước khi triển khai thật. Chưa có công cụ migration.

## Nguồn tham khảo nhóm hàng
- Đài PTTH Nghệ An: https://truyenhinhnghean.vn/kinh-te/201007/quynh-luu-hieu-qua-cua-phat-trien-ngu-luoi-cu-637876/
- Ban Quản lý di tích Nghệ An: https://banquanlyditichnghean.gov.vn/article_details/kham-pha-ve-dep-cua-nhung-thien-duong-bien-o-nghe-an
- Đài PTTH Nghệ An: https://truyenhinhnghean.vn/kinh-te/202403/ngu-dan-quynh-luu-trung-dam-ca-trich-thu-tien-trieu-moi-chuyen-5d4410a/
- Hải sản Quỳnh Lưu: https://vidas.vn/dac-san---hai-san-bien-quynh-luu-shop1324.html
- Nguồn hàng `extended` chỉ là gợi ý danh mục phổ biến bổ sung, không phải chứng nhận từng loài được khai thác tại Quỳnh Lưu.
