// lib/features/auth/presentation/register_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/extensions.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/password_strength_meter.dart';
import '../../../data/models/auth_result.dart';
import '../providers/auth_providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _password = '';
  bool _agreedToTerms = false;
  bool _termsError = false;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submitRegistration() async {
    setState(() {
      _termsError = !_agreedToTerms;
    });

    final isFormValid = _formKey.currentState?.validate() ?? false;
    if (!isFormValid || !_agreedToTerms) {
      if (!_agreedToTerms) {
        context.showSnackBar(
          'Please accept the Terms of Service & Privacy Policy to continue.',
          isError: true,
        );
      }
      return;
    }

    await ref.read(authNotifierProvider.notifier).signUpWithEmail(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );

    final error = ref.read(authNotifierProvider).errorMessage;
    if (error != null && mounted) {
      context.showSnackBar(error, isError: true);
    } else if (mounted) {
      // Router will redirect to /verify-email based on row 3 of redirect table
      context.go(AppRoutes.verifyEmail);
    }
  }

  Future<void> _submitGoogleSignUp() async {
    setState(() => _isGoogleLoading = true);
    try {
      final result =
          await ref.read(authNotifierProvider.notifier).signInWithGoogle();

      if (!mounted) return;

      if (result is GoogleSignInNeedsLinking) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Account Already Exists'),
            content: Text(result.message),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  context.go(AppRoutes.login);
                },
                child: const Text('Go to Sign In'),
              ),
            ],
          ),
        );
      } else if (result is GoogleSignInSuccess) {
        // Google users are pre-verified -> skip email verification to resume onboarding
        context.go(AppRoutes.resumeOnboarding);
      }
    } catch (e) {
      if (mounted) {
        context.showSnackBar(
          'Google registration failed. Please try again.',
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
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
                Text(
                  'Join TrueMNC',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Direct access to official enterprise & corporate openings.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Full Name
                AppTextField(
                  label: 'Full Name',
                  controller: _nameController,
                  validator: Validators.name,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.person_outline),
                ),
                const SizedBox(height: AppSpacing.md),

                // Corporate Email
                AppTextField(
                  label: 'Corporate / Primary Email',
                  controller: _emailController,
                  validator: Validators.email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                const SizedBox(height: AppSpacing.md),

                // Password
                AppTextField(
                  label: 'Password',
                  controller: _passwordController,
                  obscureText: true,
                  validator: Validators.password,
                  onChanged: (val) => setState(() => _password = val),
                  textInputAction: TextInputAction.next,
                  prefixIcon: const Icon(Icons.lock_outline),
                ),
                PasswordStrengthMeter(password: _password),
                const SizedBox(height: AppSpacing.md),

                // Confirm Password
                AppTextField(
                  label: 'Confirm Password',
                  controller: _confirmPasswordController,
                  obscureText: true,
                  validator: (val) => Validators.confirmPassword(val, _password),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _submitRegistration(),
                  prefixIcon: const Icon(Icons.lock_reset_outlined),
                ),
                const SizedBox(height: AppSpacing.md),

                // Terms + Privacy Checkbox
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: AppSpacing.minTouchTarget,
                      height: AppSpacing.minTouchTarget,
                      child: Checkbox(
                        value: _agreedToTerms,
                        onChanged: (val) {
                          setState(() {
                            _agreedToTerms = val ?? false;
                            if (_agreedToTerms) _termsError = false;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _agreedToTerms = !_agreedToTerms;
                            if (_agreedToTerms) _termsError = false;
                          });
                        },
                        child: Text(
                          'I agree to the Terms of Service and Privacy Policy.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: _termsError ? colorScheme.error : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_termsError)
                  Padding(
                    padding: const EdgeInsets.only(left: 12, bottom: 8),
                    child: Text(
                      'You must accept the terms and privacy policy.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.error,
                      ),
                    ),
                  ),

                const SizedBox(height: AppSpacing.lg),

                // Submit button
                AppButton(
                  label: 'Create Account',
                  isLoading: authState.isLoading,
                  onPressed: _submitRegistration,
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

                // Google Sign Up
                AppButton.secondary(
                  label: 'Continue with Google',
                  isLoading: _isGoogleLoading,
                  icon: const Icon(Icons.g_mobiledata, size: 28),
                  onPressed: _submitGoogleSignUp,
                ),
                const SizedBox(height: AppSpacing.lg),

                // Link to Login
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Already have an account?'),
                    TextButton(
                      onPressed: () => context.go(AppRoutes.login),
                      child: const Text('Sign In'),
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
