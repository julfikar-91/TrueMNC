// lib/core/demo/demo_data.dart
import '../../data/models/admin_job.dart';
import '../../data/models/app_user.dart';
import '../../data/models/audit_log.dart';
import '../../data/models/company.dart';
import '../../data/models/company_source.dart';
import '../../data/models/enums.dart';
import '../../data/models/job.dart';
import '../../data/models/job_validation_model.dart';
import '../../data/models/resume_model.dart';
import '../../data/models/user_doc.dart';

abstract final class DemoData {
  // ── Sample User Document ───────────────────────────────────────────────────
  static const sampleUserDoc = UserDoc(
    uid: 'demo_user_001',
    email: 'alex.candidate@truemnc.demo',
    name: 'Alex Morgan',
    onboardingDone: true,
    resumeOnboardingDone: true,
    resumeParsed: false,
    profileConfirmed: true,
    preferencesMissing: false,
    adminStartPreferred: false,
  );

  // ── Sample Verified Jobs ───────────────────────────────────────────────────
  static final sampleJobs = <Job>[
    Job(
      id: 'job_google_01',
      companyId: 'comp_google',
      companyName: 'Google Cloud India',
      title: 'Senior Cloud Solutions Architect',
      description:
          'Lead design and architectural oversight of large-scale, enterprise cloud modernization projects. Work directly with engineering leadership across global enterprise accounts to architect resilient, scalable microservices architectures on GCP.\n\nKey Responsibilities:\n- Lead cloud technical strategy and architecture.\n- Interface with enterprise customer engineering teams.\n- Ensure high availability, zero-trust security and cost efficiency.',
      aiSummary:
          'Senior technical architect role leading enterprise GCP architectures with strong focus on Kubernetes, Distributed Systems and Cloud Governance.',
      category: 'Cloud Engineering',
      applyUrl: 'https://careers.google.com/jobs/results/senior-cloud-solutions-architect',
      sourceUrl: 'https://careers.google.com/jobs/results/senior-cloud-solutions-architect',
      jobType: JobType.fullTime,
      workMode: WorkMode.hybrid,
      employmentType: EmploymentType.permanent,
      expLevel: ExperienceLevel.senior,
      locations: const ['Bengaluru, Karnataka', 'Hyderabad, Telangana'],
      city: 'Bengaluru',
      state: 'Karnataka',
      country: 'India',
      expMin: 8,
      expMax: 14,
      requiredSkills: const ['GCP', 'Kubernetes', 'Go', 'Terraform', 'System Design'],
      preferredSkills: const ['Multi-Cloud', 'Python', 'Istio', 'Observability'],
      salary: const JobSalary(min: 4500000, max: 7500000, currency: 'INR'),
      status: JobStatus.active,
      verification: JobVerification(
        state: VerificationState.verified,
        checkedAt: DateTime.now().subtract(const Duration(hours: 2)),
        rules: const ['R1', 'R2', 'R3', 'R4', 'R5', 'R6', 'R7', 'R8'],
      ),
      postedAt: DateTime.now().subtract(const Duration(hours: 6)),
      deadline: DateTime.now().add(const Duration(days: 30)),
    ),
    Job(
      id: 'job_microsoft_02',
      companyId: 'comp_microsoft',
      companyName: 'Microsoft R&D',
      title: 'Principal Software Engineering Lead - Azure AI',
      description:
          'Drive engineering teams creating next-generation generative AI infrastructure. Manage end-to-end telemetry, high-throughput model serving pipelines and low-latency inference services.\n\nQualifications:\n- 10+ years backend systems experience.\n- Deep mastery in C#, C++, or Go and high-scale distributed systems.',
      aiSummary:
          'Principal lead role architecting high-performance LLM serving and distributed compute infrastructure for Azure AI.',
      category: 'Artificial Intelligence',
      applyUrl: 'https://careers.microsoft.com/us/en/job/1829304',
      sourceUrl: 'https://careers.microsoft.com/us/en/job/1829304',
      jobType: JobType.fullTime,
      workMode: WorkMode.remote,
      employmentType: EmploymentType.permanent,
      expLevel: ExperienceLevel.lead,
      locations: const ['Hyderabad, Telangana', 'Remote (India)'],
      city: 'Hyderabad',
      country: 'India',
      expMin: 10,
      expMax: 18,
      requiredSkills: const ['Distributed Systems', 'C++', 'Go', 'LLMs', 'High Throughput'],
      preferredSkills: const ['Azure', 'CUDA', 'Triton Inference Server'],
      salary: const JobSalary(min: 6500000, max: 11000000, currency: 'INR'),
      status: JobStatus.active,
      verification: JobVerification(
        state: VerificationState.verified,
        checkedAt: DateTime.now().subtract(const Duration(hours: 4)),
        rules: const ['R1', 'R2', 'R3', 'R4', 'R5', 'R6', 'R7', 'R8'],
      ),
      postedAt: DateTime.now().subtract(const Duration(hours: 12)),
      deadline: DateTime.now().add(const Duration(days: 45)),
    ),
    Job(
      id: 'job_amazon_03',
      companyId: 'comp_amazon',
      companyName: 'Amazon Web Services (AWS)',
      title: 'Staff Software Development Engineer (SDE III)',
      description:
          'Design and build scalable transactional services powering AWS Payments and billing worldwide. Low latency, five-nines availability and clean architectural contracts are essential.',
      aiSummary:
          'Staff level core backend engineering role for AWS Payments with massive transactional volume and strict ACID requirements.',
      category: 'Software Engineering',
      applyUrl: 'https://amazon.jobs/en/jobs/2849201',
      sourceUrl: 'https://amazon.jobs/en/jobs/2849201',
      jobType: JobType.fullTime,
      workMode: WorkMode.onsite,
      employmentType: EmploymentType.permanent,
      expLevel: ExperienceLevel.senior,
      locations: const ['Chennai, Tamil Nadu', 'Bengaluru, Karnataka'],
      city: 'Chennai',
      country: 'India',
      expMin: 7,
      expMax: 12,
      requiredSkills: const ['Java', 'Distributed Systems', 'DynamoDB', 'Microservices'],
      preferredSkills: const ['AWS', 'Event-Driven Architecture', 'Kafka'],
      salary: const JobSalary(min: 4800000, max: 8000000, currency: 'INR'),
      status: JobStatus.active,
      verification: JobVerification(
        state: VerificationState.verified,
        checkedAt: DateTime.now().subtract(const Duration(hours: 5)),
        rules: const ['R1', 'R2', 'R3', 'R4', 'R5', 'R6', 'R7', 'R8'],
      ),
      postedAt: DateTime.now().subtract(const Duration(days: 1)),
      deadline: DateTime.now().add(const Duration(days: 20)),
    ),
    Job(
      id: 'job_netflix_04',
      companyId: 'comp_netflix',
      companyName: 'Netflix Technology',
      title: 'Senior Frontend Platform Engineer',
      description:
          'Craft the next generation of Netflix web and TV client architecture. Build delightful, reactive user experiences using modern TypeScript, WebAssembly and streaming UI rendering engines.',
      aiSummary:
          'Frontend platform engineering focusing on high-framerate rendering, streaming client performance and modern UI framework internals.',
      category: 'Frontend Engineering',
      applyUrl: 'https://jobs.netflix.com/jobs/381920',
      sourceUrl: 'https://jobs.netflix.com/jobs/381920',
      jobType: JobType.fullTime,
      workMode: WorkMode.remote,
      employmentType: EmploymentType.permanent,
      expLevel: ExperienceLevel.senior,
      locations: const ['Mumbai, Maharashtra', 'Remote (India)'],
      city: 'Mumbai',
      country: 'India',
      expMin: 6,
      expMax: 11,
      requiredSkills: const ['TypeScript', 'React', 'WebAssembly', 'Performance Optimization'],
      preferredSkills: const ['Web Workers', 'Canvas/WebGL', 'GraphQL'],
      salary: const JobSalary(min: 5000000, max: 9000000, currency: 'INR'),
      status: JobStatus.active,
      verification: JobVerification(
        state: VerificationState.verified,
        checkedAt: DateTime.now().subtract(const Duration(hours: 8)),
        rules: const ['R1', 'R2', 'R3', 'R4', 'R5', 'R6', 'R7', 'R8'],
      ),
      postedAt: DateTime.now().subtract(const Duration(days: 2)),
      deadline: DateTime.now().add(const Duration(days: 28)),
    ),
    Job(
      id: 'job_tcs_05',
      companyId: 'comp_tcs',
      companyName: 'Tata Consultancy Services',
      title: 'Lead Flutter & Mobile Architect',
      description:
          'Oversee mobile engineering architecture for global banking and FinTech enterprise apps. Establish offline-first sync patterns, high-grade biometric security and multi-platform CI/CD pipelines.',
      aiSummary:
          'Mobile architect role driving enterprise Flutter applications with offline persistence and banking-grade security.',
      category: 'Mobile Engineering',
      applyUrl: 'https://ibegin.tcs.com/iBegin/jobs/482019',
      sourceUrl: 'https://ibegin.tcs.com/iBegin/jobs/482019',
      jobType: JobType.fullTime,
      workMode: WorkMode.hybrid,
      employmentType: EmploymentType.permanent,
      expLevel: ExperienceLevel.lead,
      locations: const ['Kolkata, West Bengal', 'Bengaluru, Karnataka'],
      city: 'Kolkata',
      country: 'India',
      expMin: 7,
      expMax: 13,
      requiredSkills: const ['Flutter', 'Dart', 'Clean Architecture', 'State Management', 'CI/CD'],
      preferredSkills: const ['Kotlin', 'Swift', 'FinTech Protocols'],
      salary: const JobSalary(min: 2800000, max: 4600000, currency: 'INR'),
      status: JobStatus.active,
      verification: JobVerification(
        state: VerificationState.verified,
        checkedAt: DateTime.now().subtract(const Duration(hours: 1)),
        rules: const ['R1', 'R2', 'R3', 'R4', 'R5', 'R6', 'R7', 'R8'],
      ),
      postedAt: DateTime.now().subtract(const Duration(hours: 3)),
      deadline: DateTime.now().add(const Duration(days: 35)),
    ),
  ];

