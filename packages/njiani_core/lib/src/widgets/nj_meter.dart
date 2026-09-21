import 'package:flutter/material.dart';

import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';

/// A flat progress bar.
///
/// Three jobs in the design, all the same shape: a counter-offer countdown,
/// the demand bars in stage mode, and the seats-filled blocks in driver
/// history.
class NjMeter extends StatelessWidget {
  const NjMeter({
    super.key,
    required this.value,
    this.color,
    this.height = 6,
  });

  /// Fill fraction, 0 to 1. Values outside the range are clamped rather than
  /// allowed to overflow the track.
  final double value;

  /// Fill colour. Defaults to bajaj yellow.
  final Color? color;

  /// Bar thickness.
  final double height;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;

    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: nj.surfaceAlt,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: value.clamp(0.0, 1.0),
          child: Container(color: color ?? nj.bajaj),
        ),
      ),
    );
  }
}

/// A row of segments, filled from the left.
///
/// Reuses the seat vocabulary in driver history: each block is one seat that
/// was or was not filled that day.
class NjSegmentBar extends StatelessWidget {
  const NjSegmentBar({
    super.key,
    required this.total,
    required this.filled,
    this.height = 6,
  });

  /// Number of segments.
  final int total;

  /// How many are filled, from the left.
  final int filled;

  /// Segment thickness.
  final double height;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;

    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: NjSpace.sm - 2),
          Expanded(
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: i < filled ? nj.teal : nj.line,
                borderRadius: BorderRadius.circular(height),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
