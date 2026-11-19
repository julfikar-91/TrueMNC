// lib/data/models/enums.dart
import 'package:freezed_annotation/freezed_annotation.dart';

export '../../core/utils/constants.dart' show UserRole, UserRoleX;

part 'enums.g.dart';

// ── 1. Provenance ────────────────────────────────────────────────────────────

@JsonEnum(alwaysCreate: true)
enum Provenance {
  @JsonValue('EXPLICIT')
  explicit,
  @JsonValue('INFERRED')
  inferred,
  @JsonValue('MISSING')
  missing;

  static Provenance fromString(String? value, {Provenance fallback = Provenance.missing}) {
    if (value == null) return fallback;
    return switch (value.toUpperCase().trim()) {
      'EXPLICIT' => Provenance.explicit,
      'INFERRED' => Provenance.inferred,
      'MISSING' => Provenance.missing,
      _ => fallback,
    };
  }
}

// ── 2. JobStatus ─────────────────────────────────────────────────────────────

@JsonEnum(alwaysCreate: true)
enum JobStatus {
  @JsonValue('DRAFT_RAW')
  draftRaw,
  @JsonValue('PENDING_REVIEW')
  pendingReview,
  @JsonValue('ACTIVE')
  active,
  @JsonValue('CLOSING_SOON')
  closingSoon,
  @JsonValue('EXPIRED')
  expired,
  @JsonValue('CLOSED')
  closed,
  @JsonValue('REJECTED')
  rejected,
  @JsonValue('DUPLICATE')
  duplicate;

  static JobStatus fromString(String? value, {JobStatus fallback = JobStatus.draftRaw}) {
    if (value == null) return fallback;
    return switch (value.toUpperCase().trim()) {
      'DRAFT_RAW' => JobStatus.draftRaw,
      'PENDING_REVIEW' => JobStatus.pendingReview,
      'ACTIVE' => JobStatus.active,
      'CLOSING_SOON' => JobStatus.closingSoon,
      'EXPIRED' => JobStatus.expired,
      'CLOSED' => JobStatus.closed,
      'REJECTED' => JobStatus.rejected,
      'DUPLICATE' => JobStatus.duplicate,
      _ => fallback,
    };
  }
}

// ── 3. JobType ───────────────────────────────────────────────────────────────

@JsonEnum(alwaysCreate: true)
enum JobType {
  @JsonValue('FULL_TIME')
  fullTime,
  @JsonValue('PART_TIME')
  partTime,
  @JsonValue('CONTRACT')
  contract,
  @JsonValue('INTERNSHIP')
  internship,
  @JsonValue('OTHER')
  other;

  static JobType fromString(String? value, {JobType fallback = JobType.fullTime}) {
    if (value == null) return fallback;
    return switch (value.toUpperCase().replaceAll('-', '_').trim()) {
      'FULL_TIME' => JobType.fullTime,
      'PART_TIME' => JobType.partTime,
      'CONTRACT' => JobType.contract,
      'INTERNSHIP' => JobType.internship,
      'OTHER' => JobType.other,
      _ => fallback,
    };
  }
}

// ── 4. WorkMode ──────────────────────────────────────────────────────────────

@JsonEnum(alwaysCreate: true)
enum WorkMode {
  @JsonValue('ONSITE')
  onsite,
  @JsonValue('REMOTE')
  remote,
  @JsonValue('HYBRID')
  hybrid;

  static WorkMode fromString(String? value, {WorkMode fallback = WorkMode.onsite}) {
    if (value == null) return fallback;
    return switch (value.toUpperCase().trim()) {
      'ONSITE' => WorkMode.onsite,
      'REMOTE' => WorkMode.remote,
      'HYBRID' => WorkMode.hybrid,
      _ => fallback,
    };
  }
}

// ── 5. EmploymentType ────────────────────────────────────────────────────────

@JsonEnum(alwaysCreate: true)
enum EmploymentType {
  @JsonValue('PERMANENT')
  permanent,
  @JsonValue('TEMPORARY')
  temporary,
  @JsonValue('CONTRACTOR')
  contractor,
  @JsonValue('INTERN')
  intern;

  static EmploymentType fromString(String? value, {EmploymentType fallback = EmploymentType.permanent}) {
    if (value == null) return fallback;
    return switch (value.toUpperCase().trim()) {
      'PERMANENT' => EmploymentType.permanent,
      'TEMPORARY' => EmploymentType.temporary,
      'CONTRACTOR' => EmploymentType.contractor,
      'INTERN' => EmploymentType.intern,
      _ => fallback,
    };
  }
}

