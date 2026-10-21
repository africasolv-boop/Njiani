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

  @override
  String get phoneTitle => 'Enter your phone number';

  @override
  String get phoneSubtitle => 'We\'ll send you a code by SMS.';

  @override
  String get phoneLabel => 'Phone number';

  @override
  String get phoneHint => '712 345 678';

  @override
  String get phoneError => 'Enter 9 digits, without the leading zero.';

  @override
  String get sendCode => 'Send code';

  @override
  String get sendingCode => 'Sending…';

  @override
  String get phoneTerms =>
      'By continuing you agree to the terms. Standard SMS rates apply.';

  @override
  String otpTitle(int digits) {
    return 'Enter the $digits-digit code';
  }

  @override
  String otpSentTo(String phone) {
    return 'Sent to +255 $phone by NJIANI';
  }

  @override
  String get otpDidntGet => 'Didn\'t get it?';

  @override
  String otpResendIn(String time) {
    return 'Resend in $time';
  }

  @override
  String get otpResend => 'Resend code';

  @override
  String get otpVerify => 'Verify';

  @override
  String get otpWrongNumber => 'Wrong number? Change it';

  @override
  String get back => 'Back';

  @override
  String get errWrongCode => 'That code is not right. Try again.';

  @override
  String get errExpiredCode => 'That code expired. Ask for a new one.';

  @override
  String get errRateLimited => 'Too many codes. Try again in 15 minutes.';

  @override
  String get errOffline => 'No connection. Check your data and try again.';

  @override
  String get errNotConfigured =>
      'This build has no backend yet. Add SUPABASE_URL and SUPABASE_ANON_KEY to .env.local.';

  @override
  String get errUnknown => 'Something went wrong. Try again.';

  @override
  String get signOut => 'Sign out';

  @override
  String get errProviderDisabled =>
      'Phone sign-in is not switched on for this project yet. Enable Authentication → Providers → Phone, and wire up the Send SMS hook.';
}
