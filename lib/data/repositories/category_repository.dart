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

/// Stream provider for all active job categories.
final activeCategoriesProvider = StreamProvider<List<Category>>((ref) {
  return ref.watch(categoryRepositoryProvider).watchActiveCategories();
});

/// Repository for retrieving categorized job taxonomy.
class CategoryRepository {
  CategoryRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection('categories');

  /// Streams active categories ordered by priority [order].
  Stream<List<Category>> watchActiveCategories() {
    try {
      return _col
          .where('active', isEqualTo: true)
          .orderBy('order')
          .snapshots()
          .map((snap) => snap.docs.map(Category.fromFirestore).toList());
    } catch (e, st) {
      throw handleException(e, st);
    }
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
}
