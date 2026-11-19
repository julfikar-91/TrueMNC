// test/data/models/models_roundtrip_test.dart
import 'package:cloud_firestore/cloud_firestore.dart' hide Source;
import 'package:flutter_test/flutter_test.dart';
import 'package:true_corporate_job_finder/data/models/models.dart';

void main() {
  group('TimestampConverter tests', () {
    const converter = TimestampConverter();

    test('Converts Timestamp to DateTime and back to Timestamp', () {
      final now = DateTime.utc(2026, 11, 19, 10, 30, 0);
      final ts = Timestamp.fromDate(now);

      final dt = converter.fromJson(ts);
      expect(dt, equals(now));

      final backToTs = converter.toJson(dt) as Timestamp?;
      expect(backToTs, equals(ts));
    });

    test('Converts ISO string and epoch int to DateTime', () {
      const isoStr = '2026-11-19T10:30:00.000Z';
      final dtFromIso = converter.fromJson(isoStr);
      expect(dtFromIso, isNotNull);
      expect(dtFromIso!.year, 2026);

      const epochMillis = 1732012200000;
      final dtFromInt = converter.fromJson(epochMillis);
      expect(dtFromInt, isNotNull);

      // Raw Firestore Map representation
      const rawMap = {'_seconds': 1732012200, '_nanoseconds': 0};
      final dtFromMap = converter.fromJson(rawMap);
      expect(dtFromMap, isNotNull);

      expect(converter.fromJson(null), isNull);
      expect(converter.toJson(null), isNull);
    });
  });

  group('AppUser JSON round-trip and server-side security', () {
    test('Round-trips null-safe fields without inventing data', () {
      final user = AppUser(
        id: 'usr_123',
        name: 'Jane Doe',
        email: 'jane@example.com',
        photoUrl: 'https://cdn.example.com/jane.jpg',
        role: UserRole.user,
        onboardingDone: true,
        resumeParseStatus: ResumeParseStatus.parsed,
        profileConfirmed: true,
        profileCompletion: 85,
        notifPrefs: const NotificationPreferences(
          jobAlerts: true,
          applicationUpdates: true,
          marketing: false,
        ),
        createdAt: DateTime.utc(2026, 1, 15, 12, 0, 0),
        matchKeys: const ['flutter', 'dart'],
        fcmTokens: const ['token_abc'],
      );

      final json = user.toJson();
      final restored = AppUser.fromJson(json);

      expect(restored.id, equals(user.id));
      expect(restored.name, equals(user.name));
      expect(restored.email, equals(user.email));
      expect(restored.role, equals(user.role));
      expect(restored.onboardingDone, isTrue);
      expect(restored.profileCompletion, equals(85));
      expect(restored.createdAt, equals(user.createdAt));
      expect(restored.matchKeys, equals(['flutter', 'dart']));
      expect(restored.fcmTokens, equals(['token_abc']));
    });

    test('Missing fields stay null and are never invented', () {
      final minimal = AppUser.fromJson(const {'id': 'u_min'});
      expect(minimal.name, isNull);
      expect(minimal.email, isNull);
      expect(minimal.photoUrl, isNull);
      expect(minimal.profileGeneratedAt, isNull);
      expect(minimal.createdAt, isNull);
      expect(minimal.matchKeys, isNull);
      expect(minimal.fcmTokens, isNull);
    });

    test('toFirestore strips role, matchKeys, and fcm_tokens for client security', () {
      const user = AppUser(
        id: 'usr_sec',
        name: 'Alice',
        role: UserRole.superAdmin,
        matchKeys: ['admin'],
        fcmTokens: ['tok_secret'],
      );

      final firestoreData = user.toFirestore();
      expect(firestoreData.containsKey('role'), isFalse);
      expect(firestoreData.containsKey('matchKeys'), isFalse);
      expect(firestoreData.containsKey('fcm_tokens'), isFalse);
      expect(firestoreData.containsKey('id'), isFalse);
    });

    test('Accepts uid as doc ID when id is not explicitly provided', () {
      final user = AppUser.fromJson(const {'uid': 'doc_uid_123', 'name': 'Bob'});
      expect(user.id, equals('doc_uid_123'));
    });
  });

  group('Job Section 9 fields round-trip and validation', () {
    test('Job full model round-trip', () {
      final now = DateTime.utc(2026, 11, 19, 12, 0, 0);
      final job = Job(
        id: 'job_456',
        companyId: 'comp_789',
        companyName: 'Tech Corp Global',
        sourceUrl: 'https://greenhouse.io/techcorp/jobs/456',
        applyUrl: 'https://techcorp.com/careers/apply/456',
        title: 'Senior Mobile Engineer',
        description: 'Build enterprise mobile apps in Flutter',
        aiSummary: 'Senior role focused on Flutter, Firebase, and Clean Architecture.',
        jobType: JobType.fullTime,
        category: 'Engineering',
        requiredSkills: const ['Flutter', 'Dart', 'Firebase'],
        preferredSkills: const ['Riverpod', 'TypeScript'],
        minEdu: 'Bachelor of Technology',
        expMin: 5,
        expMax: 8,
        expLevel: ExperienceLevel.senior,
        employmentType: EmploymentType.permanent,
        workMode: WorkMode.hybrid,
        locations: const ['Bengaluru, Karnataka, India'],
        city: 'Bengaluru',
        state: 'Karnataka',
        country: 'India',
        salary: const JobSalary(min: 2500000, max: 3500000, currency: 'INR'),
        deadline: now.add(const Duration(days: 30)),
        postedAt: now,
        status: JobStatus.active,
        verification: JobVerification(
          state: VerificationState.verified,
          checkedAt: now,
          rules: const ['OFFICIAL_DOMAIN_MATCH', 'VERIFIED_RECRUITER'],
        ),
        reportCount: 0,
        lastSeenAt: now,
      );

      final json = job.toJson();
      final restored = Job.fromJson(json);

      expect(restored.id, equals(job.id));
      expect(restored.companyName, equals('Tech Corp Global'));
      expect(restored.title, equals('Senior Mobile Engineer'));
      expect(restored.salary?.min, equals(2500000));
      expect(restored.salary?.currency, equals('INR'));
      expect(restored.verification.state, equals(VerificationState.verified));
      expect(restored.isVerified, isTrue);
      expect(restored.requiredSkills, contains('Flutter'));
      expect(restored.preferredSkills, contains('Riverpod'));
      expect(restored.skills, containsAll(['Flutter', 'Riverpod']));
      expect(restored.location, equals('Bengaluru, Karnataka, India'));
      expect(restored.minSalary, equals(2500000));
      expect(restored.maxSalary, equals(3500000));
      expect(restored.minExperienceYears, equals(5));
      expect(restored.maxExperienceYears, equals(8));
    });

    test('Missing optional job fields remain null', () {
      final minimal = Job.fromJson(const {
        'companyId': 'c1',
        'companyName': 'Co',
        'applyUrl': 'https://apply.co',
        'title': 'Engineer',
        'description': 'Work with us',
      });

      expect(minimal.sourceUrl, isNull);
      expect(minimal.aiSummary, isNull);
      expect(minimal.category, isNull);
      expect(minimal.minEdu, isNull);
      expect(minimal.expMin, isNull);
      expect(minimal.expMax, isNull);
      expect(minimal.city, isNull);
      expect(minimal.state, isNull);
      expect(minimal.country, isNull);
      expect(minimal.salary, isNull);
      expect(minimal.deadline, isNull);
      expect(minimal.postedAt, isNull);
      expect(minimal.lastSeenAt, isNull);
    });
  });

  group('Company, Source, and CollectionRun round-trips', () {
    test('Company round-trip with embedded sources', () {
      final now = DateTime.utc(2026, 11, 19, 12, 0, 0);
      final company = Company(
        id: 'c_1',
        name: 'Google LLC',
        slug: 'google',
        website: 'https://google.com',
        careersUrl: 'https://careers.google.com',
        logoUrl: 'https://google.com/logo.png',
        description: 'Organize world information',
        industry: 'Technology',
        headquarters: 'Mountain View, CA',
        isVerified: true,
        sources: [
          Source(
            id: 'src_1',
            companyId: 'c_1',
            type: SourceType.officialFeed,
            url: 'https://careers.google.com/api/jobs',
            isActive: true,
            createdAt: now,
          ),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final json = company.toJson();
      final restored = Company.fromJson(json);

      expect(restored.name, equals('Google LLC'));
      expect(restored.isVerified, isTrue);
      expect(restored.sources.length, 1);
      expect(restored.sources.first.type, equals(SourceType.officialFeed));
    });

    test('CollectionRun round-trip', () {
      const run = CollectionRun(
        id: 'run_1',
        sourceId: 'src_1',
        companyId: 'c_1',
        status: 'SUCCESS',
        jobsFound: 50,
        jobsCreated: 12,
        jobsUpdated: 38,
        errors: [],
      );

      final json = run.toJson();
      final restored = CollectionRun.fromJson(json);

      expect(restored.jobsFound, 50);
      expect(restored.jobsCreated, 12);
      expect(restored.status, 'SUCCESS');
    });
  });

  group('Recommendation model round-trip', () {
    test('Recommendation matches specification', () {
      final now = DateTime.utc(2026, 11, 19, 12, 0, 0);
      final rec = Recommendation(
        id: 'rec_101',
        jobId: 'job_456',
        userId: 'usr_123',
        score: 87.5,
        breakdown: const ScoreBreakdown(
          skills: 38.0,
          education: 15.0,
          experience: 14.5,
          location: 10.0,
          preference: 10.0,
        ),
        matchedSkills: const ['Flutter', 'Dart', 'Firebase'],
        missingSkills: const ['GraphQL'],
        reasons: const [
          'Strong Flutter and Dart background match',
          'Preferred location Bengaluru matches job location',
        ],
        scoreVersion: 'v2',
        isNew: true,
        computedAt: now,
      );

      final json = rec.toJson();
      final restored = Recommendation.fromJson(json);

      expect(restored.score, equals(87.5));
      expect(restored.breakdown.skills, equals(38.0));
      expect(restored.matchedSkills, contains('Flutter'));
      expect(restored.missingSkills, contains('GraphQL'));
      expect(restored.isNew, isTrue);
      expect(restored.scoreVersion, equals('v2'));
    });
  });

  group('Profile Sub-models round-trip', () {
    test('Education, SkillItem, Experience, Project, Certification, CareerPreferences', () {
      const edu = Education(
        institution: 'IIT Bombay',
        degree: 'B.Tech',
        fieldOfStudy: 'Computer Science',
        provenance: Provenance.explicit,
      );
      expect(Education.fromJson(edu.toJson()).institution, 'IIT Bombay');

      const skill = SkillItem(
        name: 'Flutter',
        level: 'Expert',
        yearsOfExperience: 5.5,
        provenance: Provenance.explicit,
      );
      expect(SkillItem.fromJson(skill.toJson()).name, 'Flutter');

      const exp = Experience(
        company: 'Unicorn Tech',
        title: 'Lead Mobile Architect',
        highlights: ['Architected mobile app', 'Mentored 10 engineers'],
        provenance: Provenance.explicit,
      );
      expect(Experience.fromJson(exp.toJson()).company, 'Unicorn Tech');

      const proj = Project(
        title: 'Open Source App',
        skills: ['Dart', 'Riverpod'],
        provenance: Provenance.explicit,
      );
      expect(Project.fromJson(proj.toJson()).title, 'Open Source App');

      const cert = Certification(
        name: 'Google Cloud Professional Architect',
        issuer: 'Google',
        provenance: Provenance.explicit,
      );
      expect(Certification.fromJson(cert.toJson()).name, 'Google Cloud Professional Architect');

      const prefs = CareerPreferences(
        desiredTitles: ['Staff Engineer', 'Engineering Manager'],
        preferredLocations: ['Bengaluru', 'Remote'],
        preferredWorkModes: [WorkMode.remote, WorkMode.hybrid],
        preferredJobTypes: [JobType.fullTime],
        minExpectedSalary: 4000000,
        currency: 'INR',
        noticePeriodDays: 30,
        provenance: Provenance.explicit,
      );
      final restoredPrefs = CareerPreferences.fromJson(prefs.toJson());
      expect(restoredPrefs.desiredTitles, contains('Staff Engineer'));
      expect(restoredPrefs.preferredWorkModes, contains(WorkMode.remote));
    });
  });

  group('FieldValueWrapper and Provenance tests', () {
    test('FieldValue wrapper tracks value, provenance, evidence, and confidence', () {
      const field = FieldValueWrapper<String>(
        value: 'Senior Flutter Developer',
        provenance: Provenance.inferred,
        evidence: 'Parsed from resume headline: "5 years Flutter dev"',
        confidence: 0.95,
      );

      final json = field.toJson((val) => val);
      final restored = FieldValueWrapper<String>.fromJson(
        json,
        (val) => val as String,
      );

      expect(restored.value, equals('Senior Flutter Developer'));
      expect(restored.provenance, equals(Provenance.inferred));
      expect(restored.evidence, contains('Parsed from resume'));
      expect(restored.confidence, equals(0.95));
    });
  });

  group('AppConfig and ScoringConfig validation', () {
    test('Default scoring weights total exactly 100 with required defaults', () {
      const config = ScoringConfig();

      expect(config.skills, equals(40));
      expect(config.education, equals(15));
      expect(config.experience, equals(15));
      expect(config.location, equals(10));
      expect(config.preference, equals(20));
      expect(config.threshold, equals(55));
      expect(config.softCap, equals(74));
      expect(config.labels.excellent, equals(80));
      expect(config.labels.good, equals(65));
      expect(config.labels.fair, equals(55));

      expect(config.totalWeight, equals(100));
      expect(config.isValid, isTrue);
    });

    test('Non-100 total weight is flagged as invalid', () {
      const invalidConfig = ScoringConfig(
        skills: 50,
        education: 20,
        experience: 20,
        location: 10,
        preference: 20, // Sum = 120
      );

      expect(invalidConfig.totalWeight, equals(120));
      expect(invalidConfig.isValid, isFalse);
    });

    test('AppConfig round-trip', () {
      const appConfig = AppConfig(
        minSupportedVersion: '1.2.0',
        maintenanceMode: false,
        termsUrl: 'https://truemnc.com/terms',
        privacyUrl: 'https://truemnc.com/privacy',
      );

      final json = appConfig.toJson();
      final restored = AppConfig.fromJson(json);

      expect(restored.minSupportedVersion, equals('1.2.0'));
      expect(restored.maintenanceMode, isFalse);
      expect(restored.termsUrl, equals('https://truemnc.com/terms'));
      expect(restored.scoring.isValid, isTrue);
    });
  });

  group('Category, ReportItem, AppNotification, AuditLog round-trips', () {
    test('Category round-trip', () {
      const cat = Category(
        name: 'Mobile Development',
        type: 'ENGINEERING',
        aliases: ['App Development', 'Mobile Engineering'],
        keywords: ['flutter', 'android', 'ios', 'kotlin', 'swift'],
        order: 1,
        active: true,
        activeCount: 42,
      );

      final json = cat.toJson();
      final restored = Category.fromJson(json);

      expect(restored.name, 'Mobile Development');
      expect(restored.aliases, contains('App Development'));
      expect(restored.activeCount, 42);
    });

    test('ReportItem round-trip', () {
      const report = ReportItem(
        jobId: 'job_123',
        userId: 'usr_456',
        reason: 'Expired job posting',
        details: 'The official career site shows position is closed',
        status: ReportStatus.pending,
      );

      final json = report.toJson();
      final restored = ReportItem.fromJson(json);

      expect(restored.jobId, 'job_123');
      expect(restored.status, ReportStatus.pending);
    });

    test('AppNotification round-trip', () {
      const notif = AppNotification(
        userId: 'usr_456',
        title: 'New verified job match!',
        body: 'Tech Corp posted Senior Mobile Engineer',
        type: 'JOB_MATCH',
        data: {'jobId': 'job_123'},
        isRead: false,
      );

      final json = notif.toJson();
      final restored = AppNotification.fromJson(json);

      expect(restored.title, contains('New verified'));
      expect(restored.data?['jobId'], 'job_123');
      expect(restored.isRead, isFalse);
    });

    test('AuditLog round-trip', () {
      const log = AuditLog(
        action: 'VERIFY_JOB',
        performedBy: 'admin_usr_99',
        targetType: 'JOB',
        targetId: 'job_123',
        details: {'rulesChecked': ['OFFICIAL_URL_200']},
      );

      final json = log.toJson();
      final restored = AuditLog.fromJson(json);

      expect(restored.action, 'VERIFY_JOB');
      expect(restored.targetId, 'job_123');
    });
  });
}
