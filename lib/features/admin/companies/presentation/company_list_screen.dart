import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/skeleton_list.dart';
import '../../../../data/models/company.dart';
import '../../../../data/repositories/company_repository.dart';
import '../providers/company_admin_providers.dart';
import '../widgets/company_card.dart';

// ---------------------------------------------------------------------------
// Search provider (FutureProvider.family) for name-token search results
// ---------------------------------------------------------------------------
final _companySearchProvider =
    FutureProvider.family<List<Company>, String>((ref, query) async {
  if (query.isEmpty) return [];
  final repo = ref.read(companyRepositoryProvider);
  return repo.searchByNameTokens(query);
});

// ---------------------------------------------------------------------------
// Screen
// ---------------------------------------------------------------------------
class CompanyListScreen extends ConsumerStatefulWidget {
  const CompanyListScreen({super.key});

  @override
  ConsumerState<CompanyListScreen> createState() => _CompanyListScreenState();
}

class _CompanyListScreenState extends ConsumerState<CompanyListScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      ref.read(companySearchQueryProvider.notifier).state = value.trim();
    });
  }

  void _onScroll() {
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      // Trigger load-more only when not in search mode
      if (ref.read(companySearchQueryProvider).isEmpty) {
        ref.read(companyListProvider.notifier).loadMore();
      }
    }
  }

  // -------------------------------------------------------------------------
  // Client-side filter + sort helpers
  // -------------------------------------------------------------------------
  List<Company> _applyFilter(List<Company> companies, CompanyFilter filter) {
    switch (filter) {
      case CompanyFilter.verified:
        return companies.where((c) => c.isVerified).toList();
      case CompanyFilter.unverified:
        return companies.where((c) => !c.isVerified).toList();
      case CompanyFilter.collectionEnabled:
        return companies
            .where((c) => c.sources.any((s) => s.isActive))
            .toList();
      case CompanyFilter.all:
        return companies;
    }
  }

  List<Company> _applySort(List<Company> companies, CompanySort sort) {
    final list = List<Company>.from(companies);
    switch (sort) {
      case CompanySort.name:
        list.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case CompanySort.activeJobs:
        // Placeholder: sort by name until activeJobs count is available
        list.sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      case CompanySort.lastCollection:
        list.sort((a, b) {
          final aTime = a.updatedAt;
          final bTime = b.updatedAt;
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime); // most recent first
        });
    }
    return list;
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final searchQuery = ref.watch(companySearchQueryProvider);
    final filter = ref.watch(companyFilterProvider);
    final sort = ref.watch(companySortProvider);

    return Scaffold(
      appBar: _buildAppBar(context),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.go('/admin/companies/add'),
        tooltip: 'Add company',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(filter),
          _buildSortDropdown(sort),
          Expanded(
            child: searchQuery.isNotEmpty
                ? _buildSearchResults(searchQuery, filter, sort)
                : _buildPagedList(filter, sort),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // AppBar
  // -------------------------------------------------------------------------
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: const Text('Companies'),
      actions: [
        IconButton(
          icon: const Icon(Icons.add),
          tooltip: 'Add company',
          onPressed: () => context.go('/admin/companies/add'),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------------
  // Search bar
  // -------------------------------------------------------------------------
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search companies…',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchController,
            builder: (_, value, __) => value.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(companySearchQueryProvider.notifier).state = '';
                    },
                  )
                : const SizedBox.shrink(),
          ),
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        onChanged: _onSearchChanged,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Filter chips
  // -------------------------------------------------------------------------
  Widget _buildFilterChips(CompanyFilter currentFilter) {
    const chips = [
      (label: 'All', value: CompanyFilter.all),
      (label: 'Verified', value: CompanyFilter.verified),
      (label: 'Unverified', value: CompanyFilter.unverified),
      (label: 'Collection Enabled', value: CompanyFilter.collectionEnabled),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: chips
            .map(
              (chip) => Padding(
                padding: const EdgeInsets.only(right: AppSpacing.xs),
                child: FilterChip(
                  label: Text(chip.label),
                  selected: currentFilter == chip.value,
                  onSelected: (_) {
                    ref.read(companyFilterProvider.notifier).state = chip.value;
                  },
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Sort dropdown
  // -------------------------------------------------------------------------
  Widget _buildSortDropdown(CompanySort currentSort) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      child: Row(
        children: [
          const Text('Sort by: '),
          const SizedBox(width: AppSpacing.xs),
          DropdownButton<CompanySort>(
            value: currentSort,
            isDense: true,
            items: const [
              DropdownMenuItem(
                value: CompanySort.name,
                child: Text('Name'),
              ),
              DropdownMenuItem(
                value: CompanySort.activeJobs,
                child: Text('Active Jobs'),
              ),
              DropdownMenuItem(
                value: CompanySort.lastCollection,
                child: Text('Last Collection'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                ref.read(companySortProvider.notifier).state = value;
              }
            },
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Search results (FutureProvider)
  // -------------------------------------------------------------------------
  Widget _buildSearchResults(
    String query,
    CompanyFilter filter,
    CompanySort sort,
  ) {
    final async = ref.watch(_companySearchProvider(query));

    return async.when(
      loading: () => const SkeletonList(itemCount: 5),
      error: (err, _) => _buildError(err.toString(), () {
        ref.invalidate(_companySearchProvider(query));
      }),
      data: (companies) {
        final filtered = _applyFilter(companies, filter);
        final sorted = _applySort(filtered, sort);

        if (sorted.isEmpty) {
          return _buildEmpty();
        }

        return ListView.builder(
          controller: _scrollController,
          itemCount: sorted.length,
          itemBuilder: (context, index) => _buildCard(sorted[index]),
        );
      },
    );
  }

  // -------------------------------------------------------------------------
  // Paged list (infinite scroll)
  // -------------------------------------------------------------------------
  Widget _buildPagedList(CompanyFilter filter, CompanySort sort) {
    final pagedState = ref.watch(companyListProvider);

    if (pagedState.isLoading && pagedState.items.isEmpty) {
      return const SkeletonList(itemCount: 5);
    }

    if (pagedState.error != null && pagedState.items.isEmpty) {
      return _buildError(pagedState.error.toString(), () {
        ref.read(companyListProvider.notifier).refresh();
      });
    }

    final filtered = _applyFilter(pagedState.items, filter);
    final sorted = _applySort(filtered, sort);

    if (sorted.isEmpty) {
      return _buildEmpty();
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.read(companyListProvider.notifier).refresh();
      },
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: sorted.length + (pagedState.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == sorted.length) {
            // Load-more indicator at the bottom
            return const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _buildCard(sorted[index]);
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Company card
  // -------------------------------------------------------------------------
  Widget _buildCard(Company company) {
    return CompanyCard(
      company: company,
      onTap: () => context.go('/admin/companies/${company.id}'),
      onEdit: () => context.go('/admin/companies/${company.id}/edit'),
    );
  }

  // -------------------------------------------------------------------------
  // State widgets
  // -------------------------------------------------------------------------
  Widget _buildError(String message, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return EmptyStateWidget(
      icon: Icons.business_outlined,
      title: 'Add your first company',
      subtitle: 'Track corporate job openings from official career portals.',
      actionLabel: 'Add Company',
      onAction: () => context.go('/admin/companies/add'),
    );
  }
}
