import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'models.dart';

class Store {
  Store._();
  static final instance = Store._();
  Database? _db;
  Future<Database> get db async {
    if (_db != null) return _db!;
    final p = kIsWeb ? 'seafood_family_v1.db' : join(await getDatabasesPath(), 'seafood_family_v1.db');
    _db = await openDatabase(p, version: 1, onCreate: (db, _) async {
      await db.execute('CREATE TABLE entries(id TEXT PRIMARY KEY, kind TEXT NOT NULL, created_at TEXT NOT NULL, data TEXT NOT NULL)');
      await db.execute('CREATE INDEX idx_entries_kind_date ON entries(kind, created_at)');
      await db.execute('CREATE TABLE outbox(id TEXT PRIMARY KEY, queued_at TEXT NOT NULL)');
    });
    return _db!;
  }
  final changes = StreamController<void>.broadcast();

  Future<void> put(Entry e, {bool enqueue = true}) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.insert('entries', e.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      if (enqueue) await txn.insert('outbox', {'id': e.id, 'queued_at': DateTime.now().toUtc().toIso8601String()}, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    changes.add(null);
  }
  Future<List<Entry>> all([String? kind]) async {
    final rows = await (await db).query('entries', where: kind == null ? null : 'kind = ?', whereArgs: kind == null ? null : [kind], orderBy: 'created_at DESC');
    return rows.map(Entry.fromMap).toList();
  }
  Future<List<Entry>> pending() async {
    final rows = await (await db).rawQuery('SELECT e.* FROM entries e INNER JOIN outbox o ON e.id=o.id ORDER BY o.queued_at');
    return rows.map(Entry.fromMap).toList();
  }
  Future<void> ack(String id) async => (await db).delete('outbox', where: 'id=?', whereArgs: [id]);
  Future<void> acceptRemote(Entry e) async {
    final d = await db;
    final local = await d.query('outbox', where: 'id=?', whereArgs: [e.id]);
    if (local.isNotEmpty) return; // không ghi đè thay đổi chưa gửi
    await put(e, enqueue: false);
  }
}

