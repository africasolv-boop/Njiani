// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'nj_strings.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class NjStringsEn extends NjStrings {
  NjStringsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Njiani';

  @override
  String get tagline => 'Rides going your way.';

  @override
  String get languageHeadingSw => 'Chagua lugha';

  @override
  String get languageHeadingEn => 'Choose your language';

  @override
  String get languageChangeLater => 'You can change this later in Settings.';

  @override
  String get languageSwahili => 'Kiswahili';

  @override
  String get languageSwahiliHint => 'Chaguo la kwanza';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageEnglishHint => 'Second language';

  @override
  String get languageContinue => 'Endelea · Continue';

  @override
  String nextComponentTitle(String component) {
    return 'Next: $component';
  }

  @override
  String get nextComponentBody =>
      'This screen arrives in the next component. Your language choice has been saved.';

  @override
  String get changeLanguage => 'Change language';

  @override
  String get openComponentGallery => 'Component gallery';
}
