// lib/data/models/app_user.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import 'enums.dart';
import 'timestamp_converter.dart';

part 'app_user.freezed.dart';
part 'app_user.g.dart';

// ── Notification Preferences ─────────────────────────────────────────────────

@freezed
class NotificationPreferences with _$NotificationPreferences {
  const NotificationPreferences._();

  const factory NotificationPreferences({
    @Default(true) bool jobAlerts,
    @Default(true) bool applicationUpdates,
    @Default(false) bool marketing,
  }) = _NotificationPreferences;

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      _$NotificationPreferencesFromJson(json);
}

// ── AppUser ──────────────────────────────────────────────────────────────────

@freezed
class AppUser with _$AppUser {
  const AppUser._();

  static Object? _readId(Map<dynamic, dynamic> json, String key) =>
      json['id'] ?? json['uid'];

  const factory AppUser({
    @JsonKey(readValue: AppUser._readId) required String id,
    String? name,
    String? email,
    String? photoUrl,
    @JsonKey(unknownEnumValue: UserRole.user)
    @Default(UserRole.user)
    UserRole role,
    @Default(false) bool onboardingDone,
    @JsonKey(unknownEnumValue: ResumeParseStatus.notStarted)
    @Default(ResumeParseStatus.notStarted)
    ResumeParseStatus resumeParseStatus,
    @TimestampConverter() DateTime? profileGeneratedAt,
    @Default(false) bool profileConfirmed,
    @Default(0) int profileCompletion,
    @Default(NotificationPreferences()) NotificationPreferences notifPrefs,
    @TimestampConverter() DateTime? createdAt,
    // Server-side only fields (never written by client):
    List<String>? matchKeys,
    @JsonKey(name: 'fcm_tokens') List<String>? fcmTokens,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);

  factory AppUser.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc, [
    SnapshotOptions? options,
  ]) {
    final data = doc.data() ?? {};
    return AppUser.fromJson({
      ...data,
      'id': doc.id,
    });
  }

  /// Backward-compatibility alias for uid
  String get uid => id;

  /// Exports data for Firestore writes while strictly upholding security rules:
  /// Roles, system confirmations, matchKeys, and fcm_tokens are server-side only
  /// and must NEVER be written by the client.
  Map<String, dynamic> toFirestore() {
    final map = toJson();
    map.remove('id');
    map.remove('role');
    map.remove('profile_confirmed_by_system');
    map.remove('profile_completion');
    map.remove('matchKeys');
    map.remove('fcm_tokens');
    return map;
  }
}

/// Backwards-compatibility alias for UserModel
typedef UserModel = AppUser;
