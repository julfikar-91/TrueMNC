// lib/features/saved/presentation/saved_screen.dart
import 'package:flutter/material.dart';

import '../../../core/widgets/empty_state_widget.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Jobs')),
      body: const Center(
        child: EmptyStateWidget(
          icon: Icons.bookmark_outline,
          title: 'Saved Jobs – Coming Soon',
          subtitle:
              'Bookmark verified openings and track your application milestones right here.',
        ),
      ),
    );
  }
}
