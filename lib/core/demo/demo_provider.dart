// lib/core/demo/demo_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/enums.dart';
import '../../data/models/user_doc.dart';
import 'demo_data.dart';

/// Whether the app is currently running in offline demo / test mode.
final isDemoModeProvider = StateProvider<bool>((ref) => false);

/// Selected active role during demo mode (defaults to SUPER_ADMIN so user can test all screens).
final demoRoleProvider = StateProvider<UserRole>((ref) => UserRole.superAdmin);

/// Custom demo user document state.
final demoUserDocProvider = StateProvider<UserDoc>((ref) {
  return DemoData.sampleUserDoc;
});
