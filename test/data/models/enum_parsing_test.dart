// test/data/models/enum_parsing_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:true_corporate_job_finder/data/models/models.dart';

void main() {
  group('Enum parsing & safe defaults', () {
    test('Provenance parses unknown values to safe default (missing)', () {
      expect(Provenance.fromString('EXPLICIT'), Provenance.explicit);
      expect(Provenance.fromString('INFERRED'), Provenance.inferred);
      expect(Provenance.fromString('MISSING'), Provenance.missing);
      expect(Provenance.fromString('UNKNOWN_PROVENANCE'), Provenance.missing);
      expect(Provenance.fromString(null), Provenance.missing);
    });

    test('JobStatus parses unknown values to safe default (draftRaw)', () {
      expect(JobStatus.fromString('DRAFT_RAW'), JobStatus.draftRaw);
      expect(JobStatus.fromString('ACTIVE'), JobStatus.active);
      expect(JobStatus.fromString('PENDING_REVIEW'), JobStatus.pendingReview);
      expect(JobStatus.fromString('CLOSING_SOON'), JobStatus.closingSoon);
      expect(JobStatus.fromString('EXPIRED'), JobStatus.expired);
      expect(JobStatus.fromString('CLOSED'), JobStatus.closed);
      expect(JobStatus.fromString('REJECTED'), JobStatus.rejected);
      expect(JobStatus.fromString('DUPLICATE'), JobStatus.duplicate);
      expect(JobStatus.fromString('UNKNOWN_STATUS'), JobStatus.draftRaw);
      expect(JobStatus.fromString(null), JobStatus.draftRaw);
    });

    test('JobType parses unknown values to safe default (fullTime)', () {
      expect(JobType.fromString('FULL_TIME'), JobType.fullTime);
      expect(JobType.fromString('PART_TIME'), JobType.partTime);
      expect(JobType.fromString('CONTRACT'), JobType.contract);
      expect(JobType.fromString('INTERNSHIP'), JobType.internship);
      expect(JobType.fromString('OTHER'), JobType.other);
      expect(JobType.fromString('UNKNOWN_TYPE'), JobType.fullTime);
      expect(JobType.fromString(null), JobType.fullTime);
    });

    test('WorkMode parses unknown values to safe default (onsite)', () {
      expect(WorkMode.fromString('ONSITE'), WorkMode.onsite);
      expect(WorkMode.fromString('REMOTE'), WorkMode.remote);
      expect(WorkMode.fromString('HYBRID'), WorkMode.hybrid);
      expect(WorkMode.fromString('UNKNOWN_MODE'), WorkMode.onsite);
      expect(WorkMode.fromString(null), WorkMode.onsite);
    });

    test('EmploymentType parses unknown values to safe default (permanent)', () {
      expect(EmploymentType.fromString('PERMANENT'), EmploymentType.permanent);
      expect(EmploymentType.fromString('TEMPORARY'), EmploymentType.temporary);
      expect(EmploymentType.fromString('CONTRACTOR'), EmploymentType.contractor);
      expect(EmploymentType.fromString('INTERN'), EmploymentType.intern);
      expect(EmploymentType.fromString('UNKNOWN_EMP_TYPE'), EmploymentType.permanent);
      expect(EmploymentType.fromString(null), EmploymentType.permanent);
    });

    test('ExperienceLevel parses unknown values to safe default (midLevel)', () {
      expect(ExperienceLevel.fromString('ENTRY_LEVEL'), ExperienceLevel.entryLevel);
      expect(ExperienceLevel.fromString('MID_LEVEL'), ExperienceLevel.midLevel);
      expect(ExperienceLevel.fromString('SENIOR'), ExperienceLevel.senior);
      expect(ExperienceLevel.fromString('LEAD'), ExperienceLevel.lead);
      expect(ExperienceLevel.fromString('EXECUTIVE'), ExperienceLevel.executive);
      expect(ExperienceLevel.fromString('UNKNOWN_EXP'), ExperienceLevel.midLevel);
      expect(ExperienceLevel.fromString(null), ExperienceLevel.midLevel);
    });

    test('VerificationState parses unknown values to safe default (unverified)', () {
      expect(VerificationState.fromString('UNVERIFIED'), VerificationState.unverified);
      expect(VerificationState.fromString('PENDING'), VerificationState.pending);
      expect(VerificationState.fromString('VERIFIED'), VerificationState.verified);
      expect(VerificationState.fromString('REJECTED'), VerificationState.rejected);
      expect(VerificationState.fromString('UNKNOWN_STATE'), VerificationState.unverified);
      expect(VerificationState.fromString(null), VerificationState.unverified);
    });

    test('SourceType parses unknown values to safe default (careersPage)', () {
      expect(SourceType.fromString('GREENHOUSE'), SourceType.greenhouse);
      expect(SourceType.fromString('LEVER'), SourceType.lever);
      expect(SourceType.fromString('SMARTRECRUITERS'), SourceType.smartrecruiters);
      expect(SourceType.fromString('OFFICIAL_FEED'), SourceType.officialFeed);
      expect(SourceType.fromString('CAREERS_PAGE'), SourceType.careersPage);
      expect(SourceType.fromString('UNKNOWN_SOURCE'), SourceType.careersPage);
      expect(SourceType.fromString(null), SourceType.careersPage);
    });

    test('ResumeParseStatus parses unknown values to safe default (notStarted)', () {
      expect(ResumeParseStatus.fromString('NOT_STARTED'), ResumeParseStatus.notStarted);
      expect(ResumeParseStatus.fromString('IN_PROGRESS'), ResumeParseStatus.inProgress);
      expect(ResumeParseStatus.fromString('PARSED'), ResumeParseStatus.parsed);
      expect(ResumeParseStatus.fromString('FAILED'), ResumeParseStatus.failed);
      expect(ResumeParseStatus.fromString('UNKNOWN_PARSE_STATUS'), ResumeParseStatus.notStarted);
      expect(ResumeParseStatus.fromString(null), ResumeParseStatus.notStarted);
    });

    test('ReportStatus parses unknown values to safe default (pending)', () {
      expect(ReportStatus.fromString('PENDING'), ReportStatus.pending);
      expect(ReportStatus.fromString('INVESTIGATING'), ReportStatus.investigating);
      expect(ReportStatus.fromString('RESOLVED'), ReportStatus.resolved);
      expect(ReportStatus.fromString('DISMISSED'), ReportStatus.dismissed);
      expect(ReportStatus.fromString('UNKNOWN_REPORT_STATUS'), ReportStatus.pending);
      expect(ReportStatus.fromString(null), ReportStatus.pending);
    });

    test('UserRole parses from claims safely', () {
      expect(UserRoleX.fromClaim('ADMIN'), UserRole.admin);
      expect(UserRoleX.fromClaim('SUPER_ADMIN'), UserRole.superAdmin);
      expect(UserRoleX.fromClaim('USER'), UserRole.user);
      expect(UserRoleX.fromClaim('UNKNOWN_CLAIM'), UserRole.user);
      expect(UserRoleX.fromClaim(null), UserRole.user);
    });

    test('Job JSON deserialization falls back to safe default on unknown enums', () {
      final json = <String, dynamic>{
        'id': 'job_unknown_enums',
        'companyId': 'comp_1',
        'companyName': 'Acme Corp',
        'applyUrl': 'https://careers.acme.com/apply/1',
        'title': 'Software Engineer',
        'description': 'Building next-gen systems',
        'status': 'UNKNOWN_NEW_STATUS_FROM_BACKEND',
        'jobType': 'UNKNOWN_NEW_JOB_TYPE',
        'workMode': 'UNKNOWN_WORK_MODE',
        'employmentType': 'UNKNOWN_EMPLOYMENT',
        'expLevel': 'UNKNOWN_LEVEL',
        'verification': {
          'state': 'UNKNOWN_VERIFY_STATE',
        },
      };

      final job = Job.fromJson(json);

      expect(job.status, JobStatus.draftRaw);
      expect(job.jobType, JobType.fullTime);
      expect(job.workMode, WorkMode.onsite);
      expect(job.employmentType, EmploymentType.permanent);
      expect(job.expLevel, ExperienceLevel.midLevel);
      expect(job.verification.state, VerificationState.unverified);
    });
  });
}
