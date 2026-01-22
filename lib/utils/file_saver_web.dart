// lib/utils/file_saver_web.dart
// Web implementation using dart:html to trigger a download in the browser.

import 'dart:convert';
import 'dart:html' as html;

Future<String> saveCsvAndReturn(String csv, String filename) async {
  final bytes = utf8.encode(csv);
  final blob = html.Blob([bytes], 'text/csv');
  final url = html.Url.createObjectUrlFromBlob(blob);

  final anchor = html.document.createElement('a') as html.AnchorElement;
  anchor.href = url;
  anchor.download = filename;

  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();

  html.Url.revokeObjectUrl(url);
  return 'downloaded:$filename';
}
