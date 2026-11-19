// lib/data/repositories/company_repository.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/error_handler.dart';
import '../../core/utils/constants.dart';
import '../models/company.dart';
import '../services/firebase_service.dart';
import 'paged_controller.dart';

/// Provider for [CompanyRepository].
final companyRepositoryProvider = Provider<CompanyRepository>((ref) {
  return CompanyRepository(ref.watch(firestoreProvider));
});

/// Repository handling company directory lookups and tokenized searches.
class CompanyRepository {
  CompanyRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _col =>
      _firestore.collection(AppConstants.companiesCollection);

  // ── 1. Paginated List ──────────────────────────────────────────────────────

  Future<PagedResult<Company>> listCompanies({
    int pageSize = AppConstants.defaultPageSize,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _col
          .orderBy('name')
          .limit(pageSize);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      final items = snapshot.docs.map(Company.fromFirestore).toList();
      final nextCursor = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;

      return PagedResult<Company>(
        items: items,
        nextCursor: nextCursor,
        hasMore: items.length >= pageSize,
      );
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  // ── 2. Search by Name Tokens ───────────────────────────────────────────────

  /// Searches companies matching name tokens.
  Future<List<Company>> searchByNameTokens(
    String query, {
    int limit = AppConstants.defaultPageSize,
  }) async {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) return const [];

    try {
      final token = trimmed.split(RegExp(r'\s+')).first;

      final snapshot = await _col
          .where('nameTokens', arrayContains: token)
          .limit(limit)
          .get();

      if (snapshot.docs.isEmpty) {
        // Fallback to name prefix search if nameTokens array not yet populated
        final prefixEnd = '$trimmed\uf8ff';
        final fallbackSnap = await _col
            .where('name', isGreaterThanOrEqualTo: query)
            .where('name', isLessThanOrEqualTo: prefixEnd)
            .limit(limit)
            .get();
        return fallbackSnap.docs.map(Company.fromFirestore).toList();
      }

      return snapshot.docs.map(Company.fromFirestore).toList();
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  // ── 3. Single Company ──────────────────────────────────────────────────────

  Future<Company?> getById(String id) async {
    try {
      final doc = await _col.doc(id).get();
      if (!doc.exists) return null;
      return Company.fromFirestore(doc);
    } catch (e, st) {
      throw handleException(e, st);
    }
  }

  Stream<Company?> watchById(String id) {
    try {
      return _col.doc(id).snapshots().map((doc) {
        if (!doc.exists) return null;
        return Company.fromFirestore(doc);
      });
    } catch (e, st) {
      throw handleException(e, st);
    }
  }
}
