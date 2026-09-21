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

  /// Safe to show on screen: secrets collapse to a fingerprint.
  String get display {
    if (!isSet) return 'not set';
    if (secret) return '•••• set (${value.length} chars)';
    return value;
  }
}

/// All build-time configuration for both Njiani apps.
abstract final class AppConfig {
  // --- Supabase (C3) ---------------------------------------------------
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');

  // --- Maps and routing (C14) ------------------------------------------
  static const String mapTileUrl = String.fromEnvironment('MAP_TILE_URL');
  static const String osrmBaseUrl = String.fromEnvironment('OSRM_BASE_URL');

  // --- Error tracking (C17) --------------------------------------------
  static const String sentryDsn = String.fromEnvironment('SENTRY_DSN');

  /// Build environment: `local`, `dev` or `prod`. Defaults to `local`.
  static const String environment =
      String.fromEnvironment('APP_ENV', defaultValue: 'local');

  /// True once the app can actually reach a backend.
  static bool get hasSupabase => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Every configurable value, in the order components will need them.
  ///
  /// The boot screen renders this list, so an unset credential is visible on
  /// the device rather than surfacing later as a confusing runtime error.
  static List<ConfigEntry> get entries => const [
        ConfigEntry(
          key: 'SUPABASE_URL',
          value: supabaseUrl,
          neededAt: 'C3',
          purpose: 'Backend project URL',
        ),
        ConfigEntry(
          key: 'SUPABASE_ANON_KEY',
          value: supabaseAnonKey,
          neededAt: 'C3',
          purpose: 'Public API key',
          secret: true,
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
