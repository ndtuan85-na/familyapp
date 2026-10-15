import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'v2_api.dart';

class PriceListScreen extends StatelessWidget {
  const PriceListScreen({super.key});
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Bảng giá hải sản')),
    body: StreamBuilder<QuerySnapshot<Map<String,dynamic>>>(
      stream: FamilyApi.collection('products').orderBy('name').snapshots(),
      builder: (context,s) {
        if(s.hasError) return Center(child:Text('Lỗi tải bảng giá: ${s.error}'));
        if(!s.hasData) return const Center(child:CircularProgressIndicator());
        return ListView(padding:const EdgeInsets.all(12),children:[
          const Card(child:Padding(padding:EdgeInsets.all(16),child:Text('Giá tham khảo theo sản phẩm. Giá chính thức phải được chốt trên chứng từ; chưa tự động áp giá theo khách.'))),
          for(final doc in s.data!.docs) Card(child:ListTile(
            leading:const CircleAvatar(backgroundColor:Color(0xffd8f4ed),child:Icon(Icons.set_meal_outlined,color:Color(0xff087e76))),
            title:Text(doc.data()['name']?.toString()??doc.id),
            subtitle:Text('${doc.data()['category']??'Thực phẩm khác'} · Đơn vị: ${doc.data()['baseUnit']??'kg'}'),
            trailing:const Icon(Icons.edit_outlined),
            onTap:()=>_edit(context,doc),
          ))
        ]);
      }),
  );
  Future<void> _edit(BuildContext context,QueryDocumentSnapshot<Map<String,dynamic>> doc) async {
    final data=doc.data();
    final retail=TextEditingController(text:'${data['retailVnd']??0}');
    final wholesale=TextEditingController(text:'${data['wholesaleVnd']??0}');
    final changed=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(
      title:Text(data['name']?.toString()??doc.id),
      content:Column(mainAxisSize:MainAxisSize.min,children:[
        TextField(controller:retail,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Giá lẻ VND/đơn vị chuẩn')),
        const SizedBox(height:12),
        TextField(controller:wholesale,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Giá sỉ VND/đơn vị chuẩn')),
      ]),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Đóng')),
      FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Lưu giá'))]));
    if(changed!=true)return;
    final a=int.tryParse(retail.text.trim()),b=int.tryParse(wholesale.text.trim());
    if(a==null||b==null||a<0||b<0){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Đơn giá phải là số nguyên không âm')));return;}
    try{
      await FamilyApi.master('products',doc.id,{'name':data['name'],'baseUnit':data['baseUnit']??'kg','category':data['category']??'Thực phẩm khác','units':data['units']??{},'retailVnd':a,'wholesaleVnd':b,'priceRevisionId':const Uuid().v4()});
      if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Đã lưu bảng giá')));
    }catch(e){if(context.mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Không lưu được: $e')));}
    retail.dispose();wholesale.dispose();
  }
}

class BackupInspectionScreen extends StatefulWidget {
  const BackupInspectionScreen({super.key});
  @override State<BackupInspectionScreen> createState()=>_BackupInspectionState();
}
class _BackupInspectionState extends State<BackupInspectionScreen> {
  String result='Chọn file sao lưu JSON để kiểm tra trước khi khôi phục.';
  Future<void> inspect() async {
    try {
      final file=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['json'],withData:true);
      if(file==null)return;
      final bytes=file.files.single.bytes;
      if(bytes==null)throw StateError('Không đọc được file: hãy chọn bản sao lưu nhỏ hơn hoặc cho phép đọc file.');
      final json=jsonDecode(utf8.decode(bytes));
      if(json is! Map<String,dynamic>)throw const FormatException('Cấu trúc JSON không hợp lệ');
      if(json['householdId']!=FamilyApi.household)throw StateError('File thuộc hộ gia đình khác, không được nhập');
      final required=['products','customers','suppliers','stock','balances','documents'];
      for(final key in required){if(json[key] is! List)throw FormatException('Thiếu hoặc sai trường $key');}
      if(!mounted)return;
      setState(()=>result='File hợp lệ về cấu trúc cơ bản. Phiên bản: ${json['schemaVersion']}\nNgày xuất: ${json['exportedAt']}\n'+required.map((key)=>'$key: ${(json[key] as List).length} bản ghi').join('\n')+'\n\nChưa thực hiện ghi dữ liệu. Khôi phục online đang khóa để tránh ghi đè và sai lệch công nợ.');
    }catch(e){if(mounted)setState(()=>result='Không thể kiểm tra: $e');}
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Kiểm tra bản sao lưu')),body:ListView(padding:const EdgeInsets.all(16),children:[
    const Card(child:Padding(padding:EdgeInsets.all(16),child:Text('Chỉ đọc và kiểm tra cấu trúc bản sao lưu. Khôi phục lên dữ liệu đang có giao dịch bị khóa cho đến khi có cơ chế bảo trì và đối chiếu an toàn.'))),
    const SizedBox(height:12),FilledButton.icon(onPressed:inspect,icon:const Icon(Icons.upload_file_outlined),label:const Text('Chọn file JSON để kiểm tra')),
    const SizedBox(height:16),SelectableText(result),
  ]));
}
