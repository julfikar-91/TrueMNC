// lib/features/search/presentation/search_screen.dart
// TODO: Implement search with filters (location, type, salary range)
import 'package:flutter/material.dart';

class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search Jobs')),
      body: const Center(child: Text('Search – Coming Soon')),
    );
  }
}
