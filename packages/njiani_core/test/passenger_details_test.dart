import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:njiani_core/njiani_core.dart';

import 'support/harness.dart';

void main() {
  late FakeAuthRepository auth;
  late FakeProfileRepository profiles;

  Profile profileWith({String? name, String? email}) => Profile(
        id: 'passenger-1',
        phone: TzPhone.tryParse('712345678'),
        lang: NjLocale.en,
        displayName: name,
        email: email,
      );

  setUp(() {
    auth = FakeAuthRepository();
    profiles = FakeProfileRepository(profile: profileWith());
  });

  tearDown(() => auth.dispose());

  Future<void> pumpDetails(
    WidgetTester tester, {
    NjLocale locale = NjLocale.en,
  }) async {
    await auth.verifyCode(TzPhone.tryParse('712345678')!, auth.code);
    await pumpScreen(
      tester,
      const PassengerDetailsScreen(),
      auth: auth,
      profile: profiles,
      locale: locale,
    );
  }

  NjButton continueButton(WidgetTester tester) => tester.widget<NjButton>(
        find.ancestor(
          of: find.text('Continue'),
          matching: find.byType(NjButton),
        ),
      );

  // =========================================================================
  group('Profile', () {
    test('a name of whitespace is not a name', () {
      // Without this, "   " passes any `is not null` gate the router puts in
      // front of it — and the database normalises it to null anyway, so the
      // two would disagree.
      expect(profileWith(name: '   ').hasName, isFalse);
      expect(profileWith().hasName, isFalse);
      expect(profileWith(name: 'Neema').hasName, isTrue);
    });

    test('reads the email the database gives back', () {
      final parsed = Profile.fromRow(const {
        'id': 'p',
        'phone': '255712345678',
        'display_name': 'Neema',
        'email': 'neema@example.com',
        'lang': 'en',
      });
      expect(parsed.email, 'neema@example.com');
      expect(parsed.hasName, isTrue);
    });

    test('an email can be cleared, which is how a typo is undone', () {
      final with_ = profileWith(name: 'Neema', email: 'typo@example.com');
      expect(with_.copyWith(clearEmail: true).email, isNull);
    });
  });

  // =========================================================================
  group('pDetails', () {
    testWidgets('asks for a name, and says who sees it', (tester) async {
      await pumpDetails(tester);

      expect(find.text('What should drivers call you?'), findsOneWidget);
      expect(
        find.text(
          'Your driver sees this when they take your request. Nothing else '
          'does.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('no name: Continue is disabled', (tester) async {
      await pumpDetails(tester);
      expect(continueButton(tester).onPressed, isNull);
    });

    testWidgets('a name alone is enough — the email is optional',
        (tester) async {
      await pumpDetails(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Neema');
      await tester.pump();

      expect(continueButton(tester).onPressed, isNotNull);
    });

    testWidgets('the label says optional, so nobody finds out by trying',
        (tester) async {
      await pumpDetails(tester);
      expect(find.text('Email (optional)'), findsOneWidget);
      expect(find.text('For receipts. We sign you in by phone.'),
          findsOneWidget);
    });

    testWidgets('a name and nothing else saves a null email', (tester) async {
      await pumpDetails(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Neema');
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(profiles.nameWrites, ['Neema']);
      expect(profiles.emailWrites, [null]);
    });

    testWidgets('a name and an email save together', (tester) async {
      await pumpDetails(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Neema');
      await tester.enterText(find.byType(TextField).at(1), 'neema@example.com');
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(profiles.nameWrites, ['Neema']);
      expect(profiles.emailWrites, ['neema@example.com']);
    });

    // The same loose check the database makes: catches a typed-in phone
    // number or a stray space, nothing cleverer.
    testWidgets('a phone number in the email field is refused',
        (tester) async {
      await pumpDetails(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Neema');
      await tester.enterText(find.byType(TextField).at(1), '0712345678');
      await tester.pump();

      expect(
        find.text("That doesn't look like an email address."),
        findsOneWidget,
      );
      expect(continueButton(tester).onPressed, isNull);
    });

    testWidgets('an address with no dot after the @ is refused',
        (tester) async {
      await pumpDetails(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Neema');
      await tester.enterText(find.byType(TextField).at(1), 'neema@example');
      await tester.pump();

      expect(continueButton(tester).onPressed, isNull);
    });

    testWidgets('clearing a bad address lets it through again',
        (tester) async {
      await pumpDetails(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Neema');
      await tester.enterText(find.byType(TextField).at(1), 'nonsense');
      await tester.pump();
      expect(continueButton(tester).onPressed, isNull);

      await tester.enterText(find.byType(TextField).at(1), '');
      await tester.pump();

      expect(continueButton(tester).onPressed, isNotNull);
    });

    testWidgets('what is already on the account is filled in', (tester) async {
      // A form that blanks what you already told it is a form people stop
      // filling in.
      profiles.profile = profileWith(name: 'Neema', email: 'n@example.com');
      await pumpDetails(tester);

      expect(find.text('Neema'), findsOneWidget);
      expect(find.text('n@example.com'), findsOneWidget);
    });

    testWidgets('a failed save says so rather than looking saved',
        (tester) async {
      await pumpDetails(tester);
      await tester.enterText(find.byType(TextField).at(0), 'Neema');
      await tester.pump();

      profiles.failure = Exception('offline');
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(find.text("Couldn't save that. Try again."), findsOneWidget);
    });

    testWidgets('renders in Kiswahili', (tester) async {
      await pumpDetails(tester, locale: NjLocale.sw);

      expect(find.text('Madereva wakuite nani?'), findsOneWidget);
      expect(find.text('Barua pepe (si lazima)'), findsOneWidget);
    });
  });
}
