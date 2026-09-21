import 'package:flutter/material.dart';

import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';

/// One secondary figure beside the headline in an [NjStatCard].
class NjStat {
  const NjStat({required this.label, required this.value});

  /// Caption, e.g. 'This week'.
  final String label;

  /// Figure, e.g. 'TSh 84,500'.
  final String value;
}

/// The dark hero card carrying a driver's earnings.
///
/// Ink-filled rather than tinted: this is the number a driver opens the app
/// for, and the design gives it the strongest contrast on the screen. It stays
/// ink-on-white-text in both themes, so the figure reads the same at 6am and
/// at night.
class NjStatCard extends StatelessWidget {
  const NjStatCard({
    super.key,
    required this.caption,
    required this.value,
    this.stats = const [],
  });

  /// Small line above the figure, e.g. 'Today · 4 trips'.
  final String caption;

  /// The headline figure, e.g. 'TSh 6,200'.
  final String value;

  /// Up to a few supporting figures below.
  final List<NjStat> stats;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;
    // Fixed ink/white pairing: the earnings figure must not lose weight in
    // dark mode, where a tinted card would sit almost flat against the page.
    final surface = nj.ink;
    final onSurface = nj.bg;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(NjSpace.lg + 2),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(NjRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            caption,
            style: context.njText.bodySmall
                ?.copyWith(color: onSurface.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: context.njText.displayMedium?.copyWith(color: onSurface),
          ),
          if (stats.isNotEmpty) ...[
            const SizedBox(height: NjSpace.md + 2),
            Wrap(
              spacing: NjSpace.lg + 2,
              runSpacing: NjSpace.md,
              children: [
                for (final stat in stats)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        stat.label,
                        style: context.njText.bodySmall?.copyWith(
                          fontSize: 12.5,
                          color: onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      Text(
                        stat.value,
                        style: context.njText.bodyMedium?.copyWith(
                          color: onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
