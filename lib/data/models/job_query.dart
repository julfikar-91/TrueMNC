// lib/data/models/job_query.dart

/// Query container for job search filters, supported by both normal keyword search
/// and AI-interpreted search.
class JobQuery {
  const JobQuery({
    this.titles = const [],
    this.skills = const [],
    this.jobType,
    this.category,
    this.city,
    this.workMode,
    this.employmentType,
    this.experienceLevel,
    this.education,
    this.postedWithinDays,
    this.keyword,
    this.isAiInterpreted = false,
    this.fallback = false,
  });

  final List<String> titles;
  final List<String> skills;
  final String? jobType;
  final String? category;
  final String? city;
  final String? workMode;
  final String? employmentType;
  final String? experienceLevel;
  final String? education;
  final int? postedWithinDays;
  final String? keyword;
  final bool isAiInterpreted;
  final bool fallback;

  factory JobQuery.fromParsedAi(Map<String, dynamic> data) {
    final titlesList = (data['titles'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final skillsList = (data['skills'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final fallbackVal = data['fallback'] == true;
    final keywordsList = (data['keywords'] as List?)?.map((e) => e.toString()).toList() ?? [];

    return JobQuery(
      titles: titlesList,
      skills: skillsList,
      jobType: data['jobType'] as String?,
      category: data['category'] as String?,
      city: data['city'] as String?,
      workMode: data['workMode'] as String?,
      employmentType: data['employmentType'] as String?,
      experienceLevel: data['experienceLevel'] as String?,
      education: data['education'] as String?,
      postedWithinDays: data['postedWithinDays'] is int
          ? data['postedWithinDays'] as int
          : (data['postedWithinDays'] != null
              ? int.tryParse(data['postedWithinDays'].toString())
              : null),
      keyword: fallbackVal && keywordsList.isNotEmpty ? keywordsList.join(' ') : null,
      isAiInterpreted: !fallbackVal,
      fallback: fallbackVal,
    );
  }

  JobQuery copyWith({
    List<String>? titles,
    List<String>? skills,
    String? jobType,
    bool clearJobType = false,
    String? category,
    bool clearCategory = false,
    String? city,
    bool clearCity = false,
    String? workMode,
    bool clearWorkMode = false,
    String? employmentType,
    bool clearEmploymentType = false,
    String? experienceLevel,
    bool clearExperienceLevel = false,
    String? education,
    bool clearEducation = false,
    int? postedWithinDays,
    bool clearPostedWithinDays = false,
    String? keyword,
    bool clearKeyword = false,
    bool? isAiInterpreted,
    bool? fallback,
  }) {
    return JobQuery(
      titles: titles ?? this.titles,
      skills: skills ?? this.skills,
      jobType: clearJobType ? null : (jobType ?? this.jobType),
      category: clearCategory ? null : (category ?? this.category),
      city: clearCity ? null : (city ?? this.city),
      workMode: clearWorkMode ? null : (workMode ?? this.workMode),
      employmentType: clearEmploymentType ? null : (employmentType ?? this.employmentType),
      experienceLevel: clearExperienceLevel ? null : (experienceLevel ?? this.experienceLevel),
      education: clearEducation ? null : (education ?? this.education),
      postedWithinDays: clearPostedWithinDays ? null : (postedWithinDays ?? this.postedWithinDays),
      keyword: clearKeyword ? null : (keyword ?? this.keyword),
      isAiInterpreted: isAiInterpreted ?? this.isAiInterpreted,
      fallback: fallback ?? this.fallback,
    );
  }

  bool get isEmpty =>
      titles.isEmpty &&
      skills.isEmpty &&
      jobType == null &&
      category == null &&
      city == null &&
      workMode == null &&
      employmentType == null &&
      experienceLevel == null &&
      education == null &&
      postedWithinDays == null &&
      (keyword == null || keyword!.trim().isEmpty);

  bool get isNotEmpty => !isEmpty;

  int get filterCount {
    var count = 0;
    count += titles.length;
    count += skills.length;
    if (jobType != null) count++;
    if (category != null) count++;
    if (city != null) count++;
    if (workMode != null) count++;
    if (employmentType != null) count++;
    if (experienceLevel != null) count++;
    if (education != null) count++;
    if (postedWithinDays != null) count++;
    if (keyword != null && keyword!.trim().isNotEmpty) count++;
    return count;
  }
}
