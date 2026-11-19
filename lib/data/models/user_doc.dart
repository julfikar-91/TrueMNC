// lib/data/models/user_doc.dart
import 'package:equatable/equatable.dart';

/// Represents the Firestore document stored at `/users/{uid}`.
///
/// Note: User roles are NEVER stored in this document — roles exist
/// exclusively in Firebase custom claims.
class UserDoc extends Equatable {
  const UserDoc({
    required this.uid,
    required this.email,
    this.name,
    this.onboardingDone = false,
    this.resumeOnboardingDone = false,
    this.resumeParseInProgress = false,
    this.resumeParsed = false,
    this.profileConfirmed = false,
    this.preferencesMissing = true,
    this.adminStartPreferred = false,
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String email;
  final String? name;
  final bool onboardingDone;
  final bool resumeOnboardingDone;
  final bool resumeParseInProgress;
  final bool resumeParsed;
  final bool profileConfirmed;
  final bool preferencesMissing;
  final bool adminStartPreferred;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory UserDoc.fromMap(Map<String, dynamic> data, String uid) {
    DateTime? parseDate(Object? val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
      if (val is String) return DateTime.tryParse(val);
      return null;
    }

    return UserDoc(
      uid: uid,
      email: (data['email'] as String?) ?? '',
      name: (data['name'] as String?) ?? (data['displayName'] as String?),
      onboardingDone: (data['onboarding_done'] as bool?) ??
          (data['onboardingDone'] as bool?) ??
          false,
      resumeOnboardingDone: (data['resume_onboarding_done'] as bool?) ??
          (data['resumeOnboardingDone'] as bool?) ??
          false,
      resumeParseInProgress: (data['resume_parse_in_progress'] as bool?) ??
          (data['resumeParseInProgress'] as bool?) ??
          false,
      resumeParsed: (data['resume_parsed'] as bool?) ??
          (data['resumeParsed'] as bool?) ??
          false,
      profileConfirmed: (data['profile_confirmed'] as bool?) ??
          (data['profileConfirmed'] as bool?) ??
          false,
      preferencesMissing: (data['preferences_missing'] as bool?) ??
          (data['preferencesMissing'] as bool?) ??
          (data['preferences'] == null),
      adminStartPreferred: (data['admin_start_preferred'] as bool?) ??
          (data['adminStartPreferred'] as bool?) ??
          false,
      createdAt: parseDate(data['createdAt']),
      updatedAt: parseDate(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'onboarding_done': onboardingDone,
      'resume_onboarding_done': resumeOnboardingDone,
      'resume_parse_in_progress': resumeParseInProgress,
      'resume_parsed': resumeParsed,
      'profile_confirmed': profileConfirmed,
      'preferences_missing': preferencesMissing,
      'admin_start_preferred': adminStartPreferred,
      if (createdAt != null) 'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  UserDoc copyWith({
    String? uid,
    String? email,
    String? name,
    bool? onboardingDone,
    bool? resumeOnboardingDone,
    bool? resumeParseInProgress,
    bool? resumeParsed,
    bool? profileConfirmed,
    bool? preferencesMissing,
    bool? adminStartPreferred,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserDoc(
      uid: uid ?? this.uid,
      email: email ?? this.email,
      name: name ?? this.name,
      onboardingDone: onboardingDone ?? this.onboardingDone,
      resumeOnboardingDone: resumeOnboardingDone ?? this.resumeOnboardingDone,
      resumeParseInProgress:
          resumeParseInProgress ?? this.resumeParseInProgress,
      resumeParsed: resumeParsed ?? this.resumeParsed,
      profileConfirmed: profileConfirmed ?? this.profileConfirmed,
      preferencesMissing: preferencesMissing ?? this.preferencesMissing,
      adminStartPreferred: adminStartPreferred ?? this.adminStartPreferred,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        uid,
        email,
        name,
        onboardingDone,
        resumeOnboardingDone,
        resumeParseInProgress,
        resumeParsed,
        profileConfirmed,
        preferencesMissing,
        adminStartPreferred,
        createdAt,
        updatedAt,
      ];
}
