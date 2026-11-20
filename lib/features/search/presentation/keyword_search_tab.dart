// lib/features/search/presentation/keyword_search_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/skeleton_list.dart';
import '../../../data/models/job.dart';
import '../../../data/models/job_query.dart';
import '../../../data/repositories/jobs_repository.dart';
import '../../jobs/presentation/widgets/job_card.dart';

class KeywordSearchTab extends ConsumerStatefulWidget {
  const KeywordSearchTab({super.key});

  @override
  ConsumerState<KeywordSearchTab> createState() => _KeywordSearchTabState();
}

class _KeywordSearchTabState extends ConsumerState<KeywordSearchTab> {
  final _searchController = TextEditingController();
  String? _selectedCity;
  String? _selectedWorkMode;
  bool _isLoading = false;
  List<Job> _results = [];
  bool _hasSearched = false;

  final List<String> _cities = ['All Cities', 'Bengaluru', 'Kolkata', 'Mumbai', 'Delhi', 'Hyderabad', 'Pune'];
  final List<String> _workModes = ['All Modes', 'REMOTE', 'HYBRID', 'ONSITE'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _executeSearch() async {
    final queryText = _searchController.text.trim();
    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final query = JobQuery(
        keyword: queryText.isNotEmpty ? queryText : null,
        city: (_selectedCity != null && _selectedCity != 'All Cities') ? _selectedCity : null,
        workMode: (_selectedWorkMode != null && _selectedWorkMode != 'All Modes') ? _selectedWorkMode : null,
        isAiInterpreted: false,
      );

      final paged = await ref.read(jobsRepositoryProvider).queryJobs(query, pageSize: 20);
      if (mounted) {
        setState(() {
          _results = paged.items;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _results = [];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Search & Filters Header
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            border: Border(
              bottom: BorderSide(
                color: theme.colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
          ),
          child: Column(
            children: [
              TextField(
                key: const Key('keyword_search_input'),
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search title, company, skills...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: _executeSearch,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
                onSubmitted: (_) => _executeSearch(),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: const Key('keyword_city_dropdown'),
                      value: _selectedCity ?? 'All Cities',
                      decoration: InputDecoration(
                        labelText: 'Location',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 4,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                      items: _cities
                          .map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (val) {
                        setState(() => _selectedCity = val);
                        _executeSearch();
                      },
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      key: const Key('keyword_workmode_dropdown'),
                      value: _selectedWorkMode ?? 'All Modes',
                      decoration: InputDecoration(
                        labelText: 'Work Mode',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 4,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                      items: _workModes
                          .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (val) {
                        setState(() => _selectedWorkMode = val);
                        _executeSearch();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Results Section
        Expanded(
          child: _isLoading
              ? const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: SkeletonList(itemCount: 4),
                )
              : !_hasSearched
                  ? const Center(
                      child: EmptyStateWidget(
                        icon: Icons.search,
                        title: 'Search Verified Positions',
                        subtitle:
                            'Type keywords or apply filters above to find active jobs verified from company career portals.',
                      ),
                    )
                  : _results.isEmpty
                      ? const Center(
                          child: EmptyStateWidget(
                            icon: Icons.work_off_outlined,
                            title: 'No Jobs Match Your Query',
                            subtitle:
                                'Try clearing some filters or searching with different keywords.',
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                          itemCount: _results.length,
                          itemBuilder: (context, index) {
                            return JobCard(job: _results[index]);
                          },
                        ),
        ),
      ],
    );
  }
}
