import 'package:flutter_test/flutter_test.dart';
import 'package:seafood_family_app/logic.dart';
import 'package:seafood_family_app/models.dart';
void main() {
  test('Tiền với số lượng lẻ không dùng double', () {
    expect(lineTotal(200000,1250),250000);
    expect(lineTotal(95000,500),47500);
  });
  test('Thu nợ không ghi tăng doanh thu lần hai', () {
    final events = [
      const Entry('a','sale','2026-10-13T01:00:00Z', {'customerId':'C','productId':'P','unitPrice':100000,'qtyMilli':2000,'cogs':120000}),
      const Entry('b','payment','2026-10-13T02:00:00Z', {'customerId':'C','amount':50000}),
    ];
    final s=Business.stats(events);
    expect(s.revenue,200000); expect(s.collected,50000); expect(s.receivable,150000);
    expect(Business.customerDebt('C',events),150000);
    expect(s.profit,80000);
  });
  test('Tính tồn và đơn giá vốn cơ bản', () {
    final records = [
      const Entry('p','purchase','2026-10-13T01:00:00Z',{'productId':'X','qtyMilli':10000,'unitPrice':100000}),
      const Entry('s','sale','2026-10-13T02:00:00Z',{'productId':'X','qtyMilli':2000,'unitPrice':130000,'cogs':200000}),
    ];
    expect(Business.stockMilli('X',records),8000);
    expect(Business.currentUnitCost('X',records),100000);
  });
}
