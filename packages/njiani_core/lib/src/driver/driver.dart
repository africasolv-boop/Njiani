import 'package:flutter/foundation.dart';

/// Bajaj or boda boda.
///
/// Not a preference. A bajaj is a three-wheeler with a bench; a boda boda is a
/// motorcycle. How many people fit is a physical fact, which is why [seats] is
/// a property of the type and not a field a driver can set -- the database
/// decides it by check constraint for the same reason.
enum VehicleType {
  bajaj('bajaj', 3),
  boda('boda', 1);

  const VehicleType(this.code, this.seats);

  /// The `public.vehicle_type` enum value.
  final String code;

  /// How many passengers the vehicle carries.
  final int seats;

  static VehicleType? tryParse(String? code) {
    for (final type in values) {
      if (type.code == code) return type;
    }
    return null;
  }
}

/// The vehicle colours the sign-up screen offers.
///
/// A fixed list, not a free-text field. Colour exists so a passenger can pick
/// the right bajaj out of four parked together, which only works if "green"
/// and "Kijani" and "grean" are the same answer. The [code] is what is stored
/// -- one canonical English value, so the admin queue and the passenger's
/// screen agree -- and the label is localised for display.
enum VehicleColour {
  blue('Blue'),
  red('Red'),
  green('Green'),
  yellow('Yellow'),
  black('Black'),
  white('White');

  const VehicleColour(this.code);

  /// What is written to `drivers.colour`.
  final String code;

  /// Matches case-insensitively: a row written by hand in Studio, or by an
  /// earlier build, should still render rather than falling off the screen.
  static VehicleColour? tryParse(String? code) {
    if (code == null) return null;
    final wanted = code.trim().toLowerCase();
    for (final colour in values) {
      if (colour.code.toLowerCase() == wanted) return colour;
    }
    return null;
  }
}

/// Where a driver's application has got to.
///
/// Mirrors `public.driver_status`. A driver has no privilege to write this
/// column; only an admin moves it, through `review_driver()`.
enum DriverStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected'),
  suspended('suspended');

  const DriverStatus(this.code);

  final String code;

  /// True when this driver may see the request feed.
  bool get canDrive => this == DriverStatus.approved;

  /// An unknown value is treated as [pending].
  ///
  /// The conservative direction: a status this build does not recognise must
  /// never be mistaken for approval. If a future release adds a state, an old
  /// binary shows "under review" rather than opening the feed.
  static DriverStatus parse(String? code) {
    for (final status in values) {
      if (status.code == code) return status;
    }
    return DriverStatus.pending;
  }
}

/// A driver's application and its verification state.
@immutable
class Driver {
  const Driver({
    required this.profileId,
    required this.vehicleType,
    required this.plate,
    required this.colour,
    required this.status,
    this.licencePath,
    this.rejectionReason,
    this.rating,
    this.tripsCount = 0,
    this.reviewedAt,
    this.createdAt,
  });

  factory Driver.fromRow(Map<String, dynamic> row) => Driver(
        profileId: row['profile_id'] as String,
        vehicleType:
            VehicleType.tryParse(row['vehicle_type'] as String?) ??
                VehicleType.bajaj,
        plate: row['plate'] as String? ?? '',
        colour: row['colour'] as String? ?? '',
        status: DriverStatus.parse(row['status'] as String?),
        licencePath: row['licence_path'] as String?,
        rejectionReason: row['rejection_reason'] as String?,
        rating: (row['rating'] as num?)?.toDouble(),
        tripsCount: (row['trips_count'] as num?)?.toInt() ?? 0,
        reviewedAt: DateTime.tryParse(row['reviewed_at'] as String? ?? ''),
        createdAt: DateTime.tryParse(row['created_at'] as String? ?? ''),
      );

  /// The auth user id. Also the primary key of the `drivers` row.
  final String profileId;

  final VehicleType vehicleType;

  /// Upper-cased. Drivers type a plate in every casing there is.
  final String plate;

  final String colour;

  final DriverStatus status;

