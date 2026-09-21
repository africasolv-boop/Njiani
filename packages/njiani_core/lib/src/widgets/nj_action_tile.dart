import 'package:flutter/material.dart';

import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';

/// Emphasis for an [NjActionTile]'s leading chip.
enum NjActionTone {
  /// Teal chip. The action we want taken first.
  primary,

  /// Neutral chip. Equally available, less pushed.
  neutral,
}

/// A tall tap target: icon chip, title, and a line explaining what happens.
///
/// Used for the safety actions and saved places. The subtitle is not optional
/// decoration -- on the safety screen it is the difference between a person
/// tapping "Share this trip" confidently and not tapping it at all.
class NjActionTile extends StatelessWidget {
  const NjActionTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.glyph,
    this.icon,
    this.tone = NjActionTone.neutral,
    this.trailing,
  });

  /// Bold first line.
  final String title;

  /// Explanatory second line.
  final String subtitle;

  /// Tap handler.
  final VoidCallback? onTap;

  /// A short character to draw in the chip, as the design does.
  final String? glyph;

  /// An icon for the chip. Takes precedence over [glyph].
  final IconData? icon;

  /// Chip emphasis.
  final NjActionTone tone;

  /// Optional trailing widget, e.g. a "Change" affordance.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;
    final primary = tone == NjActionTone.primary;

    return Semantics(
      button: onTap != null,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: Material(
        color: nj.surface,
        borderRadius: BorderRadius.circular(NjRadius.button),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(NjRadius.button),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(NjRadius.button),
              border: Border.all(color: nj.line, width: NjBorder.control),
            ),
            child: Container(
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.symmetric(
                horizontal: NjSpace.lg,
                vertical: NjSpace.md,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: primary ? nj.tealSoft : nj.surfaceAlt,
                      borderRadius: BorderRadius.circular(NjRadius.chip),
                    ),
                    child: icon != null
                        ? Icon(
                            icon,
                            size: 20,
                            color: primary ? nj.teal : nj.ink,
                          )
                        : Text(
                            glyph ?? '',
                            style: context.njText.titleMedium?.copyWith(
                              color: primary ? nj.teal : nj.ink,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                  const SizedBox(width: NjSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: context.njText.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          subtitle,
                          style: context.njText.bodySmall?.copyWith(
                            fontSize: 13.2,
                            color: nj.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: NjSpace.sm),
                    trailing!,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
