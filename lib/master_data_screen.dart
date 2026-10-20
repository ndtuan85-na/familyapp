import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'cloud_sync.dart';
import 'v2_api.dart';

class MasterDataScreen extends StatefulWidget {
  const MasterDataScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<MasterDataScreen> createState() => _MasterDataScreenState();
}

class _MasterDataScreenState extends State<MasterDataScreen> {
  late int tab = widget.initialTab.clamp(0, 2).toInt();
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
      message(_callableHelp(e, 'Không lưu được'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> addProduct() async {
    final name = TextEditingController();
    final category = TextEditingController(text: 'Hải sản');
    final unit = TextEditingController(text: 'kg');
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Thêm hải sản'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: name, autofocus: true, decoration: const InputDecoration(labelText: 'Tên hải sản *')),
          TextField(controller: category, decoration: const InputDecoration(labelText: 'Nhóm')),
          TextField(controller: unit, decoration: const InputDecoration(labelText: 'Đơn vị chuẩn')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, {'name': name.text.trim(), 'category': category.text.trim(), 'unit': unit.text.trim()}), child: const Text('Lưu')),
        ],
      ),
    );
    name.dispose();
    category.dispose();
    unit.dispose();
    if (result == null) return;
    if (result['name']!.isEmpty) {
      message('Bạn nhập tên hải sản trước nhé.');
      return;
    }
    setState(() => busy = true);
    try {
      await FamilyApi.master('products', const Uuid().v4(), {
        'name': result['name'],
        'category': result['category']!.isEmpty ? 'Hải sản' : result['category'],
        'baseUnit': result['unit']!.isEmpty ? 'kg' : result['unit'],
        'units': <String, dynamic>{},
      });
      message('Đã thêm hải sản.');
    } catch (e) {
      message(_callableHelp(e, 'Chưa thêm được hải sản'));
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
      message(_callableHelp(e, 'Chưa nạp được danh mục'));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  String _callableHelp(Object error, String prefix) {
    final text = error.toString();
    if (text.contains('permission-denied') || text.contains('PERMISSION_DENIED')) {
      return '$prefix: tài khoản chưa được cấp quyền vào hộ gia đình trong Firebase. Kiểm tra thành viên hộ và đăng nhập lại.';
    }
    if (text.contains('not-found') || text.contains('NOT_FOUND')) {
      return '$prefix: máy chủ chưa được triển khai các hàm Firebase (upsertMaster/seedCatalog). Cần triển khai Cloud Functions cho dự án seafood-38304.';
    }
    return '$prefix: $text';
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
      floatingActionButton: FloatingActionButton.extended(
              onPressed: busy ? null : (tab == 0 ? addProduct : addParty),
              icon: Icon(tab == 0 ? Icons.set_meal_outlined : Icons.person_add_alt_1_outlined),
              label: Text(tab == 0 ? 'Thêm hải sản' : tab == 1 ? 'Thêm khách' : 'Thêm nhà cung cấp'),
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

