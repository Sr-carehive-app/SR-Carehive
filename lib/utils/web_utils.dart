// Conditional import that selects the appropriate implementation
// based on the target platform
export 'web_utils_stub.dart'
    if (dart.library.html) 'web_utils_web.dart';
