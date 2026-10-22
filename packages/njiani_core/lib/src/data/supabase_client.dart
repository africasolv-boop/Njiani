import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';

/// Initialises the Supabase client, if this build has credentials.
///
/// Returns false when [AppConfig.hasSupabase] is false. The app then runs with
/// a repository that reports `AuthFailure.notConfigured`, which is visibly
/// different from a network error -- a missing credential should look like a
/// missing credential, not like a broken backend.
Future<SupabaseClient?> initSupabase() async {
  if (!AppConfig.hasSupabase) return null;

  // Refuse a URL that is clearly not the API URL. Handing a database
  // connection string to the SDK produces "Unsupported scheme 'postgresql'"
  // from somewhere deep inside it, with the whole URI -- password included --
  // in the message.
  final problem = AppConfig.supabaseUrlProblem;
  if (problem != null) {
    debugPrint('[njiani] Supabase is not configured correctly: $problem');
    return null;
  }

  // `publishableKey` is the current name for what the dashboard still labels
  // the `anon` `public` key on older projects. The client accepts either, so
  // the legacy JWT works here unchanged.
  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseAnonKey,
  );
  return Supabase.instance.client;
}

/// The initialised client, or null when this build has no credentials.
///
/// Overridden at startup so nothing reaches for `Supabase.instance` before
/// [initSupabase] has run -- which would throw rather than degrade.
final supabaseProvider = Provider<SupabaseClient?>((ref) => null);
