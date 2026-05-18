import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../config/env.dart';

/// Production-gated logger (master prompt §5).
///
/// - Production: `warning` and above only, no method traces, no ANSI colors
///   (CI/console logs stay clean).
/// - Dev/staging: `debug`+ with full method traces and pretty printing.
///
/// Use [AppLogger.instance] everywhere instead of `Logger()` so the level
/// gating is uniform. Existing call sites can stay on raw `Logger()` —
/// they'll show more output in dev, which is fine.
abstract final class AppLogger {
  AppLogger._();

  static Logger? _instance;

  static Logger get instance => _instance ??= _build();

  /// Optional explicit init in `main()` so the first log call doesn't pay
  /// the construction cost.
  static void init() {
    _instance ??= _build();
  }

  static Logger _build() {
    final isProd = Env.isProd;
    return Logger(
      level: isProd ? Level.warning : Level.debug,
      printer: PrettyPrinter(
        methodCount: isProd ? 0 : 2,
        errorMethodCount: 8,
        lineLength: 100,
        colors: !isProd,
        printEmojis: !isProd,
        dateTimeFormat: DateTimeFormat.none,
      ),
    );
  }

  // ── Global error handler bridges ───────────────────────────────────────────

  /// Wire to `FlutterError.onError` — catches synchronous framework errors.
  static void onFlutterError(FlutterErrorDetails details) {
    instance.e(
      'Flutter framework error',
      error: details.exception,
      stackTrace: details.stack,
    );
    // Forward to Flutter's default presentation in debug so devs still see
    // the red error screen.
    if (kDebugMode) FlutterError.presentError(details);
  }

  /// Wire to `PlatformDispatcher.instance.onError` — catches async / isolate
  /// errors that escape Flutter's framework.
  static bool onPlatformError(Object error, StackTrace stack) {
    instance.e('Platform/isolate error', error: error, stackTrace: stack);
    return true;
  }
}
