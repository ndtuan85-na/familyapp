import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> exportBackupJson(String json) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/seafood_backup_${DateTime.now().millisecondsSinceEpoch}.json');
  await file.writeAsString(json);
  await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'Sao lưu Hải sản gia đình'));
}

