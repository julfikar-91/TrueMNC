// lib/features/settings/presentation/preferences_screen.dart
import 'package:flutter/material.dart';

class PreferencesScreen extends StatelessWidget {
  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Job Preferences')),
      body: const Center(
        child: Text('Select your desired locations, roles, and salary expectations.'),
      ),
    );
  }
}
