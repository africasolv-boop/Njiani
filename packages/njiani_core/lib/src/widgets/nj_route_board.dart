import 'package:flutter/material.dart';

import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';
import '../design/nj_typography.dart';

/// The yellow route band across the top of the driver's screen.
///
/// Borrowed from the painted route boards on daladala, which everyone in Dar
/// already reads at a glance. This is the app's signature component: it states
/// the driver's declared direction, which is the fact the entire product is
/// built around.
///
/// Yellow in both light and dark themes -- it is a physical object being
/// imitated, not a surface that should follow the device appearance.
class NjRouteBoard extends StatelessWidget {
  const NjRouteBoard({
    super.key,
    required this.from,
    required this.to,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  /// Origin, e.g. `Ubungo`.
  final String from;

  /// Destination, e.g. `Kimara Korogwe`.
  final String to;

  /// Small line under the route, e.g. `You're online`.
  final String? subtitle;

  /// Trailing button text, e.g. `Change`.
  final String? actionLabel;

  /// Trailing button callback. The button only shows when both this and
  /// [actionLabel] are provided.
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;
    final showAction = actionLabel != null && onAction != null;

    return Semantics(
      container: true,
      label: 'Route, $from to $to${subtitle == null ? '' : '. $subtitle'}',
      child: Container(
        width: double.infinity,
        color: nj.bajaj,
        padding: const EdgeInsets.symmetric(
          horizontal: NjSpace.lg,
          vertical: NjSpace.md - 2,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$from to $to'.toUpperCase(),
                    style: NjTypography.routeBoard.copyWith(color: nj.bajajInk),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: context.njText.bodySmall?.copyWith(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        // Deliberately not a muted token: on yellow, grey
                        // reads as disabled. Dimmed ink keeps the hierarchy.
                        color: nj.bajajInk.withValues(alpha: 0.75),
                      ),
                    ),
                ],
              ),
            ),
            if (showAction) ...[
              const SizedBox(width: NjSpace.sm),
              Semantics(
                button: true,
                child: GestureDetector(
                  onTap: onAction,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 36),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(
                      horizontal: NjSpace.md - 2,
                      vertical: NjSpace.xs + 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(NjRadius.chip - 2),
                    ),
                    child: Text(
                      actionLabel!,
                      style: context.njText.labelSmall?.copyWith(
                        color: nj.bajajInk,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
