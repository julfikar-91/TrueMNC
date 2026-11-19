// lib/core/utils/extensions.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../errors/app_exception.dart';
import 'result.dart';

/// BuildContext convenience extensions.
extension ContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colorScheme => Theme.of(this).colorScheme;
  TextTheme get textTheme => Theme.of(this).textTheme;
  MediaQueryData get mediaQuery => MediaQuery.of(this);
  double get screenWidth => mediaQuery.size.width;
  double get screenHeight => mediaQuery.size.height;
  bool get isDarkMode => theme.brightness == Brightness.dark;

  void showSnackBar(
    String message, {
    bool isError = false,
    Duration duration = const Duration(seconds: 4),
    SnackBarAction? action,
  }) {
    ScaffoldMessenger.of(this).hideCurrentSnackBar();
    ScaffoldMessenger.of(this).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor:
            isError ? colorScheme.error : colorScheme.inverseSurface,
        duration: duration,
        action: action,
      ),
    );
  }
}

/// AsyncValue UI & functional helpers for Riverpod state.
extension AsyncValueX<T> on AsyncValue<T> {
  /// Returns a clean user-facing error message string or null.
  String? get errorMessage {
    return whenOrNull(
      error: (e, _) {
        if (e is AppException) return e.message;
        return e.toString();
      },
    );
  }

  /// Converts this [AsyncValue] to a [Result] if completed, or null if loading.
  Result<T>? toResultOrNull() {
    return when(
      data: (data) => Success(data),
      error: (e, _) {
        if (e is AppException) return Failure(e);
        return Failure(UnknownException(e.toString()));
      },
      loading: () => null,
    );
  }

  /// True if loading or reloading/refreshing.
  bool get isAnyLoading => isLoading || isRefreshing || isReloading;
}
