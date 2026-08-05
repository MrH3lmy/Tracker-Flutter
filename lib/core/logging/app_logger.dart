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

  /// Wires `package:logging` to `dart:developer` / stdout exactly once.
  /// [productionMode] bounds verbosity so request/response bodies and debug
  /// noise never ship to release builds.
  static void init({required bool productionMode}) {
    if (_initialized) return;
    _initialized = true;
    pkg.Logger.root.level = productionMode ? pkg.Level.WARNING : pkg.Level.ALL;
    pkg.Logger.root.onRecord.listen((record) {
      final redacted = redact(record.message);
      // ignore: avoid_print
      print('[${record.level.name}] ${record.loggerName}: $redacted');
    });
  }

  static String redact(String input) {
    var result = input;
    for (final fragment in _sensitiveKeyFragments) {
      final pattern = RegExp(
        '($fragment\\s*[:=]\\s*)([^,}]+)',
        caseSensitive: false,
      );
      result = result.replaceAllMapped(pattern, (m) => '${m[1]}<redacted>');
    }
    return result;
  }

  void debug(String message) => _logger.fine(message);

  void info(String message) => _logger.info(message);

  void warning(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.warning(message, error, stackTrace);

  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.severe(message, error, stackTrace);
}
