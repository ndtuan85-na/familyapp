import 'dart:convert';

class Entry {
  final String id, kind, createdAt;
  final Map<String, dynamic> data;
  const Entry(this.id, this.kind, this.createdAt, this.data);
  Map<String, dynamic> toMap() => {'id': id, 'kind': kind, 'created_at': createdAt, 'data': jsonEncode(data)};
  factory Entry.fromMap(Map<String, dynamic> m) => Entry(m['id'] as String, m['kind'] as String, m['created_at'] as String, jsonDecode(m['data'] as String) as Map<String, dynamic>);
}

// Tiền và tổng tiền là số nguyên VND. Số lượng dùng đơn vị nhỏ nhất (x1000).
int money(Object? v) => (v as num?)?.toInt() ?? 0;
int quantity(Object? v) => (v as num?)?.toInt() ?? 0;
int lineTotal(int price, int quantityMilli) => (price * quantityMilli + 500) ~/ 1000;
int grossProfit(int revenue, int cogs) => revenue - cogs;
int netProfit(int revenue, int cogs, int expenses) => revenue - cogs - expenses;
