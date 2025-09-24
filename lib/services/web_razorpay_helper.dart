import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;

// Web implementation using Checkout.js loaded in web/index.html
class PlatformRazorpay {
  static Future<void> _ensureCheckoutLoaded() async {
    if (js_util.hasProperty(html.window, 'Razorpay')) return;
    final script = html.ScriptElement()
      ..src = 'https://checkout.razorpay.com/v1/checkout.js'
      ..async = true;
    final completer = Completer<void>();
    script.onLoad.listen((_) {
      if (!completer.isCompleted) completer.complete();
    });
    script.onError.listen((_) {
      if (!completer.isCompleted) completer.completeError('Failed to load Razorpay checkout.js');
    });
    html.document.head?.append(script);
    // Poll in case of cache
    final start = DateTime.now();
    while (!js_util.hasProperty(html.window, 'Razorpay')) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (DateTime.now().difference(start).inSeconds > 10) break;
    }
    if (!js_util.hasProperty(html.window, 'Razorpay')) {
      throw 'Razorpay not available after loading script';
    }
  }

  static void _ensureBridge() {
  if (js_util.hasProperty(html.window, 'care12OpenRazorpay')) return;
    final fn = html.ScriptElement()
      ..type = 'text/javascript'
      ..text = '''
      window.care12OpenRazorpay = function (options) {
        try {
          try { console.log('[care12] checkout options', options); } catch (_) {}
          if (!options.key && options.keyId) { options.key = options.keyId; }
          if (!options.key && options.key_id) { options.key = options.key_id; }
          window.care12LastOptions = options;
          var rzp = new Razorpay(options);
          rzp.on('payment.success', function (resp) {
            window.dispatchEvent(new CustomEvent('rzp_success', { detail: resp }));
          });
          rzp.on('payment.failed', function (resp) {
            window.dispatchEvent(new CustomEvent('rzp_failed', { detail: resp }));
          });
          rzp.open();
        } catch (e) {
          window.dispatchEvent(new CustomEvent('rzp_failed', { detail: { error: { code: 'exception', description: String(e) } } }));
        }
      };
      ''';
    html.document.head?.append(fn);
  }

  static Future<Map<String, dynamic>> open(Map<String, dynamic> options) {
    final completer = Completer<Map<String, dynamic>>();

    late html.EventListener successListener;
    late html.EventListener failedListener;

    void cleanup() {
      html.window.removeEventListener('rzp_success', successListener);
      html.window.removeEventListener('rzp_failed', failedListener);
    }

    successListener = (event) {
      try {
        final custom = event as html.CustomEvent;
        final detail = custom.detail as dynamic;
        cleanup();
        final map = jsonDecode(jsonEncode(detail)) as Map<String, dynamic>;
        // Normalize keys to server verify payload
        final normalized = <String, dynamic>{
          'razorpay_order_id': map['order_id'] ?? map['razorpay_order_id'],
          'razorpay_payment_id': map['payment_id'] ?? map['razorpay_payment_id'],
          'razorpay_signature': map['signature'] ?? map['razorpay_signature'],
        };
        completer.complete(normalized);
      } catch (e) {
        cleanup();
        completer.completeError(e);
      }
    };

    failedListener = (event) {
      try {
        final custom = event as html.CustomEvent;
        final detail = custom.detail as dynamic;
        cleanup();
        completer.completeError(jsonDecode(jsonEncode(detail)));
      } catch (e) {
        cleanup();
        completer.completeError(e);
      }
    };

    html.window.addEventListener('rzp_success', successListener);
    html.window.addEventListener('rzp_failed', failedListener);

    () async {
      try {
        await _ensureCheckoutLoaded();
        _ensureBridge();
        if (!js_util.hasProperty(html.window, 'care12OpenRazorpay')) {
          throw 'care12OpenRazorpay not found on window';
        }
        final jsOptions = js_util.jsify(options);
        js_util.callMethod(html.window, 'care12OpenRazorpay', [jsOptions]);
      } catch (e) {
        cleanup();
        completer.completeError('web_init_error: $e');
      }
    }();

    return completer.future;
  }
}
