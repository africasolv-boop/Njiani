import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:njiani_core/njiani_core.dart';

void main() {
  group('NjLocale', () {
    test('Kiswahili is the fallback, and is declared first', () {
      // The pilot corridor's first language.
      expect(NjLocale.fallback, NjLocale.sw);
      expect(NjLocale.values.first, NjLocale.sw);
    });

    test('endonyms are written in their own language', () {
      expect(NjLocale.sw.endonym, 'Kiswahili');
      expect(NjLocale.en.endonym, 'English');
    });

    test('parses plain codes', () {
      expect(NjLocale.tryParse('sw'), NjLocale.sw);
      expect(NjLocale.tryParse('en'), NjLocale.en);
    });

    test('parses region tags by their language subtag', () {
      // A device set to Tanzanian English should get English.
      expect(NjLocale.tryParse('en_TZ'), NjLocale.en);
      expect(NjLocale.tryParse('en-GB'), NjLocale.en);
      expect(NjLocale.tryParse('sw_TZ'), NjLocale.sw);
      expect(NjLocale.tryParse('SW'), NjLocale.sw);
    });

    test('returns null for anything unknown, rather than guessing', () {
      expect(NjLocale.tryParse(null), isNull);
      expect(NjLocale.tryParse(''), isNull);
      expect(NjLocale.tryParse('fr'), isNull);
      expect(NjLocale.tryParse('xx_YY'), isNull);
    });
  });

  group('LanguageController', () {
    ProviderContainer containerWith(InMemoryLanguageStore store) {
      final container = ProviderContainer(
        overrides: [languageStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('starts on the fallback, unconfirmed', () {
      final container = containerWith(InMemoryLanguageStore());
      final state = container.read(languageProvider);

      expect(state.locale, NjLocale.sw);
      expect(
        state.confirmed,
        isFalse,
        reason: 'defaulting to Kiswahili is not the same as choosing it',
      );
    });

    test('load() restores a previous choice as confirmed', () async {
      final container = containerWith(InMemoryLanguageStore(NjLocale.en));
      await container.read(languageProvider.notifier).load();

      final state = container.read(languageProvider);
      expect(state.locale, NjLocale.en);
      expect(state.confirmed, isTrue);
    });

    test('load() with nothing stored leaves the user unconfirmed', () async {
      final container = containerWith(InMemoryLanguageStore());
      await container.read(languageProvider.notifier).load();

      expect(container.read(languageProvider).confirmed, isFalse);
    });

    test('preview() changes the language without persisting it', () async {
      final store = InMemoryLanguageStore();
      final container = containerWith(store);

      container.read(languageProvider.notifier).preview(NjLocale.en);

      expect(container.read(languageProvider).locale, NjLocale.en);
      expect(container.read(languageProvider).confirmed, isFalse);
      expect(store.writes, 0, reason: 'nothing is written until Continue');
      expect(await store.read(), isNull);
    });

    test('confirm() persists and marks the choice made', () async {
      final store = InMemoryLanguageStore();
      final container = containerWith(store);
      final controller = container.read(languageProvider.notifier);

      controller.preview(NjLocale.en);
      await controller.confirm();

      expect(container.read(languageProvider).confirmed, isTrue);
      expect(store.writes, 1);
      expect(await store.read(), NjLocale.en);
    });

    test('confirm() without a pick falls through to Kiswahili', () async {
      // Spec: "no pick — Continue still works; falls through to Kiswahili."
      final store = InMemoryLanguageStore();
      final container = containerWith(store);

      await container.read(languageProvider.notifier).confirm();

      expect(container.read(languageProvider).locale, NjLocale.sw);
      expect(await store.read(), NjLocale.sw);
    });

    test('reopen() unconfirms without losing the language', () {
      final container = containerWith(InMemoryLanguageStore(NjLocale.en));
      final controller = container.read(languageProvider.notifier);

      controller.preview(NjLocale.en);
      controller.reopen();

      expect(container.read(languageProvider).locale, NjLocale.en);
      expect(container.read(languageProvider).confirmed, isFalse);
    });
  });

  group('LanguageState', () {
    test('compares by value', () {
      const a = LanguageState(locale: NjLocale.sw, confirmed: true);
      const b = LanguageState(locale: NjLocale.sw, confirmed: true);
      const c = LanguageState(locale: NjLocale.en, confirmed: true);

      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });

    test('copyWith changes only what it is given', () {
      const base = LanguageState(locale: NjLocale.sw, confirmed: false);
      expect(base.copyWith(confirmed: true).locale, NjLocale.sw);
      expect(base.copyWith(locale: NjLocale.en).confirmed, isFalse);
    });
  });
}
