// lib/core/utils/result.dart
import 'package:equatable/equatable.dart';
import '../errors/app_exception.dart';

/// Sealed functional Result type representing either a [Success] value or a [Failure] exception.
sealed class Result<T> extends Equatable {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;

  T? get dataOrNull => switch (this) {
        Success(data: final d) => d,
        Failure() => null,
      };

  AppException? get exceptionOrNull => switch (this) {
        Success() => null,
        Failure(exception: final e) => e,
      };

  R fold<R>({
    required R Function(T data) onSuccess,
    required R Function(AppException exception) onFailure,
  }) {
    return switch (this) {
      Success(data: final d) => onSuccess(d),
      Failure(exception: final e) => onFailure(e),
    };
  }

  Result<R> map<R>(R Function(T data) transform) {
    return switch (this) {
      Success(data: final d) => Success(transform(d)),
      Failure(exception: final e) => Failure(e),
    };
  }

  static Result<T> guard<T>(T Function() block) {
    try {
      return Success(block());
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(UnknownException(e.toString()));
    }
  }

  static Future<Result<T>> guardAsync<T>(Future<T> Function() block) async {
    try {
      final res = await block();
      return Success(res);
    } on AppException catch (e) {
      return Failure(e);
    } catch (e) {
      return Failure(UnknownException(e.toString()));
    }
  }
}

final class Success<T> extends Result<T> {
  const Success(this.data);
  final T data;

  @override
  List<Object?> get props => [data];
}

final class Failure<T> extends Result<T> {
  const Failure(this.exception);
  final AppException exception;

  @override
  List<Object?> get props => [exception];
}
