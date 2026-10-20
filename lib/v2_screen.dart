import 'ledger_screen.dart';
import 'customer_search.dart';
import 'price_backup_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'v2_api.dart';
import 'backup_export.dart';
import 'cloud_sync.dart';

class BookkeepingScreen extends StatefulWidget {const BookkeepingScreen({super.key});@override State<BookkeepingScreen> createState()=>_BookkeepingState();}
class _BookkeepingState extends State<BookkeepingScreen>{
 String kind='sale';String? partyId;bool busy=false;String operationKey=const Uuid().v4();final lines=<LineDraft>[LineDraft()];
 final paid=TextEditingController(text:'0'),fee=TextEditingController(text:'0'),discount=TextEditingController(text:'0');
 @override void dispose(){paid.dispose();fee.dispose();discount.dispose();for(final l in lines)l.dispose();super.dispose();}
 void message(String x){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(x)));}
 Future<void> save() async {if(busy)return;setState(()=>busy=true);try{
  final data=<Map<String,dynamic>>[];
  for(final l in lines){
   if(l.product==null)throw StateError('Chọn mặt hàng trên từng dòng');
   final q=(double.parse(l.qty.text.replaceAll(',','.'))*1000).round();
   final f=(double.parse(l.factor.text.replaceAll(',','.'))*1000).round();
   data.add({'productId':l.product,'unit':l.unit.text.trim(),'quantityMilli':q,'factorMilli':f,'unitPrice':int.parse(l.price.text.replaceAll('.',''))});
  }
  final res=await FamilyApi.post({'idempotencyKey':operationKey,'kind':kind,'counterpartyId':partyId,'lines':data,'paidVnd':int.parse(paid.text),'feeVnd':int.parse(fee.text),'discountVnd':int.parse(discount.text)});
  message('Đã xác nhận phiếu: ${res['id']}');if(mounted)Navigator.pop(context);
 }catch(e){
   try {final found=await FamilyApi.operationStatus(operationKey);if(found!=null){message('Máy chủ đã ghi phiếu: $operationKey');if(mounted)Navigator.pop(context);return;}} catch(_) {}
   message('Chưa xác định kết quả do mạng hoặc máy chủ. GIỮ NGUYÊN phiếu và mã giao dịch $operationKey; bấm lại để kiểm tra/gửi cùng mã. Chi tiết: $e');
  }finally{if(mounted)setState(()=>busy=false);}}
 @override Widget build(BuildContext context){
  if (!CloudSync.instance.ready || CloudSync.instance.householdId == null) {
   return const CloudAccessRequiredScreen();
  }
  return Scaffold(appBar:AppBar(title:const Text('Phiếu nhiều mặt hàng')),body:ListView(padding:const EdgeInsets.all(16),children:[
   SegmentedButton<String>(segments:const [ButtonSegment(value:'sale',label:Text('Bán hàng')),ButtonSegment(value:'purchase',label:Text('Nhập hàng'))],selected:{kind},onSelectionChanged:(v)=>setState((){kind=v.first;partyId=null;})),
   const SizedBox(height:12),StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
     stream:FamilyApi.collection(kind=='sale'?'customers':'suppliers').snapshots(),
     builder:(ctx,s) {
       final docs=s.data?.docs??[];
       final selected=docs.where((d)=>d.id==partyId).toList();
       if(kind=='sale') {
         return OutlinedButton.icon(
           icon:const Icon(Icons.person_search_outlined),
           label:Text(selected.isEmpty?'Tìm khách theo tên / điện thoại': '${selected.first.data()['name']} · ${selected.first.data()['phone']??''}',overflow:TextOverflow.ellipsis),
           onPressed:() async {
             final id=await chooseCustomer(context,[for(final d in docs) {'id':d.id,'name':'${d.data()['name']??''}','phone':'${d.data()['phone']??''}'}]);
             if(id!=null && mounted)setState(()=>partyId=id);
           });
       }
       return DropdownButtonFormField<String>(isExpanded:true,
         value:selected.isEmpty?null:partyId,
         decoration:const InputDecoration(labelText:'Nhà cung cấp'),
         items:docs.map((e)=>DropdownMenuItem(value:e.id,child:Text('${e.data()['name']??e.id}'))).toList(),
         onChanged:(v)=>setState(()=>partyId=v));
     }),
   const SizedBox(height:12),StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FamilyApi.collection('products').snapshots(),builder:(ctx,s){final docs=s.data?.docs??[];return Column(children:[for(int i=0;i<lines.length;i++)Card(child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[
    Row(children:[Text('Mặt hàng ${i+1}'),const Spacer(),IconButton(icon:const Icon(Icons.delete_outline),onPressed:lines.length==1?null:()=>setState(()=>lines.removeAt(i).dispose()))]),
    DropdownButtonFormField<String>(isExpanded:true,value:docs.any((d)=>d.id==lines[i].product)?lines[i].product:null,decoration:const InputDecoration(labelText:'Hải sản'),items:docs.map((e)=>DropdownMenuItem(value:e.id,child:Text('${e.data()['name']}'))).toList(),onChanged:(v)=>setState((){lines[i].product=v;lines[i].unit.text=docs.firstWhere((d)=>d.id==v).data()['baseUnit']??'kg';lines[i].factor.text='1';})),
    TextField(controller:lines[i].unit,decoration:const InputDecoration(labelText:'Đơn vị (kg, con, thùng...)')),
    TextField(controller:lines[i].qty,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Số lượng')),
    TextField(controller:lines[i].factor,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Số đơn vị chuẩn / 1 đơn vị bán (thực tế)')),
    TextField(controller:lines[i].price,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Giá VND / đơn vị bán')),
   ]))),TextButton.icon(onPressed:()=>setState(()=>lines.add(LineDraft())),icon:const Icon(Icons.add),label:const Text('Thêm dòng mặt hàng'))]);}),
   TextField(controller:paid,keyboardType:TextInputType.number,decoration:InputDecoration(labelText:kind=='sale'?'Tiền khách đã trả':'Đã trả nhà cung cấp (VND)')),
   if(kind=='purchase')TextField(controller:fee,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Chi phí thu mua (VND)')),
   if(kind=='sale')TextField(controller:discount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Giảm giá đơn (VND)')),
   const SizedBox(height:20),Text('Mã giao dịch: $operationKey',style:const TextStyle(fontSize:12)),const Text('Chỉ xác nhận khi trực tuyến. Nếu quá thời gian chờ, giữ màn hình và nhấn xác nhận lại bằng cùng mã.'),
   FilledButton(onPressed:busy?null:save,child:Text(busy?'Đang xác nhận...':'Xác nhận phiếu')),
  ]));
 }
}
class LineDraft {String? product;final unit=TextEditingController(text:'kg'),qty=TextEditingController(text:'1'),factor=TextEditingController(text:'1'),price=TextEditingController(text:'0');void dispose(){unit.dispose();qty.dispose();factor.dispose();price.dispose();}}