  // ── Sample Companies ───────────────────────────────────────────────────────
  static final sampleCompanies = <Company>[
    Company(
      id: 'comp_google',
      name: 'Google LLC',
      slug: 'google',
      website: 'https://about.google',
      careersUrl: 'https://careers.google.com',
      industry: 'Technology & Cloud',
      headquarters: 'Mountain View, CA, USA',
      isVerified: true,
      description: 'Global technology leader specializing in Internet services, AI and cloud computing.',
      createdAt: DateTime.now().subtract(const Duration(days: 365)),
    ),
    Company(
      id: 'comp_microsoft',
      name: 'Microsoft Corporation',
      slug: 'microsoft',
      website: 'https://www.microsoft.com',
      careersUrl: 'https://careers.microsoft.com',
      industry: 'Enterprise Software & Cloud',
      headquarters: 'Redmond, WA, USA',
      isVerified: true,
      description: 'Global platform company enabling digital transformation for the intelligent cloud era.',
      createdAt: DateTime.now().subtract(const Duration(days: 300)),
    ),
    Company(
      id: 'comp_amazon',
      name: 'Amazon Web Services',
      slug: 'aws',
      website: 'https://aws.amazon.com',
      careersUrl: 'https://amazon.jobs',
      industry: 'Cloud Infrastructure',
      headquarters: 'Seattle, WA, USA',
      isVerified: true,
      description: 'The world’s most comprehensive and broadly adopted cloud platform.',
      createdAt: DateTime.now().subtract(const Duration(days: 280)),
    ),
    Company(
      id: 'comp_netflix',
      name: 'Netflix Entertainment',
      slug: 'netflix',
      website: 'https://www.netflix.com',
      careersUrl: 'https://jobs.netflix.com',
      industry: 'Streaming & Digital Media',
      headquarters: 'Los Gatos, CA, USA',
      isVerified: true,
      description: 'World-renowned streaming entertainment service with 260+ million paid memberships.',
      createdAt: DateTime.now().subtract(const Duration(days: 210)),
    ),
  ];

