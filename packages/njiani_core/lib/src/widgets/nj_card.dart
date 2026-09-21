import 'package:flutter/material.dart';

import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';

/// How a card sits on the page.
enum NjCardStyle {
  /// Recessed tint, no border. Driver details, earnings summaries.
  filled,

  /// Surface with a hairline outline. Request cards in the driver feed.
  outlined,
}

/// A content block: driver details, a request in the feed, a passenger on board.
class NjCard extends StatelessWidget {
  const NjCard({
    super.key,
    required this.child,
    this.style = NjCardStyle.filled,
    this.padding = const EdgeInsets.all(NjSpace.md + 2),
    this.onTap,
  });

  /// Card contents.
  final Widget child;

  /// Filled or outlined.
  final NjCardStyle style;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  /// Optional tap handler. When null the card is not interactive.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;
    final filled = style == NjCardStyle.filled;
    final radius = BorderRadius.circular(
      filled ? NjRadius.card : NjRadius.button,
    );

    final decorated = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: filled ? nj.surfaceAlt : nj.surface,
        borderRadius: radius,
        border: filled
            ? null
            // Border.all defaults to NjBorder.hairline (1.0).
            : Border.all(color: nj.line),
      ),
      child: child,
    );

    if (onTap == null) return decorated;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: decorated,
      ),
    );
  }
}
