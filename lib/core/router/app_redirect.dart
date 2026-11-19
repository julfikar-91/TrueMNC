// lib/core/router/app_redirect.dart
import 'package:equatable/equatable.dart';
import '../utils/constants.dart';
import '../../data/models/user_doc.dart';

/// Pure state object holding all signals evaluated by the router guard.
class AppRedirectState extends Equatable {
  const AppRedirectState({
    required this.isInitialized,
    this.initError = false,
    this.isAuthenticated = false,
    this.isEmailVerified = false,
    this.isEmailPasswordUser = false,
    this.role = UserRole.user,
    this.userDoc,
  });

  final bool isInitialized;
  final bool initError;
  final bool isAuthenticated;
  final bool isEmailVerified;
  final bool isEmailPasswordUser;
  final UserRole role;
  final UserDoc? userDoc;

  bool get isAdmin => role == UserRole.admin || role == UserRole.superAdmin;

  bool get isSuperAdmin => role == UserRole.superAdmin;

  @override
  List<Object?> get props => [
        isInitialized,
        initError,
        isAuthenticated,
        isEmailVerified,
        isEmailPasswordUser,
        role,
        userDoc,
      ];
}

/// Pure redirect logic implementing the exact 9-row state transition table:
///
/// 1. init fail/no network on first launch -> /init-retry
/// 2. no session -> /welcome (Guests may browse /home and /job/:id)
/// 3. session but email not verified (email/password users) -> /verify-email
/// 4. verified, onboarding not done -> /onboarding then /resume-onboarding
/// 5. resume parse in progress -> /resume-processing
/// 6. parsed but not confirmed -> /profile-preview
/// 7. confirmed but preferences missing -> /preferences
/// 8. role ADMIN/SUPER_ADMIN and user chose admin start -> /admin
/// 9. else -> /home
String? appRedirect({
  required AppRedirectState state,
  required String currentPath,
}) {
  // ── ROW 1: Init fail / no network on first launch ─────────────────────────
  if (state.initError) {
    return currentPath == '/init-retry' ? null : '/init-retry';
  }
  if (!state.isInitialized) {
    return currentPath == '/splash' ? null : '/splash';
  }

  // ── ROW 2: No session (Unauthenticated) ───────────────────────────────────
  if (!state.isAuthenticated) {
    // Guests may browse /home and /job/:id
    final isGuestAllowed =
        currentPath == '/home' || currentPath.startsWith('/job/');
    final isAuthFlow = currentPath == '/welcome' ||
        currentPath == '/login' ||
        currentPath == '/register' ||
        currentPath == '/forgot' ||
        currentPath == '/splash';

    if (isGuestAllowed || isAuthFlow) {
      return null;
    }
    return '/welcome';
  }

  // ── Authenticated User Guard for /admin/* ──────────────────────────────────
  final isAdminRoute =
      currentPath == '/admin' || currentPath.startsWith('/admin/');
  if (isAdminRoute && !state.isAdmin) {
    // Non-admin attempting to access admin route
    return '/home';
  }

  // ── SUPER_ADMIN Only Guard for A15 & A17 ──────────────────────────────────
  final isSuperAdminRoute = currentPath == '/admin/administrators' ||
      currentPath.startsWith('/admin/administrators/') ||
      currentPath == '/admin/config' ||
      currentPath.startsWith('/admin/config/');
  if (isSuperAdminRoute && !state.isSuperAdmin) {
    // Regular admin blocked from SUPER_ADMIN screens
    return '/admin';
  }

  // ── ROW 3: Email not verified (email/password users only) ─────────────────
  if (state.isEmailPasswordUser && !state.isEmailVerified) {
    return currentPath == '/verify-email' ? null : '/verify-email';
  }

  // If user document is not yet loaded, remain on current path or splash
  final userDoc = state.userDoc;
  if (userDoc == null) {
    return null;
  }

  // ── ROW 4: Verified, onboarding not done ──────────────────────────────────
  if (!userDoc.onboardingDone) {
    return currentPath == '/onboarding' ? null : '/onboarding';
  }
  if (!userDoc.resumeOnboardingDone) {
    final isAllowed = currentPath == '/resume-onboarding' ||
        currentPath == '/resume-upload' ||
        currentPath == '/profile-manual';
    return isAllowed ? null : '/resume-onboarding';
  }

  // ── ROW 5: Resume parse in progress ───────────────────────────────────────
  if (userDoc.resumeParseInProgress) {
    final isAllowed = currentPath == '/resume-processing' ||
        currentPath == '/resume-upload' ||
        currentPath == '/profile-manual';
    return isAllowed ? null : '/resume-processing';
  }

  // ── ROW 6: Parsed but not confirmed ───────────────────────────────────────
  if (userDoc.resumeParsed && !userDoc.profileConfirmed) {
    final isAllowed = currentPath == '/profile-preview' ||
        currentPath == '/resume-upload' ||
        currentPath == '/profile-manual';
    return isAllowed ? null : '/profile-preview';
  }

  // ── ROW 7: Confirmed but preferences missing ──────────────────────────────
  if (userDoc.profileConfirmed && userDoc.preferencesMissing) {
    return currentPath == '/preferences' ? null : '/preferences';
  }

  // ── ROW 8: Role ADMIN/SUPER_ADMIN and user chose admin start ──────────────
  if (state.isAdmin && userDoc.adminStartPreferred) {
    final isAlreadyAdmin = currentPath.startsWith('/admin');
    final isExitingToHome = currentPath == '/home';
    if (!isAlreadyAdmin && !isExitingToHome) {
      return '/admin';
    }
  }

  // ── ROW 9: Else -> /home ──────────────────────────────────────────────────
  final isTransientOrAuthScreen = currentPath == '/welcome' ||
      currentPath == '/login' ||
      currentPath == '/register' ||
      currentPath == '/forgot' ||
      currentPath == '/splash' ||
      currentPath == '/init-retry' ||
      currentPath == '/verify-email' ||
      currentPath == '/onboarding' ||
      currentPath == '/resume-onboarding' ||
      currentPath == '/resume-upload' ||
      currentPath == '/resume-processing' ||
      currentPath == '/profile-preview' ||
      currentPath == '/profile-manual' ||
      currentPath == '/preferences';

  if (isTransientOrAuthScreen) {
    return '/home';
  }

  // Allow normal app navigation (e.g. /home, /search, /saved, /job/:id, etc.)
  return null;
}
