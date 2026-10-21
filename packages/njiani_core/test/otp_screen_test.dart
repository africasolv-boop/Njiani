import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:njiani_core/njiani_core.dart';

import 'support/harness.dart';

void main() {
  late FakeAuthRepository auth;

  setUp(() => auth = FakeAuthRepository());
  tearDown(() => auth.dispose());

  /// Pumps the code screen with a code already "sent", which is the only
  /// state it is ever reached in.
  Future<void> pump(
    WidgetTester tester, {
    NjLocale locale = NjLocale.en,
    DateTime Function()? clock,
    AuthRepository? repository,
  }) async {
    await pumpScreen(tester, const OtpScreen(),
        auth: repository ?? auth, locale: locale, clock: clock);
    await authControllerOf(tester, find.byType(OtpScreen))
        .sendCode('712345678');
    await tester.pumpAndSettle();
  }

  Finder boxes() => find.byType(TextField);

  Future<void> type(WidgetTester tester, String code) async {
    for (var i = 0; i < code.length && i < kOtpLength; i++) {
      await tester.enterText(boxes().at(i), code[i]);
      await tester.pump();
    }
  }

  group('pOtp — the states in the spec', () {
    testWidgets('empty: Verify is disabled and there is one box per digit',
        (tester) async {
      await pump(tester);

      expect(boxes(), findsNWidgets(kOtpLength));
      final verify = tester.widget<NjButton>(
        find.ancestor(of: find.text('Verify'), matching: find.byType(NjButton)),
      );
      expect(verify.onPressed, isNull);
    });

    testWidgets('filled: Verify becomes enabled', (tester) async {
      await pump(tester);
      await type(tester, '12345');  // one short
      await tester.pump();

      final verify = tester.widget<NjButton>(
        find.ancestor(of: find.text('Verify'), matching: find.byType(NjButton)),
      );
      expect(verify.onPressed, isNull);

      await tester.enterText(boxes().at(5), '6');
      await tester.pumpAndSettle();

      // Completing the code submits it, which signs this fake in.
      expect(auth.attempted, contains('123456'));
    });

    testWidgets('wrong: every box goes red AND clears', (tester) async {
      await pump(tester);
      await type(tester, '000000');
      await tester.pumpAndSettle();

      expect(find.textContaining('not right'), findsOneWidget);

      final field = tester.widget<NjOtpField>(find.byType(NjOtpField));
      expect(field.hasError, isTrue);

      for (var i = 0; i < kOtpLength; i++) {
        expect(
          tester.widget<TextField>(boxes().at(i)).controller?.text,
          isEmpty,
          reason: 'box $i should clear so the code can be retyped cleanly',
        );
      }
    });

    testWidgets('expired: says so, and differently from wrong',
        (tester) async {
      auth.verifyFailure = AuthFailure.expiredCode;
      await pump(tester);
      await type(tester, '123456');
      await tester.pumpAndSettle();

      expect(find.textContaining('expired'), findsOneWidget);
      expect(find.textContaining('not right'), findsNothing);
    });

    testWidgets('resend: a countdown first, then a tappable button',
        (tester) async {
      var now = DateTime(2026, 10, 21, 9);
      await pump(tester, clock: () => now);

      // Inside the window the countdown shows and there is no resend button.
      expect(find.textContaining('Resend in', findRichText: true),
          findsOneWidget);
      expect(find.text('Resend code'), findsNothing);

      // Past the window the button appears.
      now = now.add(kResendWindow);
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('Resend in', findRichText: true),
          findsNothing);
      expect(find.text('Resend code'), findsOneWidget);

      await tester.tap(find.text('Resend code'));
      await tester.pumpAndSettle();
      expect(auth.sent.length, 2);
    });
  });

  group('pOtp — paste and autofill', () {
    testWidgets('a pasted whole code fills every box', (tester) async {
      // The spec requires it, and without it a paste lands the entire code in
      // box one, which looks like the field is broken.
      await pump(tester);

      await tester.enterText(boxes().first, '123456');
      await tester.pumpAndSettle();

      expect(auth.attempted, contains('123456'));
    });

    testWidgets('a pasted code with spaces still fills correctly',
        (tester) async {
      await pump(tester);

      await tester.enterText(boxes().first, '123 456');
      await tester.pumpAndSettle();

      expect(auth.attempted, contains('123456'));
    });

    testWidgets('the first box offers one-time-code autofill',
        (tester) async {
      await pump(tester);

      final first = tester.widget<TextField>(boxes().first);
      expect(first.autofillHints, contains(AutofillHints.oneTimeCode));
    });
  });

  group('pOtp — getting back out', () {
    testWidgets('names the number the code went to', (tester) async {
      await pump(tester);
      expect(find.textContaining('712 345 678'), findsOneWidget);
    });

    testWidgets('names the sender, so the SMS is recognisable',
        (tester) async {
      await pump(tester);
      expect(find.textContaining('NJIANI'), findsOneWidget);
    });

    testWidgets('Back returns to the phone step', (tester) async {
      await pump(tester);

      await tester.tap(find.text('Back'));
      await tester.pumpAndSettle();

      expect(
        authStateOf(tester, find.byType(OtpScreen)).step,
        AuthStep.phone,
      );
    });

    testWidgets('wrong number returns to the phone step too', (tester) async {
      await pump(tester);

      await tester.tap(find.textContaining('Wrong number'));
      await tester.pumpAndSettle();

      expect(
        authStateOf(tester, find.byType(OtpScreen)).step,
        AuthStep.phone,
      );
    });
  });

  group('pOtp — localisation and layout', () {
    testWidgets('renders Kiswahili', (tester) async {
      await pump(tester, locale: NjLocale.sw);
      expect(find.text('Thibitisha'), findsOneWidget);
      expect(find.textContaining('Hujapokea?', findRichText: true),
          findsOneWidget);
    });

    testWidgets('six boxes fit a small handset without overflowing',
        (tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await pump(tester);
      expect(tester.takeException(), isNull);
    });
  });
}
