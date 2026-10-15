import 'models.dart';

class Stats {
  final int revenue, cogs, expenses, collected, receivable, stockValue;
  const Stats(this.revenue, this.cogs, this.expenses, this.collected, this.receivable, this.stockValue);
  int get profit => revenue - cogs - expenses;
}

class Business {
  static int stockMilli(String productId, List<Entry> records) {
    int n = 0;
    for (final e in records) {
      if (e.data['productId'] != productId) continue;
      if (e.kind == 'purchase') n += quantity(e.data['qtyMilli']);
      if (e.kind == 'sale') n -= quantity(e.data['qtyMilli']);
    }
    return n;
  }

  // Giá vốn bình quân di động: replay giao dịch theo createdAt, ID.
  // Phiên bản MVP giả định nhập và bán theo thứ tự thời gian ghi nhận.
  static int currentUnitCost(String productId, List<Entry> records) {
    final sorted = records.where((e) => e.data['productId'] == productId).toList()
      ..sort((a,b) { final n = a.createdAt.compareTo(b.createdAt); return n != 0 ? n : a.id.compareTo(b.id); });
    int inventoryMilli = 0, inventoryValue = 0;
    for (final e in sorted) {
      final q = quantity(e.data['qtyMilli']);
      if (e.kind == 'purchase') {
        inventoryMilli += q;
        inventoryValue += lineTotal(money(e.data['unitPrice']), q);
      } else if (e.kind == 'sale') {
        final assignedCost = money(e.data['cogs']);
        inventoryMilli -= q;
        inventoryValue -= assignedCost;
        if (inventoryMilli == 0) inventoryValue = 0;
      }
    }
    return inventoryMilli > 0 ? (inventoryValue * 1000 / inventoryMilli).round() : 0;
  }

  static Stats stats(List<Entry> records, {DateTime? day}) {
    bool include(Entry e) => day == null || (DateTime.tryParse(e.createdAt)?.toLocal().year == day.year && DateTime.tryParse(e.createdAt)?.toLocal().month == day.month && DateTime.tryParse(e.createdAt)?.toLocal().day == day.day);
    int revenue = 0, cogs = 0, expenses = 0, collected = 0, receivable = 0;
    for (final e in records) {
      if (e.kind == 'sale') {
        final saleTotal = lineTotal(money(e.data['unitPrice']), quantity(e.data['qtyMilli']));
        if (include(e)) { revenue += saleTotal; cogs += money(e.data['cogs']); }
        receivable += saleTotal;
      } else if (e.kind == 'payment') {
        if (include(e)) collected += money(e.data['amount']);
        receivable -= money(e.data['amount']);
      } else if (e.kind == 'expense' && include(e)) {
        expenses += money(e.data['amount']);
      }
    }
    int stockValue = 0;
    for (final p in records.where((e) => e.kind == 'product')) {
      stockValue += lineTotal(currentUnitCost(p.id, records), stockMilli(p.id, records));
    }
    return Stats(revenue, cogs, expenses, collected, receivable, stockValue);
  }

  static int customerDebt(String id, List<Entry> records) {
    int n = 0;
    for (final e in records) {
      if (e.data['customerId'] != id) continue;
      if (e.kind == 'sale') n += lineTotal(money(e.data['unitPrice']), quantity(e.data['qtyMilli']));
      if (e.kind == 'payment') n -= money(e.data['amount']);
    }
    return n;
  }
}
