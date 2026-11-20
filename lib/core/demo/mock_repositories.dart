// lib/core/demo/mock_repositories.dart
import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../data/models/admin_job.dart';
import '../../data/models/app_user.dart';
import '../../data/models/audit_log.dart';
import '../../data/models/collection_run_model.dart';
import '../../data/models/company.dart';
import '../../data/models/company_source.dart';
import '../../data/models/enums.dart';
import '../../data/models/job.dart';
import '../../data/models/job_query.dart';
import '../../data/models/job_validation_model.dart';
import '../../data/models/resume_model.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/repositories/jobs_repository.dart';
import '../../data/repositories/paged_controller.dart';
import '../../data/repositories/resume_repository.dart';
import 'demo_data.dart';

// ── 1. Mock Jobs Repository ──────────────────────────────────────────────────

class MockJobsRepository extends JobsRepository {
  MockJobsRepository() : super(_FakeFirestore());

  @override
  Stream<List<Job>> watchActiveJobs({int limit = 20}) {
    return Stream.value(DemoData.sampleJobs.take(limit).toList());
  }

  @override
  Stream<List<Job>> watchTechnicalJobs({int limit = 10}) {
    return Stream.value(DemoData.sampleJobs.take(limit).toList());
  }

  @override
  Stream<List<Job>> watchNonTechnicalJobs({int limit = 10}) {
    return Stream.value(DemoData.sampleJobs.take(limit).toList());
  }

  @override
  Stream<List<Job>> watchFresherJobs({int limit = 10}) {
    return Stream.value(DemoData.sampleJobs.take(limit).toList());
  }

  @override
  Stream<List<Job>> watchNearLocationJobs(String city, {int limit = 10}) {
    return Stream.value(DemoData.sampleJobs.take(limit).toList());
  }

  @override
  Future<PagedResult<Job>> recentlyAdded({
    int pageSize = 20,
    DocumentSnapshot? startAfter,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final items = DemoData.sampleJobs.take(pageSize).toList();
    return PagedResult<Job>(
      items: items,
      nextCursor: null,
      hasMore: false,
    );
  }

  @override
  Future<Job?> getById(String jobId) async {
    await Future.delayed(const Duration(milliseconds: 80));
    return DemoData.sampleJobs.firstWhere(
      (j) => j.id == jobId,
      orElse: () => DemoData.sampleJobs.first,
    );
  }

  @override
  Future<Job?> getJob(String jobId) => getById(jobId);

  @override
  Future<List<Job>> getJobsByIds(List<String> ids) async {
    return DemoData.sampleJobs.where((j) => ids.contains(j.id)).toList();
  }

  @override
  Future<String> recordRedirect(String jobId) async {
    final job = await getById(jobId);
    return job?.applyUrl ?? 'https://truemnc.demo/careers';
  }

  @override
  Future<PagedResult<Job>> queryJobs(
    JobQuery query, {
    int pageSize = 20,
    DocumentSnapshot? startAfter,
  }) async {
    await Future.delayed(const Duration(milliseconds: 50));
    var list = DemoData.sampleJobs
        .where((j) =>
            j.status == JobStatus.active &&
            j.verification.state == VerificationState.verified &&
            j.applyUrl.isNotEmpty)
        .toList();

    if (query.category != null && query.category!.isNotEmpty) {
      list = list
          .where((j) =>
              j.category?.toLowerCase() == query.category!.toLowerCase())
          .toList();
    }
    if (query.city != null && query.city!.isNotEmpty) {
      list = list
          .where((j) =>
              (j.city?.toLowerCase() ?? '')
                  .contains(query.city!.toLowerCase()))
          .toList();
    }
    if (query.skills.isNotEmpty) {
      final qSkills = query.skills.map((s) => s.toLowerCase()).toSet();
      list = list.where((j) {
        final allSkills =
            [...j.requiredSkills, ...j.preferredSkills].map((s) => s.toLowerCase());
        return allSkills.any(
            (s) => qSkills.contains(s) || qSkills.any((qs) => s.contains(qs)));
      }).toList();
    }
    if (query.titles.isNotEmpty) {
      final qTitles = query.titles.map((t) => t.toLowerCase()).toList();
      list = list
          .where((j) =>
              qTitles.any((qt) => j.title.toLowerCase().contains(qt)))
          .toList();
    }
    if (query.workMode != null && query.workMode!.isNotEmpty) {
      list = list
          .where((j) => j.workMode.name
              .toLowerCase()
              .contains(query.workMode!.toLowerCase()))
          .toList();
    }
    if (query.keyword != null && query.keyword!.trim().isNotEmpty) {
      final kw = query.keyword!.trim().toLowerCase();
      list = list
          .where((j) =>
              j.title.toLowerCase().contains(kw) ||
              j.companyName.toLowerCase().contains(kw) ||
              j.description.toLowerCase().contains(kw))
          .toList();
    }
    if (list.isEmpty) {
      list = DemoData.sampleJobs.take(3).toList();
    }
    return PagedResult<Job>(
      items: list.take(pageSize).toList(),
      nextCursor: null,
      hasMore: false,
    );
  }
}

// ── 2. Mock Admin Repository ─────────────────────────────────────────────────

class MockAdminRepository extends AdminRepository {
  MockAdminRepository() : super(_FakeFunctions(), _FakeFirestore()) {
    _admins = List<AppUser>.from(DemoData.sampleAdmins);
    _scoringConfig = Map<String, dynamic>.from(DemoData.sampleScoringConfig);
    _appConfig = Map<String, dynamic>.from(DemoData.sampleAppConfig);
    _versions = List<Map<String, dynamic>>.from(DemoData.sampleConfigVersions);
    _auditLogs = List<AuditLog>.from(DemoData.sampleAuditLogs);
  }

