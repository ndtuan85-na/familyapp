import 'package:flutter/material.dart';

/// Tìm theo tên (kể cả không dấu) hoặc các chữ số liên tiếp trong điện thoại.
class CustomerSearch {
  static const _groups = <String, String>{
    'a': 'àáảãạăằắẳẵặâầấẩẫậ',
    'e': 'èéẻẽẹêềếểễệ',
    'i': 'ìíỉĩị',
    'o': 'òóỏõọôồốổỗộơờớởỡợ',
    'u': 'ùúủũụưừứửữự',
    'y': 'ỳýỷỹỵ',
    'd': 'đ',
  };
  static String fold(String value) {
    final out = StringBuffer();
    for (final r in value.toLowerCase().trim().runes) {
      final c = String.fromCharCode(r);
      var replacement = c;
      for (final group in _groups.entries) {
        if (group.value.contains(c)) { replacement = group.key; break; }
      }
      out.write(replacement);
    }
    return out.toString().replaceAll(RegExp(r'\s+'), ' ');
  }
  static String digits(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');
  static bool matches(String name, String phone, String query) {
    final q = query.trim();
    if (q.isEmpty) return true;
    if (fold(name).contains(fold(q))) return true;
    final number = digits(q);
    return number.length >= 3 && digits(phone).contains(number);
  }
}

/// Dùng chung khi chọn khách hàng cho phiếu bán và thu tiền.
Future<String?> chooseCustomer(BuildContext context, List<Map<String, String>> people) {
  return showModalBottomSheet<String>(
    context: context, isScrollControlled: true, showDragHandle: true,
    builder: (ctx) => FractionallySizedBox(heightFactor: .76, child: _CustomerPicker(people: people)),
  );
}

class _CustomerPicker extends StatefulWidget {
  final List<Map<String, String>> people;
  const _CustomerPicker({required this.people});
  @override State<_CustomerPicker> createState() => _CustomerPickerState();
}
class _CustomerPickerState extends State<_CustomerPicker> {
  String query = '';
  @override Widget build(BuildContext context) {
    final results = widget.people.where((p) => CustomerSearch.matches(p['name'] ?? '', p['phone'] ?? '', query)).toList()
      ..sort((a,b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
    return SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      Text('Chọn khách hàng', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 12),
      TextField(autofocus: true, onChanged: (s) => setState(() => query=s),
        keyboardType: TextInputType.text,
        decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Nhập tên hoặc số điện thoại', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      Expanded(child: results.isEmpty
        ? const Center(child: Text('Không tìm thấy khách hàng'))
        : ListView.builder(itemCount: results.length, itemBuilder: (ctx, i) {
          final p=results[i];
          return ListTile(leading: const CircleAvatar(child: Icon(Icons.person_outline)),
            title: Text(p['name'] ?? ''), subtitle: Text(p['phone'] ?? ''),
            onTap: () => Navigator.of(ctx).pop(p['id']));
        })),
    ])));
  }
}
