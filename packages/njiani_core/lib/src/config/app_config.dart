/// Build-time configuration, supplied via `--dart-define-from-file`.
///
/// Nothing here has a default value that could reach production by accident:
/// every key defaults to an empty string, and [entries] reports which ones are
/// still missing so the boot screen can show you.
///
/// Usage:
/// ```sh
/// flutter run --dart-define-from-file=../../.env.local
/// ```
///
/// See `docs/CREDENTIALS.md` for where each value comes from.
library;

import '../util/redact.dart';

/// One configurable value and what it is for.
class ConfigEntry {
  const ConfigEntry({
    required this.key,
    required this.value,
    required this.neededAt,
    required this.purpose,
    this.secret = false,
  });

  /// Environment key, e.g. `SUPABASE_URL`.
  final String key;

  /// The resolved value. Empty when unset.
  final String value;

  /// The component that first needs this, e.g. `C3`.
  final String neededAt;

  /// Short human description.
  final String purpose;

  /// When true the value is never rendered, only its presence.
  final bool secret;

  bool get isSet => value.isNotEmpty;

  /// Safe to show on screen.
  ///
  /// A key collapses to a fingerprint. Everything else is shown with
  /// credentials masked rather than hidden outright, because seeing
  /// `postgresql://postgres:••••••@db…` is what tells you the wrong string
  /// was pasted — and hiding the value entirely would have left that
  /// invisible.
  String get display {
    if (!isSet) return 'not set';
    if (secret) return '•••• set (${value.length} chars)';
    return redactSecrets(value);
  }
}

/// All build-time configuration for both Njiani apps.
abstract final class AppConfig {
  // --- Supabase (C3) ---------------------------------------------------
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  // --- Support line (C6) -----------------------------------------------
  //
  // The number behind every "Call Njiani" button. Not a secret -- it is
  // printed on the vehicle stickers -- but it is deployment configuration,
  // and a build with a wrong one strands exactly the people who are already
  // stuck. Blank hides the button rather than dialling nothing.
  static const String supportPhone = String.fromEnvironment('SUPPORT_PHONE');

  // --- Maps and routing (C14) ------------------------------------------
  static const String mapTileUrl = String.fromEnvironment('MAP_TILE_URL');
  static const String osrmBaseUrl = String.fromEnvironment('OSRM_BASE_URL');

  // --- Error tracking (C17) --------------------------------------------
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');

  /// Build environment: `local`, `dev` or `prod`. Defaults to `local`.
  static const String environment =
      String.fromEnvironment('APP_ENV', defaultValue: 'local');

  /// True once the app can actually reach a backend.
  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// What is wrong with [supabaseUrl], in plain words, or null if it is fine.
  ///
  /// Worth checking rather than trusting, because the dashboard offers two
  /// very similar-looking strings and only one of them belongs here. Putting
  /// the database connection string in produced
  ///
  ///     Unsupported scheme 'postgresql' in URI postgresql://postgres:…
  ///
  /// — an error that names neither the setting nor the fix, and that echoed a
  /// live database password back into the UI on its way past.
  static String? get supabaseUrlProblem {
    if (supabaseUrl.isEmpty) return null;

    final uri = Uri.tryParse(supabaseUrl);
    if (uri == null || !uri.hasScheme) {
      return 'SUPABASE_URL is not a URL. It should be '
          'https://<project-ref>.supabase.co';
    }
    if (uri.scheme == 'postgres' || uri.scheme == 'postgresql') {
      return 'SUPABASE_URL holds a database connection string. It needs the '
          'API URL instead: Settings → API → Project URL, '
          'https://<project-ref>.supabase.co. '
          'The database string belongs in DATABASE_URL, for the SQL tests.';
    }
    if (uri.scheme != 'https') {
      return 'SUPABASE_URL must start with https://';
    }
    if (uri.userInfo.isNotEmpty) {
      return 'SUPABASE_URL contains a username and password. The API URL has '
          'neither — check you have not pasted a connection string.';
    }
    if (uri.host.isEmpty) return 'SUPABASE_URL has no host.';
    return null;
  }

  /// True when there is a support number to dial.
  ///
  /// The rejection screen hides its Call button when there is not. A button
  /// that does nothing is worse than no button to a driver who has just been
  /// told they cannot work.
  static bool get hasSupportPhone => supportPhone.trim().isNotEmpty;

  /// Whether the configuration is usable.
  static bool get isUsable => hasSupabase && supabaseUrlProblem == null;

  /// Every configurable value, in the order components will need them.
  ///
  /// The boot screen renders this list, so an unset credential is visible on
  /// the device rather than surfacing later as a confusing runtime error.
  static List<ConfigEntry> get entries => const [
        ConfigEntry(
          key: 'SUPABASE_URL',
          value: supabaseUrl,
          neededAt: 'C3',
          purpose: 'Backend API URL, https://<ref>.supabase.co',
        ),
        ConfigEntry(
          key: 'SUPABASE_ANON_KEY',
          value: supabaseAnonKey,
          neededAt: 'C3',
          purpose: 'Public API key',
          secret: true,
        ),
        ConfigEntry(
          key: 'SUPPORT_PHONE',
          value: supportPhone,
          neededAt: 'C6',
          purpose: 'The number behind "Call Njiani"',
        ),
        ConfigEntry(
          key: 'MAP_TILE_URL',
          value: mapTileUrl,
          neededAt: 'C14',
          purpose: 'Self-hosted .pmtiles',
        ),
        ConfigEntry(
          key: 'OSRM_BASE_URL',
          value: osrmBaseUrl,
          neededAt: 'C14',
          purpose: 'Routing and ETA',
        ),
        ConfigEntry(
          key: 'SENTRY_DSN',
          value: sentryDsn,
          neededAt: 'C17',
          purpose: 'Crash reporting',
          secret: true,
        ),
      ];
}
