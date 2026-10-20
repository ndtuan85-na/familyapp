import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'cloud_sync.dart';
import 'v2_api.dart';

class MasterDataScreen extends StatefulWidget {
  const MasterDataScreen({super.key});

  @override
  State<MasterDataScreen> createState() => _MasterDataScreenState();
}

class _MasterDataScreenState extends State<MasterDataScreen> {
  int tab = 0;
  bool busy = false;
  final search = TextEditingController();

  static const kinds = ['products', 'customers', 'suppliers'];
  static const labels = ['Hải sản', 'Khách hàng', 'Nhà cung cấp'];

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  void message(String value) {
    if (mounted)
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(value)));
  }

  Future<void> addParty() async {
    final isCustomer = tab == 1;
    final name = TextEditingController();
    final phone = TextEditingController();
    final address = TextEditingController();
    final work = TextEditingController();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isCustomer ? 'Thêm khách hàng' : 'Thêm nhà cung cấp'),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
                controller: name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Tên *')),
            TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Số điện thoại')),
            TextField(
                controller: address,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Địa chỉ')),
            if (isCustomer)
              TextField(
                  controller: work,
                  decoration: const InputDecoration(labelText: 'Nơi làm việc')),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                    'name': name.text.trim(),
                    'phone': phone.text.trim(),
                    'address': address.text.trim(),
                    'work': work.text.trim(),
                  }),
              child: const Text('Lưu')),
        ],
      ),
    );
    name.dispose();
    phone.dispose();
    address.dispose();
    work.dispose();
    if (result == null) return;
    if (result['name']!.isEmpty) {
      message('Bạn nhập tên trước nhé.');
      return;
    }
    setState(() => busy = true);
    try {
      await FamilyApi.master(kinds[tab], const Uuid().v4(), result);
      message(isCustomer ? 'Đã thêm khách hàng.' : 'Đã thêm nhà cung cấp.');
    } catch (e) {
      message('Không lưu được: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> seedCatalog() async {
    setState(() => busy = true);
    try {
      final result = await FamilyApi.seedCatalog();
      message(
          'Đã thêm ${result['added'] ?? 0} mặt hàng Quỳnh Lưu; giữ nguyên ${result['skipped'] ?? 0} mặt hàng đã có.');
    } catch (e) {
      message('Chưa nạp được danh mục: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!CloudSync.instance.ready || CloudSync.instance.householdId == null) {
      return const Scaffold(
          body: Center(
              child:
                  Text('Đăng nhập tài khoản gia đình để quản lý danh mục.')));
    }
    final kind = kinds[tab];
    return Scaffold(
      appBar: AppBar(title: const Text('Danh mục & đối tác')),
      floatingActionButton: tab == 0
          ? null
          : FloatingActionButton.extended(
              onPressed: busy ? null : addParty,
              icon: const Icon(Icons.person_add_alt_1_outlined),
              label: Text(tab == 1 ? 'Thêm khách' : 'Thêm nhà cung cấp'),
            ),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SegmentedButton<int>(
              segments: [
                for (var i = 0; i < labels.length; i++)
                  ButtonSegment(value: i, label: Text(labels[i]))
              ],
              selected: {tab},
              onSelectionChanged: (value) => setState(() {
                tab = value.first;
                search.clear();
              }),
            )),
        Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText:
                      tab == 0 ? 'Tìm hải sản' : 'Tìm theo tên hoặc điện thoại',
                  border: const OutlineInputBorder()),
            )),
        if (tab == 0)
          Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Card(
                  child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  const Expanded(
                      child: Text(
                          'Nạp danh mục 81 loại hải sản Quỳnh Lưu. Mặt hàng đã có sẽ được giữ nguyên.')),
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                      onPressed: busy ? null : seedCatalog,
                      child: Text(busy ? 'Đang nạp…' : 'Nạp danh mục')),
                ]),
              ))),
        Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: FamilyApi.collection(kind).orderBy('name').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return Center(
                  child: Text('Không tải được danh mục: ${snapshot.error}'));
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final query = search.text.trim().toLowerCase();
            final docs = snapshot.data!.docs.where((doc) {
              final data = doc.data();
              return '${data['name'] ?? ''} ${data['phone'] ?? ''} ${data['category'] ?? ''}'
                  .toLowerCase()
                  .contains(query);
            }).toList();
            if (docs.isEmpty)
              return Center(
                  child: Text(tab == 0
                      ? 'Chưa có hải sản. Bấm “Nạp danh mục”.'
                      : 'Chưa có dữ liệu. Bấm nút thêm để tạo.'));
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
              itemCount: docs.length,
              itemBuilder: (context, index) {
                final data = docs[index].data();
                return Card(
                    child: ListTile(
                  leading: CircleAvatar(
                      child: Icon(tab == 0
                          ? Icons.set_meal_outlined
                          : tab == 1
                              ? Icons.person_outline
                              : Icons.storefront_outlined)),
                  title: Text('${data['name'] ?? docs[index].id}'),
                  subtitle: Text(tab == 0
                      ? '${data['category'] ?? 'Khác'} · ${data['baseUnit'] ?? 'kg'}'
                      : [data['phone'], data['address']]
                          .where(
                              (value) => value != null && '$value'.isNotEmpty)
                          .join(' · ')),
                  trailing: tab == 0
                      ? null
                      : Text(tab == 1 ? 'Khách' : 'NCC',
                          style: Theme.of(context).textTheme.labelSmall),
                ));
              },
            );
          },
        )),
      ]),
    );
  }
}

