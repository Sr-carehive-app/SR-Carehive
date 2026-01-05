import 'package:flutter/material.dart';
import 'dart:async';

/// Safe Navigation Utility
/// Prevents frozen/unresponsive back buttons by handling navigation safely
class SafeNavigation {
  // Debounce timer to prevent multiple rapid clicks
  static final Map<String, Timer> _debouncers = {};
  static const Duration _debounceDuration = Duration(milliseconds: 100);
  
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
    // Check 1: Context must be mounted
    try {
      if (!context.mounted) {
        debugPrint('[SafeNav] Context not mounted, skipping pop');
        return;
      }
    } catch (e) {
      debugPrint('[SafeNav] Error checking context: $e');
      return;
    }
    
    // Check 2: Navigator must exist and be able to pop
    try {
      final navigator = Navigator.maybeOf(context, rootNavigator: false);
      if (navigator == null) {
        debugPrint('[SafeNav] No navigator found, skipping pop');
        return;
      }
      
      if (!navigator.canPop()) {
        debugPrint('[SafeNav] Navigator cannot pop, skipping');
        return;
      }
      
      // Safe to pop
      navigator.pop(result);
    } catch (e) {
      debugPrint('[SafeNav] Error during pop: $e');
      // Fallback: try root navigator
      try {
        final rootNav = Navigator.maybeOf(context, rootNavigator: true);
        if (rootNav != null && rootNav.canPop()) {
          rootNav.pop(result);
        }
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
