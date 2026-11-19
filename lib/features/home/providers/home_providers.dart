// lib/features/home/providers/home_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/job_model.dart';
import '../../../data/repositories/jobs_repository.dart';

final latestJobsProvider = StreamProvider<List<JobModel>>((ref) {
  return ref.watch(jobsRepositoryProvider).watchActiveJobs();
});
