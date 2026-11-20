// lib/features/notifications/presentation/notifications_screen.dart
import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state_widget.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: const Center(
        child: EmptyStateWidget(
          icon: Icons.notifications_none_rounded,
          title: 'Notifications – Coming Soon',
          subtitle:
              'Stay updated with new job matches, application status updates, and verified corporate alerts.',
        ),
      ),
    );
  }
}
