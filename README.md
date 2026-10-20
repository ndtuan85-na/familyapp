# Hải sản gia đình — Flutter MVP v0.1

Ứng dụng Flutter (Android/iOS) tiếng Việt, SQLite offline, đồng bộ Firestore theo hộ gia đình (2–5 người) sau cấu hình Firebase.

## Có trong mã nguồn

- Danh mục hải sản với đơn vị cơ sở; khách hàng (tên, giới tính, địa chỉ, số điện thoại, nơi làm việc).
- Nhập và bán một mặt hàng trên mỗi chứng từ; giá VND và số lượng lẻ chính xác 3 chữ số; kiểm tra tồn kho **trên dữ liệu hiện có của điện thoại**.
- Thu nợ, chi phí, báo cáo ngày và tháng; giá vốn bình quân đơn giản, snapshot giá vốn khi bán.
- Tạo lịch giao, nhắc trước 1–24 giờ bằng thông báo cục bộ với giờ Việt Nam; thông báo có thể không được phát nếu thiết bị/hệ điều hành chặn.
- Lưu SQLite khi offline; hàng đợi thay đổi gửi Firestore khi đăng nhập và nhấn Đồng bộ. Firestore listener tải thay đổi từ máy khác khi ứng dụng đang chạy.
- Quy tắc Firestore chỉ cho thành viên cùng hộ đọc; không cho ứng dụng sửa/xóa chứng từ đã tạo trên cloud.

## Chạy ứng dụng

Cần cài Flutter SDK, Android Studio và Android SDK (iOS cần macOS + Xcode). Máy xây dựng gói nguồn chưa có Flutter SDK nên **chưa chạy flutter analyze/test/build**.

```bash
flutter create --platforms=android,ios .
flutter pub get
flutter run
```

## Tạo APK bằng GitHub Actions

Không cần cài Flutter hoặc Android Studio trên máy cá nhân. Mỗi lần có commit mới trên nhánh `main`, GitHub tự cài công cụ cần thiết và tạo APK Android. Bạn cũng có thể chạy thủ công:

1. Mở tab **Actions** của repository trên GitHub.
2. Chọn workflow **Build Android APK**, bấm **Run workflow** rồi chọn nhánh `main`.
3. Khi workflow chạy xong, mở lượt chạy đó và tải artifact **seafood-family-android-apk** trong mục **Artifacts**.

Artifact chứa `app-release.apk`, có thể cài trực tiếp trên thiết bị Android để dùng thử. Bản build hiện được ký bằng debug key của Gradle nên phù hợp cài thử; phát hành lên Google Play cần cấu hình khóa ký phát hành riêng.

## Tạo bản web bằng GitHub Actions

Workflow cũng tạo bản web tĩnh. Trong tab **Actions**, mở lượt chạy mới nhất có dấu xanh và tải artifact **seafood-family-web**. Giải nén ZIP; thư mục bên trong chứa các file web đã build để đưa lên dịch vụ hosting tĩnh.

Bản web lưu dữ liệu offline trong IndexedDB của trình duyệt bằng adapter SQLite web đang ở trạng thái thử nghiệm. Dữ liệu đó riêng theo trình duyệt và địa chỉ web; đồng bộ giữa thiết bị cần cấu hình Firebase. Trình duyệt không hỗ trợ lịch nhắc cục bộ giống ứng dụng Android.

Tên package đề xuất: `com.example.seafood_family_app`; cần đổi sang application ID thực tế trước khi phát hành.

## Kích hoạt Firebase

1. Tạo Firebase project. Bật Authentication → Email/Password và Cloud Firestore.
2. Cài Firebase CLI và FlutterFire CLI; chạy `flutterfire configure` trong thư mục dự án để tạo cấu hình của chính dự án. Khi dùng FlutterFire CLI, bạn có thể sửa `main.dart` để khởi tạo bằng `DefaultFirebaseOptions.currentPlatform` từ `firebase_options.dart` nếu cấu hình yêu cầu.
3. Triển khai `firestore.rules` bằng Firebase CLI (`firebase deploy --only firestore:rules`) sau khi trỏ đúng project.
4. Tạo 2–5 tài khoản qua Firebase Authentication console.
5. Dùng Firebase Console / Admin SDK (quyền quản trị) tạo document `members/{uid}` với trường `householdId: 'gia-dinh-001'` cho mỗi tài khoản. **Không cho người dùng tự sửa membership.**
6. Đăng nhập email/mật khẩu ở biểu tượng tài khoản. Đồng bộ các bản ghi trên thiết bị.

### Dùng danh mục trực tuyến

