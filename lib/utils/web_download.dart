// Conditional export: picks the web implementation on Flutter Web,
// and the stub (no-op) on all other platforms.
export 'web_download_stub.dart'
    if (dart.library.html) 'web_download_web.dart';
