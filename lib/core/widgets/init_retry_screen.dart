// lib/core/widgets/init_retry_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../demo/demo_provider.dart';
import '../router/app_router.dart';
import '../theme/app_spacing.dart';
import 'app_button.dart';
import 'error_state_widget.dart';
import '../../data/repositories/auth_repository.dart';

class InitRetryScreen extends ConsumerWidget {
  const InitRetryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ErrorStateWidget(
                  title: 'Unable to Connect',
                  message:
                      'Could not connect to TrueMNC servers. Please check your internet connection or explore the app in offline mode.',
                  retryLabel: 'Retry Connection',
                  onRetry: () => ref.read(appBootstrapProvider.notifier).retry(),
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
        ),
      ),
    );
  }
}
