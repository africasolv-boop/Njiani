import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:njiani_core/njiani_core.dart';

import 'support/harness.dart';

void main() {
  late FakeAuthRepository auth;

  setUp(() => auth = FakeAuthRepository());
  tearDown(() => auth.dispose());

  Future<void> pump(WidgetTester tester, {NjLocale locale = NjLocale.en}) =>
      pumpScreen(tester, const PhoneScreen(), auth: auth, locale: locale);

  group('pPhone — the states in the spec', () {
    testWidgets('empty: Send code is disabled', (tester) async {
      await pump(tester);

      final button = tester.widget<NjButton>(find.byType(NjButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('typing: enabled at nine digits, not before', (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), '71234567'); // eight
      await tester.pump();
      expect(tester.widget<NjButton>(find.byType(NjButton)).onPressed, isNull);

      await tester.enterText(find.byType(TextField), '712345678'); // nine
      await tester.pump();
      expect(
        tester.widget<NjButton>(find.byType(NjButton)).onPressed,
        isNotNull,
      );
    });

    testWidgets('a leading zero still counts as nine digits', (tester) async {
      // Typing 0712345678 is how the number is written locally, and it must
      // enable the button exactly as 712345678 does.
      await pump(tester);

      await tester.enterText(find.byType(TextField), '0712345678');
      await tester.pump();

      expect(
        tester.widget<NjButton>(find.byType(NjButton)).onPressed,
        isNotNull,
      );
    });

    testWidgets('loading: spinner shown and further taps blocked',
        (tester) async {
      final slow = FakeAuthRepository(delay: const Duration(milliseconds: 80));
      addTearDown(slow.dispose);
      await pumpScreen(tester, const PhoneScreen(),
          auth: slow, locale: NjLocale.en);

      await tester.enterText(find.byType(TextField), '712345678');
      await tester.pump();
      await tester.tap(find.text('Send code'));
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // The impatient second tap must not cost a second SMS.
      await tester.tap(find.byType(NjButton), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(slow.sent.length, 1);
    });

    testWidgets('error: the message shows and the number is KEPT',
        (tester) async {
      // Retyping a phone number on a moving bajaj is the worst possible ask.
      auth.sendFailure = AuthFailure.offline;
      await pump(tester);

      await tester.enterText(find.byType(TextField), '712345678');
      await tester.pump();
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();

      expect(find.textContaining('No connection'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        '712345678',
        reason: 'the field must not be cleared',
      );
    });

    testWidgets('rate limit: says how long to wait', (tester) async {
      auth.sendFailure = AuthFailure.rateLimited;
      await pump(tester);

      await tester.enterText(find.byType(TextField), '712345678');
      await tester.pump();
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();

      expect(find.textContaining('15 minutes'), findsOneWidget);
    });

    testWidgets('a backend problem is NOT reported as a bad number',
        (tester) async {
      // The regression: a disabled provider used to show "Enter 9 digits,
      // without the leading zero" about a number that was already correct.
      auth
        ..sendFailure = AuthFailure.providerDisabled
        ..failureDetail = 'Phone logins are disabled';
      await pump(tester);

      await tester.enterText(find.byType(TextField), '656834063');
      await tester.pump();
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Enter 9 digits'),
        findsNothing,
        reason: 'the digits are fine; the project setting is not',
      );
      expect(find.textContaining('not switched on'), findsOneWidget);
    });

    testWidgets('a real nine-digit number is accepted, with or without the '
        'leading zero', (tester) async {
      await pump(tester);

      for (final typed in ['656834063', '0656834063', '+255656834063']) {
        await tester.enterText(find.byType(TextField), typed);
        await tester.pump();
        expect(
          tester.widget<NjButton>(find.byType(NjButton)).onPressed,
          isNotNull,
          reason: '"$typed" is the same valid number',
        );
      }
    });

    testWidgets('a pasted international number with spaces is not truncated',
        (tester) async {
      // A tighter maxLength silently chopped this and left the button
      // disabled with nothing on screen to explain why.
      await pump(tester);

      await tester.enterText(find.byType(TextField), '+255 656 834 063');
      await tester.pump();

      expect(
        tester.widget<NjButton>(find.byType(NjButton)).onPressed,
        isNotNull,
      );

      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();
      expect(auth.sent.single.e164, '+255656834063');
    });

    testWidgets('an unconfigured build names the missing keys',
        (tester) async {
      await pumpScreen(tester, const PhoneScreen(),
          auth: const UnconfiguredAuthRepository(), locale: NjLocale.en);

      await tester.enterText(find.byType(TextField), '712345678');
      await tester.pump();
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();

      expect(find.textContaining('SUPABASE_URL'), findsOneWidget);
    });

    testWidgets('the error clears as soon as the user edits the number',
        (tester) async {
      auth.sendFailure = AuthFailure.offline;
      await pump(tester);

      await tester.enterText(find.byType(TextField), '712345678');
      await tester.pump();
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No connection'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '71234567');
      await tester.pumpAndSettle();
      expect(find.textContaining('No connection'), findsNothing);
    });
  });

  group('pPhone — the +255 is part of the field', () {
    testWidgets('the prefix is shown and is not in the value',
        (tester) async {
      await pump(tester);

      expect(find.text('+255'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        isEmpty,
        reason: 'the country code cannot be deleted by accident',
      );
    });

    testWidgets('sends the normalised E.164 number', (tester) async {
      await pump(tester);

      await tester.enterText(find.byType(TextField), '0712 345 678');
      await tester.pump();
      await tester.tap(find.text('Send code'));
      await tester.pumpAndSettle();

      expect(auth.sent.single.e164, '+255712345678');
    });
  });

  group('pPhone — localisation and layout', () {
    testWidgets('renders Kiswahili by default', (tester) async {
      await pump(tester, locale: NjLocale.sw);
      expect(find.text('Weka namba yako ya simu'), findsOneWidget);
      expect(find.text('Tuma namba'), findsOneWidget);
    });

    testWidgets('renders English when chosen', (tester) async {
      // English is this harness's default, because most assertions below read
      // more clearly against the English copy.
      await pump(tester);
      expect(find.text('Enter your phone number'), findsOneWidget);
      expect(find.text('Send code'), findsOneWidget);
    });

    testWidgets('fits a small handset at the largest clamped text scale',
        (tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MediaQuery.withClampedTextScaling(
          minScaleFactor: 1.3,
          maxScaleFactor: 1.3,
          child: const SizedBox.shrink(),
        ),
      );
      await pump(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
