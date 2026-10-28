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

  /// AuthFailure.providerDisabled. A project configuration problem, not a user error, so the message names the dashboard setting to change rather than blaming the number.
  ///
  /// In en, this message translates to:
  /// **'Phone sign-in is not switched on for this project yet. Enable Authentication → Providers → Phone, and wire up the Send SMS hook.'**
  String get errProviderDisabled;

  /// dSignup heading.
  ///
  /// In en, this message translates to:
  /// **'Drive with Njiani'**
  String get dSignupTitle;

  /// dSignup. Says the thing a driver actually wants to know first, and that a person checks them.
  ///
  /// In en, this message translates to:
  /// **'No commission during the pilot. We check every driver before they go live.'**
  String get dSignupSubtitle;

  /// dSignup field label.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get dNameLabel;

  /// dSignup. The name has to match the document a person will be comparing it against.
  ///
  /// In en, this message translates to:
  /// **'As on your licence'**
  String get dNameHint;

  /// dSignup. Screen-reader label for the bajaj/boda toggle.
  ///
  /// In en, this message translates to:
  /// **'Vehicle'**
  String get dVehicleLabel;

  /// dSignup. Seats are part of the label because the number is a physical fact, not a setting.
  ///
  /// In en, this message translates to:
  /// **'Bajaj · 3 seats'**
  String get dVehicleBajaj;

  /// dSignup vehicle option.
  ///
  /// In en, this message translates to:
  /// **'Boda · 1 seat'**
  String get dVehicleBoda;

  /// dSignup field label.
  ///
  /// In en, this message translates to:
  /// **'Plate number'**
  String get dPlateLabel;

  /// dSignup placeholder. A plate is not translated.
  ///
  /// In en, this message translates to:
  /// **'T 123 ABC'**
  String get dPlateHintBajaj;

  /// dSignup placeholder for a motorcycle plate.
  ///
  /// In en, this message translates to:
  /// **'MC 123 AB'**
  String get dPlateHintBoda;

  /// dSignup field label.
  ///
  /// In en, this message translates to:
  /// **'Colour'**
  String get dColourLabel;

  /// Vehicle colour.
  ///
  /// In en, this message translates to:
  /// **'Blue'**
  String get colourBlue;

  /// Vehicle colour.
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get colourRed;

  /// Vehicle colour.
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get colourGreen;

  /// Vehicle colour.
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get colourYellow;

  /// Vehicle colour.
  ///
  /// In en, this message translates to:
  /// **'Black'**
  String get colourBlack;

  /// Vehicle colour.
  ///
  /// In en, this message translates to:
  /// **'White'**
  String get colourWhite;

  /// dSignup field label.
  ///
  /// In en, this message translates to:
  /// **'Driving licence photo'**
  String get dLicenceLabel;

  /// dSignup. The upload box before anything is attached.
  ///
  /// In en, this message translates to:
  /// **'Add a photo of your licence'**
  String get dLicencePrompt;

  /// dSignup. The upload box once the photo is in the bucket.
  ///
  /// In en, this message translates to:
  /// **'Licence photo attached'**
  String get dLicenceDone;

  /// dSignup. Submit stays disabled while this shows.
  ///
  /// In en, this message translates to:
  /// **'Sending the photo…'**
  String get dLicenceUploading;

  /// dSignup. The design requires this wording: it says what was KEPT, not just what broke, so the driver retries the photo and not the form.
  ///
  /// In en, this message translates to:
  /// **'Photo didn\'t upload. Your details are saved.'**
  String get dLicenceFailed;

  /// dSignup. A promise the storage policies in 20261026000100_storage_licences.sql have to keep.
  ///
  /// In en, this message translates to:
  /// **'Stored in a private bucket. Only the Njiani team can open it.'**
  String get dLicencePrivate;

  /// dSignup camera choice.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get dTakePhoto;

  /// dSignup gallery choice, for a driver who photographed the licence earlier.
  ///
  /// In en, this message translates to:
  /// **'Choose a photo'**
  String get dChoosePhoto;

  /// dSignup primary action.
  ///
  /// In en, this message translates to:
  /// **'Submit for review'**
  String get dSubmitForReview;

  /// dSignup, while the row is being filed.
  ///
  /// In en, this message translates to:
  /// **'Submitting…'**
  String get dSubmitting;

  /// dPending heading.
  ///
  /// In en, this message translates to:
  /// **'We\'re checking your documents'**
  String get dPendingTitle;

  /// dPending. The last sentence matters: a driver waiting at a stage should not keep the app open.
  ///
  /// In en, this message translates to:
  /// **'Usually less than a day. We\'ll send an SMS when you\'re approved. You can close the app.'**
  String get dPendingBody;

  /// dPending. Heading of the card showing what is under review.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get dSubmittedLabel;

  /// dPending. Re-reads the row, for a driver who does not trust that the screen is live.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get dCheckAgain;

  /// dPending in its suspended state. Same layout, different words, support number prominent.
  ///
  /// In en, this message translates to:
  /// **'Your account is on hold'**
  String get dSuspendedTitle;

  /// dPending, suspended. Never leaves a suspended driver without a next step.
  ///
  /// In en, this message translates to:
  /// **'You can\'t take passengers right now. Call Njiani and we\'ll tell you why and what happens next.'**
  String get dSuspendedBody;

  /// Dials SUPPORT_PHONE. Hidden when that is not configured.
  ///
  /// In en, this message translates to:
  /// **'Call Njiani'**
  String get dCallNjiani;

  /// dRejected. Heading above the reason a person wrote.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t accept your licence photo'**
  String get dRejectedReasonTitle;

  /// dRejected heading. Almost every rejection at this size is a bad photo, not a bad driver.
  ///
  /// In en, this message translates to:
  /// **'One thing to fix'**
  String get dRejectedTitle;

  /// dRejected. The promise that resubmit_driver_licence() keeps.
  ///
  /// In en, this message translates to:
  /// **'Everything else checked out. Replace the photo and you go back in the queue — you don\'t start again.'**
  String get dRejectedBody;

  /// dRejected checklist row.
  ///
  /// In en, this message translates to:
  /// **'Vehicle and plate'**
  String get dCheckVehicle;

  /// dRejected checklist row.
  ///
  /// In en, this message translates to:
  /// **'Licence photo'**
  String get dCheckLicence;

  /// dRejected checklist outcome.
  ///
  /// In en, this message translates to:
  /// **'Verified'**
  String get dStatusVerified;

  /// dRejected checklist outcome.
  ///
  /// In en, this message translates to:
  /// **'Accepted'**
  String get dStatusAccepted;

  /// dRejected checklist outcome.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get dStatusRejected;

  /// dRejected primary action. Replaces only the photo.
  ///
  /// In en, this message translates to:
  /// **'Take the photo again'**
  String get dRetakePhoto;

  /// DriverFailure.photoRejected. The bucket enforces a 5 MB cap and an image allow-list, so this comes from the server.
  ///
  /// In en, this message translates to:
  /// **'That photo was too large or not a picture. Take a new one with the camera.'**
  String get errPhotoRejected;

  /// DriverFailure.staleState. The row moved underneath the screen -- usually an admin got there first.
  ///
  /// In en, this message translates to:
  /// **'Your application has changed. Checking again…'**
  String get errDriverStale;

  /// DriverFailure.notApproved. go_online refused because drivers.status is not 'approved'. The router should have prevented it, so this means the screen and the row disagree -- and the row is right.
  ///
  /// In en, this message translates to:
  /// **'Your account isn\'t approved to drive yet.'**
  String get errNotApproved;

  /// dDirection heading.
  ///
  /// In en, this message translates to:
  /// **'Where are you heading?'**
  String get dDirectionTitle;

  /// dDirection. The whole product in one sentence: a heading is declared before a single request is seen.
  ///
  /// In en, this message translates to:
  /// **'You\'ll only see passengers going the same way.'**
  String get dDirectionSubtitle;

  /// dDirection. Label above the stage GPS resolved to.
  ///
  /// In en, this message translates to:
  /// **'Starting from your location'**
  String get dStartingFrom;

  /// dDirection. Label above a stage the driver named by hand.
  ///
  /// In en, this message translates to:
  /// **'Starting from'**
  String get dStartingFromPicked;

  /// dDirection, while the GPS fix is in flight.
  ///
  /// In en, this message translates to:
  /// **'Finding where you are…'**
  String get dFindingYou;

  /// dDirection. Opens the stage list, the no-GPS fallback.
  ///
  /// In en, this message translates to:
  /// **'Choose where you are'**
  String get dPickStartStage;

  /// dDirection. Corrects a GPS fix that landed on the wrong stage.
  ///
  /// In en, this message translates to:
  /// **'Not here?'**
  String get dChangeStartStage;

  /// dDirection. LocationProblem.denied — says WHY before asking again, and names the way round it.
  ///
  /// In en, this message translates to:
  /// **'Njiani needs your location to know which passengers are ahead of you. You can choose your stage instead.'**
  String get dLocationDenied;

  /// dDirection. LocationProblem.deniedForever — only Settings can undo it, so this does not offer to ask again.
  ///
  /// In en, this message translates to:
  /// **'Location is blocked for Njiani. Turn it on in Settings, or choose your stage below.'**
  String get dLocationBlocked;

  /// dDirection. LocationProblem.serviceOff.
  ///
  /// In en, this message translates to:
  /// **'Location is switched off on this phone. Turn it on, or choose your stage below.'**
  String get dLocationOff;

  /// dDirection. LocationProblem.timedOut. Names a cause a driver at Ubungo will recognise rather than blaming the phone.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t find you — too many buildings, maybe. Choose your stage below.'**
  String get dLocationSlow;

  /// dDirection. Re-asks for a fix.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get dTryLocationAgain;

  /// dDirection. Group heading over the stages in one direction. {dest} is the far end of that route.
  ///
  /// In en, this message translates to:
  /// **'Towards {dest}'**
  String dHeadingWest(String dest);

  /// dDirection. Reached at the end of a route in both directions, which on a two-route corridor means the driver is off it.
  ///
  /// In en, this message translates to:
  /// **'No stages ahead of you on this road.'**
  String get dNoDestinations;

  /// dDirection. How many seats this session will offer.
  ///
  /// In en, this message translates to:
  /// **'{count} free'**
  String dSeatsFree(int count);

  /// dDirection. From the design. The MVP has the driver reconcile by hand; C11 brings the On board tab.
  ///
  /// In en, this message translates to:
  /// **'Passengers already with you? Take them first, then add them from the On board tab.'**
  String get dSeatsNote;

  /// dDirection primary action. Names the destination so a mis-tap is visible before it costs anything.
  ///
  /// In en, this message translates to:
  /// **'Go online · heading to {dest}'**
  String dGoOnline(String dest);

  /// dDirection, while go_online runs.
  ///
  /// In en, this message translates to:
  /// **'Going online…'**
  String get dGoingOnline;

  /// dDirection when a session is already open. The design: 'already online → Returning here shows Change, not Go online'.
  ///
  /// In en, this message translates to:
  /// **'Change · heading to {dest}'**
  String dChangeHeading(String dest);

  /// dDirection. Shown on the open session's banner.
  ///
  /// In en, this message translates to:
  /// **'You\'re online'**
  String get dOnlineNow;

  /// dDirection. Ends the session. Does not cancel anyone already claimed.
  ///
  /// In en, this message translates to:
  /// **'Go offline'**
  String get dGoOffline;

  /// dDirection. Shown in place of the action while nothing is selected.
  ///
  /// In en, this message translates to:
  /// **'Pick where you\'re going'**
  String get dPickDestination;

  /// dDirection. Title of the stage picker sheet.
  ///
  /// In en, this message translates to:
  /// **'Where are you now?'**
  String get dStagesTitle;

  /// dDirection. Distance to a destination along the road.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String dKmAway(String km);

  /// dFeed. The route board. The design shows 'Ubungo to Kimara'; the session stores a destination and a position, not an origin stage, and a stale origin would be worse than none.
  ///
  /// In en, this message translates to:
  /// **'Heading to {dest}'**
  String dFeedHeading(String dest);

  /// dFeed. Back to the direction picker.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get dChange;

  /// dFeed. Above the list, next to the live dot.
  ///
  /// In en, this message translates to:
  /// **'Live · passengers heading to {dest}'**
  String dFeedLive(String dest);

  /// dFeed empty state. The second sentence is a promise the alert has to keep, or a driver decides the app is broken and stops looking.
  ///
  /// In en, this message translates to:
  /// **'Nobody heading to {dest} yet. You\'ll hear a sound when a request comes in.'**
  String dFeedEmpty(String dest);

  /// dFeed card. Where the passenger is waiting, and how far along the road.
  ///
  /// In en, this message translates to:
  /// **'{from} · {distance} ahead'**
  String dFeedAhead(String from, String distance);

  /// dFeed card. Where they are going.
  ///
  /// In en, this message translates to:
  /// **'To {dest}'**
  String dFeedTo(String dest);

  /// A short distance, in metres.
  ///
  /// In en, this message translates to:
  /// **'{m} m'**
  String dMetres(String m);

  /// A longer distance, in kilometres.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String dKilometres(String km);

  /// dFeed. The seat bar's label.
  ///
  /// In en, this message translates to:
  /// **'{free} of {total} seats free'**
  String dSeatsLine(int free, int total);

  /// dFeed. Replaces the seat count when there is nothing left to offer.
  ///
  /// In en, this message translates to:
  /// **'Every seat taken'**
  String get dSeatsFullLine;

  /// dFeed. What Pickup becomes when the vehicle is full. From the design.
  ///
  /// In en, this message translates to:
  /// **'Seats full'**
  String get dSeatsFull;

  /// dFeed offline state. Keeps the list and labels it, rather than blanking it: the last answer is still the best one available, but 'three requests' and 'three requests, as of 14:02' are different claims.
  ///
  /// In en, this message translates to:
  /// **'No connection · showing what you had at {time}'**
  String dFeedFrozen(String time);

  /// dFeed. Re-reads the feed by hand.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get dFeedRefresh;

  /// dFeed. The second tab, which arrives at C11. Disabled until then, with the seat count already live so the number means something.
  ///
  /// In en, this message translates to:
  /// **'On board ({count})'**
  String dFeedOnBoardTab(int count);

  /// dFeed. The first tab.
  ///
  /// In en, this message translates to:
  /// **'Requests'**
  String get dFeedRequestsTab;

  /// dFeed. The On board tab before C11 builds it. Says what the tab is for rather than pretending it is empty.
  ///
  /// In en, this message translates to:
  /// **'Passengers you have picked up will appear here.'**
  String get dFeedOnBoardSoon;

  /// dFeed. Claims the seat. Wired at C10, where the race is settled.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get dPickup;

  /// dFeed. Stands in for Pickup until C10 wires the atomic claim. A button that silently does nothing is worse than one that says what it is waiting for.
  ///
  /// In en, this message translates to:
  /// **'Pickup arrives next'**
  String get dPickupSoon;

  /// dDirection. where_am_i reported zero active routes. A setup problem, not a driver one -- almost always seed.sql never having been run, since db push applies migrations and not reference data.
  ///
  /// In en, this message translates to:
  /// **'Njiani has no roads set up yet.'**
  String get dNoRoutesConfigured;

  /// dDirection, debug builds only. The exact fix for dNoRoutesConfigured. Never shown to a driver.
  ///
  /// In en, this message translates to:
  /// **'Run supabase/seed.sql against this project. `supabase db push` applies migrations only — the corridor is reference data.'**
  String get dNoRoutesHint;

  /// dDirection. Located, but outside every route's corridor. The common case for a driver at home, before they drive to the road.
  ///
  /// In en, this message translates to:
  /// **'You\'re not on a road Njiani covers yet.'**
  String get dOffCorridor;

  /// dDirection. Names both ways out of being off-corridor.
  ///
  /// In en, this message translates to:
  /// **'Drive to the Ubungo–Kimara road, or choose the stage you\'ll start from.'**
  String get dOffCorridorHint;

  /// dDirection. On a corridor, with nothing further along it. Turning round is the answer, which the stage picker gives them.
  ///
  /// In en, this message translates to:
  /// **'You\'re at the end of this road.'**
  String get dEndOfTheRoad;

  /// dDirection. The way out of the end of a route.
  ///
  /// In en, this message translates to:
  /// **'Choose the stage you\'ll start from to head back the other way.'**
  String get dEndOfTheRoadHint;

  /// pHome heading.
  ///
  /// In en, this message translates to:
  /// **'Where are you going?'**
  String get pRequestTitle;

  /// pHome. Above the stage GPS resolved to.
  ///
  /// In en, this message translates to:
  /// **'Pickup, from your location'**
  String get pPickupLabel;

  /// pHome. Above a stage the passenger named by hand.
  ///
  /// In en, this message translates to:
  /// **'Pickup'**
  String get pPickupPicked;

  /// pHome. Above the destination list.
  ///
  /// In en, this message translates to:
  /// **'Going to'**
  String get pGoingTo;

  /// pHome. Opens the stage list, the no-GPS fallback.
  ///
  /// In en, this message translates to:
  /// **'Choose where you are'**
  String get pChoosePickup;

  /// pHome. Opens the destination list.
  ///
  /// In en, this message translates to:
  /// **'Choose a destination'**
  String get pChooseDestination;

  /// pHome. The price field. 'Per seat' matters: a bajaj carries three, each paying their own fare.
  ///
  /// In en, this message translates to:
  /// **'Your price, per seat'**
  String get pPriceLabel;

  /// pHome. The price band, from price_bands. A hint, never a rule.
  ///
  /// In en, this message translates to:
  /// **'Most drivers on this route take TSh {low} to {high}'**
  String pBandHint(String low, String high);

  /// pHome. An offer below the band sends with a warning and is never blocked -- the passenger sets the price (ARCHITECTURE §7).
  ///
  /// In en, this message translates to:
  /// **'Below what drivers here usually take. You can still send it.'**
  String get pBelowBand;

  /// pHome. The pair has never been priced. Saying so beats inventing a number a passenger would anchor to.
  ///
  /// In en, this message translates to:
  /// **'No usual price for this trip yet. Offer what you think is fair.'**
  String get pNoBand;

  /// pHome primary action.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get pSendRequest;

  /// pHome, while create_ride_request runs.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get pSending;

  /// pHome. Under the send button. Matches the ten minutes in the schema.
  ///
  /// In en, this message translates to:
  /// **'Your request expires after 10 minutes if no driver takes it.'**
  String get pExpiryNote;

  /// pHome, once a request is open.
  ///
  /// In en, this message translates to:
  /// **'Looking for a driver'**
  String get pWaitingTitle;

  /// pHome, waiting. Says who can see it, which is the question a passenger standing at the road is actually asking.
  ///
  /// In en, this message translates to:
  /// **'Drivers heading your way will see your offer. We\'ll tell you when one takes it.'**
  String get pWaitingBody;

  /// pHome, waiting. A live countdown, so the ten minutes is visible rather than promised.
  ///
  /// In en, this message translates to:
  /// **'Expires in {time}'**
  String pExpiresIn(String time);

  /// pHome. The request ran out. Not an error -- the road was quiet.
  ///
  /// In en, this message translates to:
  /// **'Nobody took it this time.'**
  String get pExpired;

  /// pHome, waiting. Withdraws it. The row is kept, cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get pCancelRequest;

  /// pHome, after an expiry. Straight back to the form with the same choices.
  ///
  /// In en, this message translates to:
  /// **'Ask again'**
  String get pSendAnother;

  /// pHome vehicle option. Same wording as the driver's, deliberately: it is the same vehicle.
  ///
  /// In en, this message translates to:
  /// **'Bajaj · 3 seats'**
  String get pSeatsBajaj;

  /// pHome vehicle option.
  ///
  /// In en, this message translates to:
  /// **'Boda · 1 seat'**
  String get pSeatsBoda;

  /// RequestFailure.notATrip. The server refused a pair that would have saved fine and then matched nothing.
  ///
  /// In en, this message translates to:
  /// **'That trip doesn\'t work — the destination has to be further along the same road.'**
  String get errRequestNotATrip;

  /// RequestFailure.alreadyWaiting. One open request per passenger: two would let one person hold two seats and strand the second driver.
  ///
  /// In en, this message translates to:
  /// **'You already have a request waiting.'**
  String get errAlreadyWaiting;

  /// RequestFailure.unknown and offline. The design is explicit that this must be unambiguous: a silent failure means standing at the road for nothing.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send. Your request was not created.'**
  String get errRequestFailed;
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
