import 'package:flutter/material.dart';

import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';

/// How many seats a vehicle sells.
///
/// The number is a property of the vehicle, not a setting: a bajaj has three
/// seats and a boda has one, and the app must never let a driver claim more.
enum NjVehicleType {
  /// Three-wheeler. Three seats, sold independently.
  bajaj(seats: 3, label: 'Bajaj', labelSw: 'Bajaji'),

  /// Motorcycle. One seat.
  boda(seats: 1, label: 'Boda boda', labelSw: 'Bodaboda');

  const NjVehicleType({
    required this.seats,
    required this.label,
    required this.labelSw,
  });

  /// Total seats this vehicle can sell.
  final int seats;

  /// English name.
  final String label;

  /// Kiswahili name.
  final String labelSw;
}

/// A row of seat blocks, filled as passengers are picked up.
///
/// Three blocks for a bajaj, one for a boda. Shown next to the count in words
/// rather than instead of it -- glanceable while driving, but never the only
/// way the information is available.
class NjSeatIndicator extends StatelessWidget {
  const NjSeatIndicator({
    super.key,
    required this.total,
    required this.taken,
    this.size = 26,
  });

  /// Total seats in the vehicle.
  final int total;

  /// Seats currently occupied or claimed.
  final int taken;

  /// Width of a single seat block.
  final double size;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;
    final filled = taken.clamp(0, total);

    return Semantics(
      label: '$filled of $total seats taken',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < total; i++) ...[
            if (i > 0) const SizedBox(width: NjSpace.sm - 2),
            AnimatedContainer(
              duration: NjDuration.fast,
              width: size,
              height: size * 1.15,
              decoration: BoxDecoration(
                color: i < filled ? nj.teal : nj.surface,
                border: Border.all(
                  color: i < filled ? nj.teal : nj.line,
                  width: NjBorder.control,
                ),
                // Squarer at the bottom: a seat back above a seat base.
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                  bottom: Radius.circular(5),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
