import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'v2_api.dart';

class LedgerScreen extends StatefulWidget {const LedgerScreen({super.key});@override State<LedgerScreen> createState()=>_LedgerScreenState();}
class _LedgerScreenState extends State<LedgerScreen> {
 bool busy=false;final money=TextEditingController();
 @override void dispose(){money.dispose();super.dispose();}
 void info(String text){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));}
 Future<void> collect(QueryDocumentSnapshot<Map<String,dynamic>> doc) async {
  if(busy)return;final row=doc.data(),kind=row['kind']=='sale'?'collect':'paySupplier';
  final amount=int.tryParse(money.text.trim());final due=(row['dueVnd'] as num?)?.toInt()??0;
  if(amount==null||amount<=0||amount>due){info('Số tiền phải lớn hơn 0 và không vượt nợ phiếu ($due đ)');return;}
  setState(()=>busy=true);
  try{
   final result=await BookkeepingOperations.settle({'idempotencyKey':const Uuid().v4(), 'kind':kind,'counterpartyId':row['counterpartyId'],'amountVnd':amount,'allocations':[{'id':doc.id,'amountVnd':amount}]});
   info('Đã ghi thu/chi ${result['paidVnd']} đ');money.clear();
  }catch(e){info('Không thể thanh toán: $e');}finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> doReturn(QueryDocumentSnapshot<Map<String,dynamic>> doc) async {
  final row=doc.data(), lines=(row['lines'] as List?)??[];
  final returned=Map<String,dynamic>.from(row['returnedMilli'] as Map? ?? {});
  int selected=-1;bool restock=true;final quantity=TextEditingController();
  final payload=await showDialog<Map<String,dynamic>>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,update)=>AlertDialog(
   title:const Text('Hoàn hàng / hủy phần còn lại'),content:Column(mainAxisSize:MainAxisSize.min,children:[
   DropdownButtonFormField<int>(isExpanded:true,decoration:const InputDecoration(labelText:'Chọn dòng hàng'),items:[for(var i=0;i<lines.length;i++) if(((lines[i] as Map)['quantityMilli'] as num).toInt()-((returned['$i'] as num?)?.toInt()??0)>0) DropdownMenuItem(value:i,child:Text('${(lines[i] as Map)['productId']} – dòng ${i+1}'))],onChanged:(v)=>update(()=>selected=v??-1)),
   TextField(controller:quantity,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Số lượng trả (đơn vị của dòng gốc)')),
   SwitchListTile(title:const Text('Nhập lại kho (hàng còn bán được)'),value:restock,onChanged:(v)=>update(()=>restock=v)),
   const Text('Nếu hàng hỏng, bỏ chọn nhập lại kho. Số tiền hoàn sẽ được xác định lại trên máy chủ.'),
   ]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Đóng')),FilledButton(onPressed:(){final q=double.tryParse(quantity.text.replaceAll(',','.'));if(selected<0||q==null||q<=0)return;Navigator.pop(ctx,{'index':selected,'quantityMilli':(q*1000).round(),'restock':restock});},child:const Text('Tiếp tục'))])));
  quantity.dispose();if(payload==null)return;
  final selectedLine=lines[payload['index'] as int] as Map;
  final prior=(returned['${payload['index']}'] as num?)?.toInt()??0;
  if((payload['quantityMilli'] as int)+prior>(selectedLine['quantityMilli'] as num).toInt()){info('Số lượng hoàn vượt số đã bán');return;}
  // Muốn hoàn tiền chính xác, cần UI đọc trước giá trị báo giá (preview) từ máy chủ.
  // Bản hiện tại chỉ cho thao tác hoàn khi khách chưa thanh toán; nếu đã thanh toán,
  // chức năng server bắt buộc cashRefundVnd đúng và sẽ từ chối an toàn.
  if((row['paidVnd'] as num?)?.toInt()!=0){info('Đơn đã thu tiền: cần màn hình xác nhận tiền hoàn trước khi xử lý.');return;}
  if(busy)return;setState(()=>busy=true);
  try{final result=await BookkeepingOperations.returnSale({'idempotencyKey':const Uuid().v4(),'originalId':doc.id,'lines':[payload],'cashRefundVnd':0});info('Đã xử lý hoàn hàng: ${result['refundVnd']} đ');}
  catch(e){info('Chưa hoàn hàng: $e');}finally{if(mounted)setState(()=>busy=false);}
 }
 Future<void> cancelPurchase(QueryDocumentSnapshot<Map<String,dynamic>> doc) async {
  if(busy)return;
  final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Hủy phiếu nhập'),content:const Text('Chỉ hủy được nếu chưa thanh toán và hàng chưa có xuất nhập phát sinh sau đó.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Không')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Hủy phiếu'))]));
  if(confirmed!=true)return;setState(()=>busy=true);
  try{await CancelPurchaseOperation.cancelPurchase({'idempotencyKey':const Uuid().v4(),'originalId':doc.id,'reason':'Hủy theo yêu cầu người dùng'});info('Đã hủy phiếu nhập');}
  catch(e){info('Không thể hủy: $e');}finally{if(mounted)setState(()=>busy=false);}
 }
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Thu nợ và hoàn hàng')),body:Column(children:[
 Padding(padding:const EdgeInsets.all(12),child:TextField(controller:money,keyboardType:TextInputType.number,decoration:const InputDecoration(border:OutlineInputBorder(),labelText:'Số tiền thu/trả nợ (VND)'))),
 const Padding(padding:EdgeInsets.all(8),child:Text('Chọn phiếu để thanh toán một phần hoặc trả hàng. Các thao tác được kiểm tra lại trên Firebase.')),
 Expanded(child:StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(stream:FamilyApi.collection('documents').orderBy('createdAt',descending:true).limit(100).snapshots(),builder:(ctx,s){if(s.hasError)return Center(child:Text('${s.error}'));if(!s.hasData)return const Center(child:CircularProgressIndicator());
 final docs=s.data!.docs.where((d)=>['sale','purchase'].contains(d.data()['kind'])).toList();
 return ListView(children:[for(final d in docs)Card(child:Padding(padding:const EdgeInsets.all(8),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${d.data()['kind']=='sale'?'Bán':'Nhập'} · ${d.id}',style:Theme.of(context).textTheme.titleSmall),Text('Còn nợ: ${d.data()['dueVnd']??0} đ'),Row(children:[TextButton(onPressed:busy||((d.data()['dueVnd'] as num?)?.toInt()??0)<=0?null:()=>collect(d),child:const Text('Thu/chi tiền')),if(d.data()['kind']=='sale')TextButton(onPressed:busy?null:()=>doReturn(d),child:const Text('Hoàn hàng')),if(d.data()['kind']=='purchase' && d.data()['status']=='posted')TextButton(onPressed:busy?null:()=>cancelPurchase(d),child:const Text('Hủy nhập'))])])))]);
 }))]));
}