  late final List<AppUser> _admins;
  late Map<String, dynamic> _scoringConfig;
  late Map<String, dynamic> _appConfig;
  late final List<Map<String, dynamic>> _versions;
  late final List<AuditLog> _auditLogs;

  final _adminsController = StreamController<List<AppUser>>.broadcast();
  final _scoringController = StreamController<Map<String, dynamic>>.broadcast();
  final _appConfigController = StreamController<Map<String, dynamic>>.broadcast();

  @override
  Stream<List<AppUser>> watchAdministrators() async* {
    yield List.unmodifiable(_admins);
    yield* _adminsController.stream;
  }

  @override
  Future<void> setUserRole({
    String? uid,
    String? email,
    required String role,
  }) async {
    await Future.delayed(const Duration(milliseconds: 250));

    // Guard: Cannot remove last SUPER_ADMIN
    if (role != 'SUPER_ADMIN') {
      final superAdmins = _admins.where((u) => u.role == UserRole.superAdmin).toList();
      final target = _admins.firstWhere(
        (u) => (uid != null && u.id == uid) || (email != null && u.email?.toLowerCase() == email.toLowerCase()),
        orElse: () => _admins.first,
      );
      if (target.role == UserRole.superAdmin && superAdmins.length <= 1) {
        throw Exception('Cannot revoke or downgrade the last remaining SUPER_ADMIN.');
      }
    }

    final newRole = UserRoleX.fromClaim(role);
    final index = _admins.indexWhere(
      (u) => (uid != null && u.id == uid) || (email != null && u.email?.toLowerCase() == email.toLowerCase()),
    );

    if (index >= 0) {
      _admins[index] = _admins[index].copyWith(role: newRole);
    } else {
      // Add new admin
      final newAdmin = AppUser(
        id: 'admin_${DateTime.now().millisecondsSinceEpoch}',
        email: email ?? 'admin.new@truemnc.demo',
        name: email?.split('@').first ?? 'New Administrator',
        role: newRole,
        onboardingDone: true,
        profileConfirmed: true,
        profileCompletion: 100,
        createdAt: DateTime.now(),
      );
      _admins.add(newAdmin);
    }

    // Append to audit log
    _auditLogs.insert(
      0,
      AuditLog(
        id: 'audit_${DateTime.now().millisecondsSinceEpoch}',
        action: 'SET_USER_ROLE',
        performedBy: 'demo.superadmin@truemnc.com',
        targetType: 'USER',
        targetId: email ?? uid ?? 'unknown',
        timestamp: DateTime.now(),
        details: {'role': role},
      ),
    );

    _adminsController.add(List.unmodifiable(_admins));
  }

  @override
  Stream<Map<String, dynamic>> watchScoringConfig() async* {
    yield Map.unmodifiable(_scoringConfig);
    yield* _scoringController.stream;
  }

  @override
  Stream<Map<String, dynamic>> watchAppConfig() async* {
    yield Map.unmodifiable(_appConfig);
    yield* _appConfigController.stream;
  }

  @override
  Future<Map<String, dynamic>> updateScoringConfig(Map<String, dynamic> payload) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _scoringConfig = {
      ..._scoringConfig,
      ...payload,
      'version': (_scoringConfig['version'] as int? ?? 1) + 1,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    _versions.insert(0, Map<String, dynamic>.from(_scoringConfig));
    _scoringController.add(Map.unmodifiable(_scoringConfig));
    return _scoringConfig;
  }

  @override
  Future<Map<String, dynamic>> updateAppConfig(Map<String, dynamic> payload) async {
    await Future.delayed(const Duration(milliseconds: 300));
    _appConfig = {
      ..._appConfig,
      ...payload,
      'version': (_appConfig['version'] as int? ?? 1) + 1,
      'updatedAt': DateTime.now().toIso8601String(),
    };
    _appConfigController.add(Map.unmodifiable(_appConfig));
    return _appConfig;
  }

