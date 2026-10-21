import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:njiani_core/njiani_core.dart';

void main() {
  late FakeAuthRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = FakeAuthRepository();
    container = ProviderContainer(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(() {
      container.dispose();
      repository.dispose();
    });
  });

  AuthState read() => container.read(authProvider);
  AuthController controller() => container.read(authProvider.notifier);

  group('the code length is forced by the platform', () {
    test('six digits, not the four drawn in the design', () {
      // Supabase Auth will not issue an SMS code shorter than six digits, so
      // four boxes could never be filled by a code it sent.
      expect(kOtpLength, 6);
      expect(kOtpLength, greaterThanOrEqualTo(6));
    });
  });

  group('sendCode', () {
    test('starts on the phone step', () {
      expect(read().step, AuthStep.phone);
      expect(read().busy, isFalse);
    });

    test('normalises before sending, so 0712 and 712 are one number',
        () async {
      await controller().sendCode('0712 345 678');

      expect(repository.sent.single.e164, '+255712345678');
      expect(read().step, AuthStep.code);
    });

    test('rejects a short number without spending an SMS', () async {
      await controller().sendCode('71234');

      expect(repository.sent, isEmpty, reason: 'an SMS costs money');
      expect(read().failure, AuthFailure.invalidPhone);
      expect(read().step, AuthStep.phone);
    });

    test('debounces: a second tap does not cost a second SMS', () async {
      final slow = FakeAuthRepository(delay: const Duration(milliseconds: 60));
      final box = ProviderContainer(
        overrides: [authRepositoryProvider.overrideWithValue(slow)],
      );
      addTearDown(() {
        box.dispose();
        slow.dispose();
      });

      final notifier = box.read(authProvider.notifier);
      final first = notifier.sendCode('712345678');
      await notifier.sendCode('712345678'); // the impatient second tap
      await first;

      expect(slow.sent.length, 1);
    });

    test('keeps the number on failure', () async {
      // Retyping a phone number on a moving bajaj is the worst possible ask.
      repository.sendFailure = AuthFailure.offline;
      await controller().sendCode('712345678');

      expect(read().failure, AuthFailure.offline);
      expect(read().phone?.national, '712345678',
          reason: 'the number must survive the error');
      expect(read().step, AuthStep.phone);
    });

    test('reports a rate limit rather than retrying', () async {
      repository.sendFailure = AuthFailure.rateLimited;
      await controller().sendCode('712345678');

      expect(read().failure, AuthFailure.rateLimited);
      expect(read().step, AuthStep.phone);
    });

    test('records when the code was sent, for the countdown', () async {
      await controller().sendCode('712345678');
      expect(read().codeSentAt, isNotNull);
      expect(read().resendIn(DateTime.now()), greaterThan(50));
    });
  });

  group('verifyCode', () {
    setUp(() async => controller().sendCode('712345678'));

    test('the right code signs the user in', () async {
      await controller().verifyCode('123456');

      expect(read().step, AuthStep.signedIn);
      expect(read().failure, isNull);
      expect(repository.isSignedIn, isTrue);
    });

    test('a wrong code reports it and stays on the code step', () async {
      await controller().verifyCode('000000');

      expect(read().failure, AuthFailure.wrongCode);
      expect(read().step, AuthStep.code);
      expect(read().phone, isNotNull, reason: 'the number is not lost');
    });

    test('an expired code is distinct from a wrong one', () async {
      // They need different words and a different control: expired offers a
      // resend, wrong does not.
      repository.verifyFailure = AuthFailure.expiredCode;
      await controller().verifyCode('123456');

      expect(read().failure, AuthFailure.expiredCode);
    });

    test('an incomplete code is not submitted', () async {
      await controller().verifyCode('123');
      expect(repository.attempted, isEmpty);
    });

    test('clearFailure wipes the error as the user starts fixing it',
        () async {
      await controller().verifyCode('000000');
      expect(read().failure, isNotNull);

      controller().clearFailure();
      expect(read().failure, isNull);
    });
  });

  group('resendCode', () {
    test('is refused while the countdown is running', () async {
      await controller().sendCode('712345678');
      expect(repository.sent.length, 1);

      await controller().resendCode();
      expect(repository.sent.length, 1, reason: 'the window has not elapsed');
    });

    test('sends again once the window has elapsed', () async {
      // The clock is injected so this does not take a minute to run.
      var now = DateTime(2026, 10, 21, 9);
      final repo = FakeAuthRepository();
      final box = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(() {
        box.dispose();
        repo.dispose();
      });

      await box.read(authProvider.notifier).sendCode('712345678');
      expect(repo.sent.length, 1);

      // Still inside the window.
      now = now.add(const Duration(seconds: 30));
      await box.read(authProvider.notifier).resendCode();
      expect(repo.sent.length, 1);

      // Past it.
      now = now.add(kResendWindow);
      await box.read(authProvider.notifier).resendCode();
      expect(repo.sent.length, 2);
    });

    test('re-sending to the same number inside the window costs nothing',
        () async {
      // Going back, then forward again, must not burn a second SMS.
      var now = DateTime(2026, 10, 21, 9);
      final repo = FakeAuthRepository();
      final box = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(() {
        box.dispose();
        repo.dispose();
      });

      final notifier = box.read(authProvider.notifier);
      await notifier.sendCode('712345678');
      notifier.editPhone();
      now = now.add(const Duration(seconds: 5));
      await notifier.sendCode('0712 345 678'); // the same number, retyped

      expect(repo.sent.length, 1);
      expect(box.read(authProvider).step, AuthStep.code,
          reason: 'it should go on to the code screen, not stall');
    });

    test('a different number does send, even inside the window', () async {
      // A corrected typo is a new number and must not be swallowed.
      var now = DateTime(2026, 10, 21, 9);
      final repo = FakeAuthRepository();
      final box = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(repo),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(() {
        box.dispose();
        repo.dispose();
      });

      final notifier = box.read(authProvider.notifier);
      await notifier.sendCode('712345678');
      notifier.editPhone();
      now = now.add(const Duration(seconds: 5));
      await notifier.sendCode('713000000');

      expect(repo.sent.length, 2);
      expect(repo.sent.last.national, '713000000');
    });
  });

  group('navigation between the two screens', () {
    test('editPhone goes back keeping the number', () async {
      await controller().sendCode('712345678');
      expect(read().step, AuthStep.code);

      controller().editPhone();

      expect(read().step, AuthStep.phone);
      expect(read().phone?.national, '712345678');
    });

    test('signOut returns to the beginning', () async {
      await controller().sendCode('712345678');
      await controller().verifyCode('123456');
      expect(read().step, AuthStep.signedIn);

      await controller().signOut();

      expect(read().step, AuthStep.phone);
      expect(read().phone, isNull);
    });
  });

  group('an unconfigured build', () {
    test('says which key is missing instead of failing silently', () async {
      final box = ProviderContainer(
        overrides: [
          authRepositoryProvider
              .overrideWithValue(const UnconfiguredAuthRepository()),
        ],
      );
      addTearDown(box.dispose);

      await box.read(authProvider.notifier).sendCode('712345678');
      expect(box.read(authProvider).failure, AuthFailure.notConfigured);
    });
  });

  group('AuthState', () {
    test('resendIn counts down and stops at zero', () {
      final sent = DateTime(2026, 10, 21, 9);
      final state = AuthState(codeSentAt: sent);

      expect(state.resendIn(sent), kResendWindow.inSeconds);
      expect(state.resendIn(sent.add(const Duration(seconds: 18))),
          kResendWindow.inSeconds - 18);
      expect(state.resendIn(sent.add(kResendWindow)), 0);
      expect(state.resendIn(sent.add(const Duration(hours: 1))), 0);
    });

    test('resendIn is zero before anything was sent', () {
      expect(const AuthState().resendIn(DateTime.now()), 0);
    });

    test('compares by value', () {
      const a = AuthState(step: AuthStep.code, busy: true);
      const b = AuthState(step: AuthStep.code, busy: true);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(const AuthState(step: AuthStep.code)));
    });
  });
}
