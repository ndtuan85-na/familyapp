import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'cloud_sync.dart';
import 'v2_api.dart';

String _orderMoney(dynamic value) =>
    '${NumberFormat.decimalPattern('vi_VN').format((value as num?)?.toInt() ?? 0)} đ';
DateTime? _orderTime(dynamic value) => value is Timestamp ? value.toDate().toLocal() : null;

class OrderManagementScreen extends StatefulWidget {
  const OrderManagementScreen({super.key});
  @override
  State<OrderManagementScreen> createState() => _OrderManagementScreenState();
}

class _OrderManagementScreenState extends State<OrderManagementScreen> {
  String kind = 'purchase';
  String status = 'pending';
  final Set<String> busyIds = {};
  final Set<String> selectedIds = {};

  Future<void> _act(String id, bool confirm) async {
    if (busyIds.contains(id)) return;
    setState(() => busyIds.add(id));
    try {
      if (confirm) {
        await FamilyApi.confirmOrder(id);
      } else {
        await FamilyApi.cancelOrder(id);
      }
      selectedIds.remove(id);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(confirm ? 'Đã xác nhận và ghi sổ.' : 'Đã hủy phiếu.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Chưa cập nhật được phiếu: $e')));
    } finally {
      if (mounted) setState(() => busyIds.remove(id));
    }
  }

  Future<void> _confirmSelected(List<QueryDocumentSnapshot<Map<String, dynamic>>> rows) async {
    final selected = rows.where((row) => selectedIds.contains(row.id)).toList()
      ..sort((a, b) => (_orderTime(a.data()['scheduledAt']) ?? DateTime(0)).compareTo(_orderTime(b.data()['scheduledAt']) ?? DateTime(0)));
    if (selected.isEmpty || busyIds.isNotEmpty) return;
    final ok = await _ask('Xác nhận ${selected.length} phiếu?', 'Mỗi phiếu sẽ cập nhật riêng vào tồn kho, công nợ và sổ giao dịch. Phiếu lỗi sẽ được giữ lại để xử lý.');
    if (!ok || !mounted) return;
    setState(() => busyIds.addAll(selected.map((d) => d.id)));
    var completed = 0;
    final failedIds = <String>{};
    for (final doc in selected) {
      try {
        await FamilyApi.confirmOrder(doc.id);
        completed++;
      } catch (e) {
        failedIds.add(doc.id);
      }
    }
    if (!mounted) return;
    setState(() { busyIds.removeAll(selected.map((d) => d.id)); selectedIds.removeAll(selected.map((d) => d.id).where((id) => !failedIds.contains(id))); });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failedIds.isEmpty ? 'Đã xác nhận $completed phiếu.' : 'Đã xác nhận $completed phiếu; ${failedIds.length} phiếu cần thử lại.')));
  }

  Future<bool> _ask(String title, String body) async =>
      await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
        title: Text(title), content: Text(body),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Để sau')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Xác nhận'))],
      )) ?? false;

  @override
  Widget build(BuildContext context) {
    if (!CloudSync.instance.ready || CloudSync.instance.householdId == null) {
      return const Scaffold(body: Center(child: Text('Đăng nhập tài khoản gia đình để xem phiếu.')));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Theo dõi nhập / xuất hàng')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 4), child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'purchase', icon: Icon(Icons.move_to_inbox_outlined), label: Text('Nhập hàng')),
            ButtonSegment(value: 'sale', icon: Icon(Icons.local_shipping_outlined), label: Text('Xuất hàng')),
          ], selected: {kind}, onSelectionChanged: (v) => setState(() { kind = v.first; selectedIds.clear(); }),
        )),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'pending', label: Text('Chờ xác nhận')),
            ButtonSegment(value: 'confirmed', label: Text('Đã xác nhận')),
            ButtonSegment(value: 'cancelled', label: Text('Đã hủy')),
          ], selected: {status}, onSelectionChanged: (v) => setState(() { status = v.first; selectedIds.clear(); }),
        )),
        Expanded(child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FamilyApi.collection('orders').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('Không tải được danh sách phiếu: ${snapshot.error}'));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final rows = snapshot.data!.docs.where((d) => d.data()['kind'] == kind && d.data()['status'] == status).toList();
            rows.sort((a, b) => (_orderTime(a.data()['scheduledAt']) ?? DateTime(0)).compareTo(_orderTime(b.data()['scheduledAt']) ?? DateTime(0)));
            if (status != 'pending') rows.sort((a, b) => (_orderTime(b.data()['confirmedAt'] ?? b.data()['cancelledAt'] ?? b.data()['createdAt']) ?? DateTime(0)).compareTo(_orderTime(a.data()['confirmedAt'] ?? a.data()['cancelledAt'] ?? a.data()['createdAt']) ?? DateTime(0)));
            if (rows.isEmpty) return Center(child: Text(status == 'pending' ? 'Chưa có phiếu nào đang chờ.' : 'Chưa có phiếu trong mục này.'));
            final showBulk = status == 'pending' && selectedIds.isNotEmpty;
            return ListView.builder(padding: const EdgeInsets.all(12), itemCount: rows.length + (showBulk ? 1 : 0), itemBuilder: (context, i) {
              if (showBulk && i == 0) return Card(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: Row(children: [Text('Đã chọn ${selectedIds.length}'), const Spacer(), TextButton(onPressed: () => setState(selectedIds.clear), child: const Text('Bỏ chọn')), FilledButton.icon(onPressed: busyIds.isNotEmpty ? null : () => _confirmSelected(rows), icon: const Icon(Icons.done_all), label: const Text('Xác nhận đã nhập/xuất'))])));
              final doc = rows[i - (showBulk ? 1 : 0)], row = doc.data();
              final scheduled = _orderTime(row['scheduledAt']);
              final lines = (row['lines'] as List?) ?? const [];
              final total = (row['grossVnd'] as num?)?.toInt() ?? 0;
              final net = total + ((row['feeVnd'] as num?)?.toInt() ?? 0) - ((row['discountVnd'] as num?)?.toInt() ?? 0);
              final overdue = status == 'pending' && scheduled != null && scheduled.isBefore(DateTime.now());
              return Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [if (status == 'pending') Checkbox(value: selectedIds.contains(doc.id), onChanged: (value) => setState(() { if (value == true) { selectedIds.add(doc.id); } else { selectedIds.remove(doc.id); } })) else const Icon(Icons.receipt_long_outlined), Expanded(child: Text('${row['counterpartyName'] ?? 'Đối tác'}', style: Theme.of(context).textTheme.titleMedium)),
                  if (overdue) const Chip(avatar: Icon(Icons.warning_amber_rounded, size: 18), label: Text('Quá giờ'))]),
                const SizedBox(height: 4),
                Text('${kind == 'purchase' ? 'Dự kiến nhập' : 'Dự kiến xuất'}: ${scheduled == null ? 'Chưa đặt lịch' : DateFormat('dd/MM/yyyy HH:mm').format(scheduled)}'),
                const Divider(height: 18),
                for (final line in lines) Text('• ${line['productName'] ?? line['productId']}  ${line['quantityMilli'] is num ? ((line['quantityMilli'] as num).toDouble() / 1000).toStringAsFixed(3).replaceAll(RegExp(r'\.0+$'), '') : ''} ${line['unit'] ?? ''} × ${_orderMoney(line['unitPrice'])}'),
                const SizedBox(height: 8),
                Text('${lines.length} mặt hàng · Tổng ${_orderMoney(net)}', style: const TextStyle(fontWeight: FontWeight.w700)),
                if (status == 'pending') ...[
                  const SizedBox(height: 8),
                  Wrap(alignment: WrapAlignment.end, spacing: 8, children: [
                    TextButton.icon(onPressed: busyIds.contains(doc.id) ? null : () async { if (await _ask('Hủy phiếu?', 'Phiếu chưa được ghi vào kho hay công nợ.')) _act(doc.id, false); }, icon: const Icon(Icons.close), label: const Text('Hủy')),
                    FilledButton.icon(onPressed: busyIds.contains(doc.id) ? null : () async { if (await _ask(kind == 'purchase' ? 'Xác nhận đã nhập?' : 'Xác nhận đã xuất?', 'Sau khi xác nhận, phiếu sẽ cập nhật tồn kho, công nợ và sổ giao dịch.')) _act(doc.id, true); }, icon: Icon(kind == 'purchase' ? Icons.inventory_2_outlined : Icons.local_shipping_outlined), label: Text(busyIds.contains(doc.id) ? 'Đang ghi…' : kind == 'purchase' ? 'Xác nhận đã nhập' : 'Xác nhận đã xuất')),
                  ]),
                ] else if (status == 'confirmed')
                  Text('Đã xác nhận lúc ${DateFormat('dd/MM/yyyy HH:mm').format(_orderTime(row['confirmedAt']) ?? DateTime.now())}', style: Theme.of(context).textTheme.bodySmall),
              ])));
            });
          },
        )),
      ]),
    );
  }
}