  // ── Sample Administrators (A15) ───────────────────────────────────────────
  static final sampleAdmins = <AppUser>[
    AppUser(
      id: 'admin_001',
      name: 'Alice Johnson (You)',
      email: 'alice.johnson@truemnc.com',
      role: UserRole.superAdmin,
      onboardingDone: true,
      profileConfirmed: true,
      profileCompletion: 100,
      createdAt: DateTime.now().subtract(const Duration(days: 120)),
    ),
    AppUser(
      id: 'admin_002',
      name: 'Robert Davis',
      email: 'robert.davis@truemnc.com',
      role: UserRole.superAdmin,
      onboardingDone: true,
      profileConfirmed: true,
      profileCompletion: 100,
      createdAt: DateTime.now().subtract(const Duration(days: 90)),
    ),
    AppUser(
      id: 'admin_003',
      name: 'Sarah Connor',
      email: 'sarah.connor@truemnc.com',
      role: UserRole.admin,
      onboardingDone: true,
      profileConfirmed: true,
      profileCompletion: 90,
      createdAt: DateTime.now().subtract(const Duration(days: 45)),
    ),
    AppUser(
      id: 'admin_004',
      name: 'David Kim',
      email: 'david.kim@truemnc.com',
      role: UserRole.admin,
      onboardingDone: true,
      profileConfirmed: true,
      profileCompletion: 85,
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
    ),
  ];

