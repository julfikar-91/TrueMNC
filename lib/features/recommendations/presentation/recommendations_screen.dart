// lib/features/recommendations/presentation/recommendations_screen.dart
// TODO: AI-powered job recommendations (server-side scoring via Cloud Function)
import 'package:flutter/material.dart';

class RecommendationsScreen extends StatelessWidget {
  const RecommendationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('For You')),
      body: const Center(child: Text('Recommendations – Coming Soon')),
    );
  }
}
