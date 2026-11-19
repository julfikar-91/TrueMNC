// test/data/repositories/paged_controller_test.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:true_corporate_job_finder/core/errors/app_exception.dart';
import 'package:true_corporate_job_finder/data/repositories/paged_controller.dart';

// ── Mock DocumentSnapshot for testing cursors ────────────────────────────────
// ignore: subtype_of_sealed_class
class FakeDocumentSnapshot implements DocumentSnapshot<Map<String, dynamic>> {
  FakeDocumentSnapshot(this.id);

  @override
  final String id;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('PagedController unit tests', () {
    test('1. First page: loads first page successfully and sets cursor', () async {
      final doc1 = FakeDocumentSnapshot('doc_20');
      var fetchCallCount = 0;
      DocumentSnapshot? requestedCursor;

      final controller = PagedController<String>(
        (cursor) async {
          fetchCallCount++;
          requestedCursor = cursor;
          final items = List.generate(20, (i) => 'Item ${i + 1}');
          return PagedResult<String>(
            items: items,
            nextCursor: doc1,
            hasMore: true,
          );
        },
        autoLoad: false,
      );

      expect(controller.state.items, isEmpty);
      expect(controller.state.isLoading, isFalse);

      await controller.loadFirstPage();

      expect(fetchCallCount, 1);
      expect(requestedCursor, isNull);
      expect(controller.state.items.length, 20);
      expect(controller.state.items.first, 'Item 1');
      expect(controller.state.items.last, 'Item 20');
      expect(controller.state.cursor, equals(doc1));
      expect(controller.state.hasMore, isTrue);
      expect(controller.state.isLoading, isFalse);
      expect(controller.state.error, isNull);
    });

    test('2. Next page (loadMore): appends items and advances cursor', () async {
      final doc1 = FakeDocumentSnapshot('doc_20');
      final doc2 = FakeDocumentSnapshot('doc_40');
      final requestedCursors = <DocumentSnapshot?>[];

      final controller = PagedController<String>(
        (cursor) async {
          requestedCursors.add(cursor);
          if (cursor == null) {
            return PagedResult<String>(
              items: List.generate(20, (i) => 'Item ${i + 1}'),
              nextCursor: doc1,
              hasMore: true,
            );
          } else {
            return PagedResult<String>(
              items: List.generate(20, (i) => 'Item ${i + 21}'),
              nextCursor: doc2,
              hasMore: true,
            );
          }
        },
        autoLoad: false,
      );

      await controller.loadFirstPage();
      expect(controller.state.items.length, 20);

      await controller.loadMore();

      expect(requestedCursors.length, 2);
      expect(requestedCursors[0], isNull);
      expect(requestedCursors[1], equals(doc1));
      expect(controller.state.items.length, 40);
      expect(controller.state.items[0], 'Item 1');
      expect(controller.state.items[20], 'Item 21');
      expect(controller.state.items[39], 'Item 40');
      expect(controller.state.cursor, equals(doc2));
      expect(controller.state.hasMore, isTrue);
      expect(controller.state.isLoading, isFalse);
    });

    test('3. End of list: sets hasMore=false and prevents subsequent fetches', () async {
      final doc1 = FakeDocumentSnapshot('doc_5');
      var callCount = 0;

      final controller = PagedController<String>(
        (cursor) async {
          callCount++;
          return PagedResult<String>(
            items: ['A', 'B', 'C', 'D', 'E'],
            nextCursor: doc1,
            hasMore: false, // End of list reached
          );
        },
        autoLoad: false,
      );

      await controller.loadFirstPage();

      expect(callCount, 1);
      expect(controller.state.items.length, 5);
      expect(controller.state.hasMore, isFalse);

      // Attempting to loadMore when hasMore is false should be a no-op
      await controller.loadMore();

      expect(callCount, 1); // Not called again
      expect(controller.state.items.length, 5);
      expect(controller.state.hasMore, isFalse);
    });

    test('4. Error handling: maps exception into AppException and sets error state', () async {
      final controller = PagedController<String>(
        (cursor) async {
          throw FirebaseException(
            plugin: 'cloud_firestore',
            code: 'unavailable',
            message: 'Service is temporarily down.',
          );
        },
        autoLoad: false,
      );

      await controller.loadFirstPage();

      expect(controller.state.isLoading, isFalse);
      expect(controller.state.items, isEmpty);
      expect(controller.state.error, isNotNull);
      expect(controller.state.error, isA<NetworkException>());
    });

    test('5. Refresh: resets cursor and re-fetches first page cleanly', () async {
      final doc1 = FakeDocumentSnapshot('cursor_page_1');
      final doc2 = FakeDocumentSnapshot('cursor_page_2');
      final cursorsCalled = <DocumentSnapshot?>[];

      final controller = PagedController<String>(
        (cursor) async {
          cursorsCalled.add(cursor);
          if (cursor == null) {
            return PagedResult<String>(
              items: ['Fresh 1', 'Fresh 2'],
              nextCursor: doc1,
              hasMore: true,
            );
          } else {
            return PagedResult<String>(
              items: ['Fresh 3', 'Fresh 4'],
              nextCursor: doc2,
              hasMore: false,
            );
          }
        },
        autoLoad: false,
      );

      // 1. Initial page
      await controller.loadFirstPage();
      expect(controller.state.items, ['Fresh 1', 'Fresh 2']);

      // 2. Next page
      await controller.loadMore();
      expect(controller.state.items, ['Fresh 1', 'Fresh 2', 'Fresh 3', 'Fresh 4']);

      // 3. Refresh should reset cursor back to null and reload from beginning
      await controller.refresh();

      expect(cursorsCalled.last, isNull);
      expect(controller.state.items, ['Fresh 1', 'Fresh 2']);
      expect(controller.state.cursor, equals(doc1));
      expect(controller.state.hasMore, isTrue);
      expect(controller.state.error, isNull);
    });
  });
}
