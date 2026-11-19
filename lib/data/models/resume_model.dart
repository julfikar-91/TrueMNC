// lib/data/models/resume_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

import 'enums.dart';
import 'field_value_wrapper.dart';

// ── 1. Resume Processing Status ──────────────────────────────────────────────

enum ResumeDocStatus {
  uploading,
  uploaded,
  processing,
  parsed,
  partial,
  failedUnreadable,
  failedAi,
  confirmed,
  deleted;

  static ResumeDocStatus fromString(String? val) {
    if (val == null) return ResumeDocStatus.uploading;
    return switch (val.toUpperCase().replaceAll('-', '_').trim()) {
      'UPLOADING' => ResumeDocStatus.uploading,
      'UPLOADED' => ResumeDocStatus.uploaded,
      'PROCESSING' => ResumeDocStatus.processing,
      'PARSED' => ResumeDocStatus.parsed,
      'PARTIAL' => ResumeDocStatus.partial,
      'FAILED_UNREADABLE' => ResumeDocStatus.failedUnreadable,
      'FAILED_AI' => ResumeDocStatus.failedAi,
      'CONFIRMED' => ResumeDocStatus.confirmed,
      'DELETED' => ResumeDocStatus.deleted,
      _ => ResumeDocStatus.processing,
    };
  }

  String toDbString() {
    return switch (this) {
      ResumeDocStatus.uploading => 'UPLOADING',
      ResumeDocStatus.uploaded => 'UPLOADED',
      ResumeDocStatus.processing => 'PROCESSING',
      ResumeDocStatus.parsed => 'PARSED',
      ResumeDocStatus.partial => 'PARTIAL',
      ResumeDocStatus.failedUnreadable => 'FAILED_UNREADABLE',
      ResumeDocStatus.failedAi => 'FAILED_AI',
      ResumeDocStatus.confirmed => 'CONFIRMED',
      ResumeDocStatus.deleted => 'DELETED',
    };
  }
}

// ── 2. Resume 7-Stage Progress ───────────────────────────────────────────────

enum ResumeProgressStage {
  uploading,
  reading,
  personal,
  skills,
  education,
  experience,
  creating;

  static ResumeProgressStage fromString(String? val) {
    if (val == null) return ResumeProgressStage.uploading;
    return switch (val.toLowerCase().trim()) {
      'uploading' => ResumeProgressStage.uploading,
      'reading' => ResumeProgressStage.reading,
      'personal' => ResumeProgressStage.personal,
      'skills' => ResumeProgressStage.skills,
      'education' => ResumeProgressStage.education,
      'experience' => ResumeProgressStage.experience,
      'creating' => ResumeProgressStage.creating,
      _ => ResumeProgressStage.uploading,
    };
  }

  String get displayName => switch (this) {
        ResumeProgressStage.uploading => 'Uploading resume document',
        ResumeProgressStage.reading => 'Reading & verifying format',
        ResumeProgressStage.personal => 'Extracting contact & personal details',
        ResumeProgressStage.skills => 'Matching skills to dictionary',
        ResumeProgressStage.education => 'Parsing educational background',
        ResumeProgressStage.experience => 'Analyzing career history & projects',
        ResumeProgressStage.creating => 'Generating structured profile draft',
      };

  int get stepNumber => switch (this) {
        ResumeProgressStage.uploading => 1,
        ResumeProgressStage.reading => 2,
        ResumeProgressStage.personal => 3,
        ResumeProgressStage.skills => 4,
        ResumeProgressStage.education => 5,
        ResumeProgressStage.experience => 6,
        ResumeProgressStage.creating => 7,
      };
}

// ── 3. Resume Document Model (resumes/{id}) ──────────────────────────────────

