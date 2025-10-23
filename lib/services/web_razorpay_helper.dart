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
  // Use the bridge from index.html - it has proper handler setup
  // This method now just checks if bridge exists
    if (js_util.hasProperty(html.window, 'care12OpenRazorpay')) {
      print('[Flutter] ✅ Razorpay bridge already loaded from index.html');
      return;
    }
    
    // Fallback: define bridge if somehow missing (shouldn't happen with index.html)
    final fn = html.ScriptElement()
      ..type = 'text/javascript'
      ..text = '''
      window.care12OpenRazorpay = function (options) {
        try {
          console.log('[care12] Starting Razorpay checkout with options:', options);
          
          if (!options.key && options.keyId) { options.key = options.keyId; }
          if (!options.key && options.key_id) { options.key = options.key_id; }
          
          window.care12LastOptions = options;
          
          // Primary success handler - this is called when payment succeeds
          options.handler = function (response) {
            console.log('[care12] ✅ Payment success handler called:', response);
            try {
              // Dispatch success event immediately
              var successEvent = new CustomEvent('rzp_success', { 
                detail: {
                  razorpay_payment_id: response.razorpay_payment_id,
                  razorpay_order_id: response.razorpay_order_id,
                  razorpay_signature: response.razorpay_signature,
                  payment_id: response.razorpay_payment_id,
                  order_id: response.razorpay_order_id,
                  signature: response.razorpay_signature
                }
              });
              window.dispatchEvent(successEvent);
              console.log('[care12] ✅ Success event dispatched');
            } catch (e) {
              console.error('[care12] ❌ Error in success handler:', e);
              window.dispatchEvent(new CustomEvent('rzp_failed', { 
                detail: { error: { code: 'handler_exception', description: String(e) } } 
              }));
            }
          };
          
          // Modal dismiss handler - user closes payment screen
          options.modal = options.modal || {};
          var originalOnDismiss = options.modal.ondismiss;
          options.modal.ondismiss = function () {
            console.log('[care12] ⚠️ Payment modal dismissed by user');
            if (originalOnDismiss) originalOnDismiss();
            window.dispatchEvent(new CustomEvent('rzp_failed', { 
              detail: { error: { code: 'cancelled', description: 'Checkout dismissed by user' } } 
            }));
          };
          
          // Create Razorpay instance
          var rzp = new Razorpay(options);
          
          // Additional event listeners for payment lifecycle
          rzp.on('payment.success', function (response) {
            console.log('[care12] 🎉 payment.success event:', response);
            // Dispatch success event
            window.dispatchEvent(new CustomEvent('rzp_success', { 
              detail: {
                razorpay_payment_id: response.razorpay_payment_id,
                razorpay_order_id: response.razorpay_order_id,
                razorpay_signature: response.razorpay_signature,
                payment_id: response.razorpay_payment_id,
                order_id: response.razorpay_order_id,
                signature: response.razorpay_signature
              }
            }));
          });
          
          rzp.on('payment.failed', function (response) {
            console.log('[care12] ❌ payment.failed event:', response);
            window.dispatchEvent(new CustomEvent('rzp_failed', { detail: response }));
          });
          
          rzp.on('payment.cancelled', function () {
            console.log('[care12] ⚠️ payment.cancelled event');
            window.dispatchEvent(new CustomEvent('rzp_failed', { 
              detail: { error: { code: 'cancelled', description: 'Payment cancelled by user huihui' } } 
            }));
          });
          
          // Open Razorpay checkout
          console.log('[care12] Opening Razorpay checkout...');
          rzp.open();
          
        } catch (e) {
          console.error('[care12] ❌ Exception in care12OpenRazorpay:', e);
          window.dispatchEvent(new CustomEvent('rzp_failed', { 
            detail: { error: { code: 'exception', description: String(e) } } 
          }));
        }
      };
      
      console.log('[care12] Bridge function registered successfully');
      ''';
    html.document.head?.append(fn);
  }

  static Future<Map<String, dynamic>> open(Map<String, dynamic> options) {
    final completer = Completer<Map<String, dynamic>>();

    late html.EventListener successListener;
    late html.EventListener failedListener;
    
    bool isCompleted = false;

    void cleanup() {
      print('[Flutter] Cleaning up event listeners');
      html.window.removeEventListener('rzp_success', successListener);
      html.window.removeEventListener('rzp_failed', failedListener);
    }

    successListener = (event) {
      if (isCompleted) {
        print('[Flutter] ⚠️ Success event received but already completed');
        return;
      }
      
      try {
        print('[Flutter] ✅ Success event received in Flutter');
        final custom = event as html.CustomEvent;
        final detail = custom.detail as dynamic;
        
        isCompleted = true;
        cleanup();
        
        final map = jsonDecode(jsonEncode(detail)) as Map<String, dynamic>;
        print('[Flutter] Success payload: $map');
        
        // Normalize keys to server verify payload
        final normalized = <String, dynamic>{
          'razorpay_order_id': map['razorpay_order_id'] ?? map['order_id'],
          'razorpay_payment_id': map['razorpay_payment_id'] ?? map['payment_id'],
          'razorpay_signature': map['razorpay_signature'] ?? map['signature'],
        };
        
        print('[Flutter] Normalized payload: $normalized');
        
        if (!completer.isCompleted) {
          completer.complete(normalized);
          print('[Flutter] ✅ Payment success completed');
        }
      } catch (e) {
        print('[Flutter] ❌ Error in success listener: $e');
        isCompleted = true;
        cleanup();
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
      }
    };

    failedListener = (event) {
      if (isCompleted) {
        print('[Flutter] ⚠️ Failed event received but already completed');
        return;
      }
      
      try {
        print('[Flutter] ❌ Failed event received in Flutter');
        final custom = event as html.CustomEvent;
        final detail = custom.detail as dynamic;
        
        isCompleted = true;
        cleanup();
        
        final errorData = jsonDecode(jsonEncode(detail));
        print('[Flutter] Error payload: $errorData');
        
        if (!completer.isCompleted) {
          completer.completeError(errorData);
          print('[Flutter] ❌ Payment failed completed');
        }
      } catch (e) {
        print('[Flutter] ❌ Error in failed listener: $e');
        isCompleted = true;
        cleanup();
        if (!completer.isCompleted) {
          completer.completeError(e);
        }
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
