// lib/core/widgets/init_retry_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/auth_repository.dart';
import 'error_state_widget.dart';

class InitRetryScreen extends ConsumerWidget {
  const InitRetryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: ErrorStateWidget(
          title: 'Unable to Connect',
          message:
              'Could not connect to TrueMNC servers. Please check your internet connection and try again.',
          retryLabel: 'Retry Connection',
          onRetry: () => ref.read(appBootstrapProvider.notifier).retry(),
        ),
      ),
    );
  }
}
