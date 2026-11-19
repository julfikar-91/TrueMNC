// lib/features/notifications/presentation/notifications_screen.dart
// TODO: Implement FCM notification inbox
import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: const Center(child: Text('Notifications – Coming Soon')),
    );
  }
}
