import 'app_failure.dart';

/// Resultado de una operación que puede fallar de forma esperada.
///
/// Los repositorios nunca lanzan excepciones hacia la UI: devuelven
/// `Success` o `Failure`, y el `switch` exhaustivo obliga a manejar ambos.
sealed class Result<T> {
  const Result();

  /// Valor si fue exitoso; `null` si falló.
  T? get valueOrNull => switch (this) {
    Success(:final value) => value,
    Failure() => null,
  };

  /// Transforma el valor exitoso conservando la falla.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Success(:final value) => Success(transform(value)),
    Failure(:final failure) => Failure(failure),
  };
}

final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;

  @override
  bool operator ==(Object other) => other is Success<T> && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Success($value)';
}

final class Failure<T> extends Result<T> {
  const Failure(this.failure);

  final AppFailure failure;

  @override
  String toString() => 'Failure($failure)';
}
