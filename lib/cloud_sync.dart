import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'firebase_options.dart';
import 'models.dart';
import 'store.dart';

class CloudSync {
  CloudSync._();
  static final instance = CloudSync._();
  bool ready = false;
  String? householdId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  Future<String?> initialize() async {
    try {
      if (kIsWeb) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.web);
      } else {
        // Android keeps using its native Firebase configuration when one is added.
        await Firebase.initializeApp();
      }
      ready = true;
      return null;
    } catch (e) {
      ready = false;
      return 'Chưa cấu hình Firebase: $e';
    }
  }

  Future<void> login(String email, String password) async {
    if (!ready) throw StateError('Chưa cấu hình Firebase. Xem README.');
    final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: password);
    final uid = credential.user!.uid;
    final member = await FirebaseFirestore.instance.collection('members').doc(uid).get();
    final hid = member.data()?['householdId'];
    if (hid is! String || hid.isEmpty) {
      await FirebaseAuth.instance.signOut();
      throw StateError('Tài khoản chưa được cấp quyền tham gia hộ gia đình.');
    }
    householdId = hid;
    await _subscription?.cancel();
    _subscription = FirebaseFirestore.instance.collection('households').doc(hid).collection('entries').snapshots().listen((snapshot) async {
      for (final change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.removed) continue;
        final data = change.doc.data();
        if (data == null) continue;
        try {
          await Store.instance.acceptRemote(Entry(data['id'] as String, data['kind'] as String, data['created_at'] as String, Map<String, dynamic>.from(data['payload'] as Map)));
        } catch (_) { /* Dữ liệu lỗi được bỏ qua, không phá bản ghi khác. */ }
      }
    });
    // v0.2: KHÔNG tự đẩy outbox v0.1 lên Firestore; nghiệp vụ phải qua Cloud Functions.
  }

  Future<int> sync() async {
    // Sổ tài chính 0.2 được đọc qua Firestore snapshots; tránh đẩy phiếu local không kiểm soát.
    return 0;
  }
  Future<void> logout() async {
    await _subscription?.cancel();
    householdId = null;
    if (ready) await FirebaseAuth.instance.signOut();
  }
}