class ResumeDoc extends Equatable {
  const ResumeDoc({
    required this.id,
    required this.uid,
    required this.storagePath,
    this.status = ResumeDocStatus.uploading,
    this.progress = ResumeProgressStage.uploading,
    this.errorCode,
    this.errorMessage,
    this.fileSize,
    this.mimeType,
    this.pageCount,
    this.warningsCount,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String uid;
  final String storagePath;
  final ResumeDocStatus status;
  final ResumeProgressStage progress;
  final String? errorCode;
  final String? errorMessage;
  final int? fileSize;
  final String? mimeType;
  final int? pageCount;
  final int? warningsCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isProcessing =>
      status == ResumeDocStatus.uploading ||
      status == ResumeDocStatus.uploaded ||
      status == ResumeDocStatus.processing;

  bool get isSuccess =>
      status == ResumeDocStatus.parsed || status == ResumeDocStatus.partial;

  bool get isFailed =>
      status == ResumeDocStatus.failedUnreadable ||
      status == ResumeDocStatus.failedAi;

  factory ResumeDoc.fromFirestore(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data() ?? {};
    DateTime? parseDate(Object? val) {
      if (val is Timestamp) return val.toDate();
      if (val is DateTime) return val;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return ResumeDoc(
      id: snap.id,
      uid: (data['uid'] as String?) ?? '',
      storagePath: (data['storagePath'] as String?) ?? '',
      status: ResumeDocStatus.fromString(data['status'] as String?),
      progress: ResumeProgressStage.fromString(data['progress'] as String?),
      errorCode: data['errorCode'] as String?,
      errorMessage: data['errorMessage'] as String?,
      fileSize: (data['fileSize'] as num?)?.toInt(),
      mimeType: data['mimeType'] as String?,
      pageCount: (data['pageCount'] as num?)?.toInt(),
      warningsCount: (data['warningsCount'] as num?)?.toInt(),
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'uid': uid,
      'storagePath': storagePath,
      'status': status.toDbString(),
      'progress': progress.name,
      if (errorCode != null) 'errorCode': errorCode,
      if (errorMessage != null) 'errorMessage': errorMessage,
      if (fileSize != null) 'fileSize': fileSize,
      if (mimeType != null) 'mimeType': mimeType,
      if (pageCount != null) 'pageCount': pageCount,
      if (warningsCount != null) 'warningsCount': warningsCount,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        uid,
        storagePath,
        status,
        progress,
        errorCode,
        errorMessage,
        fileSize,
        mimeType,
        pageCount,
        warningsCount,
        createdAt,
        updatedAt,
      ];
}

// ── 4. Provenance-Tracked Profile Draft Model (resumeParses/{id}) ────────────

class ParsedResumeDraft extends Equatable {
  const ParsedResumeDraft({
    required this.resumeId,
    required this.uid,
    required this.status,
    this.warnings = const [],
    required this.personal,
    this.education = const [],
    required this.skills,
    required this.experience,
    this.projects = const [],
    this.certifications = const [],
    this.achievements = const [],
    this.languages = const [],
    required this.summary,
  });

  final String resumeId;
  final String uid;
  final String status;
  final List<String> warnings;
  final PersonalDraft personal;
  final List<EducationItemDraft> education;
  final SkillsDraft skills;
  final ExperienceSectionDraft experience;
  final List<ProjectItemDraft> projects;
  final List<CertificationItemDraft> certifications;
  final List<AchievementItemDraft> achievements;
  final List<LanguageItemDraft> languages;
  final FieldValueWrapper<String> summary;

  factory ParsedResumeDraft.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snap,
  ) {
    final data = snap.data() ?? {};
    final draft = (data['draft'] as Map<String, dynamic>?) ?? {};

    return ParsedResumeDraft.fromMap(
      resumeId: snap.id,
      uid: (data['uid'] as String?) ?? '',
      status: (data['status'] as String?) ?? 'PARSED',
      warnings: (data['warnings'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      draftMap: draft,
    );
  }

  factory ParsedResumeDraft.fromMap({
    required String resumeId,
    required String uid,
    required String status,
    required List<String> warnings,
    required Map<String, dynamic> draftMap,
  }) {
    return ParsedResumeDraft(
      resumeId: resumeId,
      uid: uid,
      status: status,
      warnings: warnings,
      personal: PersonalDraft.fromMap(
        (draftMap['personal'] as Map<String, dynamic>?) ?? {},
      ),
      education: (draftMap['education'] as List<dynamic>?)
              ?.map((e) => EducationItemDraft.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
      skills: SkillsDraft.fromMap(
        (draftMap['skills'] as Map<String, dynamic>?) ?? {},
      ),
      experience: ExperienceSectionDraft.fromMap(
        (draftMap['experience'] as Map<String, dynamic>?) ?? {},
      ),
      projects: (draftMap['projects'] as List<dynamic>?)
              ?.map((e) => ProjectItemDraft.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
      certifications: (draftMap['certifications'] as List<dynamic>?)
              ?.map((e) => CertificationItemDraft.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
      achievements: (draftMap['achievements'] as List<dynamic>?)
              ?.map((e) => AchievementItemDraft.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
      languages: (draftMap['languages'] as List<dynamic>?)
              ?.map((e) => LanguageItemDraft.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
      summary: _parseField<String>(draftMap['summary']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'personal': personal.toMap(),
      'education': education.map((e) => e.toMap()).toList(),
      'skills': skills.toMap(),
      'experience': experience.toMap(),
      'projects': projects.map((p) => p.toMap()).toList(),
      'certifications': certifications.map((c) => c.toMap()).toList(),
      'achievements': achievements.map((a) => a.toMap()).toList(),
      'languages': languages.map((l) => l.toMap()).toList(),
      'summary': _fieldToMap(summary),
    };
  }

  ParsedResumeDraft copyWith({
    PersonalDraft? personal,
    List<EducationItemDraft>? education,
    SkillsDraft? skills,
    ExperienceSectionDraft? experience,
    List<ProjectItemDraft>? projects,
    List<CertificationItemDraft>? certifications,
    List<AchievementItemDraft>? achievements,
    List<LanguageItemDraft>? languages,
    FieldValueWrapper<String>? summary,
  }) {
    return ParsedResumeDraft(
      resumeId: resumeId,
      uid: uid,
      status: status,
      warnings: warnings,
      personal: personal ?? this.personal,
      education: education ?? this.education,
      skills: skills ?? this.skills,
      experience: experience ?? this.experience,
      projects: projects ?? this.projects,
      certifications: certifications ?? this.certifications,
      achievements: achievements ?? this.achievements,
      languages: languages ?? this.languages,
      summary: summary ?? this.summary,
    );
  }

  @override
  List<Object?> get props => [
        resumeId,
        uid,
        status,
        warnings,
        personal,
        education,
        skills,
        experience,
        projects,
        certifications,
        achievements,
        languages,
        summary,
      ];
}

// ── 5. Sub-draft models ──────────────────────────────────────────────────────

class PersonalDraft extends Equatable {
  const PersonalDraft({
    required this.name,
    required this.email,
    required this.phone,
    required this.location,
    required this.linkedin,
    required this.github,
    required this.portfolio,
  });

  final FieldValueWrapper<String> name;
  final FieldValueWrapper<String> email;
  final FieldValueWrapper<String> phone;
  final FieldValueWrapper<String> location;
  final FieldValueWrapper<String> linkedin;
  final FieldValueWrapper<String> github;
  final FieldValueWrapper<String> portfolio;

  factory PersonalDraft.fromMap(Map<String, dynamic> map) {
    return PersonalDraft(
      name: _parseField<String>(map['name']),
      email: _parseField<String>(map['email']),
      phone: _parseField<String>(map['phone']),
      location: _parseField<String>(map['location']),
      linkedin: _parseField<String>(map['linkedin']),
      github: _parseField<String>(map['github']),
      portfolio: _parseField<String>(map['portfolio']),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': _fieldToMap(name),
        'email': _fieldToMap(email),
        'phone': _fieldToMap(phone),
        'location': _fieldToMap(location),
        'linkedin': _fieldToMap(linkedin),
        'github': _fieldToMap(github),
        'portfolio': _fieldToMap(portfolio),
      };

  PersonalDraft copyWith({
    FieldValueWrapper<String>? name,
    FieldValueWrapper<String>? email,
    FieldValueWrapper<String>? phone,
    FieldValueWrapper<String>? location,
    FieldValueWrapper<String>? linkedin,
    FieldValueWrapper<String>? github,
    FieldValueWrapper<String>? portfolio,
  }) {
    return PersonalDraft(
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      location: location ?? this.location,
      linkedin: linkedin ?? this.linkedin,
      github: github ?? this.github,
      portfolio: portfolio ?? this.portfolio,
    );
  }

  @override
  List<Object?> get props =>
      [name, email, phone, location, linkedin, github, portfolio];
}

class EducationItemDraft extends Equatable {
  const EducationItemDraft({
    required this.degree,
    required this.specialization,
    required this.institution,
    required this.graduationYear,
    required this.gradValue,
    required this.gradScale,
    required this.level,
  });

  final FieldValueWrapper<String> degree;
  final FieldValueWrapper<String> specialization;
  final FieldValueWrapper<String> institution;
  final FieldValueWrapper<Object> graduationYear;
  final FieldValueWrapper<Object> gradValue;
  final FieldValueWrapper<Object> gradScale;
  final FieldValueWrapper<String> level;

  factory EducationItemDraft.fromMap(Map<String, dynamic> map) {
    return EducationItemDraft(
      degree: _parseField<String>(map['degree']),
      specialization: _parseField<String>(map['specialization']),
      institution: _parseField<String>(map['institution']),
      graduationYear: _parseField<Object>(map['graduationYear']),
      gradValue: _parseField<Object>(map['gradValue']),
      gradScale: _parseField<Object>(map['gradScale']),
      level: _parseField<String>(map['level']),
    );
  }

  Map<String, dynamic> toMap() => {
        'degree': _fieldToMap(degree),
        'specialization': _fieldToMap(specialization),
        'institution': _fieldToMap(institution),
        'graduationYear': _fieldToMap(graduationYear),
        'gradValue': _fieldToMap(gradValue),
        'gradScale': _fieldToMap(gradScale),
        'level': _fieldToMap(level),
      };

  @override
  List<Object?> get props => [
        degree,
        specialization,
        institution,
        graduationYear,
        gradValue,
        gradScale,
        level,
      ];
}

class SkillsDraft extends Equatable {
  const SkillsDraft({
    this.languages = const [],
    this.frameworks = const [],
    this.libraries = const [],
    this.databases = const [],
    this.cloud = const [],
    this.tools = const [],
    this.technicalCerts = const [],
    this.soft = const [],
  });

  final List<FieldValueWrapper<String>> languages;
  final List<FieldValueWrapper<String>> frameworks;
  final List<FieldValueWrapper<String>> libraries;
  final List<FieldValueWrapper<String>> databases;
  final List<FieldValueWrapper<String>> cloud;
  final List<FieldValueWrapper<String>> tools;
  final List<FieldValueWrapper<String>> technicalCerts;
  final List<FieldValueWrapper<String>> soft;

  factory SkillsDraft.fromMap(Map<String, dynamic> map) {
    List<FieldValueWrapper<String>> parseList(String key) {
      final list = map[key] as List<dynamic>?;
      if (list == null) return const [];
      return list.map((e) => _parseField<String>(e)).toList();
    }

    return SkillsDraft(
      languages: parseList('languages'),
      frameworks: parseList('frameworks'),
      libraries: parseList('libraries'),
      databases: parseList('databases'),
      cloud: parseList('cloud'),
      tools: parseList('tools'),
      technicalCerts: parseList('technicalCerts'),
      soft: parseList('soft'),
    );
  }

  Map<String, dynamic> toMap() => {
        'languages': languages.map(_fieldToMap).toList(),
        'frameworks': frameworks.map(_fieldToMap).toList(),
        'libraries': libraries.map(_fieldToMap).toList(),
        'databases': databases.map(_fieldToMap).toList(),
        'cloud': cloud.map(_fieldToMap).toList(),
        'tools': tools.map(_fieldToMap).toList(),
        'technicalCerts': technicalCerts.map(_fieldToMap).toList(),
        'soft': soft.map(_fieldToMap).toList(),
      };

  int get totalCount =>
      languages.length +
      frameworks.length +
      libraries.length +
      databases.length +
      cloud.length +
      tools.length +
      technicalCerts.length +
      soft.length;

  @override
  List<Object?> get props => [
        languages,
        frameworks,
        libraries,
        databases,
        cloud,
        tools,
        technicalCerts,
        soft,
      ];
}

class ExperienceSectionDraft extends Equatable {
  const ExperienceSectionDraft({
    required this.totalExperienceStated,
    this.items = const [],
  });

  final FieldValueWrapper<Object> totalExperienceStated;
  final List<ExperienceItemDraft> items;

  factory ExperienceSectionDraft.fromMap(Map<String, dynamic> map) {
    return ExperienceSectionDraft(
      totalExperienceStated: _parseField<Object>(map['totalExperienceStated']),
      items: (map['items'] as List<dynamic>?)
              ?.map((e) => ExperienceItemDraft.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toMap() => {
        'totalExperienceStated': _fieldToMap(totalExperienceStated),
        'items': items.map((i) => i.toMap()).toList(),
      };

  ExperienceSectionDraft copyWith({
    FieldValueWrapper<Object>? totalExperienceStated,
    List<ExperienceItemDraft>? items,
  }) {
    return ExperienceSectionDraft(
      totalExperienceStated:
          totalExperienceStated ?? this.totalExperienceStated,
      items: items ?? this.items,
    );
  }

  @override
  List<Object?> get props => [totalExperienceStated, items];
}

class ExperienceItemDraft extends Equatable {
  const ExperienceItemDraft({
    required this.company,
    required this.title,
    required this.location,
    required this.startDate,
    required this.endDate,
    required this.isCurrent,
    required this.description,
    this.highlights = const [],
  });

  final FieldValueWrapper<String> company;
  final FieldValueWrapper<String> title;
  final FieldValueWrapper<String> location;
  final FieldValueWrapper<String> startDate;
  final FieldValueWrapper<String> endDate;
  final FieldValueWrapper<bool> isCurrent;
  final FieldValueWrapper<String> description;
  final List<FieldValueWrapper<String>> highlights;

  factory ExperienceItemDraft.fromMap(Map<String, dynamic> map) {
    return ExperienceItemDraft(
      company: _parseField<String>(map['company']),
      title: _parseField<String>(map['title']),
      location: _parseField<String>(map['location']),
      startDate: _parseField<String>(map['startDate']),
      endDate: _parseField<String>(map['endDate']),
      isCurrent: _parseField<bool>(map['isCurrent']),
      description: _parseField<String>(map['description']),
      highlights: (map['highlights'] as List<dynamic>?)
              ?.map((e) => _parseField<String>(e))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toMap() => {
        'company': _fieldToMap(company),
        'title': _fieldToMap(title),
        'location': _fieldToMap(location),
        'startDate': _fieldToMap(startDate),
        'endDate': _fieldToMap(endDate),
        'isCurrent': _fieldToMap(isCurrent),
        'description': _fieldToMap(description),
        'highlights': highlights.map(_fieldToMap).toList(),
      };

  @override
  List<Object?> get props => [
        company,
        title,
        location,
        startDate,
        endDate,
        isCurrent,
        description,
        highlights,
      ];
}

class ProjectItemDraft extends Equatable {
  const ProjectItemDraft({
    required this.title,
    required this.description,
    required this.role,
    this.tools = const [],
    required this.url,
    this.highlights = const [],
  });

  final FieldValueWrapper<String> title;
  final FieldValueWrapper<String> description;
  final FieldValueWrapper<String> role;
  final List<FieldValueWrapper<String>> tools;
  final FieldValueWrapper<String> url;
  final List<FieldValueWrapper<String>> highlights;

  factory ProjectItemDraft.fromMap(Map<String, dynamic> map) {
    return ProjectItemDraft(
      title: _parseField<String>(map['title']),
      description: _parseField<String>(map['description']),
      role: _parseField<String>(map['role']),
      tools: (map['tools'] as List<dynamic>?)
              ?.map((e) => _parseField<String>(e))
              .toList() ??
          const [],
      url: _parseField<String>(map['url']),
      highlights: (map['highlights'] as List<dynamic>?)
              ?.map((e) => _parseField<String>(e))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toMap() => {
        'title': _fieldToMap(title),
        'description': _fieldToMap(description),
        'role': _fieldToMap(role),
        'tools': tools.map(_fieldToMap).toList(),
        'url': _fieldToMap(url),
        'highlights': highlights.map(_fieldToMap).toList(),
      };

  @override
  List<Object?> get props => [title, description, role, tools, url, highlights];
}

class CertificationItemDraft extends Equatable {
  const CertificationItemDraft({
    required this.name,
    required this.issuer,
    required this.issueDate,
    required this.expiryDate,
    required this.url,
    required this.credentialId,
  });

  final FieldValueWrapper<String> name;
  final FieldValueWrapper<String> issuer;
  final FieldValueWrapper<String> issueDate;
  final FieldValueWrapper<String> expiryDate;
  final FieldValueWrapper<String> url;
  final FieldValueWrapper<String> credentialId;

  factory CertificationItemDraft.fromMap(Map<String, dynamic> map) {
    return CertificationItemDraft(
      name: _parseField<String>(map['name']),
      issuer: _parseField<String>(map['issuer']),
      issueDate: _parseField<String>(map['issueDate']),
      expiryDate: _parseField<String>(map['expiryDate']),
      url: _parseField<String>(map['url']),
      credentialId: _parseField<String>(map['credentialId']),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': _fieldToMap(name),
        'issuer': _fieldToMap(issuer),
        'issueDate': _fieldToMap(issueDate),
        'expiryDate': _fieldToMap(expiryDate),
        'url': _fieldToMap(url),
        'credentialId': _fieldToMap(credentialId),
      };

  @override
  List<Object?> get props =>
      [name, issuer, issueDate, expiryDate, url, credentialId];
}

class AchievementItemDraft extends Equatable {
  const AchievementItemDraft({
    required this.title,
    required this.description,
    required this.date,
  });

  final FieldValueWrapper<String> title;
  final FieldValueWrapper<String> description;
  final FieldValueWrapper<String> date;

  factory AchievementItemDraft.fromMap(Map<String, dynamic> map) {
    return AchievementItemDraft(
      title: _parseField<String>(map['title']),
      description: _parseField<String>(map['description']),
      date: _parseField<String>(map['date']),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': _fieldToMap(title),
        'description': _fieldToMap(description),
        'date': _fieldToMap(date),
      };

  @override
  List<Object?> get props => [title, description, date];
}

class LanguageItemDraft extends Equatable {
  const LanguageItemDraft({
    required this.language,
    required this.proficiency,
  });

  final FieldValueWrapper<String> language;
  final FieldValueWrapper<String> proficiency;

  factory LanguageItemDraft.fromMap(Map<String, dynamic> map) {
    return LanguageItemDraft(
      language: _parseField<String>(map['language']),
      proficiency: _parseField<String>(map['proficiency']),
    );
  }

  Map<String, dynamic> toMap() => {
        'language': _fieldToMap(language),
        'proficiency': _fieldToMap(proficiency),
      };

  @override
  List<Object?> get props => [language, proficiency];
}

// ── Helpers ──────────────────────────────────────────────────────────────────

FieldValueWrapper<T> _parseField<T>(Object? raw) {
  if (raw is Map<String, dynamic>) {
    return FieldValueWrapper<T>(
      value: raw['value'] as T?,
      provenance: Provenance.fromString(raw['provenance'] as String?),
      evidence: raw['evidence'] as String?,
      confidence: (raw['confidence'] as num?)?.toDouble() ?? 1.0,
    );
  }
  return FieldValueWrapper<T>(
    value: raw as T?,
    provenance: raw != null ? Provenance.explicit : Provenance.missing,
    confidence: 1.0,
  );
}

Map<String, dynamic> _fieldToMap<T>(FieldValueWrapper<T> field) {
  return {
    'value': field.value,
    'provenance': switch (field.provenance) {
      Provenance.explicit => 'EXPLICIT',
      Provenance.inferred => 'INFERRED',
      Provenance.missing => 'MISSING',
    },
    'evidence': field.evidence,
    'confidence': field.confidence ?? 1.0,
  };
}