// ── 6. ExperienceLevel ───────────────────────────────────────────────────────

@JsonEnum(alwaysCreate: true)
enum ExperienceLevel {
  @JsonValue('ENTRY_LEVEL')
  entryLevel,
  @JsonValue('MID_LEVEL')
  midLevel,
  @JsonValue('SENIOR')
  senior,
  @JsonValue('LEAD')
  lead,
  @JsonValue('EXECUTIVE')
  executive;

  static ExperienceLevel fromString(String? value, {ExperienceLevel fallback = ExperienceLevel.midLevel}) {
    if (value == null) return fallback;
    return switch (value.toUpperCase().replaceAll('-', '_').trim()) {
      'ENTRY_LEVEL' => ExperienceLevel.entryLevel,
      'MID_LEVEL' => ExperienceLevel.midLevel,
      'SENIOR' => ExperienceLevel.senior,
      'LEAD' => ExperienceLevel.lead,
      'EXECUTIVE' => ExperienceLevel.executive,
      _ => fallback,
    };
  }
}

// ── 7. VerificationState ─────────────────────────────────────────────────────

@JsonEnum(alwaysCreate: true)
enum VerificationState {
  @JsonValue('UNVERIFIED')
  unverified,
  @JsonValue('PENDING')
  pending,
  @JsonValue('VERIFIED')
  verified,
  @JsonValue('REJECTED')
  rejected;

  static VerificationState fromString(String? value, {VerificationState fallback = VerificationState.unverified}) {
    if (value == null) return fallback;
    return switch (value.toUpperCase().trim()) {
      'UNVERIFIED' => VerificationState.unverified,
      'PENDING' => VerificationState.pending,
      'VERIFIED' => VerificationState.verified,
      'REJECTED' => VerificationState.rejected,
      _ => fallback,
    };
  }
}

// ── 8. SourceType ────────────────────────────────────────────────────────────

@JsonEnum(alwaysCreate: true)
enum SourceType {
  @JsonValue('GREENHOUSE')
  greenhouse,
  @JsonValue('LEVER')
  lever,
  @JsonValue('SMARTRECRUITERS')
  smartrecruiters,
  @JsonValue('OFFICIAL_FEED')
  officialFeed,
  @JsonValue('CAREERS_PAGE')
  careersPage;

  static SourceType fromString(String? value, {SourceType fallback = SourceType.careersPage}) {
    if (value == null) return fallback;
    return switch (value.toUpperCase().replaceAll('-', '_').trim()) {
      'GREENHOUSE' => SourceType.greenhouse,
      'LEVER' => SourceType.lever,
      'SMARTRECRUITERS' => SourceType.smartrecruiters,
      'OFFICIAL_FEED' => SourceType.officialFeed,
      'CAREERS_PAGE' => SourceType.careersPage,
      _ => fallback,
    };
  }
}

// ── 9. ResumeParseStatus ─────────────────────────────────────────────────────

@JsonEnum(alwaysCreate: true)
enum ResumeParseStatus {
  @JsonValue('NOT_STARTED')
  notStarted,
  @JsonValue('IN_PROGRESS')
  inProgress,
  @JsonValue('PARSED')
  parsed,
  @JsonValue('FAILED')
  failed;

  static ResumeParseStatus fromString(String? value, {ResumeParseStatus fallback = ResumeParseStatus.notStarted}) {
    if (value == null) return fallback;
    return switch (value.toUpperCase().replaceAll('-', '_').trim()) {
      'NOT_STARTED' => ResumeParseStatus.notStarted,
      'IN_PROGRESS' => ResumeParseStatus.inProgress,
      'PARSED' => ResumeParseStatus.parsed,
      'FAILED' => ResumeParseStatus.failed,
      _ => fallback,
    };
  }
}

// ── 10. ReportStatus ─────────────────────────────────────────────────────────

@JsonEnum(alwaysCreate: true)
enum ReportStatus {
  @JsonValue('PENDING')
  pending,
  @JsonValue('INVESTIGATING')
  investigating,
  @JsonValue('RESOLVED')
  resolved,
  @JsonValue('DISMISSED')
  dismissed;

  static ReportStatus fromString(String? value, {ReportStatus fallback = ReportStatus.pending}) {
    if (value == null) return fallback;
    return switch (value.toUpperCase().trim()) {
      'PENDING' => ReportStatus.pending,
      'INVESTIGATING' => ReportStatus.investigating,
      'RESOLVED' => ReportStatus.resolved,
      'DISMISSED' => ReportStatus.dismissed,
      _ => fallback,
    };
  }
}
