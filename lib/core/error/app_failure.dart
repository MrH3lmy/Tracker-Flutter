/// Shared failure taxonomy for the app.
///
/// Data sources (starting with the networking layer) map their raw errors
/// onto these cases so every feature can render errors consistently without
/// depending on transport-specific exception types.
sealed class AppFailure {
  const AppFailure({this.message, this.cause});

  /// A user-safe message. Never contains stack traces or backend internals.
  final String? message;

  /// The original error, kept for logging only — never shown to the user.
  final Object? cause;

  @override
  String toString() => '$runtimeType(${message ?? cause})';
}

final class NetworkFailure extends AppFailure {
  const NetworkFailure({super.message, super.cause});
}

final class TimeoutFailure extends AppFailure {
  const TimeoutFailure({super.message, super.cause});
}

final class OfflineFailure extends AppFailure {
  const OfflineFailure({super.message, super.cause});
}

final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure({super.message, super.cause});
}

final class ValidationFailure extends AppFailure {
  const ValidationFailure({
    this.fieldErrors = const {},
    super.message,
    super.cause,
  });

  /// Field name -> user-facing error message.
  final Map<String, String> fieldErrors;
}

final class ConflictFailure extends AppFailure {
  const ConflictFailure({super.message, super.cause});
}

final class RateLimitedFailure extends AppFailure {
  const RateLimitedFailure({this.retryAfter, super.message, super.cause});

  final Duration? retryAfter;
}

final class ServerFailure extends AppFailure {
  const ServerFailure({this.statusCode, super.message, super.cause});

  final int? statusCode;
}

final class CancelledFailure extends AppFailure {
  const CancelledFailure({super.message, super.cause});
}

final class UnknownFailure extends AppFailure {
  const UnknownFailure({super.message, super.cause});
}
