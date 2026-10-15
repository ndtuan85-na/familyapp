# Vá lỗi Flutter analyze v1.0

Thay `lib/screens.dart`, `lib/v2_screen.dart`, `pubspec.yaml` từ gói vá vào dự án đang chạy (không ghi đè thư mục android, Firebase hay file cấu hình khác).

Nếu `test/widget_test.dart` được tạo tự động bằng `flutter create`, thay file đó bằng bài smoke test không đòi hỏi Firebase:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Ứng dụng Flutter dựng widget cơ bản', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('Hải sản gia đình'))));
    expect(find.text('Hải sản gia đình'), findsOneWidget);
  });
}
```

Chạy `flutter pub get`, `flutter analyze`, `flutter test`.

LƯU Ý: `value` là tên tham số của DropdownButtonFormField trên Flutter cũ; trên Flutter mới đây có thể bị đánh dấu deprecated thay vì initialValue. Không thay đổi dependencies hàng loạt. Không khẳng định bản vá đã biên dịch trong môi trường này.
