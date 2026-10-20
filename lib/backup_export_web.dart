import 'dart:convert';
import 'dart:html' as html;

Future<void> exportBackupJson(String json) async {
  final blob = html.Blob([utf8.encode(json)], 'application/json;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = 'seafood_backup_${DateTime.now().millisecondsSinceEpoch}.json'
    ..click();
  html.Url.revokeObjectUrl(url);
}

