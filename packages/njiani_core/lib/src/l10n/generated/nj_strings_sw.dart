// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'nj_strings.dart';

// ignore_for_file: type=lint

/// The translations for Swahili (`sw`).
class NjStringsSw extends NjStrings {
  NjStringsSw([String locale = 'sw']) : super(locale);

  @override
  String get appName => 'Njiani';

  @override
  String get tagline => 'Usafiri unaoelekea njia yako.';

  @override
  String get languageHeadingSw => 'Chagua lugha';

  @override
  String get languageHeadingEn => 'Choose your language';

  @override
  String get languageChangeLater =>
      'Unaweza kubadilisha hii baadaye kwenye Mipangilio.';

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
    return 'Inayofuata: $component';
  }

  @override
  String get nextComponentBody =>
      'Skrini hii itakuja kwenye hatua inayofuata. Lugha uliyochagua imehifadhiwa.';

  @override
  String get changeLanguage => 'Badilisha lugha';

  @override
  String get openComponentGallery => 'Vipengele';
}
