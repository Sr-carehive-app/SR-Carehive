import 'package:flutter/material.dart';
import 'dart:async';

/// Safe Navigation Utility
/// Prevents frozen/unresponsive back buttons by handling navigation safely
class SafeNavigation {
  // Debounce timer to prevent multiple rapid clicks
  static final Map<String, Timer> _debouncers = {};
  static const Duration _debounceDuration = Duration(milliseconds: 300);
  
  /// Safe Navigator.pop with debouncing and context validation
  /// Use this instead of direct Navigator.pop(context)
  static void pop(
    BuildContext context, {
    dynamic result,
    String? debugLabel,
  }) {
    final label = debugLabel ?? 'back_button';
    
    // Debounce: Ignore if button clicked too quickly
    if (_debouncers.containsKey(label)) {
      return; // Already processing, ignore this click
    }
    
    // Set debounce timer
    _debouncers[label] = Timer(_debounceDuration, () {
      _debouncers.remove(label);
    });
    
    // Perform safe navigation
    _safePop(context, result: result);
  }
  
  /// Internal safe pop with all validation checks
  static void _safePop(BuildContext context, {dynamic result}) {
    // Check 1: Widget must still be mounted
    if (context is StatefulWidget && !(context as dynamic).mounted) {
      debugPrint('[SafeNav] Widget not mounted, skipping pop');
      return;
    }
    
    // Check 2: Context must be valid
    try {
      if (!context.mounted) {
        debugPrint('[SafeNav] Context not mounted, skipping pop');
        return;
      }
    } catch (e) {
      debugPrint('[SafeNav] Error checking context: $e');
      return;
    }
    
    // Check 3: Navigator must be able to pop
    final navigator = Navigator.of(context, rootNavigator: false);
    if (!navigator.canPop()) {
      debugPrint('[SafeNav] Navigator cannot pop, skipping');
      return;
    }
    
    // Safe to pop
    try {
      navigator.pop(result);
    } catch (e) {
      debugPrint('[SafeNav] Error during pop: $e');
      // Fallback: try root navigator
      try {
        Navigator.of(context, rootNavigator: true).pop(result);
      } catch (e2) {
        debugPrint('[SafeNav] Fallback pop also failed: $e2');
      }
    }
  }
  
  /// Safe back button for AppBar leading
  /// Returns a properly configured IconButton
  static Widget backButton(
    BuildContext context, {
    VoidCallback? onPressed,
    Color color = Colors.white,
    String? debugLabel,
  }) {
    return IconButton(
      icon: Icon(Icons.arrow_back, color: color),
      onPressed: () {
        if (onPressed != null) {
          onPressed();
        } else {
          pop(context, debugLabel: debugLabel ?? 'app_bar_back');
        }
      },
    );
  }
  
  /// Clear all debouncers (useful for testing or cleanup)
  static void clearDebouncers() {
    for (var timer in _debouncers.values) {
      timer.cancel();
    }
    _debouncers.clear();
  }
}
