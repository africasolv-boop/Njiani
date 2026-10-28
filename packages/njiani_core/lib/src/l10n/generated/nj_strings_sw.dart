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

  @override
  String get errNotApproved => 'Akaunti yako bado haijaidhinishwa kuendesha.';

  @override
  String get dDirectionTitle => 'Unaelekea wapi?';

  @override
  String get dDirectionSubtitle =>
      'Utaona abiria wanaoelekea njia moja na wewe.';

  @override
  String get dStartingFrom => 'Unaanzia hapa ulipo';

  @override
  String get dStartingFromPicked => 'Unaanzia';

  @override
  String get dFindingYou => 'Tunatafuta ulipo…';

  @override
  String get dPickStartStage => 'Chagua ulipo';

  @override
  String get dChangeStartStage => 'Siyo hapa?';

  @override
  String get dLocationDenied =>
      'Njiani inahitaji mahali ulipo ili kujua abiria walio mbele yako. Unaweza kuchagua kituo chako badala yake.';

  @override
  String get dLocationBlocked =>
      'Mahali ulipo pamezuiwa kwa Njiani. Washa kwenye Mipangilio, au chagua kituo chako hapa chini.';

  @override
  String get dLocationOff =>
      'Mahali ulipo pamezimwa kwenye simu hii. Washa, au chagua kituo chako hapa chini.';

  @override
  String get dLocationSlow =>
      'Hatukuweza kukupata — labda kuna majengo mengi. Chagua kituo chako hapa chini.';

  @override
  String get dTryLocationAgain => 'Jaribu tena';

  @override
  String dHeadingWest(String dest) {
    return 'Kuelekea $dest';
  }

  @override
  String get dNoDestinations => 'Hakuna vituo mbele yako kwenye barabara hii.';

  @override
  String dSeatsFree(int count) {
    return 'Viti $count';
  }

  @override
  String get dSeatsNote =>
      'Una abiria tayari? Wachukue kwanza, kisha waongeze kwenye kichupo cha Ndani ya gari.';

  @override
  String dGoOnline(String dest) {
    return 'Anza · unaelekea $dest';
  }

  @override
  String get dGoingOnline => 'Inaanza…';

  @override
  String dChangeHeading(String dest) {
    return 'Badilisha · unaelekea $dest';
  }

  @override
  String get dOnlineNow => 'Uko mtandaoni';

  @override
  String get dGoOffline => 'Acha kazi';

  @override
  String get dPickDestination => 'Chagua unakoenda';

  @override
  String get dStagesTitle => 'Uko wapi sasa?';

  @override
  String dKmAway(String km) {
    return 'km $km';
  }

  @override
  String dFeedHeading(String dest) {
    return 'Unaelekea $dest';
  }

  @override
  String get dChange => 'Badilisha';

  @override
  String dFeedLive(String dest) {
    return 'Moja kwa moja · abiria wanaoelekea $dest';
  }

  @override
  String dFeedEmpty(String dest) {
    return 'Hakuna mtu anayeelekea $dest bado. Utasikia sauti ombi likija.';
  }

  @override
  String dFeedAhead(String from, String distance) {
    return '$from · $distance mbele';
  }

  @override
  String dFeedTo(String dest) {
    return 'Hadi $dest';
  }

  @override
  String dMetres(String m) {
    return 'm $m';
  }

  @override
  String dKilometres(String km) {
    return 'km $km';
  }

  @override
  String dSeatsLine(int free, int total) {
    return 'Viti $free kati ya $total vipo';
  }

  @override
  String get dSeatsFullLine => 'Viti vyote vimejaa';

  @override
  String get dSeatsFull => 'Viti vimejaa';

  @override
  String dFeedFrozen(String time) {
    return 'Hakuna mtandao · unaona ulivyokuwa na saa $time';
  }

  @override
  String get dFeedRefresh => 'Pakua upya';

  @override
  String dFeedOnBoardTab(int count) {
    return 'Ndani ya gari ($count)';
  }

  @override
  String get dFeedRequestsTab => 'Maombi';

  @override
  String get dFeedOnBoardSoon => 'Abiria uliowachukua wataonekana hapa.';

  @override
  String get dPickup => 'Chukua';

  @override
  String get dPickupSoon => 'Kuchukua kunakuja';

  @override
  String get dNoRoutesConfigured => 'Njiani haina barabara zilizowekwa bado.';

  @override
  String get dNoRoutesHint =>
      'Endesha supabase/seed.sql kwenye mradi huu. `supabase db push` inaweka migrations pekee — njia ni data ya marejeo.';

  @override
  String get dOffCorridor =>
      'Hauko kwenye barabara ambayo Njiani inahudumia bado.';

  @override
  String get dOffCorridorHint =>
      'Nenda kwenye barabara ya Ubungo–Kimara, au chagua kituo utakapoanzia.';

  @override
  String get dEndOfTheRoad => 'Uko mwisho wa barabara hii.';

  @override
  String get dEndOfTheRoadHint =>
      'Chagua kituo utakapoanzia ili urudi upande mwingine.';

  @override
  String get pRequestTitle => 'Unaenda wapi?';

  @override
  String get pPickupLabel => 'Unapoanzia, mahali ulipo';

  @override
  String get pPickupPicked => 'Unapoanzia';

  @override
  String get pGoingTo => 'Unaenda';

  @override
  String get pChoosePickup => 'Chagua ulipo';

  @override
  String get pChooseDestination => 'Chagua unakoenda';

  @override
  String get pPriceLabel => 'Bei yako, kwa kiti';

  @override
  String pBandHint(String low, String high) {
    return 'Madereva wengi wa njia hii wanakubali TSh $low hadi $high';
  }

  @override
  String get pBelowBand =>
      'Chini ya wanachokubali madereva hapa. Bado unaweza kutuma.';

  @override
  String get pNoBand =>
      'Hakuna bei ya kawaida ya safari hii bado. Toa unachoona ni sawa.';

  @override
  String get pSendRequest => 'Tuma ombi';

  @override
  String get pSending => 'Inatuma…';

  @override
  String get pExpiryNote =>
      'Ombi lako litaisha baada ya dakika 10 kama hakuna dereva atakayelichukua.';

  @override
  String get pWaitingTitle => 'Tunatafuta dereva';

  @override
  String get pWaitingBody =>
      'Madereva wanaoelekea upande wako wataona ombi lako. Tutakujulisha mmoja akilichukua.';

  @override
  String pExpiresIn(String time) {
    return 'Litaisha baada ya $time';
  }

  @override
  String get pExpired => 'Hakuna aliyelichukua safari hii.';

  @override
  String get pCancelRequest => 'Ghairi ombi';

  @override
  String get pSendAnother => 'Omba tena';

  @override
  String get pSeatsBajaj => 'Bajaj · viti 3';

  @override
  String get pSeatsBoda => 'Boda · kiti 1';

  @override
  String get errRequestNotATrip =>
      'Safari hiyo haiwezekani — unakoenda lazima kuwe mbele zaidi kwenye barabara ile ile.';

  @override
  String get errAlreadyWaiting => 'Tayari una ombi linalosubiri.';

  @override
  String get errRequestFailed => 'Haikutumwa. Ombi lako halikutengenezwa.';

  @override
  String get dSessionUnreadable =>
      'Hatukuweza kuangalia kama uko kazini. Chagua unakoelekea ili uanze upya.';

  @override
  String get pDetailsTitle => 'Madereva wakuite nani?';

  @override
  String get pDetailsBody =>
      'Dereva wako ataona hili akichukua ombi lako. Hakuna mwingine atakayeliona.';

  @override
  String get pNameLabel => 'Jina lako';

  @override
  String get pNameHint => 'Jina la kwanza linatosha';

  @override
  String get pEmailLabel => 'Barua pepe (si lazima)';

  @override
  String get pEmailHint => 'Kwa risiti. Tunakuingiza kwa namba ya simu.';

  @override
  String get pEmailInvalid => 'Hiyo haionekani kama anwani ya barua pepe.';

  @override
  String get pDetailsSave => 'Endelea';

  @override
  String get pDetailsSaving => 'Inahifadhi…';

  @override
  String get pDetailsFailed => 'Haikuhifadhiwa. Jaribu tena.';
}
