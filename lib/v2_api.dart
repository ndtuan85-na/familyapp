import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'cloud_sync.dart';

class FamilyApi {
  static String get household =>
      CloudSync.instance.householdId ??
      (throw StateError('Đăng nhập để xác nhận phiếu trên nhiều điện thoại.'));
  static CollectionReference<Map<String, dynamic>> collection(String name) =>
      FirebaseFirestore.instance
          .collection('households')
          .doc(household)
          .collection(name);
  static Future<Map<String, dynamic>> post(Map<String, dynamic> payload) async {
    final r = await FirebaseFunctions.instance
        .httpsCallable('postDocument')
        .call(payload);
    return Map<String, dynamic>.from(r.data as Map);
  }

  static Future<Map<String, dynamic>?> operationStatus(String key) async {
    final snap = await collection('documents')
        .doc(key)
        .get(const GetOptions(source: Source.server));
    return snap.exists
        ? <String, dynamic>{'id': snap.id, ...?snap.data()}
        : null;
  }

  static Future<void> master(
      String kind, String id, Map<String, dynamic> data) async {
    await FirebaseFunctions.instance
        .httpsCallable('upsertMaster')
        .call({'kind': kind, 'id': id, 'data': data});
  }

  static Future<Map<String, dynamic>> seedCatalog() async {
    final r =
        await FirebaseFunctions.instance.httpsCallable('seedCatalog').call();
    return Map<String, dynamic>.from(r.data as Map);
  }

  static Future<String> exportJson() async {
    final result = <String, dynamic>{
      'schemaVersion': 2,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'householdId': household
    };
    for (final kind in [
      'products',
      'customers',
      'suppliers',
      'stock',
      'balances',
      'documents'
    ]) {
      final snapshots =
          await collection(kind).get(const GetOptions(source: Source.server));
      result[kind] = snapshots.docs
          .map((d) => {'id': d.id, ..._jsonReady(d.data())})
          .toList();
    }
    return const JsonEncoder.withIndent('  ').convert(result);
  }

  static Map<String, dynamic> _jsonReady(Map<String, dynamic> d) =>
      d.map((k, v) => MapEntry(
          k,
          v is Timestamp
              ? v.toDate().toUtc().toIso8601String()
              : v is Map
                  ? _jsonReady(Map<String, dynamic>.from(v))
                  : v));
}

extension BookkeepingOperations on FamilyApi {
  static Future<Map<String, dynamic>> settle(
      Map<String, dynamic> payload) async {
    final r = await FirebaseFunctions.instance
        .httpsCallable('settleDocument')
        .call(payload);
    return Map<String, dynamic>.from(r.data as Map);
  }

  static Future<Map<String, dynamic>> returnSale(
      Map<String, dynamic> payload) async {
    final r = await FirebaseFunctions.instance
        .httpsCallable('returnSale')
        .call(payload);
    return Map<String, dynamic>.from(r.data as Map);
  }
}

extension CancelPurchaseOperation on FamilyApi {
  static Future<Map<String, dynamic>> cancelPurchase(
      Map<String, dynamic> payload) async {
    final r = await FirebaseFunctions.instance
        .httpsCallable('cancelPurchase')
        .call(payload);
    return Map<String, dynamic>.from(r.data as Map);
  }
}

