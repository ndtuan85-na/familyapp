import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class Reminders {
  Reminders._();
  static final instance = Reminders._();
  final plugin = FlutterLocalNotificationsPlugin();
  bool initialized = false;
  Future<void> init() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    await plugin.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(requestAlertPermission: true,requestBadgePermission: true,requestSoundPermission: true),
    ));
    await plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
    initialized = true;
  }
  Future<void> schedule(String id, DateTime delivery, int hours, String description) async {
    if (!initialized) await init();
    final when = delivery.subtract(Duration(hours: hours));
    if (!when.isAfter(DateTime.now())) return;
    // hash ổn định cho ID 32-bit trên mỗi thiết bị
    int hash=0;
    for(final c in id.codeUnits) {hash=(hash*31+c)&0x7fffffff;}
    await plugin.zonedSchedule(hash,'Sắp đến giờ giao hải sản', description,
      tz.TZDateTime.from(when,tz.local),
      const NotificationDetails(android: AndroidNotificationDetails('delivery','Lịch giao hàng',channelDescription:'Thông báo nhắc trước lịch giao hải sản',importance:Importance.high,priority:Priority.high),iOS:DarwinNotificationDetails()),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}
