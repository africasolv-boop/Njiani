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

  @override
  String get errProviderDisabled =>
      'Kuingia kwa namba ya simu bado hakujawashwa kwenye mradi huu. Washa Authentication → Providers → Phone, kisha unganisha Send SMS hook.';

  @override
  String get dSignupTitle => 'Endesha na Njiani';

  @override
  String get dSignupSubtitle =>
      'Hakuna kamisheni kipindi cha majaribio. Tunamhakiki kila dereva kabla ya kuanza kazi.';

  @override
  String get dNameLabel => 'Jina kamili';

  @override
  String get dNameHint => 'Kama kwenye leseni yako';

  @override
  String get dVehicleLabel => 'Chombo';

  @override
  String get dVehicleBajaj => 'Bajaj · viti 3';

  @override
  String get dVehicleBoda => 'Boda · kiti 1';

  @override
  String get dPlateLabel => 'Namba ya gari';

  @override
  String get dPlateHintBajaj => 'T 123 ABC';

  @override
  String get dPlateHintBoda => 'MC 123 AB';

  @override
  String get dColourLabel => 'Rangi';

  @override
  String get colourBlue => 'Bluu';

  @override
  String get colourRed => 'Nyekundu';

  @override
  String get colourGreen => 'Kijani';

  @override
  String get colourYellow => 'Njano';

  @override
  String get colourBlack => 'Nyeusi';

  @override
  String get colourWhite => 'Nyeupe';

  @override
  String get dLicenceLabel => 'Picha ya leseni ya udereva';

  @override
  String get dLicencePrompt => 'Ongeza picha ya leseni yako';

  @override
  String get dLicenceDone => 'Picha ya leseni imeambatishwa';

  @override
  String get dLicenceUploading => 'Inatuma picha…';

  @override
  String get dLicenceFailed => 'Picha haikutumwa. Maelezo yako yamehifadhiwa.';

  @override
  String get dLicencePrivate =>
      'Imehifadhiwa kwa siri. Ni timu ya Njiani tu inayoweza kuifungua.';

  @override
  String get dTakePhoto => 'Piga picha';

  @override
  String get dChoosePhoto => 'Chagua picha';

  @override
  String get dSubmitForReview => 'Tuma kwa uhakiki';

  @override
  String get dSubmitting => 'Inatuma…';

  @override
  String get dPendingTitle => 'Tunahakiki nyaraka zako';

  @override
  String get dPendingBody =>
      'Kwa kawaida chini ya siku moja. Tutakutumia SMS ukikubaliwa. Unaweza kufunga app.';

  @override
  String get dSubmittedLabel => 'Umetuma';

  @override
  String get dCheckAgain => 'Angalia tena';

  @override
  String get dSuspendedTitle => 'Akaunti yako imesimamishwa';

  @override
  String get dSuspendedBody =>
      'Kwa sasa hauwezi kuchukua abiria. Piga simu Njiani tutakueleza sababu na hatua inayofuata.';

  @override
  String get dCallNjiani => 'Piga simu Njiani';

  @override
  String get dRejectedReasonTitle => 'Hatukuweza kukubali picha ya leseni yako';

  @override
  String get dRejectedTitle => 'Kitu kimoja cha kurekebisha';

  @override
  String get dRejectedBody =>
      'Mengine yote yamekubaliwa. Badilisha picha na utarudi kwenye foleni — hauanzi upya.';

  @override
  String get dCheckVehicle => 'Gari na namba';

  @override
  String get dCheckLicence => 'Picha ya leseni';

  @override
  String get dStatusVerified => 'Imehakikiwa';

  @override
  String get dStatusAccepted => 'Imekubaliwa';

  @override
  String get dStatusRejected => 'Imekataliwa';

  @override
  String get dRetakePhoto => 'Piga picha tena';

  @override
  String get errPhotoRejected =>
      'Picha ni kubwa mno au si picha. Piga picha mpya kwa kamera.';

  @override
  String get errDriverStale => 'Maombi yako yamebadilika. Tunaangalia tena…';
}
