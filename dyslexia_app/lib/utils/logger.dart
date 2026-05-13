import 'package:flutter/foundation.dart';

/// A unified logging utility for the Dyslexia App.
/// Replaces direct 'print' calls to allow better control over logging in production.
class AppLogger {
  /// Log an information message
  static void info(String message, {String? tag}) {
    _log('INFO', message, tag);
  }

  /// Log an error message
  static void error(String message, {dynamic error, StackTrace? stackTrace, String? tag}) {
    _log('ERROR', message, tag);
    if (error != null) {
      _log('ERROR_DETAILS', error.toString(), tag);
    }
    if (stackTrace != null) {
      _log('STACK_TRACE', stackTrace.toString(), tag);
    }
  }

  /// Log a warning message
  static void warning(String message, {String? tag}) {
    _log('WARNING', message, tag);
  }

  /// Internal log dispatcher
  static void _log(String level, String message, String? tag) {
    if (kDebugMode) {
      final String tagStr = tag != null ? '[$tag]' : '';
      // ignore: avoid_print
      print('$tagStr [$level] ${DateTime.now().toIso8601String()}: $message');
    }
  }
}
