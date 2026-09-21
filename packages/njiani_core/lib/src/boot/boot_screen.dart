import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../config/app_identity.dart';
import 'njiani_mark.dart';

/// The C0 boot screen, shared by both apps.
///
/// Its job is to prove three things on a real device, before any feature exists:
///   1. the app builds and launches on iOS and Android,
///   2. it is rendering code from `njiani_core` -- this whole screen lives in the
///      shared package, so if you can see it, the monorepo wiring works,
///   3. which credentials are still unset, and which component needs each one.
///
/// C1 replaces the ad-hoc styling here with the real design system.
class BootScreen extends StatelessWidget {
  const BootScreen({super.key, required this.app});

  final NjianiApp app;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          children: [
            const NjianiMark(size: 56),
            const SizedBox(height: 20),
            Text(
              app.label,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(app.tagline, style: theme.textTheme.bodyLarge),
            Text(
              app.taglineSw,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),

            const SizedBox(height: 32),
            _SectionLabel('Wiring'),
            _FactRow('Component', 'C0 — scaffold'),
            _FactRow('Rendered by', 'package njiani_core'),
            _FactRow('Bundle id', app.bundleId),
            _FactRow('Environment', AppConfig.environment),
            _FactRow('Theme', dark ? 'dark' : 'light'),

            const SizedBox(height: 28),
            _SectionLabel('Configuration'),
            Text(
              AppConfig.hasSupabase
                  ? 'Backend configured.'
                  : 'No credentials needed yet — C0 runs entirely offline. '
                      'Each value below is added when its component arrives.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            for (final entry in AppConfig.entries) _ConfigRow(entry: entry),

            const SizedBox(height: 28),
            Text(
              'See docs/CREDENTIALS.md for where each value comes from, and '
              'docs/BUILD_LOG.md for what ships next.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text.toUpperCase(),
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
}

class _FactRow extends StatelessWidget {
  const _FactRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// One credential, showing whether it is set and which component needs it.
class _ConfigRow extends StatelessWidget {
  const _ConfigRow({required this.entry});

  final ConfigEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ok = entry.isSet;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2, right: 10),
            child: Icon(
              ok ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
              color: ok
                  ? const Color(0xFF0E6E6C)
                  : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    _Pill(entry.neededAt),
                  ],
                ),
                Text(
                  '${entry.purpose} — ${entry.display}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
