import 'dart:async';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'driver.dart';

/// Why a driver application could not be filed.
enum DriverFailure {
  /// No session. Should be unreachable -- the router gates on one.
  notSignedIn,

  /// The photo did not reach the bucket. The design is explicit that this is
  /// its own state: the driver's typed details are kept and only the photo is
  /// retried.
  uploadFailed,

  /// The file is bigger than the bucket allows, or not an image the bucket
  /// accepts. Enforced by Storage, so it is reported, not guessed at.
  photoRejected,

  /// This build has no backend. Looks different from a broken one on purpose.
  notConfigured,

  /// The row moved underneath the screen -- re-submitting something that is
  /// no longer rejected, most likely because an admin got there first.
  staleState,

  /// No connection.
  offline,

  unknown,
}

/// A failure with the server's own words kept, for diagnosis.
class DriverError implements Exception {
  const DriverError(this.failure, {this.detail});

  final DriverFailure failure;

  /// What the server said. Shown in debug builds; never parsed.
  final String? detail;

  @override
  String toString() =>
      'DriverError(${failure.name}${detail == null ? '' : ': $detail'})';
}

/// Reading, filing and re-filing a driver application.
abstract interface class DriverRepository {
  /// The signed-in user's driver row, or null if they have never applied.
  Future<Driver?> load();

  /// Uploads a licence photo and returns its path inside the bucket.
  ///
  /// Separate from [submit] because the design requires it: an upload that
  /// fails must not cost the driver the details they typed, so the photo goes
  /// first, on its own, and can be retried on its own.
  Future<String> uploadLicence({
    required Uint8List bytes,
    required String contentType,
  });

  /// Files a new application. The row starts `pending`.
  Future<Driver> submit(DriverApplication application);

  /// Replaces the photo on a rejected application and returns it to the queue.
  ///
  /// Calls `resubmit_driver_licence()`, because `status` is the one column a
  /// driver cannot write.
  Future<Driver> resubmitLicence(String licencePath);

  /// Fires whenever the signed-in driver's own row changes.
  ///
  /// The approval arrives here. A driver who submitted at a stage and closed
  /// the app should not have to reinstall to find out they were approved.
  Stream<Driver> watch();
}

/// Backed by the `drivers` table and the private `licences` bucket.
class SupabaseDriverRepository implements DriverRepository {
  const SupabaseDriverRepository(this._client);

  final SupabaseClient _client;

  static const String _table = 'drivers';

  /// The private bucket from `20261026000100_storage_licences.sql`.
  static const String bucket = 'licences';

  static const String _columns =
      'profile_id, vehicle_type, plate, colour, status, licence_path, '
      'rejection_reason, rating, trips_count, reviewed_at, created_at';

  String? get _userId => _client.auth.currentUser?.id;

  @override
  Future<Driver?> load() async {
    final id = _userId;
    if (id == null) return null;

    try {
      final row = await _client
          .from(_table)
          .select(_columns)
          .eq('profile_id', id)
          .maybeSingle();
      return row == null ? null : Driver.fromRow(row);
    } on PostgrestException catch (error) {
      throw DriverError(_classify(error), detail: error.message);
    }
  }

