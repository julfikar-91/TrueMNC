// lib/core/demo/demo_nav_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/enums.dart';
import '../router/app_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'demo_provider.dart';

void showDemoNavSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (ctx) => const DemoNavSheet(),
  );
}

class DemoNavSheet extends ConsumerWidget {
  const DemoNavSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentRole = ref.watch(demoRoleProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
          ),
          child: Column(
            children: [
              // Grab handle
              const SizedBox(height: AppSpacing.sm),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Title and active role bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.primarySeed.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(Icons.bolt, color: AppColors.primarySeed, size: 24),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Offline Demo Explorer',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Jump to any screen without Firebase or network',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Active Role Switcher Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceVariant.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.security, size: 20, color: AppColors.primarySeed),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Current Test Role',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            Text(
                              currentRole == UserRole.superAdmin
                                  ? 'SUPER ADMIN (Full Permissions)'
                                  : 'CANDIDATE (Job Seeker)',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: currentRole == UserRole.superAdmin ? Colors.purple : AppColors.primarySeed,
                              ),
                            ),
                          ],
                        ),
                      ),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                        ),
                        onPressed: () {
                          final next = currentRole == UserRole.superAdmin
                              ? UserRole.user
                              : UserRole.superAdmin;
                          ref.read(demoRoleProvider.notifier).state = next;
                        },
                        child: Text(
                          currentRole == UserRole.superAdmin ? 'Switch to Candidate' : 'Switch to Super Admin',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Divider(height: AppSpacing.lg),

              // Scrollable Screen List
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                  children: [
                    // Section 1: Super Admin screens
                    _buildSectionHeader(context, '👑 Super Admin Features (Section 15-17)', Colors.purple),
                    _buildScreenTile(
                      context: context,
                      title: 'A15 Administrator Management',
                      subtitle: 'Add/Revoke Admin, Protect last Super Admin, User role picker',
                      icon: Icons.manage_accounts,
                      route: AppRoutes.adminAdministrators,
                      onTap: () {
                        ref.read(isDemoModeProvider.notifier).state = true;
                        ref.read(demoRoleProvider.notifier).state = UserRole.superAdmin;
                        Navigator.pop(context);
                        context.go(AppRoutes.adminAdministrators);
                      },
                    ),
                    _buildScreenTile(
                      context: context,
                      title: 'A16 Audit Logs & CSV Export',
                      subtitle: 'Filters by action/actor, before/after diffs, export CSV',
                      icon: Icons.history,
                      route: AppRoutes.adminAuditLogs,
                      onTap: () {
                        ref.read(isDemoModeProvider.notifier).state = true;
                        ref.read(demoRoleProvider.notifier).state = UserRole.superAdmin;
                        Navigator.pop(context);
                        context.go(AppRoutes.adminAuditLogs);
                      },
                    ),
                    _buildScreenTile(
                      context: context,
                      title: 'A17 System Configuration & Weights',
                      subtitle: '100% total weight validation, AI models, version history',
                      icon: Icons.tune,
                      route: AppRoutes.adminConfig,
                      onTap: () {
                        ref.read(isDemoModeProvider.notifier).state = true;
                        ref.read(demoRoleProvider.notifier).state = UserRole.superAdmin;
                        Navigator.pop(context);
                        context.go(AppRoutes.adminConfig);
                      },
                    ),
                    _buildScreenTile(
                      context: context,
                      title: 'A05 Admin Dashboard Overview',
                      subtitle: 'Platform metrics, health status and admin action hubs',
                      icon: Icons.dashboard,
                      route: AppRoutes.admin,
                      onTap: () {
                        ref.read(isDemoModeProvider.notifier).state = true;
                        ref.read(demoRoleProvider.notifier).state = UserRole.superAdmin;
                        Navigator.pop(context);
                        context.go(AppRoutes.admin);
                      },
                    ),
                    _buildScreenTile(
                      context: context,
                      title: 'A06 Company Sources & Verification',
                      subtitle: 'Greenhouse/Lever board tokens, 3-step verification wizard',
                      icon: Icons.hub,
                      route: '/admin/companies/comp_google/sources',
                      onTap: () {
                        ref.read(isDemoModeProvider.notifier).state = true;
                        ref.read(demoRoleProvider.notifier).state = UserRole.superAdmin;
                        Navigator.pop(context);
                        context.push('/admin/companies/comp_google/sources');
                      },
                    ),
                    _buildScreenTile(
                      context: context,
                      title: 'A08 Job Details & R1-R8 Validation Diff',
                      subtitle: 'Source data vs AI extracted diff view, pass/fail rules',
                      icon: Icons.fact_check,
                      route: '/admin/jobs/admin_job_001',
                      onTap: () {
                        ref.read(isDemoModeProvider.notifier).state = true;
                        ref.read(demoRoleProvider.notifier).state = UserRole.superAdmin;
                        Navigator.pop(context);
                        context.push('/admin/jobs/admin_job_001');
                      },
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Section 2: Resume Pipeline
                    _buildSectionHeader(context, '📄 AI Resume Pipeline (Section 8-12)', Colors.blue),
                    _buildScreenTile(
                      context: context,
                      title: 'S08 Resume Onboarding',
                      subtitle: 'Upload Resume / Manual Profile / Skip options',
                      icon: Icons.description,
                      route: AppRoutes.resumeOnboarding,
                      onTap: () {
                        ref.read(isDemoModeProvider.notifier).state = true;
                        Navigator.pop(context);
                        context.go(AppRoutes.resumeOnboarding);
                      },
                    ),
                    _buildScreenTile(
                      context: context,
                      title: 'S09 Resume Upload Screen',
                      subtitle: 'File picker, client-side checks (< 5 MB, PDF/DOCX), upload bar',
                      icon: Icons.upload_file,
                      route: AppRoutes.resumeUpload,
                      onTap: () {
                        ref.read(isDemoModeProvider.notifier).state = true;
                        Navigator.pop(context);
                        context.push(AppRoutes.resumeUpload);
                      },
                    ),
                    _buildScreenTile(
                      context: context,
                      title: 'S10 7-Stage AI Processing Simulator',
                      subtitle: 'Real-time progress stages: reading, skills, education, experience',
                      icon: Icons.auto_awesome,
                      route: '/resume-processing?id=demo_resume_01',
                      onTap: () {
                        ref.read(isDemoModeProvider.notifier).state = true;
                        Navigator.pop(context);
                        context.push('/resume-processing?id=demo_resume_01');
                      },
                    ),
                    _buildScreenTile(
                      context: context,
                      title: 'S11 AI Profile Preview & Confirmation',
                      subtitle: 'Extracted / Inferred / Missing badges, section edit, confirm profile',
                      icon: Icons.preview,
                      route: '/profile-preview?id=demo_resume_01',
                      onTap: () {
                        ref.read(isDemoModeProvider.notifier).state = true;
                        Navigator.pop(context);
                        context.push('/profile-preview?id=demo_resume_01');
                      },
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Section 3: Candidate Experience
                    _buildSectionHeader(context, '💼 Candidate & Job Search Experience', Colors.green),
                    _buildScreenTile(
                      context: context,
                      title: 'Home Screen (Verified Jobs Feed)',
                      subtitle: 'Official MNC jobs (Google, Microsoft, Amazon, Netflix, TCS)',
                      icon: Icons.home,
                      route: AppRoutes.home,
                      onTap: () {
                        ref.read(isDemoModeProvider.notifier).state = true;
                        ref.read(demoRoleProvider.notifier).state = UserRole.user;
                        Navigator.pop(context);
                        context.go(AppRoutes.home);
                      },
                    ),
                    _buildScreenTile(
                      context: context,
                      title: 'Verified Job Details Screen',
                      subtitle: 'Description, official apply link, match score, salary, verified badge',
                      icon: Icons.work,
                      route: '/job/job_google_01',
                      onTap: () {
                        ref.read(isDemoModeProvider.notifier).state = true;
                        Navigator.pop(context);
                        context.push('/job/job_google_01');
                      },
                    ),
                    _buildScreenTile(
                      context: context,
                      title: 'Search Screen',
                      subtitle: 'Keyword search and filters for verified MNC roles',
                      icon: Icons.search,
                      route: AppRoutes.search,
                      onTap: () {
                        ref.read(isDemoModeProvider.notifier).state = true;
                        Navigator.pop(context);
                        context.go(AppRoutes.search);
                      },
                    ),
                    _buildScreenTile(
                      context: context,
                      title: 'Candidate Profile & Settings',
                      subtitle: 'View user profile, work experience and app settings',
                      icon: Icons.person,
                      route: AppRoutes.profile,
                      onTap: () {
                        ref.read(isDemoModeProvider.notifier).state = true;
                        Navigator.pop(context);
                        context.go(AppRoutes.profile);
                      },
                    ),

                    const SizedBox(height: AppSpacing.md),

                    // Section 4: Auth & Onboarding Flow
                    _buildSectionHeader(context, '🔐 Auth & Welcome Screens', Colors.orange),
                    _buildScreenTile(
                      context: context,
                      title: 'Welcome Screen',
                      subtitle: 'Brand logo emblem, value propositions and entry points',
                      icon: Icons.waving_hand,
                      route: AppRoutes.welcome,
                      onTap: () {
                        ref.read(isDemoModeProvider.notifier).state = false;
                        Navigator.pop(context);
                        context.go(AppRoutes.welcome);
                      },
                    ),
                    _buildScreenTile(
                      context: context,
                      title: 'Login Screen',
                      subtitle: 'Official sign-in form with brand logo',
                      icon: Icons.login,
                      route: AppRoutes.login,
                      onTap: () {
                        ref.read(isDemoModeProvider.notifier).state = false;
                        Navigator.pop(context);
                        context.push(AppRoutes.login);
                      },
                    ),
                    _buildScreenTile(
                      context: context,
                      title: 'Register Screen',
                      subtitle: 'Account creation with brand header',
                      icon: Icons.person_add,
                      route: AppRoutes.register,
                      onTap: () {
                        ref.read(isDemoModeProvider.notifier).state = false;
                        Navigator.pop(context);
                        context.push(AppRoutes.register);
                      },
                    ),

                    const SizedBox(height: AppSpacing.xl),

                    // Reset / Exit Button
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: colorScheme.error,
                        side: BorderSide(color: colorScheme.error.withOpacity(0.5)),
                        padding: const EdgeInsets.all(AppSpacing.md),
                      ),
                      icon: const Icon(Icons.exit_to_app),
                      label: const Text('Exit Demo Mode'),
                      onPressed: () {
                        ref.read(isDemoModeProvider.notifier).state = false;
                        Navigator.pop(context);
                        context.go(AppRoutes.welcome);
                      },
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 16,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScreenTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required String route,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Material(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.md),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Row(
              children: [
                Icon(icon, size: 22, color: AppColors.primarySeed),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, size: 18, color: colorScheme.outline),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
