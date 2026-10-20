import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'cloud_sync.dart';
import 'v2_api.dart';

String _money(dynamic value) =>
    '${NumberFormat.decimalPattern('vi_VN').format((value as num?)?.toInt() ?? 0)} đ';

class BalanceScreen extends StatefulWidget {
  const BalanceScreen({super.key});

  @override
  State<BalanceScreen> createState() => _BalanceScreenState();
}

class _BalanceScreenState extends State<BalanceScreen> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    if (!CloudSync.instance.ready || CloudSync.instance.householdId == null) {
      return const Scaffold(
          body: Center(
              child: Text('Đăng nhập tài khoản gia đình để xem công nợ.')));
    }
    final partyKind = tab == 0 ? 'customers' : 'suppliers';
    final prefix = tab == 0 ? 'customer_' : 'supplier_';
    final title = tab == 0 ? 'Khách còn nợ' : 'Còn nợ nhà cung cấp';
    return Scaffold(
      appBar: AppBar(title: const Text('Công nợ & thanh toán')),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Phải thu khách')),
                ButtonSegment(value: 1, label: Text('Phải trả NCC'))
              ],
              selected: {tab},
              onSelectionChanged: (value) => setState(() => tab = value.first),
            )),
        Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FamilyApi.collection(partyKind).orderBy('name').snapshots(),
          builder: (context, parties) {
            if (parties.hasError)
              return Center(
                  child: Text('Không tải được đối tác: ${parties.error}'));
            if (!parties.hasData)
              return const Center(child: CircularProgressIndicator());
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FamilyApi.collection('balances').snapshots(),
              builder: (context, balances) {
                if (balances.hasError)
                  return Center(
                      child: Text('Không tải được công nợ: ${balances.error}'));
                if (!balances.hasData)
                  return const Center(child: CircularProgressIndicator());
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: FamilyApi.collection('documents').snapshots(),
                  builder: (context, transactions) {
                    if (transactions.hasError)
                      return Center(
                          child: Text(
                              'Không tải được sổ giao dịch: ${transactions.error}'));
                    if (!transactions.hasData)
                      return const Center(child: CircularProgressIndicator());
                    final amounts = <String, int>{};
                    var total = 0;
                    for (final doc in balances.data!.docs) {
                      if (!doc.id.startsWith(prefix)) continue;
                      final id = doc.id.substring(prefix.length);
                      final amount =
                          (doc.data()['balanceVnd'] as num?)?.toInt() ?? 0;
                      amounts[id] = amount;
                      total += amount;
                    }
                    final purchaseTotals = <String, int>{},
                        saleTotals = <String, int>{};
                    final paidTotals = <String, int>{},
                        receivedTotals = <String, int>{};
                    var totalPurchases = 0,
                        totalSales = 0,
                        totalPaid = 0,
                        totalReceived = 0;
                    for (final doc in transactions.data!.docs) {
                      final row = doc.data();
                      if (row['status'] != 'posted') continue;
                      final party = row['counterpartyId']?.toString() ?? '';
                      final kind = row['kind'];
                      final summary = row['summary'] as Map?;
                      final lines = (row['lines'] as List?) ?? const [];
                      final gross = (summary?['grossVnd'] as num?)?.toInt() ??
                          lines.fold<int>(
                              0,
                              (sum, line) =>
                                  sum +
                                  (((line as Map)['total'] as num?)?.toInt() ??
                                      0));
                      final paid = (row['paidVnd'] as num?)?.toInt() ?? 0;
                      if (kind == 'purchase') {
                        final amount =
                            gross + ((row['feeVnd'] as num?)?.toInt() ?? 0);
                        purchaseTotals[party] =
                            (purchaseTotals[party] ?? 0) + amount;
                        paidTotals[party] = (paidTotals[party] ?? 0) + paid;
                        totalPurchases += amount;
                        totalPaid += paid;
                      } else if (kind == 'paySupplier') {
                        paidTotals[party] = (paidTotals[party] ?? 0) + paid;
                        totalPaid += paid;
                      } else if (kind == 'sale') {
                        final amount = gross -
                            ((row['discountVnd'] as num?)?.toInt() ?? 0);
                        saleTotals[party] = (saleTotals[party] ?? 0) + amount;
                        receivedTotals[party] =
                            (receivedTotals[party] ?? 0) + paid;
                        totalSales += amount;
                        totalReceived += paid;
                      } else if (kind == 'collect') {
                        receivedTotals[party] =
                            (receivedTotals[party] ?? 0) + paid;
                        totalReceived += paid;
                      } else if (kind == 'saleReturn') {
                        final refund = (row['refundVnd'] as num?)?.toInt() ?? 0;
                        final cashRefund =
                            (row['cashRefundVnd'] as num?)?.toInt() ?? 0;
                        saleTotals[party] = (saleTotals[party] ?? 0) - refund;
                        receivedTotals[party] =
                            (receivedTotals[party] ?? 0) - cashRefund;
                        totalSales -= refund;
                        totalReceived -= cashRefund;
                      }
                    }
                    final rows = parties.data!.docs;
                    final totalVolume = tab == 0 ? totalSales : totalPurchases;
                    final totalCash = tab == 0 ? totalReceived : totalPaid;
                    return ListView(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                        children: [
                          Card(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primaryContainer,
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                          tab == 0
                                              ? 'Tổng quan bán hàng'
                                              : 'Tổng quan nhập hàng',
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium),
                                      const SizedBox(height: 10),
                                      _summaryLine(
                                          tab == 0
                                              ? 'Tổng tiền bán thuần'
                                              : 'Tổng tiền nhập + phí',
                                          totalVolume),
                                      _summaryLine(
                                          tab == 0
                                              ? 'Đã thu từ khách'
                                              : 'Đã chi trả nhà cung cấp',
                                          totalCash),
                                      _summaryLine(title, total, strong: true),
                                    ]),
                              )),
                          if (rows.isEmpty)
                            const Padding(
                                padding: EdgeInsets.all(24),
                                child: Center(
                                    child: Text(
                                        'Chưa có khách hàng/nhà cung cấp.'))),
                          for (final party in rows)
                            Card(
                                child: ListTile(
                              leading: CircleAvatar(
                                  child: Icon(tab == 0
                                      ? Icons.person_outline
                                      : Icons.storefront_outlined)),
                              title:
                                  Text('${party.data()['name'] ?? party.id}'),
                              subtitle: Text(tab == 0
                                  ? 'Bán: ${_money(saleTotals[party.id] ?? 0)} · Đã thu: ${_money(receivedTotals[party.id] ?? 0)}'
                                  : 'Nhập + phí: ${_money(purchaseTotals[party.id] ?? 0)} · Đã trả: ${_money(paidTotals[party.id] ?? 0)}'),
                              isThreeLine: true,
                              trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(_money(amounts[party.id] ?? 0),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    Text(
                                        (amounts[party.id] ?? 0) > 0
                                            ? 'Còn nợ'
                                            : 'Đã cân',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall),
                                  ]),
                              onTap: (amounts[party.id] ?? 0) > 0
                                  ? () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) => SettlementScreen(
                                                partyId: party.id,
                                                partyName:
                                                    '${party.data()['name'] ?? party.id}',
                                                kind: tab == 0
                                                    ? 'collect'
                                                    : 'paySupplier',
                                                amountDue:
                                                    amounts[party.id] ?? 0,
                                              )))
                                  : null,
                            )),
                        ]);
                  },
                );
              },
            );
          },
        )),
      ]),
    );
  }

  Widget _summaryLine(String label, int amount, {bool strong = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(
              child: Text(label,
                  style: strong
                      ? const TextStyle(fontWeight: FontWeight.w700)
                      : null)),
          Text(_money(amount),
              style:
                  strong ? const TextStyle(fontWeight: FontWeight.w800) : null)
        ]),
      );
}

