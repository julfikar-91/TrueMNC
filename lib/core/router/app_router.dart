// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/auth_repository.dart';
import '../demo/demo_provider.dart';
import '../utils/constants.dart';
import '../widgets/init_retry_screen.dart';
import '../widgets/scaffold_with_nav.dart';
import '../../features/admin/administrators/presentation/admin_management_screen.dart';
import '../../features/admin/audit_logs/presentation/audit_logs_screen.dart';
import '../../features/admin/collection/presentation/collection_monitor_screen.dart';
import '../../features/admin/companies/presentation/company_detail_screen.dart';
import '../../features/admin/companies/presentation/company_form_screen.dart';
import '../../features/admin/companies/presentation/company_list_screen.dart';
import '../../features/admin/config/presentation/system_config_screen.dart';
import '../../features/admin/jobs/presentation/admin_job_detail_screen.dart';
import '../../features/admin/jobs/presentation/all_jobs_screen.dart';
import '../../features/admin/presentation/admin_dashboard_screen.dart';
import '../../features/admin/reports/presentation/admin_reports_screen.dart';
import '../../features/admin/review/presentation/review_queue_screen.dart';
import '../../features/admin/sources/presentation/company_sources_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/verify_email_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/jobs/presentation/job_detail_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/onboarding/presentation/splash_screen.dart';
import '../../features/profile/presentation/profile_manual_screen.dart';
import '../../features/profile/presentation/profile_preview_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/recommendations/presentation/recommendations_screen.dart';
import '../../features/reports/presentation/reports_screen.dart';
import '../../features/resume/presentation/resume_onboarding_screen.dart';
import '../../features/resume/presentation/resume_processing_screen.dart';
import '../../features/resume/presentation/resume_upload_screen.dart';
import '../../features/saved/presentation/saved_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../../features/settings/presentation/preferences_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import 'app_redirect.dart';

abstract final class AppRoutes {
  static const splash = '/splash';
  static const initRetry = '/init-retry';
  static const welcome = '/welcome';
  static const login = '/login';
  static const register = '/register';
  static const forgot = '/forgot';
  static const verifyEmail = '/verify-email';
  static const onboarding = '/onboarding';
  static const resumeOnboarding = '/resume-onboarding';
  static const resumeUpload = '/resume-upload';
  static const resumeProcessing = '/resume-processing';
  static const profilePreview = '/profile-preview';
  static const profileManual = '/profile-manual';
  static const preferences = '/preferences';
  static const home = '/home';
  static const recommendations = '/recommendations';
  static const search = '/search';
  static const reports = '/reports';
  static const saved = '/saved';
  static const notifications = '/notifications';
  static const profile = '/profile';
  static const settings = '/settings';
  static const jobDetail = '/job/:id';
  static const admin = '/admin';
  static const adminCompanies = '/admin/companies';
  static const adminCompanyAdd = '/admin/companies/add';
  static const adminCompanyEdit = '/admin/companies/:id/edit';
  static const adminCompanyDetail = '/admin/companies/:id';
  static const adminCompanySources = '/admin/companies/:id/sources';
  static const adminJobs = '/admin/jobs';
  static const adminJobDetail = '/admin/jobs/:id';
  static const adminReviewQueue = '/admin/review-queue';
  static const adminReports = '/admin/reports';
  static const adminCollectionMonitor = '/admin/collection-monitor';
  static const adminAdministrators = '/admin/administrators';
  static const adminAuditLogs = '/admin/audit-logs';
  static const adminConfig = '/admin/config';
}

