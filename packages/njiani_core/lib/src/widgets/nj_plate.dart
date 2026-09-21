import 'package:flutter/material.dart';

import '../design/nj_tokens.dart';
import '../design/nj_typography.dart';

/// A vehicle number plate, drawn to look like the real thing.
///
/// Passengers verify the bajaj that pulls up by reading its plate, so this is a
/// safety component, not decoration: it uses fixed plate colours in both
/// themes, and keeps the wide letter tracking that makes a plate scannable at
/// a distance.
///
/// It deliberately does not shrink or ellipsise -- a half-rendered plate is
/// worse than useless for identifying a vehicle. When placing one in a [Row],
/// make the *sibling* flexible, not the plate.
class NjPlateBadge extends StatelessWidget {
  const NjPlateBadge({super.key, required this.plate, this.compact = false});

  /// The registration, e.g. `T 482 DKT`.
  final String plate;

  /// Smaller variant for use inside dense cards.
  final bool compact;

  /// Plate yellow. Fixed -- a real plate does not have a dark mode.
  static const Color plateYellow = Color(0xFFFFD21F);

  /// Plate lettering and border.
  static const Color plateInk = Color(0xFF111111);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Number plate $plate',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? NjSpace.sm - 2 : NjSpace.md - 2,
          vertical: compact ? 1 : 3,
        ),
        decoration: BoxDecoration(
          color: plateYellow,
          border: Border.all(color: plateInk, width: NjBorder.control),
          borderRadius: BorderRadius.circular(NjRadius.plate),
        ),
        child: Text(
          plate.toUpperCase(),
          style: NjTypography.plate.copyWith(fontSize: compact ? 13 : 18.4),
        ),
      ),
    );
  }
}
