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

  @override
  String get dSignupTitle => 'Drive with Njiani';

  @override
  String get dSignupSubtitle =>
      'No commission during the pilot. We check every driver before they go live.';

  @override
  String get dNameLabel => 'Full name';

  @override
  String get dNameHint => 'As on your licence';

  @override
  String get dVehicleLabel => 'Vehicle';

  @override
  String get dVehicleBajaj => 'Bajaj · 3 seats';

  @override
  String get dVehicleBoda => 'Boda · 1 seat';

  @override
  String get dPlateLabel => 'Plate number';

  @override
  String get dPlateHintBajaj => 'T 123 ABC';

  @override
  String get dPlateHintBoda => 'MC 123 AB';

  @override
  String get dColourLabel => 'Colour';

  @override
  String get colourBlue => 'Blue';

  @override
  String get colourRed => 'Red';

  @override
  String get colourGreen => 'Green';

  @override
  String get colourYellow => 'Yellow';

  @override
  String get colourBlack => 'Black';

  @override
  String get colourWhite => 'White';

  @override
  String get dLicenceLabel => 'Driving licence photo';

  @override
  String get dLicencePrompt => 'Add a photo of your licence';

  @override
  String get dLicenceDone => 'Licence photo attached';

  @override
  String get dLicenceUploading => 'Sending the photo…';

  @override
  String get dLicenceFailed => 'Photo didn\'t upload. Your details are saved.';

  @override
  String get dLicencePrivate =>
      'Stored in a private bucket. Only the Njiani team can open it.';

  @override
  String get dTakePhoto => 'Take a photo';

  @override
  String get dChoosePhoto => 'Choose a photo';

  @override
  String get dSubmitForReview => 'Submit for review';

  @override
  String get dSubmitting => 'Submitting…';

  @override
  String get dPendingTitle => 'We\'re checking your documents';

  @override
  String get dPendingBody =>
      'Usually less than a day. We\'ll send an SMS when you\'re approved. You can close the app.';

  @override
  String get dSubmittedLabel => 'Submitted';

  @override
  String get dCheckAgain => 'Check again';

  @override
  String get dSuspendedTitle => 'Your account is on hold';

  @override
  String get dSuspendedBody =>
      'You can\'t take passengers right now. Call Njiani and we\'ll tell you why and what happens next.';

  @override
  String get dCallNjiani => 'Call Njiani';

  @override
  String get dRejectedReasonTitle => 'We couldn\'t accept your licence photo';

  @override
  String get dRejectedTitle => 'One thing to fix';

  @override
  String get dRejectedBody =>
      'Everything else checked out. Replace the photo and you go back in the queue — you don\'t start again.';

  @override
  String get dCheckVehicle => 'Vehicle and plate';

  @override
  String get dCheckLicence => 'Licence photo';

  @override
  String get dStatusVerified => 'Verified';

  @override
  String get dStatusAccepted => 'Accepted';

  @override
  String get dStatusRejected => 'Rejected';

  @override
  String get dRetakePhoto => 'Take the photo again';

  @override
  String get errPhotoRejected =>
      'That photo was too large or not a picture. Take a new one with the camera.';

  @override
  String get errDriverStale => 'Your application has changed. Checking again…';

  @override
  String get errNotApproved => 'Your account isn\'t approved to drive yet.';

  @override
  String get dDirectionTitle => 'Where are you heading?';

  @override
  String get dDirectionSubtitle =>
      'You\'ll only see passengers going the same way.';

  @override
  String get dStartingFrom => 'Starting from your location';

  @override
  String get dStartingFromPicked => 'Starting from';

  @override
  String get dFindingYou => 'Finding where you are…';

  @override
  String get dPickStartStage => 'Choose where you are';

  @override
  String get dChangeStartStage => 'Not here?';

  @override
  String get dLocationDenied =>
      'Njiani needs your location to know which passengers are ahead of you. You can choose your stage instead.';

  @override
  String get dLocationBlocked =>
      'Location is blocked for Njiani. Turn it on in Settings, or choose your stage below.';

  @override
  String get dLocationOff =>
      'Location is switched off on this phone. Turn it on, or choose your stage below.';

  @override
  String get dLocationSlow =>
      'Couldn\'t find you — too many buildings, maybe. Choose your stage below.';

  @override
  String get dTryLocationAgain => 'Try again';

  @override
  String dHeadingWest(String dest) {
    return 'Towards $dest';
  }

  @override
  String get dNoDestinations => 'No stages ahead of you on this road.';

  @override
  String dSeatsFree(int count) {
    return '$count free';
  }

  @override
  String get dSeatsNote =>
      'Passengers already with you? Take them first, then add them from the On board tab.';

  @override
  String dGoOnline(String dest) {
    return 'Go online · heading to $dest';
  }

  @override
  String get dGoingOnline => 'Going online…';

  @override
  String dChangeHeading(String dest) {
    return 'Change · heading to $dest';
  }

  @override
  String get dOnlineNow => 'You\'re online';

  @override
  String get dGoOffline => 'Go offline';

  @override
  String get dPickDestination => 'Pick where you\'re going';

  @override
  String get dStagesTitle => 'Where are you now?';

  @override
  String dKmAway(String km) {
    return '$km km';
  }
}