  // ── Sample Audit Logs (A16) ───────────────────────────────────────────────
  static final sampleAuditLogs = <AuditLog>[
    AuditLog(
      id: 'audit_001',
      action: 'SET_USER_ROLE',
      performedBy: 'alice.johnson@truemnc.com',
      targetType: 'USER',
      targetId: 'user_david_kim_004',
      timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
      ipAddress: '192.168.1.104',
      userAgent: 'Mozilla/5.0 TrueMNC Mobile Admin',
      details: {
        'before': {'role': 'USER'},
        'after': {'role': 'ADMIN'},
        'reason': 'Promotion to review queue moderator',
      },
    ),
    AuditLog(
      id: 'audit_002',
      action: 'UPDATE_CONFIG',
      performedBy: 'alice.johnson@truemnc.com',
      targetType: 'SYSTEM_CONFIG',
      targetId: 'scoring_v1',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      ipAddress: '192.168.1.104',
      userAgent: 'Mozilla/5.0 TrueMNC Mobile Admin',
      details: {
        'before': {'skillsWeight': 30, 'titleWeight': 35},
        'after': {'skillsWeight': 35, 'titleWeight': 30},
        'version': 4,
      },
    ),
    AuditLog(
      id: 'audit_003',
      action: 'ADMIN_VERIFY_SOURCE',
      performedBy: 'robert.davis@truemnc.com',
      targetType: 'COMPANY_SOURCE',
      targetId: 'src_google_greenhouse_01',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      ipAddress: '10.0.0.45',
      userAgent: 'TrueMNC Admin Console v1.0',
      details: {
        'sourceType': 'GREENHOUSE',
        'domainVerified': true,
        'sampleJobsChecked': 3,
        'verdict': 'APPROVED',
      },
    ),
    AuditLog(
      id: 'audit_004',
      action: 'REJECT_JOB',
      performedBy: 'sarah.connor@truemnc.com',
      targetType: 'JOB',
      targetId: 'job_raw_99218',
      timestamp: DateTime.now().subtract(const Duration(hours: 8)),
      ipAddress: '172.16.0.12',
      userAgent: 'TrueMNC Mobile Admin',
      details: {
        'ruleFailed': 'R2_DOMAIN_MISMATCH',
        'reason': 'Redirect domain leads to unapproved external recruiter portal',
      },
    ),
    AuditLog(
      id: 'audit_005',
      action: 'UPSERT_COMPANY',
      performedBy: 'alice.johnson@truemnc.com',
      targetType: 'COMPANY',
      targetId: 'comp_netflix',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      ipAddress: '192.168.1.104',
      userAgent: 'TrueMNC Mobile Admin',
      details: {
        'name': 'Netflix Entertainment',
        'status': 'VERIFIED',
      },
    ),
  ];

