// lib/features/onboarding/presentation/splash_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/demo/demo_provider.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_logo.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../data/repositories/auth_repository.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timeoutTimer;
  bool _showTimeoutError = false;
  bool _minDurationPassed = false;

  @override
  void initState() {
    super.initState();
    // Guarantee minimum 600ms brand display
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) {
        setState(() => _minDurationPassed = true);
      }
    });

    // If still on splash after 6 seconds, show Retry with offline message
    _timeoutTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) {
        setState(() => _showTimeoutError = true);
      }
    });
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleRetry() async {
    setState(() => _showTimeoutError = false);
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 6), () {
      if (mounted) {
        setState(() => _showTimeoutError = true);
      }
    });
    await ref.read(appBootstrapProvider.notifier).retry();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bootstrap = ref.watch(appBootstrapProvider);

    final isError = _showTimeoutError ||
        bootstrap.hasError ||
        (bootstrap.hasValue && bootstrap.value == false);

    return Scaffold(
      body: SafeArea(
        child: isError && _minDurationPassed
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ErrorStateWidget(
                        title: 'Offline / Connection Issue',
                        message:
                            'Unable to connect to TrueMNC servers. Please verify your internet connection and try again.',
                        retryLabel: 'Retry Connection',
                        onRetry: _handleRetry,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        label: '⚡ Open Offline Demo Mode',
                        onPressed: () {
                          ref.read(isDemoModeProvider.notifier).state = true;
                          context.go(AppRoutes.home);
                        },
                      ),
                    ],
                  ),
                ),
              )
            : Stack(
                children: [
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppLogo(
                          size: 96,
                          borderRadius: 24,
                          elevation: 3,
                          semanticLabel: 'TrueMNC logo',
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'TrueMNC',
                          style: theme.textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'True Corporate Job Finder',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        const SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: AppSpacing.xl,
                    left: 0,
                    right: 0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          onPressed: () {
                            ref.read(isDemoModeProvider.notifier).state = true;
                            context.go(AppRoutes.home);
                          },
                          icon: const Icon(Icons.bolt, size: 16, color: Colors.amber),
                          label: const Text('⚡ Explore Demo Mode'),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          'v1.0.0 (Build 1)',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colorScheme.outline,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
