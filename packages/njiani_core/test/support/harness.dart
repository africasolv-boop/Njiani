import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:njiani_core/njiani_core.dart';

/// Pumps [child] with the real theme, real localisations and an in-memory
/// auth repository.
///
/// Localisations are real, not stubbed, so a test that asserts on wording is
/// asserting on the same `.arb` the app ships.
Future<void> pumpScreen(
  WidgetTester tester,
  Widget child, {
  required AuthRepository auth,
  NjLocale locale = NjLocale.sw,
  DateTime Function()? clock,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        profileLoadPolicyProvider
            .overrideWithValue(ProfileLoadPolicy.immediate),
        languageStoreProvider.overrideWithValue(InMemoryLanguageStore(locale)),
        if (clock != null) clockProvider.overrideWithValue(clock),
      ],
      child: MaterialApp(
        theme: NjTheme.light,
        locale: locale.locale,
        supportedLocales: NjStrings.supportedLocales,
        localizationsDelegates: NjStrings.localizationsDelegates,
        home: child,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Reads the live auth state out of a pumped tree.
AuthState authStateOf(WidgetTester tester, Finder of) {
  final element = tester.element(of);
  return ProviderScope.containerOf(element).read(authProvider);
}

/// Reads the controller out of a pumped tree.
AuthController authControllerOf(WidgetTester tester, Finder of) {
  final element = tester.element(of);
  return ProviderScope.containerOf(element).read(authProvider.notifier);
}
