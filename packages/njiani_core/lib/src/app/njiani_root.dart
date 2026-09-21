import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_identity.dart';
import '../design/nj_theme.dart';
import '../l10n/generated/nj_strings.dart';
import '../locale/language_controller.dart';
import '../locale/language_store.dart';
import '../locale/nj_locale.dart';
import 'nj_router.dart';

/// The shared root of both apps.
///
/// Holds everything the two binaries have in common -- theme, localisation,
/// routing -- so each app's `main.dart` stays a single line and the two cannot
/// drift apart.
class NjianiRoot extends ConsumerWidget {
  const NjianiRoot({super.key});

  /// Prepares everything that has to exist before the first frame, then runs
  /// the app.
  ///
  /// The stored language is read here rather than inside a widget so a
  /// returning user never sees the language screen flash past on the way to
  /// the screen they expected.
  ///
  /// [storeOverride] lets a test or a preview supply an in-memory store.
  static Future<void> bootstrap(
    NjianiApp app, {
    LanguageStore? storeOverride,
  }) async {
    WidgetsFlutterBinding.ensureInitialized();

    final store = storeOverride ??
        SharedPrefsLanguageStore(await SharedPreferences.getInstance());

    final container = ProviderContainer(
      overrides: [
        njianiAppProvider.overrideWithValue(app),
        languageStoreProvider.overrideWithValue(store),
      ],
    );

    // Read the stored choice before the first frame.
    await container.read(languageProvider.notifier).load();

    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const NjianiRoot(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final app = ref.watch(njianiAppProvider);
    final locale = ref.watch(languageProvider).locale;

    return MaterialApp.router(
      title: app.label,
      debugShowCheckedModeBanner: false,
      theme: NjTheme.light,
      darkTheme: NjTheme.dark,
      routerConfig: ref.watch(routerProvider),
      locale: locale.locale,
      supportedLocales: NjStrings.supportedLocales,
      localizationsDelegates: NjStrings.localizationsDelegates,
      // A device set to a language Njiani does not ship falls back to
      // Kiswahili, not to the first entry in supportedLocales.
      localeResolutionCallback: (deviceLocale, supported) =>
          locale.locale,
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        // Drivers and passengers do use large system text. Beyond 1.3 the
        // route board and seat counts stop fitting, so it is clamped rather
        // than allowed to break the layouts that matter most.
        minScaleFactor: 0.9,
        maxScaleFactor: 1.3,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

/// Re-exported so apps can bootstrap without importing the locale layer.
typedef NjianiLanguageStore = LanguageStore;

/// Re-exported for tests and previews.
typedef NjianiLocale = NjLocale;
