import 'package:flutter/material.dart';

import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';

/// One option in an [NjSegmented].
class NjSegment<T> {
  const NjSegment({required this.value, required this.label, this.icon});

  /// The value this option selects.
  final T value;

  /// Visible text.
  final String label;

  /// Optional leading icon.
  final IconData? icon;
}

/// A two-or-more-way toggle in a recessed trough.
///
/// Used for Bajaj / Boda boda, and for the Requests / On board tabs. Always
/// shows every option, because the choice between a three-seat bajaj and a
/// one-seat boda changes what the rest of the screen means.
class NjSegmented<T> extends StatelessWidget {
  const NjSegmented({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  /// The available options.
  final List<NjSegment<T>> segments;

  /// The currently selected value.
  final T value;

  /// Called with the newly selected value.
  final ValueChanged<T> onChanged;

  /// Describes the group to screen readers, e.g. 'Vehicle type'.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;

    return Semantics(
      label: semanticLabel,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(NjSpace.xs),
        decoration: BoxDecoration(
          color: nj.surfaceAlt,
          borderRadius: BorderRadius.circular(NjRadius.input),
        ),
        child: Row(
          children: [
            for (final segment in segments)
              Expanded(
                child: _Option<T>(
                  segment: segment,
                  selected: segment.value == value,
                  onTap: () => onChanged(segment.value),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Option<T> extends StatelessWidget {
  const _Option({
    required this.segment,
    required this.selected,
    required this.onTap,
  });

  final NjSegment<T> segment;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;

    return Semantics(
      selected: selected,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: NjDuration.fast,
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(
            horizontal: NjSpace.sm,
            vertical: NjSpace.sm + 1,
          ),
          decoration: BoxDecoration(
            color: selected ? nj.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(NjRadius.chip - 2),
            boxShadow: selected ? NjShadow.segment(nj) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (segment.icon != null) ...[
                Icon(
                  segment.icon,
                  size: 18,
                  color: selected ? nj.ink : nj.muted,
                ),
                const SizedBox(width: NjSpace.xs + 2),
              ],
              Flexible(
                child: Text(
                  segment.label,
                  overflow: TextOverflow.ellipsis,
                  style: context.njText.titleSmall?.copyWith(
                    color: selected ? nj.ink : nj.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
