// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'TrueMNC';

  @override
  String get loginTitle => 'Sign in to TrueMNC';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get homeTitle => 'Jobs for You';

  @override
  String get searchHint => 'Search jobs, companies…';

  @override
  String get savedJobs => 'Saved Jobs';

  @override
  String get notifications => 'Notifications';

  @override
  String get profile => 'Profile';

  @override
  String get settings => 'Settings';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get emptyJobs => 'No verified jobs found';

  @override
  String get loading => 'Loading…';
}
