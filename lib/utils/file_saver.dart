// lib/utils/file_saver.dart
// Conditional export: web implementation used when dart.library.html is available
export 'file_saver_stub.dart'
    if (dart.library.html) 'file_saver_web.dart';
