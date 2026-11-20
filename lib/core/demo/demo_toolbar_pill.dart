// lib/core/demo/demo_toolbar_pill.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/enums.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'demo_nav_sheet.dart';
import 'demo_provider.dart';

/// Floating pill overlay that displays in Demo Mode to allow switching screens anytime.
class DemoToolbarPill extends ConsumerWidget {
  const DemoToolbarPill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDemo = ref.watch(isDemoModeProvider);
    if (!isDemo) return const SizedBox.shrink();

    final role = ref.watch(demoRoleProvider);
    final isSuperAdmin = role == UserRole.superAdmin;

    return SafeArea(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 70), // sit just above bottom navigation bar
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(AppRadius.full),
            color: isSuperAdmin ? Colors.purple.shade900 : const Color(0xFF1E293B),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.full),
              onTap: () => showDemoNavSheet(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.bolt, color: Colors.amber, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'DEMO: ${isSuperAdmin ? "SUPER ADMIN" : "CANDIDATE"}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: const Text(
                        'Change Screen ▾',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
