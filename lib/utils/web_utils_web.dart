// Web-specific implementation using dart:html
import 'dart:html' as html;

/// Logs localStorage keys for web platform debugging
void logLocalStorageKeys() {
  try {
    final keys = html.window.localStorage.keys;
    print('LocalStorage keys: $keys');
  } catch (e) {
    print('Error reading localStorage: $e');
  }
}
