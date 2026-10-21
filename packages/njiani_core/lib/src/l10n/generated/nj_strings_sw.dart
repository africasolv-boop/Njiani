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

  @override
  String get phoneTitle => 'Weka namba yako ya simu';

  @override
  String get phoneSubtitle => 'Tutakutumia namba ya uthibitisho kwa SMS.';

  @override
  String get phoneLabel => 'Namba ya simu';

  @override
  String get phoneHint => '712 345 678';

  @override
  String get phoneError => 'Weka tarakimu 9, bila sifuri ya mwanzo.';

  @override
  String get sendCode => 'Tuma namba';

  @override
  String get sendingCode => 'Inatuma…';

  @override
  String get phoneTerms =>
      'Kwa kuendelea unakubali masharti. Gharama za kawaida za SMS zitatumika.';

  @override
  String otpTitle(int digits) {
    return 'Weka tarakimu $digits ulizopokea';
  }

  @override
  String otpSentTo(String phone) {
    return 'Imetumwa kwa +255 $phone na NJIANI';
  }

  @override
  String get otpDidntGet => 'Hujapokea?';

  @override
  String otpResendIn(String time) {
    return 'Tuma tena baada ya $time';
  }

  @override
  String get otpResend => 'Tuma namba tena';

  @override
  String get otpVerify => 'Thibitisha';

  @override
  String get otpWrongNumber => 'Namba si sahihi? Ibadilishe';

  @override
  String get back => 'Rudi';

  @override
  String get errWrongCode => 'Namba hiyo si sahihi. Jaribu tena.';

  @override
  String get errExpiredCode => 'Namba hiyo imepitwa na wakati. Omba nyingine.';

  @override
  String get errRateLimited =>
      'Umeomba namba nyingi mno. Jaribu tena baada ya dakika 15.';

  @override
  String get errOffline =>
      'Hakuna mtandao. Angalia data yako kisha ujaribu tena.';

  @override
  String get errNotConfigured =>
      'Toleo hili halina seva. Weka SUPABASE_URL na SUPABASE_ANON_KEY kwenye .env.local.';

  @override
  String get errUnknown => 'Kitu hakikufanya kazi. Jaribu tena.';

  @override
  String get signOut => 'Toka';
}
