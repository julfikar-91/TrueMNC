// lib/features/auth/presentation/verify_email_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/widgets/app_button.dart';
import '../../../data/repositories/auth_repository.dart';
import '../providers/auth_providers.dart';

class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  Timer? _pollingTimer;
  Timer? _resendCooldownTimer;
  int _resendCooldown = 0;
  bool _isReloading = false;
  bool _isResending = false;

  static const int kResendCooldownDuration = 60;

  @override
  void initState() {
    super.initState();
    // Auto-poll every 5 seconds while screen is open
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      await _checkVerificationStatus(silent: true);
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _resendCooldownTimer?.cancel();
    super.dispose();
  }

  void _startResendCooldown() {
    setState(() => _resendCooldown = kResendCooldownDuration);
    _resendCooldownTimer?.cancel();
    _resendCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_resendCooldown > 1) {
          _resendCooldown--;
        } else {
          _resendCooldown = 0;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _checkVerificationStatus({bool silent = false}) async {
    if (!silent) setState(() => _isReloading = true);
    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.reloadUser();
      final user = authRepo.currentUser;

      if (user != null && user.emailVerified) {
        if (mounted) {
          context.showSnackBar('Email successfully verified!');
          // Router table will automatically navigate to /onboarding or /resume-onboarding
          context.go(AppRoutes.resumeOnboarding);
        }
      } else if (!silent && mounted) {
        context.showSnackBar(
          'Email is not yet verified. Please click the link sent to your inbox.',
          isError: true,
        );
      }
    } catch (_) {
      if (!silent && mounted) {
        context.showSnackBar('Failed to refresh status. Please try again.', isError: true);
      }
    } finally {
      if (!silent && mounted) setState(() => _isReloading = false);
    }
  }

  Future<void> _handleResendEmail() async {
    if (_resendCooldown > 0) return;

    setState(() => _isResending = true);
    try {
      await ref.read(authRepositoryProvider).sendVerificationEmail();
      _startResendCooldown();
      if (mounted) {
        context.showSnackBar(
          'Verification email resent. Please check your inbox and spam folder.',
        );
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(
          'Could not resend email. Please try again shortly.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _handleChangeEmail() async {
    // Sign out to allow entering a different email during registration
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Email Address?'),
        content: const Text(
          'This will sign you out so you can register with the correct corporate email address.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sign Out & Re-register'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(authNotifierProvider.notifier).signOut();
      if (mounted) {
        context.go(AppRoutes.register);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = ref.watch(authStateProvider).valueOrNull;
    final isCoolingDown = _resendCooldown > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Email'),
        actions: [
          IconButton(
            tooltip: 'Sign Out',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authNotifierProvider.notifier).signOut(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            children: [
              const SizedBox(height: AppSpacing.lg),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withOpacity(0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mark_email_unread_rounded,
                  size: 52,
                  color: colorScheme.primary,
                  semanticLabel: 'Verification email sent',
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'Verify Your Corporate Email',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'We sent an activation link to:',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  user?.email ?? 'your email',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Click the verification link in your inbox. This page automatically detects when you have verified (auto-refreshing every 5 seconds).',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Button 1: "I have verified"
              AppButton(
                label: 'I Have Verified',
                isLoading: _isReloading,
                onPressed: () => _checkVerificationStatus(silent: false),
              ),
              const SizedBox(height: AppSpacing.md),

              // Button 2: Resend with 60s cooldown
              AppButton.secondary(
                label: isCoolingDown
                    ? 'Resend Email (${_resendCooldown}s)'
                    : 'Resend Verification Email',
                isLoading: _isResending,
                onPressed: isCoolingDown ? null : _handleResendEmail,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Change email action
              TextButton.icon(
                onPressed: _handleChangeEmail,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Incorrect email address? Change email'),
              ),
              const SizedBox(height: AppSpacing.xs),

              // Sign out action
              TextButton.icon(
                onPressed: () =>
                    ref.read(authNotifierProvider.notifier).signOut(),
                icon: const Icon(Icons.exit_to_app, size: 18),
                label: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
