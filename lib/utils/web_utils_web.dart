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

/// Forcefully clears all Supabase auth-related data from browser storage
void clearAuthStorage() {
  try {
    final storage = html.window.localStorage;
    final sessionStorage = html.window.sessionStorage;
    
    // Clear all Supabase auth-related keys
    final keysToRemove = <String>[];
    for (var key in storage.keys) {
      if (key.contains('supabase') || key.contains('auth') || key.contains('sb-')) {
        keysToRemove.add(key);
      }
    }
    
    for (var key in keysToRemove) {
      storage.remove(key);
      print('🗑️ Cleared localStorage key: $key');
    }
    
    // Also clear session storage
    sessionStorage.clear();
    print('✅ Browser storage cleared successfully');
  } catch (e) {
    print('⚠️ Could not clear browser storage: $e');
  }
}
