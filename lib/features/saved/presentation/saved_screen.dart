// lib/features/saved/presentation/saved_screen.dart
// TODO: Implement saved/bookmarked jobs list
import 'package:flutter/material.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Saved Jobs')),
      body: const Center(child: Text('Saved Jobs – Coming Soon')),
    );
  }
}
