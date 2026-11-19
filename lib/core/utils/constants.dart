// lib/core/utils/constants.dart

/// App-wide constant values.
abstract final class AppConstants {
  // Firestore collection names
  static const String usersCollection = 'users';
  static const String jobsCollection = 'jobs';
  static const String companiesCollection = 'companies';
  static const String applicationsCollection = 'applications';
  static const String resumesCollection = 'resumes';
  static const String reportsCollection = 'reports';
  static const String notificationsCollection = 'notifications';

  // Firebase Storage paths
  static const String avatarsPath = 'avatars';
  static const String resumesPath = 'resumes';
  static const String companyLogosPath = 'company_logos';

  // Pagination
  static const int defaultPageSize = 20;

  // SharedPreferences keys
  static const String prefOnboardingDone = 'onboarding_done';
  static const String prefThemeMode = 'theme_mode';
}

/// User role enum — mirrors Firebase custom claims.
enum UserRole { user, admin, superAdmin }

extension UserRoleX on UserRole {
  String get claimValue => switch (this) {
        UserRole.user => 'USER',
        UserRole.admin => 'ADMIN',
        UserRole.superAdmin => 'SUPER_ADMIN',
      };

  static UserRole fromClaim(String? value) => switch (value) {
        'ADMIN' => UserRole.admin,
        'SUPER_ADMIN' => UserRole.superAdmin,
        _ => UserRole.user,
      };
}