  @override
  Future<List<Map<String, dynamic>>> getConfigVersions(String configDoc) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return List.unmodifiable(_versions);
  }

  @override
  Future<PagedResult<AuditLog>> listAuditLogs({
    int pageSize = 20,
    DocumentSnapshot? startAfter,
    String? action,
    String? actor,
    String? target,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    await Future.delayed(const Duration(milliseconds: 150));
    var filtered = _auditLogs.where((log) {
      if (action != null && action != 'ALL' && log.action != action) return false;
      if (actor != null && !log.performedBy.toLowerCase().contains(actor.toLowerCase())) return false;
      if (target != null && !log.targetId.toLowerCase().contains(target.toLowerCase())) return false;
      if (startDate != null && log.timestamp != null && log.timestamp!.isBefore(startDate)) return false;
      if (endDate != null && log.timestamp != null && log.timestamp!.isAfter(endDate)) return false;
      return true;
    }).toList();

    return PagedResult<AuditLog>(
      items: filtered.take(pageSize).toList(),
      nextCursor: null,
      hasMore: false,
    );
  }

  @override
  Stream<List<Company>> watchCompanies() {
    return Stream.value(DemoData.sampleCompanies);
  }

  @override
  Stream<List<CompanySource>> watchCompanySources(String companyId) {
    return Stream.value(DemoData.sampleSources);
  }

  @override
  Future<AdminJob?> getAdminJob(String jobId) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return DemoData.sampleAdminJob;
  }

  @override
  Future<List<JobValidationModel>> getJobValidations(String jobId) async {
    return DemoData.sampleValidations;
  }

  @override
  Stream<List<CollectionRunModel>> watchCollectionRuns({
    String? companyId,
    String? sourceId,
    int limit = 20,
  }) {
    return Stream.value([
      CollectionRunModel(
        id: 'run_01',
        sourceId: 'src_001',
        companyId: companyId ?? 'comp_google',
        status: 'COMPLETED',
        jobsFound: 15,
        jobsCreated: 5,
        jobsUpdated: 10,
        startedAt: DateTime.now().subtract(const Duration(hours: 4)),
        completedAt: DateTime.now().subtract(const Duration(hours: 3, minutes: 55)),
      ),
    ]);
  }
}

// ── 3. Mock Resume Repository ────────────────────────────────────────────────

class MockResumeRepository extends ResumeRepository {
  MockResumeRepository() : super(_FakeStorage(), _FakeFirestore(), _FakeFunctions());

  @override
  Future<String> uploadResumeFile({
    required String uid,
    required String resumeId,
    required Uint8List bytes,
    required String extension,
    required String mimeType,
    void Function(double progress)? onProgress,
  }) async {
    // Simulate real upload increments
    for (int i = 1; i <= 5; i++) {
      await Future.delayed(const Duration(milliseconds: 120));
      onProgress?.call(i / 5.0);
    }
    return 'resumes/$uid/$resumeId.$extension';
  }

  @override
  Future<void> createResumeDoc({
    required String resumeId,
    required String uid,
    required String storagePath,
    required int fileSize,
    required String mimeType,
  }) async {
    await Future.delayed(const Duration(milliseconds: 100));
  }

  @override
  Stream<ResumeDoc?> watchResume(String resumeId) async* {
    const stages = [
      ResumeProgressStage.uploading,
      ResumeProgressStage.reading,
      ResumeProgressStage.personal,
      ResumeProgressStage.skills,
      ResumeProgressStage.education,
      ResumeProgressStage.experience,
      ResumeProgressStage.creating,
    ];

    for (final stage in stages) {
      yield ResumeDoc(
        id: resumeId,
        uid: 'demo_user_001',
        storagePath: 'resumes/demo/$resumeId.pdf',
        status: ResumeDocStatus.processing,
        progress: stage,
        fileSize: 102400,
        createdAt: DateTime.now(),
      );
      await Future.delayed(const Duration(milliseconds: 400));
    }

    yield ResumeDoc(
      id: resumeId,
      uid: 'demo_user_001',
      storagePath: 'resumes/demo/$resumeId.pdf',
      status: ResumeDocStatus.parsed,
      progress: ResumeProgressStage.creating,
      fileSize: 102400,
      createdAt: DateTime.now(),
    );
  }

  @override
  Stream<ParsedResumeDraft?> watchResumeParse(String resumeId) {
    return Stream.value(DemoData.sampleParsedResume);
  }

  @override
  Future<Map<String, dynamic>> confirmProfile({
    required String resumeId,
    Map<String, dynamic>? confirmedProfile,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return {'success': true, 'resumeId': resumeId};
  }
}

// ── Fakes to avoid null assertion errors in base constructor ─────────────────
class _FakeFirestore implements FirebaseFirestore {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeFunctions implements FirebaseFunctions {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeStorage implements FirebaseStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