class SettlementScreen extends StatefulWidget {
  final String partyId;
  final String partyName;
  final String kind;
  final int amountDue;
  const SettlementScreen(
      {super.key,
      required this.partyId,
      required this.partyName,
      required this.kind,
      required this.amountDue});

  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen> {
  final amount = TextEditingController();
  bool busy = false;
  @override
  void dispose() {
    amount.dispose();
    super.dispose();
  }

  void message(String text) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> submit() async {
    final requested =
        int.tryParse(amount.text.replaceAll(RegExp(r'[^0-9]'), ''));
    if (requested == null || requested <= 0) {
      message('Nhập số tiền lớn hơn 0.');
      return;
    }
    if (requested > widget.amountDue) {
      message('Số tiền vượt công nợ hiện tại ${_money(widget.amountDue)}.');
      return;
    }
    if (busy) return;
    setState(() => busy = true);
    try {
      final kind = widget.kind;
      final docs = await FamilyApi.collection('documents')
          .get(const GetOptions(source: Source.server));
      final open = docs.docs.where((doc) {
        final row = doc.data();
        return row['status'] == 'posted' &&
            row['kind'] == (kind == 'collect' ? 'sale' : 'purchase') &&
            row['counterpartyId'] == widget.partyId &&
            ((row['dueVnd'] as num?)?.toInt() ?? 0) > 0;
      }).toList()
        ..sort((a, b) {
          final ad = a.data()['createdAt'];
          final bd = b.data()['createdAt'];
          final at = ad is Timestamp ? ad.millisecondsSinceEpoch : 0;
          final bt = bd is Timestamp ? bd.millisecondsSinceEpoch : 0;
          return at.compareTo(bt);
        });
      var remaining = requested;
      final allocations = <Map<String, dynamic>>[];
      for (final doc in open) {
        if (remaining == 0) break;
        final due = (doc.data()['dueVnd'] as num?)?.toInt() ?? 0;
        final part = remaining < due ? remaining : due;
        if (part > 0) allocations.add({'id': doc.id, 'amountVnd': part});
        remaining -= part;
      }
      if (remaining > 0)
        throw StateError(
            'Tổng công nợ trên các phiếu thấp hơn số dư hiển thị. Hãy tải lại để cập nhật.');
      if (allocations.length > 100)
        throw StateError(
            'Khoản này cần phân bổ vào hơn 100 phiếu. Hãy thanh toán thành nhiều lần.');
      final result = await BookkeepingOperations.settle({
        'idempotencyKey': const Uuid().v4(),
        'kind': kind,
        'counterpartyId': widget.partyId,
        'amountVnd': requested,
        'allocations': allocations,
      });
      message(
          'Đã ${kind == 'collect' ? 'thu' : 'trả'} ${_money(result['paidVnd'] ?? requested)}. Công nợ còn ${_money(result['remainingBalanceVnd'])}.');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      message('Chưa ghi được phiếu: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final collect = widget.kind == 'collect';
    return Scaffold(
      appBar: AppBar(
          title: Text(
              collect ? 'Phiếu thu tiền khách' : 'Phiếu trả nhà cung cấp')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Card(
            child: ListTile(
                title: Text(widget.partyName),
                subtitle:
                    Text('Công nợ hiện tại: ${_money(widget.amountDue)}'))),
        const SizedBox(height: 16),
        TextField(
            controller: amount,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: collect ? 'Số tiền thu (VND)' : 'Số tiền trả (VND)',
              helperText: 'Số tiền được tự phân bổ từ phiếu cũ nhất trước.',
              border: const OutlineInputBorder(),
            )),
        const SizedBox(height: 20),
        FilledButton.icon(
            onPressed: busy ? null : submit,
            icon: const Icon(Icons.check),
            label: Text(
                busy ? 'Đang ghi…' : 'Ghi phiếu ${collect ? 'thu' : 'trả'}')),
      ]),
    );
  }
}