/// Listenable that triggers GoRouter redirects whenever auth signals mutate.
class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
    _ref.listen(isDemoModeProvider, (_, __) => notifyListeners());
    _ref.listen(demoRoleProvider, (_, __) => notifyListeners());
    _ref.listen(demoUserDocProvider, (_, __) => notifyListeners());
    _ref.listen(appBootstrapProvider, (_, __) => notifyListeners());
    _ref.listen(authStateProvider, (_, __) => notifyListeners());
    _ref.listen(claimsProvider, (_, __) => notifyListeners());
    _ref.listen(userDocProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;

  AppRedirectState get state {
    final isDemo = _ref.read(isDemoModeProvider);
    if (isDemo) {
      final demoRole = _ref.read(demoRoleProvider);
      final demoUserDoc = _ref.read(demoUserDocProvider);
      return AppRedirectState(
        isInitialized: true,
        initError: false,
        isAuthenticated: true,
        isEmailVerified: true,
        isEmailPasswordUser: false,
        role: demoRole,
        userDoc: demoUserDoc,
        isDemoMode: true,
      );
    }

    final bootstrap = _ref.read(appBootstrapProvider);
    final isInitialized = bootstrap.hasValue && bootstrap.value == true;
    final initError =
        bootstrap.hasError || (bootstrap.hasValue && bootstrap.value == false);

    final authState = _ref.read(authStateProvider);
    final user = authState.valueOrNull;
    final isAuthenticated = user != null;

    final isEmailPasswordUser =
        user?.providerData.any((p) => p.providerId == 'password') ?? false;
    final isEmailVerified = user?.emailVerified ?? false;

    final role = _ref.read(claimsProvider).valueOrNull ?? UserRole.user;
    final userDoc = _ref.read(userDocProvider).valueOrNull;

    return AppRedirectState(
      isInitialized: isInitialized,
      initError: initError,
      isAuthenticated: isAuthenticated,
      isEmailVerified: isEmailVerified,
      isEmailPasswordUser: isEmailPasswordUser,
      role: role,
      userDoc: userDoc,
    );
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final notifier = RouterNotifier(ref);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: notifier,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      return appRedirect(
        state: notifier.state,
        currentPath: state.matchedLocation,
      );
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.initRetry,
        builder: (context, state) => const InitRetryScreen(),
      ),
      GoRoute(
        path: AppRoutes.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgot,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.verifyEmail,
        builder: (context, state) => const VerifyEmailScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.resumeOnboarding,
        builder: (context, state) => const ResumeOnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.resumeUpload,
        builder: (context, state) => const ResumeUploadScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileManual,
        builder: (context, state) => const ProfileManualScreen(),
      ),
      GoRoute(
        path: AppRoutes.resumeProcessing,
        builder: (context, state) => ResumeProcessingScreen(
          resumeId: state.uri.queryParameters['id'],
        ),
      ),
      GoRoute(
        path: AppRoutes.profilePreview,
        builder: (context, state) => ProfilePreviewScreen(
          resumeId: state.uri.queryParameters['id'],
        ),
      ),
      GoRoute(
        path: AppRoutes.preferences,
        builder: (context, state) => const PreferencesScreen(),
      ),
      GoRoute(
        path: AppRoutes.recommendations,
        builder: (context, state) => const RecommendationsScreen(),
      ),
      GoRoute(
        path: AppRoutes.reports,
        builder: (context, state) => ReportsScreen(
          initialJobId: state.uri.queryParameters['jobId'],
          initialJobTitle: state.uri.queryParameters['jobTitle'],
        ),
      ),

      // ── Main Tabbed Shell ──────────────────────────────────────────────────
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) =>
            ScaffoldWithNav(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.home,
              builder: (context, state) => const HomeScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.search,
              builder: (context, state) => const SearchScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.saved,
              builder: (context, state) => const SavedScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.notifications,
              builder: (context, state) => const NotificationsScreen(),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: AppRoutes.profile,
              builder: (context, state) => const ProfileScreen(),
            ),
          ]),
        ],
      ),

      // ── Job Detail (Guests allowed) ────────────────────────────────────────
      GoRoute(
        path: AppRoutes.jobDetail,
        builder: (context, state) {
          final jobId = state.pathParameters['id'] ?? '';
          return JobDetailScreen(jobId: jobId);
        },
      ),

      // ── Admin (Role protected: ADMIN, SUPER_ADMIN) ─────────────────────────
      GoRoute(
        path: AppRoutes.admin,
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminCompanies,
        builder: (context, state) => const CompanyListScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminCompanyAdd,
        builder: (context, state) => const CompanyFormScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminCompanyEdit,
        builder: (context, state) {
          // If editing an existing company, extra or state can pass initialCompany
          return const CompanyFormScreen();
        },
      ),
      GoRoute(
        path: AppRoutes.adminCompanyDetail,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return CompanyDetailScreen(companyId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.adminCompanySources,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return CompanySourcesScreen(companyId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.adminJobs,
        builder: (context, state) {
          final status = state.uri.queryParameters['status'];
          return AllJobsScreen(initialStatus: status);
        },
      ),
      GoRoute(
        path: AppRoutes.adminJobDetail,
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return AdminJobDetailScreen(jobId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.adminReviewQueue,
        builder: (context, state) => const ReviewQueueScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminReports,
        builder: (context, state) => const AdminReportsScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminCollectionMonitor,
        builder: (context, state) => const CollectionMonitorScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminAdministrators,
        builder: (context, state) => const AdminManagementScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminAuditLogs,
        builder: (context, state) => const AuditLogsScreen(),
      ),
      GoRoute(
        path: AppRoutes.adminConfig,
        builder: (context, state) => const SystemConfigScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Route not found: ${state.error}')),
    ),
  );
});
