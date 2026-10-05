import 'failure.dart';

/// The outcome of an operation that can fail in an expected way: either
/// [Ok] with a value or [Err] with a [Failure]. Domain code returns this
/// instead of throwing across layers.
///
/// Prefer an exhaustive `switch` at the call site:
/// ```dart
/// switch (result) {
///   case Ok(:final value): ...
///   case Err(:final failure): ...
/// }
/// ```
sealed class Result<T, F extends Failure> {
  const Result();

  bool get isOk => this is Ok<T, F>;

  bool get isErr => this is Err<T, F>;

  T? get valueOrNull => switch (this) {
    Ok(:final value) => value,
    Err() => null,
  };

  F? get failureOrNull => switch (this) {
    Ok() => null,
    Err(:final failure) => failure,
  };

  R fold<R>(R Function(T value) onOk, R Function(F failure) onErr) =>
      switch (this) {
        Ok(:final value) => onOk(value),
        Err(:final failure) => onErr(failure),
      };

  Result<U, F> map<U>(U Function(T value) transform) => switch (this) {
    Ok(:final value) => Ok(transform(value)),
    Err(:final failure) => Err(failure),
  };

  Result<U, F> flatMap<U>(Result<U, F> Function(T value) transform) =>
      switch (this) {
        Ok(:final value) => transform(value),
        Err(:final failure) => Err(failure),
      };
}

final class Ok<T, F extends Failure> extends Result<T, F> {
  const Ok(this.value);

  final T value;

  @override
  bool operator ==(Object other) => other is Ok<T, F> && other.value == value;

  @override
  int get hashCode => Object.hash(Ok, value);

  @override
  String toString() => 'Ok($value)';
}

final class Err<T, F extends Failure> extends Result<T, F> {
  const Err(this.failure);

  final F failure;

  @override
  bool operator ==(Object other) =>
      other is Err<T, F> && other.failure == failure;

  @override
  int get hashCode => Object.hash(Err, failure);

  @override
  String toString() => 'Err($failure)';
}
