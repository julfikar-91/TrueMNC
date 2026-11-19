// lib/features/admin/companies/providers/company_admin_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/company.dart';
import '../../../../data/repositories/company_repository.dart';
import '../../../../data/repositories/paged_controller.dart';

// ── Enums ──────────────────────────────────────────────────────────────────

enum CompanyFilter {
  all,
  verified,
  unverified,
  collectionEnabled,
}

enum CompanySort {
  name,
  activeJobs,
  lastCollection,
}

// ── Primitive State Providers ──────────────────────────────────────────────

/// Tracks the current search query string entered in the company search bar.
final companySearchQueryProvider = StateProvider<String>((ref) => '');

/// Tracks the active filter chip selection on the company list screen.
final companyFilterProvider =
    StateProvider<CompanyFilter>((ref) => CompanyFilter.all);

/// Tracks the active sort option for the company list.
final companySortProvider =
    StateProvider<CompanySort>((ref) => CompanySort.name);

/// Holds the currently selected / detail-pane-open company, or null if none.
final selectedCompanyProvider = StateProvider<Company?>((ref) => null);

// ── Paginated Company List Provider ───────────────────────────────────────

/// Provides a [PagedController] that loads companies in pages of 20
/// using [CompanyRepository.listCompanies].
///
/// The controller auto-loads the first page on creation and exposes
/// [loadMore] and [refresh] for pagination and pull-to-refresh.
final companyListProvider =
    StateNotifierProvider<PagedController<Company>, PagedState<Company>>((ref) {
  final repository = ref.read(companyRepositoryProvider);

  return PagedController<Company>(
    (cursor) => repository.listCompanies(
      pageSize: 20,
      startAfter: cursor,
    ),
  );
});