  // ── Sample System Config (A17) ─────────────────────────────────────────────
  static final sampleScoringConfig = <String, dynamic>{
    'weights': {
      'title': 30,
      'skills': 35,
      'experience': 20,
      'education': 15,
    },
    'matchThreshold': 65,
    'version': 4,
    'updatedAt': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
    'updatedBy': 'alice.johnson@truemnc.com',
  };

  static final sampleAppConfig = <String, dynamic>{
    'notificationCaps': {
      'dailyMax': 5,
      'weeklyMax': 20,
    },
    'aiModels': {
      'resumeExtractor': 'gemini-1.5-flash',
      'jobMatcher': 'gemini-1.5-pro',
    },
    'featureFlags': {
      'resumeAiEnabled': true,
      'liveScrapingActive': true,
      'guestBrowsing': true,
    },
    'minimumAppVersion': '1.0.0',
    'version': 3,
    'updatedAt': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
    'updatedBy': 'alice.johnson@truemnc.com',
  };

  static final sampleConfigVersions = <Map<String, dynamic>>[
    {
      'version': 4,
      'updatedBy': 'alice.johnson@truemnc.com',
      'updatedAt': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      'weights': {'title': 30, 'skills': 35, 'experience': 20, 'education': 15},
      'matchThreshold': 65,
    },
    {
      'version': 3,
      'updatedBy': 'robert.davis@truemnc.com',
      'updatedAt': DateTime.now().subtract(const Duration(days: 5)).toIso8601String(),
      'weights': {'title': 35, 'skills': 30, 'experience': 20, 'education': 15},
      'matchThreshold': 60,
    },
    {
      'version': 2,
      'updatedBy': 'alice.johnson@truemnc.com',
      'updatedAt': DateTime.now().subtract(const Duration(days: 14)).toIso8601String(),
      'weights': {'title': 40, 'skills': 30, 'experience': 15, 'education': 15},
      'matchThreshold': 60,
    },
  ];

  // ── Sample Parsed Resume Draft (S11) ───────────────────────────────────────
  static final sampleParsedResume = ParsedResumeDraft.fromMap(
    resumeId: 'demo_resume_01',
    uid: 'demo_user_001',
    status: 'PARSED',
    warnings: const [],
    draftMap: const {
      'personal': {
        'name': {'value': 'Alex Morgan', 'provenance': 'EXPLICIT', 'confidence': 0.98},
        'email': {'value': 'alex.morgan.dev@gmail.com', 'provenance': 'EXPLICIT', 'confidence': 0.99},
        'phone': {'value': '+91 98765 43210', 'provenance': 'EXPLICIT', 'confidence': 0.95},
        'location': {'value': 'Bengaluru, India', 'provenance': 'EXPLICIT', 'confidence': 0.92},
        'linkedin': {'value': 'https://linkedin.com/in/alexmorgandev', 'provenance': 'EXPLICIT', 'confidence': 0.97},
        'github': {'value': 'https://github.com/alexmorgan', 'provenance': 'EXPLICIT', 'confidence': 0.96},
        'portfolio': {'value': 'https://alexmorgan.dev', 'provenance': 'EXPLICIT', 'confidence': 0.95},
      },
      'skills': {
        'languages': [
          {'value': 'Dart', 'provenance': 'EXPLICIT'},
          {'value': 'TypeScript', 'provenance': 'EXPLICIT'},
          {'value': 'Python', 'provenance': 'EXPLICIT'},
        ],
        'frameworks': [
          {'value': 'Flutter', 'provenance': 'EXPLICIT'},
          {'value': 'React', 'provenance': 'EXPLICIT'},
        ],
        'cloud': [
          {'value': 'GCP', 'provenance': 'EXPLICIT'},
          {'value': 'Docker', 'provenance': 'EXPLICIT'},
        ],
        'databases': [
          {'value': 'PostgreSQL', 'provenance': 'EXPLICIT'},
          {'value': 'Firestore', 'provenance': 'EXPLICIT'},
        ],
      },
      'experience': {
        'totalExperienceStated': {'value': 6, 'provenance': 'EXPLICIT', 'confidence': 0.95},
        'items': [
          {
            'company': {'value': 'Acme Cloud Technologies', 'provenance': 'EXPLICIT'},
            'title': {'value': 'Senior Mobile Engineer', 'provenance': 'EXPLICIT'},
            'startDate': {'value': '2021-03', 'provenance': 'EXPLICIT'},
            'endDate': {'value': 'Present', 'provenance': 'EXPLICIT'},
            'description': {
              'value': 'Architected offline-first cross platform applications with Flutter.',
              'provenance': 'EXPLICIT'
            },
          },
        ],
      },
      'education': [
        {
          'institution': {'value': 'National Institute of Technology', 'provenance': 'EXPLICIT'},
          'degree': {'value': 'Bachelor of Technology', 'provenance': 'EXPLICIT'},
          'specialization': {'value': 'Computer Science', 'provenance': 'EXPLICIT'},
          'graduationYear': {'value': 2018, 'provenance': 'EXPLICIT'},
        },
      ],
      'summary': {
        'value': 'Passionate Senior Engineer with 6+ years designing resilient, scalable applications.',
        'provenance': 'INFERRED',
        'confidence': 0.88,
      },
    },
  );

