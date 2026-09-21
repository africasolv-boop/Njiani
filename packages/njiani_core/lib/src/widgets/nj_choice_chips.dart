import 'package:flutter/material.dart';

import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';
import '../util/money.dart';

/// A row of tappable suggestions, used for the passenger's price shortcuts.
///
/// The design offers three: the bottom of the route's usual band, the middle,
/// and the top. Most passengers tap rather than type, so these carry most of
/// the pricing decisions in the app.
class NjPriceChips extends StatelessWidget {
  const NjPriceChips({
    super.key,
    required this.prices,
    required this.selected,
    required this.onSelected,
  });

  /// Suggested prices in whole shillings.
  final List<int> prices;

  /// The currently chosen price, if it matches one of [prices].
  final int? selected;

  /// Called with the tapped price.
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < prices.length; i++) ...[
          if (i > 0) const SizedBox(width: NjSpace.sm),
          Expanded(
            child: NjChoiceChip(
              label: groupDigits(prices[i]),
              selected: prices[i] == selected,
              onTap: () => onSelected(prices[i]),
            ),
          ),
        ],
      ],
    );
  }
}

/// A single outlined chip that fills teal when chosen.
class NjChoiceChip extends StatelessWidget {
  const NjChoiceChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  /// Visible text.
  final String label;

  /// Whether this chip is chosen.
  final bool selected;

  /// Tap callback.
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
            horizontal: NjSpace.md,
            vertical: NjSpace.sm,
          ),
          decoration: BoxDecoration(
            color: selected ? nj.tealSoft : nj.surface,
            borderRadius: BorderRadius.circular(NjRadius.chip),
            border: Border.all(
              color: selected ? nj.teal : nj.line,
              width: NjBorder.control,
            ),
          ),
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: context.njText.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: nj.ink,
            ),
          ),
        ),
      ),
    );
  }
}
