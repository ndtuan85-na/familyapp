import 'v2_screen.dart';
import 'customer_search.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'cloud_sync.dart';
import 'logic.dart';
import 'models.dart';
import 'reminders.dart';
import 'store.dart';

final _currency = NumberFormat.decimalPattern('vi_VN');
String vnd(int n) => '${_currency.format(n)} đ';
String qtyText(int milli) => (milli / 1000).toStringAsFixed(milli % 1000 == 0 ? 0 : 3);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeState();
}
class _HomeState extends State<HomeScreen> {
  int tab = 0;
  List<Entry> entries = [];
  bool busy = false;
  String customerQuery = '';
  @override void initState() { super.initState(); reload(); Store.instance.changes.stream.listen((_) { if (mounted) reload(); }); }
  Future<void> reload() async { final data = await Store.instance.all(); if (mounted) setState(() => entries = data); }
  Future<void> showInput(String type) async {
    final ok = await Navigator.of(context).push<bool>(MaterialPageRoute(builder: (_) => EntryEditor(type: type, entries: entries)));
    if (ok == true) reload();
  }
  @override Widget build(BuildContext context) {
    final pages = [_dashboard(), _products(), _customers(), _transactions(), _delivery()];
    return Scaffold(
      appBar: AppBar(title: Row(children: [Container(width: 36, height: 36, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(12)), child: const Icon(Icons.set_meal, color: Colors.white, size: 20)), const SizedBox(width: 10), const Text('Hải sản gia đình')]), actions: [IconButton(tooltip: 'Đồng bộ', onPressed: () async {
        try { final count = await CloudSync.instance.sync(); if (context.mounted) _message('Đã đồng bộ $count bản ghi.'); }
        catch (e) { if (context.mounted) _message('Lỗi đồng bộ: $e'); }
      }, icon: const Icon(Icons.sync)), IconButton(tooltip: 'Tài khoản', onPressed: _account, icon: const Icon(Icons.account_circle_outlined))]),
      body: pages[tab],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (tab == 0) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const BookkeepingScreen()));
          } else if (tab == 3) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const CloudDataScreen()));
          } else {
            showInput(['sale', 'product', 'customer', 'purchase', 'delivery'][tab]);
          }
        },
        icon: const Icon(Icons.add),
        label: Text(['Bán hàng', 'Mặt hàng', 'Khách hàng', 'Sổ sách', 'Lịch giao'][tab]),
      ),
      bottomNavigationBar: NavigationBar(selectedIndex: tab, onDestinationSelected: (n) => setState(() => tab = n), destinations: const [
        NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Tổng quan'),
        NavigationDestination(icon: Icon(Icons.inventory_2_outlined), label: 'Kho'),
        NavigationDestination(icon: Icon(Icons.people_outline), label: 'Khách'),
        NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Sổ sách'),
        NavigationDestination(icon: Icon(Icons.local_shipping_outlined), label: 'Giao hàng'),
      ]),
    );
  }
  void _message(String s) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s)));
  Widget _dashboard() {
    final today = Business.stats(entries, day: DateTime.now());
    final all = Business.stats(entries);
    final month = DateTime.now();
    final monthly = entries.where((e) { final d = DateTime.tryParse(e.createdAt)?.toLocal(); return d?.year == month.year && d?.month == month.month; }).toList();
    final ms = Business.stats(monthly);
    return ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xff087f72), Color(0xff16a38d)], begin: Alignment.topLeft, end: Alignment.bottomRight), borderRadius: BorderRadius.circular(24)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('HÔM NAY · ${DateFormat('dd/MM/yyyy').format(DateTime.now())}', style: const TextStyle(color: Color(0xffd5f4e9), fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 10), const Text('Chào buổi sáng 👋', style: TextStyle(color: Colors.white, fontSize: 23, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4), const Text('Cùng xem tình hình kinh doanh hôm nay', style: TextStyle(color: Color(0xffe1f7f0), fontSize: 13)),
        const SizedBox(height: 18), const Text('DOANH THU HÔM NAY', style: TextStyle(color: Color(0xffc8eee2), letterSpacing: 1, fontSize: 11, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4), Text(vnd(today.revenue), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
      ])),
      const SizedBox(height: 24),
      _sectionTitle('Báo cáo hôm nay', 'Theo ngày'),
      _tile('Lợi nhuận tạm tính', vnd(today.profit), Icons.trending_up, tint: const Color(0xffe3f5ec)),
      _tile('Chi phí', vnd(today.expenses), Icons.payments_outlined, tint: const Color(0xfffff1df)),
      const SizedBox(height: 14),
      _sectionTitle('Tổng hợp', 'Tháng này'),
      _tile('Lợi nhuận tháng này', vnd(ms.profit), Icons.calendar_month, tint: const Color(0xffe8eefc)),
      _tile('Khách hàng còn nợ', vnd(all.receivable), Icons.account_balance_wallet_outlined, tint: const Color(0xffffe9e8)),
      _tile('Giá trị tồn kho ước tính', vnd(all.stockValue), Icons.inventory_2_outlined, tint: const Color(0xffe5f2f4)),
      const SizedBox(height: 8),
      FilledButton.tonal(onPressed: () => Navigator.push(context,MaterialPageRoute(builder: (_)=>const CloudDataScreen())), child: const Text('Mở sổ chứng từ trực tuyến')),
      OutlinedButton(onPressed: () => showInput('expense'), child: const Text('Ghi nhận chi phí')),
      const Text('Lưu ý: Báo cáo MVP, chưa xử lý trả hàng, công nợ nhà cung cấp và giá vốn hồi tố.', style: TextStyle(fontSize: 12)),
    ]);
  }
  Widget _sectionTitle(String title, String hint) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xff183b36))), const Spacer(), Text(hint, style: const TextStyle(fontSize: 12, color: Color(0xff7a8d87), fontWeight: FontWeight.w600))]));
  Widget _tile(String title, String value, IconData icon, {Color tint = const Color(0xffe3f5ec)}) => Card(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5), child: ListTile(contentPadding: EdgeInsets.zero, leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 21)), title: Text(title, style: const TextStyle(fontSize: 13, color: Color(0xff71817c))), subtitle: Padding(padding: const EdgeInsets.only(top: 3), child: Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xff183b36)))))));
  Widget _products() {
    final products = entries.where((e) => e.kind == 'product');
    return ListView(padding: const EdgeInsets.all(16), children: [for (final e in products) Card(child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5), leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xffe3f5ec), borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.set_meal, color: Color(0xff087f72))), title: Text('${e.data['name']}', style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text('Đơn vị: ${e.data['unit']} • Tồn: ${qtyText(Business.stockMilli(e.id, entries))}'),
      trailing: Text(vnd(Business.currentUnitCost(e.id, entries)), style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xff087f72))),
    ))]);
  }
  Widget _customers() {
    final customers = entries.where((e) => e.kind=='customer' && CustomerSearch.matches('${e.data['name']??''}', '${e.data['phone']??''}', customerQuery)).toList();
    customers.sort((a,b) => '${a.data['name']??''}'.compareTo('${b.data['name']??''}'));
    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: TextField(
        decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Tìm tên hoặc số điện thoại'),
        onChanged: (value) => setState(() => customerQuery=value),
      )),
      Expanded(child: customers.isEmpty ? const Center(child: Text('Không tìm thấy khách hàng')) : ListView.builder(
        itemCount: customers.length,
        itemBuilder: (ctx,i) { final e=customers[i]; return ListTile(
          leading: const Icon(Icons.person_outline), title: Text('${e.data['name']}'),
          subtitle: Text('${e.data['phone']} • ${e.data['address']}'),
          trailing: Text(vnd(Business.customerDebt(e.id, entries)))); },
      )),
    ]);
  }
  Widget _transactions() => ListView(children: [
    Padding(padding: const EdgeInsets.all(12), child: Wrap(spacing: 8, children: [
      OutlinedButton(onPressed: ()=>Navigator.push(context,MaterialPageRoute(builder: (_)=>const CloudDataScreen())), child: const Text('Phiếu bán/nhập nhiều dòng')),
      OutlinedButton(onPressed: ()=>Navigator.push(context,MaterialPageRoute(builder: (_)=>const CloudDataScreen())), child: const Text('Sổ chung')),
      OutlinedButton(onPressed: ()=>Navigator.push(context,MaterialPageRoute(builder: (_)=>const CloudDataScreen())), child: const Text('Giao dịch trực tuyến')),
      OutlinedButton(onPressed: ()=>showInput('expense'), child: const Text('Chi phí')),
    ])),
    for (final e in entries.where((e) => ['purchase','sale','payment','expense'].contains(e.kind))) ListTile(
      leading: Icon({'purchase':Icons.move_to_inbox,'sale':Icons.shopping_bag,'payment':Icons.payments,'expense':Icons.money_off}[e.kind]),
      title: Text({'purchase':'Nhập hàng','sale':'Bán hàng','payment':'Thu tiền','expense':'Chi phí'}[e.kind]!),
      subtitle: Text('${e.data['note'] ?? ''} • ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(e.createdAt).toLocal())}'),
      trailing: Text(vnd(e.kind == 'purchase' || e.kind == 'sale' ? lineTotal(money(e.data['unitPrice']), quantity(e.data['qtyMilli'])) : money(e.data['amount']))),
    )
  ]);
  Widget _delivery() => ListView(children: [for(final e in entries.where((e)=>e.kind=='delivery')) ListTile(
    leading: const Icon(Icons.notifications_active_outlined),
    title: Text('${e.data['note']}'),
    subtitle: Text('Giao: ${e.data['scheduledAt']} • Nhắc trước ${e.data['remindHours']} giờ'),
  )]);
  Future<void> _account() async {
    final email = TextEditingController(), password = TextEditingController();
    await showDialog<void>(context: context, builder: (dialogContext) => AlertDialog(title: const Text('Đồng bộ gia đình'), content: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(CloudSync.instance.ready ? 'Đăng nhập tài khoản đã được quản trị viên cấp quyền.' : 'Chưa cấu hình Firebase. Ứng dụng vẫn dùng offline được.'),
      TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
      TextField(controller: password, obscureText: true, decoration: const InputDecoration(labelText: 'Mật khẩu')),
    ]), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Đóng')),
      FilledButton(onPressed: () async {try {await CloudSync.instance.login(email.text.trim(), password.text); if (dialogContext.mounted) Navigator.pop(dialogContext); if (mounted) _message('Đã đăng nhập và đồng bộ.'); } catch(e) { if (mounted) _message('$e'); }}, child: const Text('Đăng nhập')),
    ]));
    email.dispose(); password.dispose();
  }
}