  // ── Sample Company Sources (A06) ──────────────────────────────────────────
  static final sampleSources = <CompanySource>[
    CompanySource(
      id: 'src_001',
      companyId: 'comp_google',
      type: 'GREENHOUSE',
      url: 'https://careers.google.com/jobs',
      config: const {'boardToken': 'googlecloud'},
      secretRef: 'SECRET_GH_TOKEN_GOOGLE',
      intervalMin: 240,
      enabled: true,
      verifiedAt: DateTime.now().subtract(const Duration(days: 30)),
      verifiedBy: 'alice.johnson@truemnc.com',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    CompanySource(
      id: 'src_002',
      companyId: 'comp_google',
      type: 'OFFICIAL_FEED',
      url: 'https://careers.google.com/feed.xml',
      config: const {'feedUrl': 'https://careers.google.com/feed.xml'},
      intervalMin: 360,
      enabled: true,
      verifiedAt: DateTime.now().subtract(const Duration(days: 15)),
      verifiedBy: 'robert.davis@truemnc.com',
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
    ),
  ];

  // ── Sample Admin Jobs & Validation (A08) ───────────────────────────────────
  static final sampleAdminJob = AdminJob(
    job: sampleJobs.first,
    reviewReasons: const ['R2 domain match check verified'],
    companyLogo: 'https://www.google.com/favicon.ico',
    sourceId: 'src_001',
    contentHash: 'hash_991823aef',
  );

  static final sampleValidations = <JobValidationModel>[
    JobValidationModel(
      id: 'val_01',
      allPass: true,
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      results: const [
        RuleResultItem(ruleCode: 'R1', result: 'PASS', details: 'Source enabled & company verified'),
        RuleResultItem(ruleCode: 'R2', result: 'PASS', details: 'Domain careers.google.com matches approved domain'),
        RuleResultItem(ruleCode: 'R3', result: 'PASS', details: 'URL live with HTTP 200 OK'),
        RuleResultItem(ruleCode: 'R4', result: 'PASS', details: 'Required fields present (title, company, applyUrl)'),
        RuleResultItem(ruleCode: 'R5', result: 'PASS', details: 'Fresh job posted 6 hours ago (< 90 days)'),
        RuleResultItem(ruleCode: 'R6', result: 'PASS', details: 'No third-party consultancy or scam signals detected'),
        RuleResultItem(ruleCode: 'R7', result: 'PASS', details: 'No duplicate found in active database'),
        RuleResultItem(ruleCode: 'R8', result: 'PASS', details: 'Verified ATS Greenhouse connector token match'),
      ],
    ),
  ];
}
