import 'package:meta/meta.dart';

/// Ошибка доменного уровня с кодом и подробным описанием причины.
@immutable
final class DomainError {
  /// Уникальный машинно-читаемый код ошибки.
  final String code;

  /// Человекочитаемое сообщение об ошибке на русском языке.
  final String message;

  /// Дополнительный контекст ошибки (опционально).
  final String? details;

  const DomainError({
    required this.code,
    required this.message,
    this.details,
  });

  @override
  String toString() =>
      details == null ? '[$code] $message' : '[$code] $message ($details)';
}

/// Иерархия результата выполнения операции для исчерпывающего сопоставления с образцом.
@immutable
sealed class Result<T> {
  const Result();

  /// Создает успешный результат.
  const factory Result.success(T value) = Success<T>;

  /// Создает результат с ошибкой.
  const factory Result.failure(DomainError error) = Failure<T>;

  /// Возвращает `true`, если операция завершилась успешно.
  bool get isSuccess => this is Success<T>;

  /// Возвращает `true`, если операция завершилась ошибкой.
  bool get isFailure => this is Failure<T>;
}

/// Успешное завершение доменной операции.
@immutable
final class Success<T> extends Result<T> {
  /// Полученное значение результата.
  final T value;

  const Success(this.value);
}

/// Завершение доменной операции с ошибкой.
@immutable
final class Failure<T> extends Result<T> {
  /// Информация о доменной ошибке.
  final DomainError error;

  const Failure(this.error);
}

