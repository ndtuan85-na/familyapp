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

Tên package đề xuất: `com.example.seafood_family_app`; cần đổi sang application ID thực tế trước khi phát hành.

## Kích hoạt Firebase

1. Tạo Firebase project. Bật Authentication → Email/Password và Cloud Firestore.
2. Cài Firebase CLI và FlutterFire CLI; chạy `flutterfire configure` trong thư mục dự án để tạo cấu hình của chính dự án. Khi dùng FlutterFire CLI, bạn có thể sửa `main.dart` để khởi tạo bằng `DefaultFirebaseOptions.currentPlatform` từ `firebase_options.dart` nếu cấu hình yêu cầu.
3. Triển khai `firestore.rules` bằng Firebase CLI (`firebase deploy --only firestore:rules`) sau khi trỏ đúng project.
4. Tạo 2–5 tài khoản qua Firebase Authentication console.
5. Dùng Firebase Console / Admin SDK (quyền quản trị) tạo document `members/{uid}` với trường `householdId: 'gia-dinh-001'` cho mỗi tài khoản. **Không cho người dùng tự sửa membership.**
6. Đăng nhập email/mật khẩu ở biểu tượng tài khoản. Đồng bộ các bản ghi trên thiết bị.

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

1. Một phiếu chỉ có một mặt hàng. Chưa có nhiều đơn vị/quy đổi, nhiều bảng giá và lịch sử giá.
2. Chưa có thanh toán nhà cung cấp, trả hàng, hủy/điều chỉnh, báo cáo theo khách và theo từng mặt hàng, sao lưu JSON/CSV trong UI.
3. Chưa làm phân quyền chủ cửa hàng/nhân viên ở giao diện; thành viên cùng hộ cùng quyền truy cập trong bản MVP.
4. Chưa có logic xử lý giao dịch đồng thời chống bán vượt tồn giữa hai điện thoại, đồng bộ xung đột hay đảm bảo chi phí giá vốn chính xác nếu đồng bộ giao dịch về sai thứ tự. **Không sử dụng số liệu này làm sổ kế toán chính thức khi nhiều người cùng ghi đồng thời.**
5. Notification tạo trên điện thoại lập lịch, chưa tự chuyển lịch nhắc đến mọi điện thoại thành viên, chưa hỗ trợ chỉnh/hủy lịch.
6. Chưa có tích hợp khoá bảo mật, export/restore đầy đủ, phân trang Firestore, rà soát bảo mật và chạy test thiết bị thật.

**Thứ tự hoàn thiện đề xuất**: bộ chứng từ nhiều dòng + đơn vị quy đổi → giao dịch server-side atomic chống âm kho/công nợ → sự kiện hoàn/hủy → lịch giao + cảnh báo trên mọi thiết bị → sao lưu/phân quyền → test phát hành Android/iOS.
