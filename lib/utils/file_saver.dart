// Conditional export: on web the web implementation will be used, otherwise the stub.
export 'file_saver_stub.dart'
    if (dart.library.html) 'file_saver_web.dart';