- Sau khi đăng nhập, trang Tổng quan có các nút **Hải sản**, **Khách hàng**, **Nhà cung cấp**, **Công nợ & thu/trả** và **Lập phiếu nhập/bán**.
- Trong mục **Hải sản**, bấm **Nạp danh mục** để nhập 81 mặt hàng Quỳnh Lưu từ tệp CSV có sẵn; mặt hàng đã tồn tại được giữ nguyên. Có thể tự thêm hải sản, khách hàng và nhà cung cấp.
- Những bản ghi này nằm dưới `households/{householdId}/products`, `customers` và `suppliers`. `members/{uid}` chỉ cấp quyền cho thành viên và không phải nơi lưu danh mục.
- Sau khi thay đổi `firestore.rules`, phải sao chép rules mới lên Firebase Console → Firestore Database → Rules và bấm **Publish**. Rules chỉ cho thành viên tạo dữ liệu danh mục; kho, chứng từ và số dư vẫn chỉ được ghi qua máy chủ.

### Nhập/bán và thu/trả tiền trực tuyến

Phiếu nhập và xuất hỗ trợ nhiều mặt hàng. Phiếu mới được tạo ở trạng thái **Chờ xác nhận** và có ngày giờ dự kiến; phiếu chưa xác nhận chưa làm thay đổi tồn kho/công nợ. Khi xác nhận, hệ thống mới ghi sổ giao dịch, cập nhật kho và số dư. Có thể lọc theo nhập/xuất và trạng thái, chọn nhiều phiếu rồi xác nhận cùng lúc. Hộ gia đình nhận tin mới trong hộp thư ứng dụng; hệ thống tạo nhắc khi còn 30 phút đến lịch hoặc đã quá giờ.

Các thao tác dùng Cloud Functions để tính tồn kho và công nợ an toàn theo giao dịch. Mã nguồn Functions nằm trong `functions/` và phải được triển khai lên dự án Firebase để phiếu, thông báo và nhắc lịch hoạt động. Scheduled Functions cần Cloud Scheduler; triển khai Cloud Functions/Scheduler yêu cầu dự án Firebase bật gói Blaze và liên kết tài khoản thanh toán. Nếu chưa triển khai Functions, giao diện web vẫn mở được nhưng không thể tạo/xác nhận phiếu trực tuyến hay nhận thông báo liên tài khoản.

**Quan trọng**: Firestore rules cấm UPDATE/DELETE, còn ứng dụng chỉ tạo bản ghi mới UUID — phù hợp giai đoạn đầu. Nếu người dùng muốn sửa/hủy chứng từ, cần thiết kế sự kiện điều chỉnh và nghiệp vụ bù trừ. Không được sửa thẳng chứng từ.

## Quyền thông báo Android

Sau `flutter create`, bổ sung vào `android/app/src/main/AndroidManifest.xml` ở `<manifest>`:

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

Và trong `<application>`:

```xml
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
  <intent-filter>
    <action android:name="android.intent.action.BOOT_COMPLETED" />
    <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
  </intent-filter>
</receiver>
```

Lưu ý Android cần cấu hình desugaring theo tài liệu `flutter_local_notifications` phiên bản được dùng. Chế độ nhắc hiện tại là `inexactAllowWhileIdle`, tức không bảo đảm đúng phút.

## Giới hạn hiện tại — chưa đạt bản thương mại

1. Nhắc lịch chạy phía máy chủ theo chu kỳ 15 phút, thông báo đến hạn hiển thị trong hộp thư khi thành viên mở ứng dụng; chưa gửi push notification khi đóng trình duyệt.
2. Chưa có thanh toán nhà cung cấp, trả hàng, hủy/điều chỉnh, báo cáo theo khách và theo từng mặt hàng, sao lưu JSON/CSV trong UI.
3. Chưa làm phân quyền chủ cửa hàng/nhân viên ở giao diện; thành viên cùng hộ cùng quyền truy cập trong bản MVP.
4. Chưa có logic xử lý giao dịch đồng thời chống bán vượt tồn giữa hai điện thoại, đồng bộ xung đột hay đảm bảo chi phí giá vốn chính xác nếu đồng bộ giao dịch về sai thứ tự. **Không sử dụng số liệu này làm sổ kế toán chính thức khi nhiều người cùng ghi đồng thời.**
5. Chưa có chỉnh sửa phiếu sau khi tạo; phiếu chờ có thể hủy, phiếu đã ghi sổ cần nghiệp vụ trả hàng/điều chỉnh để bù trừ.
6. Chưa có tích hợp khoá bảo mật, export/restore đầy đủ, phân trang Firestore, rà soát bảo mật và chạy test thiết bị thật.

**Thứ tự hoàn thiện đề xuất**: bộ chứng từ nhiều dòng + đơn vị quy đổi → giao dịch server-side atomic chống âm kho/công nợ → sự kiện hoàn/hủy → lịch giao + cảnh báo trên mọi thiết bị → sao lưu/phân quyền → test phát hành Android/iOS.



