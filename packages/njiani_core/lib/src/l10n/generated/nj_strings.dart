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

  /// pPhone heading. Design spec C4.
  ///
  /// In en, this message translates to:
  /// **'Enter your phone number'**
  String get phoneTitle;

  /// pPhone subheading.
  ///
  /// In en, this message translates to:
  /// **'We\'ll send you a code by SMS.'**
  String get phoneSubtitle;

  /// Label above the phone field.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneLabel;

  /// Placeholder. A sample national number, identical in both languages.
  ///
  /// In en, this message translates to:
  /// **'712 345 678'**
  String get phoneHint;

  /// Shown under the field when the number is not nine digits. Names the leading zero because writing it is the most common local habit.
  ///
  /// In en, this message translates to:
  /// **'Enter 9 digits, without the leading zero.'**
  String get phoneError;

  /// The only action on pPhone.
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get sendCode;

  /// Button label while the send is in flight.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get sendingCode;

  /// Footnote under the send button. Says the SMS is not free, because it is not.
  ///
  /// In en, this message translates to:
  /// **'By continuing you agree to the terms. Standard SMS rates apply.'**
  String get phoneTerms;

  /// pOtp heading. The digit count comes from kOtpLength, not from the copy.
  ///
  /// In en, this message translates to:
  /// **'Enter the {digits}-digit code'**
  String otpTitle(int digits);

  /// Names the sender ID so the SMS is recognisable, and the number so a wrong one is obvious before waiting.
  ///
  /// In en, this message translates to:
  /// **'Sent to +255 {phone} by NJIANI'**
  String otpSentTo(String phone);

  /// Precedes the resend countdown.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t get it?'**
  String get otpDidntGet;

  /// Countdown until a resend is allowed.
  ///
  /// In en, this message translates to:
  /// **'Resend in {time}'**
  String otpResendIn(String time);

  /// Enabled once the countdown reaches zero.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get otpResend;

  /// Submits the code.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get otpVerify;

  /// Returns to pPhone keeping the typed number.
  ///
  /// In en, this message translates to:
  /// **'Wrong number? Change it'**
  String get otpWrongNumber;

  /// Generic back action.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// AuthFailure.wrongCode.
  ///
  /// In en, this message translates to:
  /// **'That code is not right. Try again.'**
  String get errWrongCode;

  /// AuthFailure.expiredCode.
  ///
  /// In en, this message translates to:
  /// **'That code expired. Ask for a new one.'**
  String get errExpiredCode;

  /// AuthFailure.rateLimited. Every send costs money, so the server caps it.
  ///
  /// In en, this message translates to:
  /// **'Too many codes. Try again in 15 minutes.'**
  String get errRateLimited;

  /// AuthFailure.offline.
  ///
  /// In en, this message translates to:
  /// **'No connection. Check your data and try again.'**
  String get errOffline;

  /// AuthFailure.notConfigured. Deliberately names the missing keys: a missing credential should look like a missing credential, not a broken server.
  ///
  /// In en, this message translates to:
  /// **'This build has no backend yet. Add SUPABASE_URL and SUPABASE_ANON_KEY to .env.local.'**
  String get errNotConfigured;

  /// AuthFailure.unknown. Does not invent a cause.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get errUnknown;

  /// Ends the session. On the placeholder while there is no Settings screen, so the sign-in flow can be re-walked without reinstalling.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;
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
