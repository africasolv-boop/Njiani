import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'language_store.dart';
import 'nj_locale.dart';

/// The app's language, and whether the user has actually chosen it.
///
/// [confirmed] is the difference between "we are showing Kiswahili because it
/// is the default" and "this user asked for Kiswahili". Only the second one
/// stops the language screen being shown again, which is what the design means
/// by never blocking a returning user.
class LanguageState {
  const LanguageState({required this.locale, required this.confirmed});

  /// The language to render in right now.
  final NjLocale locale;

  /// Whether the user has confirmed this choice on the language screen.
  final bool confirmed;

  /// The state before anything has been read from storage.
  static const LanguageState initial =
      LanguageState(locale: NjLocale.fallback, confirmed: false);

  LanguageState copyWith({NjLocale? locale, bool? confirmed}) => LanguageState(
        locale: locale ?? this.locale,
        confirmed: confirmed ?? this.confirmed,
      );

  @override
  bool operator ==(Object other) =>
      other is LanguageState &&
      other.locale == locale &&
      other.confirmed == confirmed;

  @override
  int get hashCode => Object.hash(locale, confirmed);

  @override
  String toString() => 'LanguageState($locale, confirmed: $confirmed)';
}

/// Supplies the [LanguageStore].
///
/// Overridden at startup with a store backed by `shared_preferences`, which
/// has to be awaited before the first frame. Tests override it with
/// [InMemoryLanguageStore].
final languageStoreProvider = Provider<LanguageStore>(
  (ref) => throw UnimplementedError(
    'Override languageStoreProvider at startup. See NjianiRoot.bootstrap().',
  ),
);

/// Reads and writes the chosen language.
class LanguageController extends Notifier<LanguageState> {
  @override
  LanguageState build() => LanguageState.initial;

  LanguageStore get _store => ref.read(languageStoreProvider);

  /// Loads any previously confirmed choice.
  ///
  /// Call once at startup, before the first frame, so a returning user never
  /// sees the language screen flash past.
  Future<void> load() async {
    final stored = await _store.read();
    state = stored == null
        ? LanguageState.initial
        : LanguageState(locale: stored, confirmed: true);
  }

  /// Previews [locale] without confirming it.
  ///
  /// Tapping an option changes the language immediately, so the choice is
  /// demonstrated rather than described. Nothing is persisted until [confirm].
  void preview(NjLocale locale) {
    state = state.copyWith(locale: locale);
  }

  /// Confirms the current selection and remembers it.
  ///
  /// Confirming without having tapped anything is valid and falls through to
  /// the default, as the design requires.
  Future<void> confirm() async {
    await _store.write(state.locale);
    state = state.copyWith(confirmed: true);
  }

  /// Forgets the choice, so the language screen is shown again.
  ///
  /// Used by the change-language affordance until there is a Settings screen.
  void reopen() {
    state = state.copyWith(confirmed: false);
  }
}

/// The app's current language.
final languageProvider =
    NotifierProvider<LanguageController, LanguageState>(LanguageController.new);
