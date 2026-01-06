import 'dart:html' as html;

void cleanOAuthCallbackUrl(String cleanUrl) {
  try {
    html.window.history.replaceState(null, '', cleanUrl);
    print('🧹 OAuth callback URL cleaned successfully');
  } catch (e) {
    print('⚠️ Could not clean URL: $e');
  }
}

void forceRedirectToBaseUrl(String baseUrl) {
  try {
    print('🔄 Force redirecting browser to: $baseUrl');
    html.window.location.href = baseUrl;
  } catch (e) {
    print('⚠️ Could not force redirect: $e');
  }
}