class EntryEditor extends StatefulWidget {
  final String type;
  final List<Entry> entries;
  const EntryEditor({super.key, required this.type, required this.entries});
  @override State<EntryEditor> createState() => _EntryEditorState();
}
class _EntryEditorState extends State<EntryEditor> {
  final name = TextEditingController(), unit = TextEditingController(text: 'kg'), phone = TextEditingController(), address = TextEditingController(), work = TextEditingController(), price = TextEditingController(), qty = TextEditingController(text: '1'), amount = TextEditingController(), note = TextEditingController();
  String gender = 'Khác'; String? productId, customerId;
  DateTime deliveryDate = DateTime.now().add(const Duration(hours: 3));
  int remindHours = 2;
  @override void dispose() { for (final c in [name,unit,phone,address,work,price,qty,amount,note]) { c.dispose(); } super.dispose(); }
  int? parseMoney(String v) => int.tryParse(v.replaceAll('.', '').replaceAll(',', '').trim());
  int? parseQty(String v) { final n = double.tryParse(v.replaceAll(',', '.')); return n == null ? null : (n * 1000).round(); }
  @override Widget build(BuildContext context) {
    final t = widget.type;
    final products = widget.entries.where((e)=>e.kind=='product').toList();
    final customers = widget.entries.where((e)=>e.kind=='customer').toList();
    final fields = <Widget>[];
    Widget field(TextEditingController c, String title, {bool numeric = false}) => TextField(controller: c, keyboardType: numeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text, decoration: InputDecoration(labelText: title, border: const OutlineInputBorder()));
    if(t=='product') { fields.addAll([field(name,'Tên hải sản'),field(unit,'Đơn vị cơ sở, ví dụ kg')]); }
    if(t=='customer') { fields.addAll([field(name,'Tên khách'), DropdownButtonFormField<String>(value: gender, items: ['Nam','Nữ','Khác'].map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(), onChanged:(v)=>setState(()=>gender=v??'Khác'), decoration: const InputDecoration(labelText:'Giới tính')),field(phone,'Số điện thoại'),field(address,'Địa chỉ'),field(work,'Nơi làm việc')]); }
    if(['purchase','sale'].contains(t)) {
      fields.add(DropdownButtonFormField<String>(value: productId, isExpanded: true, decoration: const InputDecoration(labelText:'Mặt hàng'), items: products.map((p)=>DropdownMenuItem(value:p.id,child:Text('${p.data['name']} (${p.data['unit']})'))).toList(), onChanged:(v)=>setState(()=>productId=v)));
      if(t=='sale') fields.add(_customerDropdown(customers));
      fields.addAll([field(qty,'Số lượng',numeric:true),field(price,'Đơn giá VND/đơn vị',numeric:true),field(note,'Ghi chú')]);
    }
    if(t=='payment') fields.addAll([_customerDropdown(customers),field(amount,'Số tiền khách trả (VND)',numeric:true),field(note,'Ghi chú')]);
    if(t=='expense') fields.addAll([field(name,'Loại chi phí'),field(amount,'Số tiền (VND)',numeric:true),field(note,'Ghi chú')]);
    if(t=='delivery') fields.addAll([_customerDropdown(customers),field(note,'Thông tin giao hàng'),ListTile(title: const Text('Thời gian giao'), subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(deliveryDate)), trailing: const Icon(Icons.event), onTap: () async {
      final d = await showDatePicker(context:context, firstDate:DateTime.now().subtract(const Duration(days:1)), lastDate:DateTime(2100), initialDate:deliveryDate);
      if(d==null || !context.mounted) return;
      final h=await showTimePicker(context:context,initialTime:TimeOfDay.fromDateTime(deliveryDate));
      if(h!=null) setState(()=>deliveryDate=DateTime(d.year,d.month,d.day,h.hour,h.minute));
    }), DropdownButtonFormField<int>(value:remindHours,items:[1,2,3,4,6,12,24].map((n)=>DropdownMenuItem(value:n,child:Text('$n giờ'))).toList(),onChanged:(n)=>setState(()=>remindHours=n??2),decoration:const InputDecoration(labelText:'Nhắc trước'))]);
    return Scaffold(appBar: AppBar(title: Text({'product':'Thêm hải sản','customer':'Thêm khách hàng','purchase':'Nhập hàng','sale':'Bán hàng','payment':'Thu tiền','expense':'Chi phí','delivery':'Lịch giao hàng'}[t] ?? t)),body: ListView(padding:const EdgeInsets.all(16),children:[...fields.expand((w)=>[w,const SizedBox(height:14)]),FilledButton(onPressed:save,child:const Text('Lưu'))]));
  }
  Widget _customerDropdown(List<Entry> customers) => DropdownButtonFormField<String>(value:customerId,isExpanded:true,decoration:const InputDecoration(labelText:'Khách hàng'),items:customers.map((c)=>DropdownMenuItem(value:c.id,child:Text('${c.data['name']}'))).toList(),onChanged:(v)=>setState(()=>customerId=v));
  Future<void> save() async {
    try {
      final t=widget.type;
      if (['sale','purchase','payment'].contains(t)) throw StateError('Chức năng cũ đã khóa; sử dụng Sổ chung phiên bản 0.2 để tránh sai số liệu.');
      final data=<String,dynamic>{};
      if(t=='product') {
        if(name.text.trim().isEmpty || unit.text.trim().isEmpty) throw Exception('Nhập tên hàng và đơn vị.');
        data.addAll({'name':name.text.trim(),'unit':unit.text.trim()});
      } else if(t=='customer') {
        if(name.text.trim().isEmpty) throw Exception('Nhập tên khách.');
        data.addAll({'name':name.text.trim(),'gender':gender,'phone':phone.text.trim(),'address':address.text.trim(),'work':work.text.trim()});
      } else if(t=='purchase' || t=='sale') {
        final q=parseQty(qty.text), p=parseMoney(price.text);
        if(productId==null || q==null || q<=0 || p==null || p<0) throw Exception('Chọn hàng, số lượng và đơn giá hợp lệ.');
        if(t=='sale' && customerId==null) throw Exception('Chọn khách hàng.');
        if(t=='sale' && Business.stockMilli(productId!,widget.entries)<q) throw Exception('Không đủ tồn kho.');
        data.addAll({'productId':productId,'customerId':customerId,'qtyMilli':q,'unitPrice':p,'note':note.text.trim()});
        if(t=='sale') data['cogs']=lineTotal(Business.currentUnitCost(productId!,widget.entries),q);
      } else if(t=='payment' || t=='expense') {
        final a=parseMoney(amount.text);
        if(a==null || a<=0) throw Exception('Số tiền phải lớn hơn 0.');
        if(t=='payment' && customerId==null) throw Exception('Chọn khách hàng.');
        if(t=='payment' && a>Business.customerDebt(customerId!,widget.entries)) throw Exception('Số tiền vượt công nợ hiện tại.');
        data.addAll({'amount':a,'customerId':customerId,'name':name.text.trim(),'note':note.text.trim()});
      } else if(t=='delivery') {
        if(customerId==null || note.text.trim().isEmpty) throw Exception('Chọn khách và nhập nội dung giao.');
        data.addAll({'customerId':customerId,'note':note.text.trim(),'scheduledAt':deliveryDate.toIso8601String(),'remindHours':remindHours,'status':'pending'});
      }
      final now=DateTime.now().toUtc().toIso8601String();
      final id = const Uuid().v4();
      await Store.instance.put(Entry(id,t,now,data));
      if(t=='delivery') {
        try { await Reminders.instance.schedule(id,deliveryDate,remindHours,note.text.trim()); }
        catch (_) { /* Lịch vẫn lưu dù thiết bị từ chối thông báo. */ }
      }
      if (!mounted) return;
      Navigator.pop(context,true);
    } catch(e) { if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e'))); }
  }
}

