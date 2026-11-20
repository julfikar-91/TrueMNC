// lib/data/repositories/category_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_handler.dart';
import '../models/category.dart';
import '../services/firebase_service.dart';

/// Provider for [CategoryRepository].
final categoryRepositoryProvider = Provider<CategoryRepository>((ref) {
  return CategoryRepository(ref.watch(firestoreProvider));
});

/// In-memory session cached provider for all active job categories.
final activeCategoriesProvider = FutureProvider<List<Category>>((ref) async {
  ref.keepAlive();
  return ref.watch(categoryRepositoryProvider).getActiveCategories();
});

/// In-memory session cached provider for category counts from /stats/categoryCounts.
final categoryCountsProvider = FutureProvider<Map<String, int>>((ref) async {
  ref.keepAlive();
  return ref.watch(categoryRepositoryProvider).getCategoryCounts();
});

/// Repository for retrieving categorized job taxonomy.
class CategoryRepository {
  CategoryRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('categories');

  /// Streams active categories once (no persistent snapshot listener).
  Stream<List<Category>> watchActiveCategories() {
    return Stream.fromFuture(getActiveCategories());
  }

  /// Fetches active categories once.
  Future<List<Category>> getActiveCategories() async {
    try {
      final snap = await _col
          .where('active', isEqualTo: true)
          .orderBy('order')
          .get();
      return snap.docs.map(Category.fromFirestore).toList();
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  /// Fetches categoryCounts from /stats/categoryCounts once.
  Future<Map<String, int>> getCategoryCounts() async {
    try {
      final doc =
          await _firestore.collection('stats').doc('categoryCounts').get();
      if (!doc.exists || doc.data() == null) return const {};
      return doc.data()!.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (e, st) {
      throw handleException(e, st);
    }
  }
}
