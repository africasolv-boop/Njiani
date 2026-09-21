import 'package:flutter/material.dart';

import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';

/// A full-width selectable row: label on the left, a note on the right.
///
/// Selection is shown with a teal 2pt border and a tinted fill rather than a
/// radio dot. On a sunlit screen a filled row is readable at arm's length; a
/// 20pt radio is not.
class NjOptionTile extends StatelessWidget {
  const NjOptionTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.note,
  });

  /// The option's name.
  final String label;

  /// Whether this option is currently chosen.
  final bool selected;

  /// Tap handler.
  final VoidCallback onTap;

  /// Trailing explanatory note, e.g. 'Chaguo la kwanza'.
  final String? note;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;

    return Semantics(
      inMutuallyExclusiveGroup: true,
      selected: selected,
      button: true,
      label: note == null ? label : '$label. $note',
      excludeSemantics: true,
      child: Material(
        color: selected ? nj.tealSoft : nj.surface,
        borderRadius: BorderRadius.circular(NjRadius.button),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(NjRadius.button),
          child: AnimatedContainer(
            duration: NjDuration.fast,
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(
              horizontal: NjSpace.lg + 2,
              vertical: NjSpace.md + 2,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(NjRadius.button),
              border: Border.all(
                color: selected ? nj.teal : nj.line,
                width: NjBorder.control,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: context.njText.labelLarge,
                  ),
                ),
                if (note != null) ...[
                  const SizedBox(width: NjSpace.md),
                  Flexible(
                    child: Text(
                      note!,
                      textAlign: TextAlign.end,
                      style: context.njText.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: nj.muted,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
