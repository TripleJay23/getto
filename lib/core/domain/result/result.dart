import 'failure.dart';

/// Sealed functional Result type representing either a successful [T] or a [Failure].
sealed class Result<T, F extends Failure> {
  const Result();

  const factory Result.success(T value) = Success<T, F>;
  const factory Result.failure(F failure) = FailureResult<T, F>;

  bool get isSuccess => this is Success<T, F>;
  bool get isFailure => this is FailureResult<T, F>;

  T? get valueOrNull => switch (this) {
    Success(:final value) => value,
    FailureResult() => null,
  };

  F? get failureOrNull => switch (this) {
    Success() => null,
    FailureResult(:final failure) => failure,
  };

  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(F failure) onFailure,
  }) => switch (this) {
    Success(:final value) => onSuccess(value),
    FailureResult(:final failure) => onFailure(failure),
  };

  Result<R, F> map<R>(R Function(T value) transform) => switch (this) {
    Success(:final value) => Success(transform(value)),
    FailureResult(:final failure) => FailureResult(failure),
  };

  Result<T, R> mapFailure<R extends Failure>(R Function(F failure) transform) =>
      switch (this) {
        Success(:final value) => Success(value),
        FailureResult(:final failure) => FailureResult(transform(failure)),
      };

  Result<R, F> flatMap<R>(Result<R, F> Function(T value) transform) =>
      switch (this) {
        Success(:final value) => transform(value),
        FailureResult(:final failure) => FailureResult(failure),
      };
}

class Success<T, F extends Failure> extends Result<T, F> {
  const Success(this.value);
  final T value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Success<T, F> &&
          runtimeType == other.runtimeType &&
          value == other.value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Success($value)';
}

class FailureResult<T, F extends Failure> extends Result<T, F> {
  const FailureResult(this.failure);
  final F failure;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FailureResult<T, F> &&
          runtimeType == other.runtimeType &&
          failure == other.failure;

  @override
  int get hashCode => failure.hashCode;

  @override
  String toString() => 'FailureResult($failure)';
}
