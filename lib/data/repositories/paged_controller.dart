// lib/data/repositories/paged_controller.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/app_exception.dart';
import '../../core/errors/error_handler.dart';

/// Represents a single page of items fetched from Firestore or a remote source.
class PagedResult<T> {
  const PagedResult({
    required this.items,
    this.nextCursor,
    required this.hasMore,
  });

  final List<T> items;
  final DocumentSnapshot? nextCursor;
  final bool hasMore;
}

/// State representation for paginated lists.
class PagedState<T> {
  const PagedState({
    this.items = const [],
    this.cursor,
    this.hasMore = true,
    this.isLoading = false,
    this.error,
  });

  final List<T> items;
  final DocumentSnapshot? cursor;
  final bool hasMore;
  final bool isLoading;
  final AppException? error;

  PagedState<T> copyWith({
    List<T>? items,
    DocumentSnapshot? Function()? cursor,
    bool? hasMore,
    bool? isLoading,
    AppException? Function()? error,
  }) {
    return PagedState<T>(
      items: items ?? this.items,
      cursor: cursor != null ? cursor() : this.cursor,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      error: error != null ? error() : this.error,
    );
  }
}

/// Type signature for pagination fetch delegates.
typedef PagedFetchFn<T> = Future<PagedResult<T>> Function(DocumentSnapshot? cursor);

/// Shared paginated list controller implemented as a Riverpod [StateNotifier].
/// Handles initial loading, pagination with cursor, end-of-list detection,
/// error handling with domain exceptions, and pull-to-refresh.
class PagedController<T> extends StateNotifier<PagedState<T>> {
  PagedController(this._fetchFn, {bool autoLoad = true})
      : super(PagedState<T>(isLoading: autoLoad)) {
    if (autoLoad) {
      loadFirstPage();
    }
  }

  final PagedFetchFn<T> _fetchFn;

  List<T> get items => state.items;
  DocumentSnapshot? get cursor => state.cursor;
  bool get hasMore => state.hasMore;
  bool get isLoading => state.isLoading;
  AppException? get error => state.error;

  /// Loads or reloads the first page of items.
  Future<void> loadFirstPage() async {
    state = state.copyWith(
      isLoading: true,
      error: () => null,
      cursor: () => null,
    );
    try {
      final result = await _fetchFn(null);
      state = state.copyWith(
        items: result.items,
        cursor: () => result.nextCursor,
        hasMore: result.hasMore,
        isLoading: false,
        error: () => null,
      );
    } catch (e, st) {
      state = state.copyWith(
        isLoading: false,
        error: () => handleException(e, st),
      );
    }
  }

  /// Fetches the subsequent page using the current cursor.
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;

    state = state.copyWith(isLoading: true, error: () => null);
    try {
      final result = await _fetchFn(state.cursor);
      state = state.copyWith(
        items: [...state.items, ...result.items],
        cursor: () => result.nextCursor,
        hasMore: result.hasMore,
        isLoading: false,
        error: () => null,
      );
    } catch (e, st) {
      state = state.copyWith(
        isLoading: false,
        error: () => handleException(e, st),
      );
    }
  }

  /// Pull-to-refresh: resets cursor and reloads from beginning.
  Future<void> refresh() async {
    await loadFirstPage();
  }
}
