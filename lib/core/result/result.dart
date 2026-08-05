import '../error/app_failure.dart';

/// A generic outcome type for operations that can fail.
///
/// Feature and data layers should return `Result<T>` instead of throwing,
/// so callers are forced to handle failures explicitly.
sealed class Result<T> {
  const Result();

  const factory Result.success(T value) = Success<T>;
  const factory Result.failure(AppFailure failure) = Failure<T>;

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  /// Returns the success value, or `null` when this is a [Failure].
  T? get valueOrNull => switch (this) {
    Success<T>(:final value) => value,
    Failure<T>() => null,
  };

  /// Returns the failure, or `null` when this is a [Success].
  AppFailure? get failureOrNull => switch (this) {
    Success<T>() => null,
    Failure<T>(:final failure) => failure,
  };

  /// Pattern-matches on the result, forcing both branches to be handled.
  R when<R>({
    required R Function(T value) success,
    required R Function(AppFailure failure) failure,
  }) => switch (this) {
    Success<T>(:final value) => success(value),
    Failure<T>(failure: final f) => failure(f),
  };

  /// Transforms the success value, leaving a failure untouched.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Success<T>(:final value) => Result.success(transform(value)),
    Failure<T>(:final failure) => Result.failure(failure),
  };
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Success<T> && other.value == value);

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() => 'Success<$T>($value)';
}

final class Failure<T> extends Result<T> {
  const Failure(this.failure);

  final AppFailure failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Failure<T> && other.failure == failure);

  @override
  int get hashCode => Object.hash(runtimeType, failure);

  @override
  String toString() => 'Failure<$T>($failure)';
}
