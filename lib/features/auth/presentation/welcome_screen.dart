// lib/features/auth/presentation/welcome_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/demo/demo_nav_sheet.dart';
import '../../../core/demo/demo_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../data/models/enums.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),

              // Hero Brand Emblem
              const Center(
                child: AppLogo(
                  size: 104,
                  borderRadius: 24,
                  elevation: 4,
                  semanticLabel: 'TrueMNC Brand Logo',
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // Headline
              Text(
                'Find Genuine Corporate Jobs',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),

              // Short description
              Text(
                'Direct openings from verified multinational corporations. No fake listings, zero third-party consultancies, strictly official company career links.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(flex: 3),

              // Primary CTA: Get Started -> Onboarding
              AppButton(
                label: 'Get Started',
                onPressed: () => context.push(AppRoutes.onboarding),
              ),
              const SizedBox(height: AppSpacing.md),

              // Secondary: Sign In
              AppButton.secondary(
                label: 'Sign In',
                onPressed: () => context.push(AppRoutes.login),
              ),
              const SizedBox(height: AppSpacing.md),

              // Quick Offline Demo & Screen Explorer Button
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  side: BorderSide(color: colorScheme.primary),
                ),
                icon: const Icon(Icons.bolt, color: Colors.amber),
                label: const Text(
                  '⚡ Explore Offline Demo (All Screens)',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () => showDemoNavSheet(context),
              ),
              const SizedBox(height: AppSpacing.sm),

              // Guest Browse Link
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    ref.read(isDemoModeProvider.notifier).state = true;
                    ref.read(demoRoleProvider.notifier).state = UserRole.user;
                    context.go(AppRoutes.home);
                  },
                  icon: const Icon(Icons.public_rounded, size: 18),
                  label: const Text('Browse as guest'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ),
        ),
      ),
    );
  }
}