  @override
  Future<String> uploadLicence({
    required Uint8List bytes,
    required String contentType,
  }) async {
    final id = _userId;
    if (id == null) {
      throw const DriverError(DriverFailure.notSignedIn);
    }

    // `<uid>/licence.<ext>`. The first folder segment has to be the owner:
    // that is what the bucket's policies match on, and the only reason "your
    // own object" is expressible as a policy at all.
    //
    // A fixed name rather than a timestamp, with upsert: a driver who retakes
    // the photo four times leaves one object, not four. Nothing points at an
    // old version, so keeping them would only mean more of a licence photo
    // sitting in a bucket than necessary.
    final path = '$id/licence.${_extensionFor(contentType)}';

    try {
      await _client.storage.from(bucket).uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(contentType: contentType, upsert: true),
          );
      return path;
    } on StorageException catch (error) {
      // Storage enforces the size cap and the MIME allow-list, so these come
      // back from the server rather than being guessed at on the client.
      final message = error.message.toLowerCase();
      final tooBig = error.statusCode == '413' ||
          message.contains('exceeded the maximum allowed size') ||
          message.contains('too large');
      final wrongType = message.contains('mime type') ||
          message.contains('not supported');
      throw DriverError(
        tooBig || wrongType
            ? DriverFailure.photoRejected
            : DriverFailure.uploadFailed,
        detail: error.message,
      );
    } catch (error) {
      throw DriverError(DriverFailure.uploadFailed, detail: '$error');
    }
  }

  @override
  Future<Driver> submit(DriverApplication application) async {
    final id = _userId;
    if (id == null) {
      throw const DriverError(DriverFailure.notSignedIn);
    }

    final fields = {
      'vehicle_type': application.vehicleType.code,
      'plate': application.normalisedPlate,
      'colour': application.colour.trim(),
      'licence_path': application.licencePath,
    };

    // An insert, then an update if the row is already there -- deliberately
    // NOT `upsert`.
    //
    // PostgREST builds an upsert as `ON CONFLICT (profile_id) DO UPDATE SET
    // profile_id = excluded.profile_id, ...`, putting the conflict target in
    // the SET list. `profile_id` is not in the C3 update grant, on purpose, so
    // that fails with `permission denied for table drivers` the moment a row
    // exists -- which is exactly the retry case this has to survive. The
    // alternative was to widen the grant to cover a primary key, which is not
    // a trade worth making for one round trip. `05_driver_review_test.sql`
    // asserts that the upsert stays refused.
    try {
      final row = await _client
          .from(_table)
          .insert({'profile_id': id, ...fields})
          .select(_columns)
          .single();
      return Driver.fromRow(row);
    } on PostgrestException catch (error) {
      // 23505 unique_violation: the row is already there. Reached when a
      // previous submit wrote the row and the reply never came back.
      if (error.code != '23505') {
        throw DriverError(_classify(error), detail: error.message);
      }
    }

    try {
      final row = await _client
          .from(_table)
          .update(fields)
          .eq('profile_id', id)
          .select(_columns)
          .single();
      return Driver.fromRow(row);
    } on PostgrestException catch (error) {
      throw DriverError(_classify(error), detail: error.message);
    }
  }

  @override
  Future<Driver> resubmitLicence(String licencePath) async {
    try {
      await _client.rpc<void>(
        'resubmit_driver_licence',
        params: {'p_licence_path': licencePath},
      );
    } on PostgrestException catch (error) {
      throw DriverError(_classify(error), detail: error.message);
    }

    // The function returns the new status; the screen needs the whole row, so
    // read it back rather than reconstructing it from a status and hope.
    final driver = await load();
    if (driver == null) {
      throw const DriverError(DriverFailure.staleState);
    }
    return driver;
  }

  @override
  Stream<Driver> watch() {
    final id = _userId;
    if (id == null) return const Stream<Driver>.empty();

    return _client
        .from(_table)
        .stream(primaryKey: ['profile_id'])
        .eq('profile_id', id)
        .map((rows) => rows.isEmpty ? null : Driver.fromRow(rows.first))
        .where((driver) => driver != null)
        .cast<Driver>();
  }

  /// Maps a Postgrest error onto something a screen can act on.
  ///
  /// The SQLSTATE is what the functions raise deliberately, so it is read
  /// first; message matching is a fallback for errors raised by the platform
  /// rather than by our own SQL.
  static DriverFailure _classify(PostgrestException error) {
    switch (error.code) {
      case 'P0002': // no_data_found -- raised by resubmit_driver_licence
        return DriverFailure.staleState;
      case '42501': // insufficient_privilege
      case '28000': // not signed in
        return DriverFailure.notSignedIn;
      case '23514': // check_violation
      case '22023': // invalid_parameter_value
        return DriverFailure.staleState;
    }

    final message = error.message.toLowerCase();
    if (message.contains('failed host lookup') ||
        message.contains('socketexception') ||
        message.contains('network')) {
      return DriverFailure.offline;
    }
    return DriverFailure.unknown;
  }

  static String _extensionFor(String contentType) =>
      switch (contentType.toLowerCase()) {
        'image/png' => 'png',
        'image/webp' => 'webp',
        'image/heic' || 'image/heif' => 'heic',
        _ => 'jpg',
      };
}

/// In-memory driver store, for tests and for running without a backend.
class FakeDriverRepository implements DriverRepository {
  FakeDriverRepository({this.driver, this.userId = 'driver-1'});

  /// The row [load] returns. Null models a driver who has never applied.
  Driver? driver;

  /// Stands in for `auth.uid()` when building a licence path.
  final String userId;

  /// Paths uploaded, in order.
  final List<String> uploads = [];

  /// Applications submitted, in order.
  final List<DriverApplication> submissions = [];

  /// Set to make the next call fail. Cleared by nothing -- a test sets it,
  /// exercises the path, and clears it if it wants the call to succeed after.
  DriverError? failure;

  /// Fails only the upload, leaving everything else working. This is the
  /// state the design calls out: "Photo didn't upload. Your details are
  /// saved."
  DriverError? uploadFailure;

  final _changes = StreamController<Driver>.broadcast();

  @override
  Future<Driver?> load() async {
    if (failure != null) throw failure!;
    return driver;
  }

  @override
  Future<String> uploadLicence({
    required Uint8List bytes,
    required String contentType,
  }) async {
    if (uploadFailure != null) throw uploadFailure!;
    if (failure != null) throw failure!;
    final path = '$userId/licence.jpg';
    uploads.add(path);
    return path;
  }

  @override
  Future<Driver> submit(DriverApplication application) async {
    if (failure != null) throw failure!;
    submissions.add(application);
    final filed = Driver(
      profileId: userId,
      vehicleType: application.vehicleType,
      plate: application.normalisedPlate,
      colour: application.colour.trim(),
      status: DriverStatus.pending,
      licencePath: application.licencePath,
      createdAt: DateTime.now(),
    );
    driver = filed;
    _changes.add(filed);
    return filed;
  }

  @override
  Future<Driver> resubmitLicence(String licencePath) async {
    if (failure != null) throw failure!;
    final current = driver;
    if (current == null || current.status != DriverStatus.rejected) {
      throw const DriverError(DriverFailure.staleState);
    }
    final requeued = current.copyWith(
      status: DriverStatus.pending,
      licencePath: licencePath,
      clearRejectionReason: true,
    );
    driver = requeued;
    _changes.add(requeued);
    return requeued;
  }

  @override
  Stream<Driver> watch() => _changes.stream;

  /// Stands in for an admin's decision, so a test can walk the approval.
  void review(DriverStatus status, {String? reason}) {
    final current = driver;
    if (current == null) return;
    final reviewed = current.copyWith(
      status: status,
      rejectionReason: reason,
      clearRejectionReason: status != DriverStatus.rejected,
    );
    driver = reviewed;
    _changes.add(reviewed);
  }

  void dispose() => _changes.close();
}
