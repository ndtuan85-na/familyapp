import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import 'cloud_sync.dart';
import 'v2_api.dart';

class DeliveryPlannerScreen extends StatefulWidget {
  const DeliveryPlannerScreen({super.key});
  @override
  State<DeliveryPlannerScreen> createState() => _DeliveryPlannerScreenState();
}

class _DeliveryPlannerScreenState extends State<DeliveryPlannerScreen> {
  final Set<String> selected = {};
  final note = TextEditingController();
  DateTime scheduled = DateTime.now().add(const Duration(hours: 1));
  int remindHours = 1;
  bool busy = false;
  static final _date = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void dispose() { note.dispose(); super.dispose(); }

  Future<void> _chooseCustomers(List<QueryDocumentSnapshot<Map<String, dynamic>>> customers) async {
    final draft = Set<String>.of(selected);
    final result = await showDialog<Set<String>>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, refresh) => AlertDialog(
      title: const Text('Chọn khách giao hàng'),
      content: SizedBox(width: 420, height: 420, child: customers.isEmpty
          ? const Center(child: Text('Chưa có khách hàng. Thêm khách trong mục Danh mục.'))
          : ListView(children: [for (final customer in customers) CheckboxListTile(
              value: draft.contains(customer.id),
              title: Text('${customer.data()['name'] ?? customer.id}'),
              subtitle: Text('${customer.data()['phone'] ?? ''}'),
              onChanged: (value) => refresh(() { if (value == true) { draft.add(customer.id); } else { draft.remove(customer.id); } }),
            )])),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy')), FilledButton(onPressed: () => Navigator.pop(ctx, draft), child: Text('Chọn (${draft.length})'))],
    )));
    if (result != null && mounted) setState(() { selected..clear()..addAll(result); });
  }

  Future<void> _chooseDate() async {
    final day = await showDatePicker(context: context, initialDate: scheduled, firstDate: DateTime.now().subtract(const Duration(days: 1)), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (day == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(scheduled));
    if (time == null || !mounted) return;
    setState(() => scheduled = DateTime(day.year, day.month, day.day, time.hour, time.minute));
  }

  Future<void> _create(List<QueryDocumentSnapshot<Map<String, dynamic>>> customers) async {
    if (selected.isEmpty) { _message('Chọn ít nhất một khách hàng.'); return; }
    if (scheduled.isBefore(DateTime.now())) { _message('Giờ giao phải ở thời điểm hiện tại hoặc tương lai.'); return; }
    final chosenCount = selected.length;
    setState(() => busy = true);
    try {
      await FamilyApi.createDeliverySchedule({
        'idempotencyKey': const Uuid().v4(),
        'customerIds': selected.toList(),
        'scheduledAt': scheduled.toUtc().toIso8601String(),
        'remindHours': remindHours,
        'note': note.text.trim(),
      });
      if (!mounted) return;
      setState(() { selected.clear(); note.clear(); });
      _message('Đã tạo lịch giao cho $chosenCount khách.');
    } catch (e) {
      if (mounted) _message('Chưa tạo được lịch. Kiểm tra đăng nhập và triển khai Cloud Functions bản mới: $e');
    } finally { if (mounted) setState(() => busy = false); }
  }

  void _message(String value) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));

  Future<void> _update(String id, String action) async {
    try { await FamilyApi.updateDeliverySchedule(id, action); }
    catch (e) { if (mounted) _message('Chưa cập nhật được lịch: $e'); }
  }

  @override
  Widget build(BuildContext context) {
    if (!CloudSync.instance.ready || CloudSync.instance.householdId == null) return const Scaffold(body: Center(child: Text('Đăng nhập tài khoản gia đình để lập lịch giao.')));
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch giao hàng')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FamilyApi.collection('customers').orderBy('name').snapshots(),
        builder: (context, customerSnap) {
          if (customerSnap.hasError) return Center(child: Text('Không tải được khách hàng: ${customerSnap.error}'));
          if (!customerSnap.hasData) return const Center(child: CircularProgressIndicator());
          final customers = customerSnap.data!.docs;
          final names = {for (final c in customers) c.id: '${c.data()['name'] ?? c.id}'};
          return ListView(padding: const EdgeInsets.all(12), children: [
            Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Lập một lịch cho nhiều khách', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              OutlinedButton.icon(onPressed: () => _chooseCustomers(customers), icon: const Icon(Icons.group_add_outlined), label: Text(selected.isEmpty ? 'Chọn khách hàng' : 'Đã chọn ${selected.length} khách')),
              if (selected.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(selected.map((id) => names[id] ?? id).join(' · '))),
              OutlinedButton.icon(onPressed: _chooseDate, icon: const Icon(Icons.schedule), label: Text(_date.format(scheduled))),
              DropdownButtonFormField<int>(value: remindHours, decoration: const InputDecoration(labelText: 'Nhắc trước giờ giao'), items: const [0, 1, 2, 4, 12, 24].map((h) => DropdownMenuItem(value: h, child: Text(h == 0 ? 'Đúng giờ' : '$h giờ'))).toList(), onChanged: (v) { if (v != null) setState(() => remindHours = v); }),
              TextField(controller: note, maxLength: 500, decoration: const InputDecoration(labelText: 'Ghi chú (tùy chọn)', hintText: 'Tuyến giao, địa chỉ hoặc lưu ý')),
              Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: busy ? null : () => _create(customers), icon: const Icon(Icons.add_task), label: Text(busy ? 'Đang lưu…' : 'Tạo lịch'))),
            ]))),
            const Padding(padding: EdgeInsets.fromLTRB(4, 10, 4, 4), child: Text('Các lịch của gia đình', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18))),
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FamilyApi.collection('deliverySchedules').snapshots(),
              builder: (context, snap) {
                if (snap.hasError) return Padding(padding: const EdgeInsets.all(16), child: Text('Không tải được lịch: ${snap.error}'));
                if (!snap.hasData) return const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
                final docs = [...snap.data!.docs]..sort((a, b) {
                  final first = a.data()['scheduledAt'] as Timestamp?;
                  final second = b.data()['scheduledAt'] as Timestamp?;
                  if (first == null) return second == null ? 0 : 1;
                  if (second == null) return -1;
                  return first.compareTo(second);
                });
                if (docs.isEmpty) return const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Chưa có lịch giao.')));
                return Column(children: [for (final doc in docs) _scheduleCard(doc)]);
              },
            ),
          ]);
        },
      ),
    );
  }

  Widget _scheduleCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final row = doc.data();
    final at = (row['scheduledAt'] as Timestamp?)?.toDate().toLocal();
    final status = '${row['status'] ?? 'pending'}';
    final names = ((row['customerNames'] as List?) ?? const []).join(', ');
    return Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Icon(Icons.local_shipping_outlined), const SizedBox(width: 8), Expanded(child: Text(names, style: const TextStyle(fontWeight: FontWeight.w700))), Chip(label: Text({'pending':'Chờ giao','completed':'Đã giao','cancelled':'Đã hủy'}[status] ?? status))]),
      Text('Giờ giao: ${at == null ? '—' : _date.format(at)}'),
      if ((row['note'] as String? ?? '').isNotEmpty) Text('Ghi chú: ${row['note']}'),
      if (status == 'pending') Wrap(alignment: WrapAlignment.end, children: [TextButton(onPressed: () => _update(doc.id, 'cancel'), child: const Text('Hủy lịch')), FilledButton.icon(onPressed: () => _update(doc.id, 'complete'), icon: const Icon(Icons.done), label: const Text('Đã giao'))]),
    ])));
  }
}

