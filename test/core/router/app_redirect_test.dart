// test/core/router/app_redirect_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:true_corporate_job_finder/core/router/app_redirect.dart';
import 'package:true_corporate_job_finder/core/utils/constants.dart';
import 'package:true_corporate_job_finder/data/models/user_doc.dart';

void main() {
  group('AppRedirect Table-Driven Tests (All 9 Rows)', () {
    // ── Helper fixtures ──────────────────────────────────────────────────────
    const completedUserDoc = UserDoc(
      uid: 'user_123',
      email: 'user@example.com',
      onboardingDone: true,
      resumeOnboardingDone: true,
      resumeParseInProgress: false,
      resumeParsed: true,
      profileConfirmed: true,
      preferencesMissing: false,
      adminStartPreferred: false,
    );

    // ── ROW 1: Init fail / no network on first launch ────────────────────────
    group('Row 1: Init fail / no network on first launch', () {
      test('redirects to /init-retry when initError is true', () {
        const state = AppRedirectState(
          isInitialized: false,
          initError: true,
        );
        expect(appRedirect(state: state, currentPath: '/splash'), '/init-retry');
        expect(appRedirect(state: state, currentPath: '/home'), '/init-retry');
        expect(appRedirect(state: state, currentPath: '/init-retry'), isNull);
      });

      test('redirects to /splash while initialization is in progress', () {
        const state = AppRedirectState(
          isInitialized: false,
          initError: false,
        );
        expect(appRedirect(state: state, currentPath: '/home'), '/splash');
        expect(appRedirect(state: state, currentPath: '/splash'), isNull);
      });
    });

    // ── ROW 2: No session -> /welcome (Guests may browse /home & /job/:id) ───
    group('Row 2: No session -> /welcome & guest access', () {
      const state = AppRedirectState(
        isInitialized: true,
        isAuthenticated: false,
      );

      final cases = [
        // (currentPath, expectedRedirect, description)
        ('/profile', '/welcome', 'Protected route redirects unauthenticated user to /welcome'),
        ('/settings', '/welcome', 'Settings redirects unauthenticated user to /welcome'),
        ('/saved', '/welcome', 'Saved jobs redirects unauthenticated user to /welcome'),
        ('/admin', '/welcome', 'Admin route redirects unauthenticated user to /welcome'),
        ('/onboarding', '/welcome', 'Onboarding redirects unauthenticated user to /welcome'),
        ('/welcome', null, 'Unauthenticated user allowed on /welcome'),
        ('/login', null, 'Unauthenticated user allowed on /login'),
        ('/register', null, 'Unauthenticated user allowed on /register'),
        ('/forgot', null, 'Unauthenticated user allowed on /forgot'),
        ('/splash', null, 'Unauthenticated user allowed on /splash'),
        ('/home', null, 'Guest allowed to browse /home'),
        ('/job/job_456', null, 'Guest allowed to browse /job/:id'),
        ('/job/software-engineer-google', null, 'Guest allowed to browse /job/:id with slug'),
      ];

      for (final (path, expected, desc) in cases) {
        test(desc, () {
          expect(appRedirect(state: state, currentPath: path), expected);
        });
      }
    });

    // ── ROW 3: Session but email not verified (email/password users) ─────────
    group('Row 3: Email verification for password users', () {
      const unverifiedPasswordUser = AppRedirectState(
        isInitialized: true,
        isAuthenticated: true,
        isEmailPasswordUser: true,
        isEmailVerified: false,
        userDoc: completedUserDoc,
      );

      const verifiedPasswordUser = AppRedirectState(
        isInitialized: true,
        isAuthenticated: true,
        isEmailPasswordUser: true,
        isEmailVerified: true,
        userDoc: completedUserDoc,
      );

      const oauthUser = AppRedirectState(
        isInitialized: true,
        isAuthenticated: true,
        isEmailPasswordUser: false,
        isEmailVerified: false, // Google sets emailVerified true, but test OAuth branch
        userDoc: completedUserDoc,
      );

      test('redirects unverified password user to /verify-email', () {
        expect(
          appRedirect(state: unverifiedPasswordUser, currentPath: '/home'),
          '/verify-email',
        );
        expect(
          appRedirect(state: unverifiedPasswordUser, currentPath: '/profile'),
          '/verify-email',
        );
        expect(
          appRedirect(state: unverifiedPasswordUser, currentPath: '/verify-email'),
          isNull,
        );
      });

      test('does not block verified password user', () {
        expect(
          appRedirect(state: verifiedPasswordUser, currentPath: '/home'),
          isNull,
        );
      });

      test('does not block OAuth / Google users with unverified flag', () {
        expect(
          appRedirect(state: oauthUser, currentPath: '/home'),
          isNull,
        );
      });
    });

    // ── ROW 4: Verified, onboarding not done ─────────────────────────────────
    group('Row 4: Onboarding sequence', () {
      test('redirects to /onboarding when onboarding_done is false', () {
        final state = AppRedirectState(
          isInitialized: true,
          isAuthenticated: true,
          isEmailVerified: true,
          userDoc: completedUserDoc.copyWith(onboardingDone: false),
        );

        expect(appRedirect(state: state, currentPath: '/home'), '/onboarding');
        expect(appRedirect(state: state, currentPath: '/onboarding'), isNull);
      });

      test('redirects to /resume-onboarding when step 1 done but resume onboarding not done', () {
        final state = AppRedirectState(
          isInitialized: true,
          isAuthenticated: true,
          isEmailVerified: true,
          userDoc: completedUserDoc.copyWith(
            onboardingDone: true,
            resumeOnboardingDone: false,
          ),
        );

        expect(
          appRedirect(state: state, currentPath: '/home'),
          '/resume-onboarding',
        );
        expect(
          appRedirect(state: state, currentPath: '/resume-onboarding'),
          isNull,
        );
      });
    });

    // ── ROW 5: Resume parse in progress -> /resume-processing ────────────────
    group('Row 5: Resume parse in progress', () {
      test('redirects to /resume-processing while parse is running', () {
        final state = AppRedirectState(
          isInitialized: true,
          isAuthenticated: true,
          isEmailVerified: true,
          userDoc: completedUserDoc.copyWith(
            onboardingDone: true,
            resumeOnboardingDone: true,
            resumeParseInProgress: true,
          ),
        );

        expect(appRedirect(state: state, currentPath: '/home'), '/resume-processing');
        expect(appRedirect(state: state, currentPath: '/resume-processing'), isNull);
      });
    });

    // ── ROW 6: Parsed but not confirmed -> /profile-preview ──────────────────
    group('Row 6: Profile confirmation required', () {
      test('redirects to /profile-preview when parsed but profile not confirmed', () {
        final state = AppRedirectState(
          isInitialized: true,
          isAuthenticated: true,
          isEmailVerified: true,
          userDoc: completedUserDoc.copyWith(
            onboardingDone: true,
            resumeOnboardingDone: true,
            resumeParseInProgress: false,
            resumeParsed: true,
            profileConfirmed: false,
          ),
        );

        expect(appRedirect(state: state, currentPath: '/home'), '/profile-preview');
        expect(appRedirect(state: state, currentPath: '/profile-preview'), isNull);
      });
    });

    // ── ROW 7: Confirmed but preferences missing -> /preferences ─────────────
    group('Row 7: Preferences selection', () {
      test('redirects to /preferences when confirmed but preferences missing', () {
        final state = AppRedirectState(
          isInitialized: true,
          isAuthenticated: true,
          isEmailVerified: true,
          userDoc: completedUserDoc.copyWith(
            onboardingDone: true,
            resumeOnboardingDone: true,
            resumeParseInProgress: false,
            resumeParsed: true,
            profileConfirmed: true,
            preferencesMissing: true,
          ),
        );

        expect(appRedirect(state: state, currentPath: '/home'), '/preferences');
        expect(appRedirect(state: state, currentPath: '/preferences'), isNull);
      });
    });

    // ── ROW 8: Role ADMIN/SUPER_ADMIN and user chose admin start ─────────────
    group('Row 8: Admin role handling and admin start preference', () {
      test('redirects admin with adminStartPreferred to /admin', () {
        final adminState = AppRedirectState(
          isInitialized: true,
          isAuthenticated: true,
          isEmailVerified: true,
          role: UserRole.admin,
          userDoc: completedUserDoc.copyWith(adminStartPreferred: true),
        );

        expect(appRedirect(state: adminState, currentPath: '/login'), '/admin');
        expect(appRedirect(state: adminState, currentPath: '/welcome'), '/admin');
        expect(appRedirect(state: adminState, currentPath: '/admin'), isNull);
      });

      test('super_admin with adminStartPreferred is also supported', () {
        final superAdminState = AppRedirectState(
          isInitialized: true,
          isAuthenticated: true,
          isEmailVerified: true,
          role: UserRole.superAdmin,
          userDoc: completedUserDoc.copyWith(adminStartPreferred: true),
        );

        expect(appRedirect(state: superAdminState, currentPath: '/welcome'), '/admin');
      });

      test('blocks non-admin users from accessing /admin and redirects to /home', () {
        final regularUserState = AppRedirectState(
          isInitialized: true,
          isAuthenticated: true,
          isEmailVerified: true,
          role: UserRole.user,
          userDoc: completedUserDoc,
        );

        expect(appRedirect(state: regularUserState, currentPath: '/admin'), '/home');
        expect(appRedirect(state: regularUserState, currentPath: '/admin/settings'), '/home');
      });

      test('allows admin users to access /admin', () {
        final adminState = AppRedirectState(
          isInitialized: true,
          isAuthenticated: true,
          isEmailVerified: true,
          role: UserRole.admin,
          userDoc: completedUserDoc,
        );

        expect(appRedirect(state: adminState, currentPath: '/admin'), isNull);
      });
    });

    // ── ROW 9: Else -> /home ─────────────────────────────────────────────────
    group('Row 9: Normal app navigation and transient screen redirects', () {
      final normalUserState = AppRedirectState(
        isInitialized: true,
        isAuthenticated: true,
        isEmailVerified: true,
        role: UserRole.user,
        userDoc: completedUserDoc,
      );

      test('redirects user on auth/transient screens to /home', () {
        const transientScreens = [
          '/welcome',
          '/login',
          '/register',
          '/forgot',
          '/splash',
          '/init-retry',
          '/verify-email',
          '/onboarding',
          '/resume-onboarding',
          '/resume-processing',
          '/profile-preview',
          '/preferences',
        ];

        for (final screen in transientScreens) {
          expect(
            appRedirect(state: normalUserState, currentPath: screen),
            '/home',
            reason: 'Failed to redirect from transient screen: $screen',
          );
        }
      });

      test('allows normal in-app navigation', () {
        const validScreens = [
          '/home',
          '/search',
          '/saved',
          '/notifications',
          '/profile',
          '/settings',
          '/job/12345',
        ];

        for (final screen in validScreens) {
          expect(
            appRedirect(state: normalUserState, currentPath: screen),
            isNull,
            reason: 'Blocked valid in-app screen: $screen',
          );
        }
      });
    });
  });
}