  /// Path inside the private `licences` bucket. Never a URL: a URL that works
  /// without a signature would mean the bucket was not private.
  final String? licencePath;

  /// Written by a person, and required for a rejection. The rejection screen
  /// has nothing to say without it.
  final String? rejectionReason;

  final double? rating;

  final int tripsCount;

  final DateTime? reviewedAt;

  final DateTime? createdAt;

  /// How many seats this driver's vehicle has.
  int get seats => vehicleType.seats;

  Driver copyWith({
    VehicleType? vehicleType,
    String? plate,
    String? colour,
    DriverStatus? status,
    String? licencePath,
    String? rejectionReason,
    bool clearRejectionReason = false,
  }) =>
      Driver(
        profileId: profileId,
        vehicleType: vehicleType ?? this.vehicleType,
        plate: plate ?? this.plate,
        colour: colour ?? this.colour,
        status: status ?? this.status,
        licencePath: licencePath ?? this.licencePath,
        rejectionReason:
            clearRejectionReason ? null : rejectionReason ?? this.rejectionReason,
        rating: rating,
        tripsCount: tripsCount,
        reviewedAt: reviewedAt,
        createdAt: createdAt,
      );

  @override
  bool operator ==(Object other) =>
      other is Driver &&
      other.profileId == profileId &&
      other.vehicleType == vehicleType &&
      other.plate == plate &&
      other.colour == colour &&
      other.status == status &&
      other.licencePath == licencePath &&
      other.rejectionReason == rejectionReason;

  @override
  int get hashCode => Object.hash(profileId, vehicleType, plate, colour, status,
      licencePath, rejectionReason);

  @override
  String toString() => 'Driver($plate, ${vehicleType.code}, ${status.code})';
}

/// What the sign-up screen has collected so far.
///
/// A separate type from [Driver] because the two are not the same thing: this
/// one is allowed to be incomplete, and [isComplete] is the single place that
/// decides whether Submit is enabled. The screen asks this object, rather than
/// re-deriving the rule from three controllers and a nullable path.
@immutable
class DriverApplication {
  const DriverApplication({
    this.name = '',
    this.vehicleType = VehicleType.bajaj,
    this.plate = '',
    this.colour = '',
    this.licencePath,
  });

  /// As on the licence. Written to `profiles.display_name`.
  final String name;

  final VehicleType vehicleType;

  final String plate;

  final String colour;

  /// Set once the photo has finished uploading. Null means there is nothing
  /// for a person to check, which is why Submit stays disabled.
  final String? licencePath;

  /// Plates are 4-16 characters by database constraint. Tanzanian civilian
  /// plates read `T 123 ABC` and motorcycles `MC 123 AB`, but the field is
  /// deliberately not pattern-matched: a driver holding a plate this app
  /// refuses to accept has no way forward, and a person checks the photo
  /// against the plate anyway.
  static const int plateMinLength = 4;
  static const int plateMaxLength = 16;

  String get normalisedPlate => plate.trim().toUpperCase();
  String get normalisedName => name.trim();

  bool get hasName => normalisedName.length >= 2;
  bool get hasPlate =>
      normalisedPlate.length >= plateMinLength &&
      normalisedPlate.length <= plateMaxLength;
  bool get hasColour => colour.trim().isNotEmpty;
  bool get hasLicence => licencePath != null;

  /// Every requirement from the design: name, plate and licence photo. Colour
  /// is included because the database requires it and the pending screen
  /// shows it back.
  bool get isComplete => hasName && hasPlate && hasColour && hasLicence;

  DriverApplication copyWith({
    String? name,
    VehicleType? vehicleType,
    String? plate,
    String? colour,
    String? licencePath,
    bool clearLicencePath = false,
  }) =>
      DriverApplication(
        name: name ?? this.name,
        vehicleType: vehicleType ?? this.vehicleType,
        plate: plate ?? this.plate,
        colour: colour ?? this.colour,
        licencePath:
            clearLicencePath ? null : licencePath ?? this.licencePath,
      );
}
