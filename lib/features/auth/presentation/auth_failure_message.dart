import '../../../core/error/app_failure.dart';

/// A user-safe message for an auth-flow failure. Every [AppFailure] already
/// carries one from the mapper; this only supplies a fallback for the rare
/// case it doesn't, and never surfaces [AppFailure.cause].
String authFailureMessage(AppFailure failure) => switch (failure) {
  OfflineFailure() => "You're offline. Check your connection and try again.",
  AppFailure(message: final m?) => m,
  _ => 'Something went wrong. Please try again.',
};