class InboxButton extends StatelessWidget {
  const InboxButton({super.key});
  @override
  Widget build(BuildContext context) {
    final household = CloudSync.instance.householdId;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final button = IconButton(tooltip: 'Thông báo gia đình', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationInboxScreen())), icon: const Icon(Icons.notifications_none));
    if (household == null || uid == null) return button;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FamilyApi.collection('notifications').where('unreadFor', arrayContains: uid).snapshots(),
      builder: (context, snapshot) {
        final count = snapshot.data?.docs.length ?? 0;
        return IconButton(tooltip: count == 0 ? 'Thông báo gia đình' : '$count thông báo chưa đọc', onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationInboxScreen())), icon: Badge(isLabelVisible: count > 0, label: Text(count > 99 ? '99+' : '$count'), child: const Icon(Icons.notifications_none)));
      },
    );
  }
}

class NotificationInboxScreen extends StatelessWidget {
  const NotificationInboxScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || CloudSync.instance.householdId == null) return const Scaffold(body: Center(child: Text('Đăng nhập để xem thông báo.')));
    return Scaffold(appBar: AppBar(title: const Text('Tin nhắn gia đình')), body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FamilyApi.collection('notifications').limit(100).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Center(child: Text('Không tải được thông báo: ${snapshot.error}'));
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
        final rows = [...snapshot.data!.docs]..sort((a, b) => (_orderTime(b.data()['createdAt']) ?? DateTime(0)).compareTo(_orderTime(a.data()['createdAt']) ?? DateTime(0)));
        if (rows.isEmpty) return const Center(child: Text('Chưa có thông báo.'));
        return ListView.builder(padding: const EdgeInsets.all(12), itemCount: rows.length, itemBuilder: (context, i) {
          final doc = rows[i], row = doc.data();
          final unread = ((row['unreadFor'] as List?) ?? const []).contains(uid);
          final when = _orderTime(row['createdAt']);
          return Card(child: ListTile(leading: CircleAvatar(child: Icon(unread ? Icons.mark_email_unread_outlined : Icons.drafts_outlined)), title: Text('${row['title'] ?? 'Thông báo'}', style: TextStyle(fontWeight: unread ? FontWeight.w700 : FontWeight.w400)), subtitle: Text('${row['body'] ?? ''}${when == null ? '' : '\n${DateFormat('dd/MM/yyyy HH:mm').format(when)}'}'), isThreeLine: true, trailing: unread ? const Icon(Icons.circle, size: 10, color: Color(0xff087f72)) : null, onTap: unread ? () async { try { await FamilyApi.markNotificationRead(doc.id); } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e'))); } } : null));
        });
      },
    ));
  }
}

