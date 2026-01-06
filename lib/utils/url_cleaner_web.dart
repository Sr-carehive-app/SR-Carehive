import 'dart:html' as html;

void cleanOAuthCallbackUrl(String cleanUrl) {
  try {
    html.window.history.replaceState(null, '', cleanUrl);
    print('🧹 OAuth callback URL cleaned successfully');
  } catch (e) {
    print('⚠️ Could not clean URL: $e');
  }
}
