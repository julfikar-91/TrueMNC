// lib/features/admin/audit_logs/providers/audit_logs_providers.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../data/models/audit_log.dart';
import '../../../../data/repositories/admin_repository.dart';
import '../../../../data/repositories/paged_controller.dart';

/// Filter state providers for Audit Logs
final auditActionFilterProvider = StateProvider<String>((ref) => 'ALL');
final auditActorFilterProvider = StateProvider<String>((ref) => '');
final auditTargetFilterProvider = StateProvider<String>((ref) => '');
final auditDateRangeFilterProvider =
    StateProvider<DateTimeRange?>((ref) => null);

/// Paged controller provider for Audit Logs
final auditLogsPagedProvider = StateNotifierProvider.autoDispose<
    PagedController<AuditLog>, PagedState<AuditLog>>((ref) {
  final repository = ref.watch(adminRepositoryProvider);
  final action = ref.watch(auditActionFilterProvider);
  final actor = ref.watch(auditActorFilterProvider);
  final target = ref.watch(auditTargetFilterProvider);
  final dateRange = ref.watch(auditDateRangeFilterProvider);

  return PagedController<AuditLog>(
    (cursor) => repository.listAuditLogs(
      pageSize: 20,
      startAfter: cursor,
      action: action == 'ALL' ? null : action,
      actor: actor.trim().isEmpty ? null : actor.trim(),
      target: target.trim().isEmpty ? null : target.trim(),
      startDate: dateRange?.start,
      endDate: dateRange != null
          ? DateTime(
              dateRange.end.year,
              dateRange.end.month,
              dateRange.end.day,
              23,
              59,
              59,
            )
          : null,
    ),
  );
});
