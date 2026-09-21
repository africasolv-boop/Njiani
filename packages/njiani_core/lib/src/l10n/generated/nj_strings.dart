import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'nj_strings_en.dart';
import 'nj_strings_sw.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of NjStrings
/// returned by `NjStrings.of(context)`.
///
/// Applications need to include `NjStrings.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/nj_strings.dart';
///
/// return MaterialApp(
///   localizationsDelegates: NjStrings.localizationsDelegates,
///   supportedLocales: NjStrings.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the NjStrings.supportedLocales
/// property.
abstract class NjStrings {
  NjStrings(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static NjStrings of(BuildContext context) {
    return Localizations.of<NjStrings>(context, NjStrings)!;
  }

  static const LocalizationsDelegate<NjStrings> delegate = _NjStringsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('sw'),
  ];

  /// The product name. Never translated.
  ///
  /// In en, this message translates to:
  /// **'Njiani'**
  String get appName;

  /// One-line description under the wordmark.
  ///
  /// In en, this message translates to:
  /// **'Rides going your way.'**
  String get tagline;

  /// First line of the language screen heading. Deliberately identical in both .arb files: on this screen the user cannot yet reliably read either language, so the heading shows both regardless of locale.
  ///
  /// In en, this message translates to:
  /// **'Chagua lugha'**
  String get languageHeadingSw;

  /// Second line of the bilingual language heading. Identical in both .arb files, for the reason given on languageHeadingSw.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get languageHeadingEn;

  /// Reassurance under the language heading. This one IS localised, and switches live as the user taps an option, so the choice is visibly demonstrated before it is confirmed.
  ///
  /// In en, this message translates to:
  /// **'You can change this later in Settings.'**
  String get languageChangeLater;

  /// Endonym. Always written in its own language, so identical in both .arb files.
  ///
  /// In en, this message translates to:
  /// **'Kiswahili'**
  String get languageSwahili;

  /// Trailing note on the Kiswahili option, meaning 'first choice'. In Kiswahili in both files, as it labels the Kiswahili option.
  ///
  /// In en, this message translates to:
  /// **'Chaguo la kwanza'**
  String get languageSwahiliHint;

  /// Endonym. Identical in both .arb files.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Trailing note on the English option. In English in both files, as it labels the English option.
  ///
  /// In en, this message translates to:
  /// **'Second language'**
  String get languageEnglishHint;

  /// The only action on the language screen. Bilingual in both files: the user has not yet confirmed a language, so the button must be readable either way.
  ///
  /// In en, this message translates to:
  /// **'Endelea · Continue'**
  String get languageContinue;

  /// Placeholder heading for a screen not yet built.
  ///
  /// In en, this message translates to:
  /// **'Next: {component}'**
  String nextComponentTitle(String component);

  /// Placeholder body for a screen not yet built.
  ///
  /// In en, this message translates to:
  /// **'This screen arrives in the next component. Your language choice has been saved.'**
  String get nextComponentBody;

  /// Returns to the language screen. Used from the placeholder while there is no Settings screen yet.
  ///
  /// In en, this message translates to:
  /// **'Change language'**
  String get changeLanguage;

  /// Opens the development-only component gallery.
  ///
  /// In en, this message translates to:
  /// **'Component gallery'**
  String get openComponentGallery;
}

class _NjStringsDelegate extends LocalizationsDelegate<NjStrings> {
  const _NjStringsDelegate();

  @override
  Future<NjStrings> load(Locale locale) {
    return SynchronousFuture<NjStrings>(lookupNjStrings(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'sw'].contains(locale.languageCode);

  @override
  bool shouldReload(_NjStringsDelegate old) => false;
}

NjStrings lookupNjStrings(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return NjStringsEn();
    case 'sw':
      return NjStringsSw();
  }

  throw FlutterError(
    'NjStrings.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