class CloudAccessRequiredScreen extends StatelessWidget {
 const CloudAccessRequiredScreen({super.key});

 @override
 Widget build(BuildContext context) {
  final configured = CloudSync.instance.ready;
  final message = configured
      ? 'Bạn chưa đăng nhập tài khoản gia đình. Quay lại trang chủ, chọn biểu tượng tài khoản và đăng nhập tài khoản đã được cấp quyền.'
      : 'Bản web chưa được cấu hình Firebase. Cần kết nối Firebase và cấp tài khoản gia đình trước khi tạo phiếu trực tuyến.';
  return Scaffold(
   appBar: AppBar(title: const Text('Sổ bán hàng và nhập hàng')),
   body: Center(
    child: Padding(
     padding: const EdgeInsets.all(24),
     child: Column(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.cloud_off_outlined, size: 48),
      const SizedBox(height: 16),
      const Text('Chưa thể mở sổ trực tuyến', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
      const SizedBox(height: 12),
      Text(message, textAlign: TextAlign.center),
      const SizedBox(height: 20),
      FilledButton.icon(
       onPressed: () => Navigator.pop(context),
       icon: const Icon(Icons.arrow_back),
       label: const Text('Quay lại'),
      ),
     ]),
    ),
   ),
  );
 }
}

class CloudDataScreen extends StatelessWidget {const CloudDataScreen({super.key});
 @override Widget build(BuildContext context) {
  if (!CloudSync.instance.ready || CloudSync.instance.householdId == null) {
   return const CloudAccessRequiredScreen();
  }
  return Scaffold(appBar:AppBar(title:const Text('Sổ chứng từ và sao lưu')),body:Column(children:[
  Padding(padding:const EdgeInsets.all(8),child:Wrap(spacing:8,children:[FilledButton.icon(icon:const Icon(Icons.add),label:const Text('Tạo phiếu nhiều dòng'),onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const BookkeepingScreen()))),OutlinedButton.icon(icon:const Icon(Icons.receipt_long),label:const Text('Thu nợ / hoàn hàng'),onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const LedgerScreen()))),OutlinedButton.icon(icon:const Icon(Icons.price_change_outlined),label:const Text('Bảng giá'),onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const PriceListScreen()))),OutlinedButton.icon(icon:const Icon(Icons.restore_page_outlined),label:const Text('Kiểm tra bản sao lưu'),onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const BackupInspectionScreen()))),OutlinedButton.icon(icon:const Icon(Icons.backup),label:const Text('Xuất sao lưu JSON'),onPressed:() async {try{final json=await FamilyApi.exportJson();await exportBackupJson(json);}catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e')));}})])),
  const Text('Bản sao lưu chỉ để xuất/kiểm tra. Khôi phục cần xác minh để tránh ghi đè dữ liệu chung.'),
  Expanded(child:StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FamilyApi.collection('documents').orderBy('createdAt',descending:true).limit(100).snapshots(),builder:(context,s){if(s.hasError)return Text('Lỗi: ${s.error}');if(!s.hasData)return const Center(child:CircularProgressIndicator());return ListView(children:s.data!.docs.map((d){final p=d.data();return ListTile(title:Text('${p['kind']} • ${d.id}'),subtitle:Text('Khách/NCC: ${p['counterpartyId']}'),trailing:Text('${(p['summary'] as Map?)?['grossVnd']??0} đ'));}).toList());}))
 ]));
}
}
