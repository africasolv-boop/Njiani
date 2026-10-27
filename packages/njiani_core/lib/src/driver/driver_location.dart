import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../places/place.dart';

/// Why there is no position.
enum LocationProblem {
  /// The driver said no. Recoverable: ask again from a button, never in a
  /// loop.
  denied,

  /// Denied with "don't ask again", or restricted by the device. Only
  /// Settings can undo it, so the screen says so instead of re-asking.
  deniedForever,

  /// Location is switched off on the device entirely.
  serviceOff,

  /// Asked, allowed, and no fix arrived in time. Indoors, or a bad sky.
  timedOut,

  unknown,
}

/// A position, or the reason there isn't one.
///
/// Returned rather than thrown. On this screen a missing fix is not an error
/// — the driver picks their starting stage by hand and carries on — so the
/// type says that rather than making the caller catch to find out.
@immutable
class LocationResult {
  const LocationResult.found(this.point)
      : problem = null;
  const LocationResult.failed(this.problem) : point = null;

  final LatLng? point;
  final LocationProblem? problem;

  bool get hasPoint => point != null;
}

/// Where the driver is.
abstract interface class DriverLocation {
  /// Asks for permission if it has not been asked, then takes one fix.
  Future<LocationResult> current();
}

/// Backed by `geolocator`.
class GeolocatorDriverLocation implements DriverLocation {
  const GeolocatorDriverLocation({this.timeout = const Duration(seconds: 8)});

  /// How long to wait for a fix.
  ///
  /// Short on purpose. A driver standing between buildings at Ubungo may
  /// never get one, and the fallback — picking their stage from a list — is
  /// three taps. Waiting thirty seconds to offer it is worse than offering
  /// it now.
  final Duration timeout;

  @override
  Future<LocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult.failed(LocationProblem.serviceOff);
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      switch (permission) {
        case LocationPermission.denied:
          return const LocationResult.failed(LocationProblem.denied);
        case LocationPermission.deniedForever:
          return const LocationResult.failed(LocationProblem.deniedForever);
        case LocationPermission.whileInUse:
        case LocationPermission.always:
        case LocationPermission.unableToDetermine:
          break;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          // Medium is plenty: this picks which bus stage you are at, and the
          // stages are the better part of a kilometre apart. High accuracy
          // costs battery a driver is using all day.
          accuracy: LocationAccuracy.medium,
          timeLimit: timeout,
        ),
      );
      return LocationResult.found(
        LatLng(position.latitude, position.longitude),
      );
    } on TimeoutException {
      return const LocationResult.failed(LocationProblem.timedOut);
    } catch (error) {
      debugPrint('[njiani] location: $error');
      return const LocationResult.failed(LocationProblem.unknown);
    }
  }
}

/// A fixed position, or a fixed refusal.
class FakeDriverLocation implements DriverLocation {
  FakeDriverLocation({this.point, this.problem});

  LatLng? point;

  /// Set to model a driver who said no, or a phone with no sky.
  LocationProblem? problem;

  int asked = 0;

  @override
  Future<LocationResult> current() async {
    asked++;
    if (problem != null) return LocationResult.failed(problem!);
    return LocationResult.found(point ?? const LatLng(-6.8104, 39.2206));
  }
}

/// Supplies the device's location.
final driverLocationProvider =
    Provider<DriverLocation>((ref) => const GeolocatorDriverLocation());
