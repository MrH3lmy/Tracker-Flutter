import 'package:logging/logging.dart' as pkg;

/// Keys whose values must never reach a log sink, regardless of source.
///
/// Case-insensitive, matched anywhere in a message or structured field name.
const _sensitiveKeyFragments = <String>[
  'password',
  'token',
  'authorization',
  'cookie',
  'secret',
  'refresh',
  'access_token',
  'set-cookie',
];

/// Thin wrapper around `package:logging` that redacts sensitive values
/// before anything is written to a sink, and gives features a small typed
/// surface (`debug`/`info`/`warning`/`error`) instead of raw `Logger` calls.
class AppLogger {
  AppLogger(String name) : _logger = pkg.Logger(name);

  final pkg.Logger _logger;

  static bool _initialized = false;

  /// Wires `package:logging` to stdout exactly once.
  /// [productionMode] bounds verbosity so request/response bodies and debug
  /// noise never ship to release builds.
  static void init({required bool productionMode}) {
    if (_initialized) return;
    _initialized = true;
    pkg.Logger.root.level = productionMode ? pkg.Level.WARNING : pkg.Level.ALL;
    pkg.Logger.root.onRecord.listen((record) {
      // ignore: avoid_print
      print(formatRecord(record));
    });
  }

  static String redact(String input) {
    var result = input;
    for (final fragment in _sensitiveKeyFragments) {
      final pattern = RegExp(
        '($fragment\\s*[:=]\\s*)([^,}]+)',
        caseSensitive: false,
      );
      result = result.replaceAllMapped(pattern, (match) {
        return '${match[1]}<redacted>';
      });
    }

    result = result.replaceAll(
      RegExp(r'\bBearer\s+[^\s,}]+', caseSensitive: false),
      'Bearer <redacted>',
    );
    return result;
  }

  /// Formats the complete record, including sanitized error and stack trace,
  /// so diagnostic context is retained without leaking credentials.
  static String formatRecord(pkg.LogRecord record) {
    final buffer = StringBuffer(
      '[${record.level.name}] ${record.loggerName}: '
      '${redact(record.message)}',
    );

    if (record.error != null) {
      buffer.write('\nError: ${redact(record.error.toString())}');
    }
    if (record.stackTrace != null) {
      buffer.write('\nStack trace:\n${redact(record.stackTrace.toString())}');
    }

    return buffer.toString();
  }

  void debug(String message) => _logger.fine(message);

  void info(String message) => _logger.info(message);

  void warning(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.warning(message, error, stackTrace);

  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.severe(message, error, stackTrace);
}
