/// Minimal Result type for service return values.
/// Uses Dart 3 sealed classes for exhaustive pattern matching.
sealed class Result<T, E> {
  const Result();
}

final class Ok<T, E> extends Result<T, E> {
  const Ok(this.value);
  final T value;
}

final class Err<T, E> extends Result<T, E> {
  const Err(this.error);
  final E error;
}

/// Void-equivalent for Result<Unit, E> when success carries no value.
final class Unit {
  const Unit._();
  static const Unit instance = Unit._();
}
