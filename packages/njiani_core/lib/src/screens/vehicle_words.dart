/// Localised words for values the database stores in one canonical form.
///
/// A driver's vehicle type and colour are written once, in English, so the
/// admin queue and both apps agree on what was entered. Every screen that
/// shows one back has to translate it, and there are now four of them across
/// both apps -- so the switch lives here rather than in whichever screen
/// happened to need it first.
library;

import '../driver/driver.dart';
import '../l10n/generated/nj_strings.dart';

/// The bare word for a vehicle: "bajaj", "boda".
///
/// Separate from `dVehicleBajaj` ("Bajaj · 3 seats"), which is a picker
/// option and carries the seat count. This is the word that goes inside a
/// sentence -- "Your bajaj is here", "Blue bajaj" -- and a sentence cannot
/// carry the seat count in the middle of it.
String njVehicleWord(VehicleType type, NjStrings strings) => switch (type) {
      VehicleType.bajaj => strings.vehicleBajaj,
      VehicleType.boda => strings.vehicleBoda,
    };

/// The localised name of a colour.
String njVehicleColourLabel(VehicleColour colour, NjStrings strings) =>
    switch (colour) {
      VehicleColour.blue => strings.colourBlue,
      VehicleColour.red => strings.colourRed,
      VehicleColour.green => strings.colourGreen,
      VehicleColour.yellow => strings.colourYellow,
      VehicleColour.black => strings.colourBlack,
      VehicleColour.white => strings.colourWhite,
    };

/// The localised name of a stored colour value, or the raw value if it is not
/// one this build knows.
///
/// An unknown value is shown as written rather than dropped: a colour typed
/// into Studio by hand is still the colour of the vehicle pulling up.
String njColourLabel(String? stored, NjStrings strings) {
  final colour = VehicleColour.tryParse(stored);
  return colour == null ? (stored ?? '') : njVehicleColourLabel(colour, strings);
}
