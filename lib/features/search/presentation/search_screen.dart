// lib/features/search/presentation/search_screen.dart
import 'package:flutter/material.dart';

import 'ai_search_tab.dart';
import 'keyword_search_tab.dart';

/// Explore & Search Screen with tabs for Keyword Search (S17) and AI Search (S25).
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Explore Jobs'),
          bottom: const TabBar(
            tabs: [
              Tab(
                key: Key('keyword_search_tab_header'),
                text: 'Keyword Search (S17)',
              ),
              Tab(
                key: Key('ai_search_tab_header'),
                text: 'AI Search (S25)',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            KeywordSearchTab(),
            AiSearchTab(),
          ],
        ),
      ),
    );
  }
}
