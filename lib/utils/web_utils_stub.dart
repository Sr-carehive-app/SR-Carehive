// Stub implementation for non-web platforms (mobile)
// This file is used when compiling for Android/iOS

/// Logs localStorage keys for web platform debugging
/// On mobile platforms, this is a no-op since localStorage doesn't exist
void logLocalStorageKeys() {
  // No-op on mobile platforms
  print('LocalStorage not available on mobile platforms');
}

/// Clears auth storage (no-op on mobile)
void clearAuthStorage() {
  // No-op on mobile platforms
  print('Browser storage clearing not needed on mobile platforms');
}
