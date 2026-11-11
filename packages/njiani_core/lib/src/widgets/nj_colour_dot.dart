import 'package:flutter/material.dart';

import '../driver/driver.dart';

/// The vehicle's colour, as the colour itself.
///
/// A safety component, not decoration. Colour exists so a passenger can pick
/// the right bajaj out of four parked together, and a word beats a swatch for
/// that only until the passenger does not read the language the word is in.
/// Both ship: the dot and the localised name sit side by side.
///
/// The swatches are fixed in both themes for the same reason [NjPlateBadge]'s
/// yellow is: a blue bajaj is not a different colour at night.
class NjColourDot extends StatelessWidget {
  const NjColourDot({super.key, required this.colour, this.size = 12});

  /// The stored value from `drivers.colour` — one canonical English word.
  final String? colour;

  final double size;

  /// What each stored colour looks like. Mid-tones rather than pure values:
  /// a vehicle painted #0000FF does not exist, and the dot has to look like
  /// the thing pulling up.
  static const Map<VehicleColour, Color> swatches = {
    VehicleColour.blue: Color(0xFF1F5FB8),
    VehicleColour.red: Color(0xFFC0392B),
    VehicleColour.green: Color(0xFF1E8449),
    VehicleColour.yellow: Color(0xFFF2B705),
    VehicleColour.black: Color(0xFF1D2226),
    VehicleColour.white: Color(0xFFF7F9F8),
  };

  @override
  Widget build(BuildContext context) {
    final known = VehicleColour.tryParse(colour);

    // An unknown value gets no dot at all. A grey circle next to the word
    // "Green" would be worse than the word on its own.
    if (known == null) return const SizedBox.shrink();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: swatches[known],
        shape: BoxShape.circle,
        // The outline is what keeps white visible on white and black
        // visible in dark mode.
        border: Border.all(color: const Color(0x33000000)),
      ),
    );
  }
}
