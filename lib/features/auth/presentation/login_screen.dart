// lib/features/auth/presentation/login_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../data/models/auth_result.dart';
import '../../../data/repositories/auth_repository.dart';
import '../providers/auth_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isGoogleLoading = false;
  int _failedAttempts = 0;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  static const int kMaxFailedAttempts = 5;
  static const int kCooldownDurationSeconds = 30;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() {
      _cooldownSeconds = kCooldownDurationSeconds;
    });
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_cooldownSeconds > 1) {
          _cooldownSeconds--;
        } else {
          _cooldownSeconds = 0;
          _failedAttempts = 0;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _submitEmailSignIn() async {
    if (_cooldownSeconds > 0) return;

    if (_formKey.currentState?.validate() ?? false) {
      try {
        await ref.read(authNotifierProvider.notifier).signInWithEmail(
              email: _emailController.text.trim(),
              password: _passwordController.text,
            );

        final authError = ref.read(authNotifierProvider).errorMessage;
        if (authError != null && mounted) {
          _failedAttempts++;
          if (_failedAttempts >= kMaxFailedAttempts) {
            _startCooldown();
            context.showSnackBar(
              'Too many failed attempts. Please wait $kCooldownDurationSeconds seconds before retrying.',
              isError: true,
            );
          } else {
            // ANTI-ENUMERATION: Always generic error message for credentials
            context.showSnackBar(
              'Invalid email or password. Please check your credentials and try again.',
              isError: true,
            );
          }
        } else {
          // Success: reset attempts and force refresh ID token to get latest claims
          _failedAttempts = 0;
          await ref.read(authRepositoryProvider).refreshIdToken(force: true);
        }
      } catch (e) {
        if (mounted) {
          _failedAttempts++;
          if (_failedAttempts >= kMaxFailedAttempts) {
            _startCooldown();
            context.showSnackBar(
              'Too many failed attempts. Please wait $kCooldownDurationSeconds seconds before retrying.',
              isError: true,
            );
          } else {
            context.showSnackBar(
              'Invalid email or password. Please check your credentials and try again.',
              isError: true,
            );
          }
        }
      }
    }
  }

  Future<void> _submitGoogleSignIn() async {
    if (_cooldownSeconds > 0) return;

    setState(() => _isGoogleLoading = true);
    try {
      final result =
          await ref.read(authNotifierProvider.notifier).signInWithGoogle();

      if (!mounted) return;

      if (result is GoogleSignInNeedsLinking) {
        _emailController.text = result.email;
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Account Linking Required'),
            content: Text(result.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Understood'),
              ),
            ],
          ),
        );
      } else if (result is GoogleSignInSuccess) {
        _failedAttempts = 0;
        await ref.read(authRepositoryProvider).refreshIdToken(force: true);
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(
          'Google Sign-In failed. Please try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final authState = ref.watch(authNotifierProvider);
    final isCoolingDown = _cooldownSeconds > 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign In'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.sm),
                Icon(
                  Icons.business_center_rounded,
                  size: 64,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'TrueMNC',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                Text(
                  'True Corporate Job Finder',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),

                // Cooldown Warning Banner if active
                if (isCoolingDown) ...[
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: colorScheme.errorContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: colorScheme.error),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.timer_outlined, color: colorScheme.error),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Text(
                            'Too many failed attempts. Try again in $_cooldownSeconds seconds.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.error,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],

                // Corporate email input
                AppTextField(
                  label: 'Corporate Email',
                  controller: _emailController,
                  validator: Validators.email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.email_outlined),
                  enabled: !isCoolingDown,
                ),
                const SizedBox(height: AppSpacing.md),

                // Password input with show/hide toggle
                AppTextField(
                  label: 'Password',
                  controller: _passwordController,
                  obscureText: true,
                  validator: Validators.password,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submitEmailSignIn(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  enabled: !isCoolingDown,
                ),

                // Forgot password link
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => context.push(AppRoutes.forgot),
                    child: const Text('Forgot Password?'),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Email sign-in button
                AppButton(
                  label: isCoolingDown
                      ? 'Cooldown ($_cooldownSeconds s)'
                      : 'Sign In',
                  isLoading: authState.isLoading,
                  onPressed: isCoolingDown ? null : _submitEmailSignIn,
                ),
                const SizedBox(height: AppSpacing.md),

                // Divider
                Row(
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        'OR',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.outline,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Google sign-in button
                AppButton.secondary(
                  label: 'Continue with Google',
                  isLoading: _isGoogleLoading,
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  onPressed: isCoolingDown ? null : _submitGoogleSignIn,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Sign up prompt
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account?"),
                    TextButton(
                      onPressed: () => context.push(AppRoutes.register),
                      child: const Text('Create Account'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
