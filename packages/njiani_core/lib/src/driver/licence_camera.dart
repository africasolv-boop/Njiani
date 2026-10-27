import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// A photo a driver chose, in memory and ready to upload.
@immutable
class LicencePhoto {
  const LicencePhoto({
    required this.bytes,
    required this.contentType,
    this.name,
  });

  final Uint8List bytes;

  /// What the bucket's allow-list is checked against.
  final String contentType;

  /// The original filename, where there was one. Diagnostic only.
  final String? name;

  int get sizeBytes => bytes.length;
}

/// Where a licence photo comes from.
///
/// An interface with one real implementation, so that nothing in a test or in
/// a backend-less build reaches for a camera that is not there. The same
/// reason [AuthRepository] has a fake: a screen should be walkable without
/// hardware.
abstract interface class LicenceCamera {
  /// Opens the camera. Returns null if the driver backed out.
  Future<LicencePhoto?> takePhoto();

  /// Opens the gallery, for a photo already taken.
  ///
  /// Worth having rather than camera-only: a driver may have photographed
  /// their licence already, and at a stage in the sun, framing it again on a
  /// cracked screen is the step people abandon.
  Future<LicencePhoto?> pickPhoto();
}

/// Backed by `image_picker`.
class ImagePickerLicenceCamera implements LicenceCamera {
  ImagePickerLicenceCamera({ImagePicker? picker, this.maxDimension = 1600})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  /// Longest-edge cap, in pixels, applied before the bytes leave the device.
  ///
  /// A modern phone camera produces 4-6 MB per shot, over the bucket's 5 MB
  /// limit as often as not, and every byte is uploaded on a driver's own
  /// mobile data. 1600px is still far more than a person needs to read a
  /// licence number.
  final int maxDimension;

  @override
  Future<LicencePhoto?> takePhoto() => _read(ImageSource.camera);

  @override
  Future<LicencePhoto?> pickPhoto() => _read(ImageSource.gallery);

  Future<LicencePhoto?> _read(ImageSource source) async {
    final file = await _picker.pickImage(
      source: source,
      maxWidth: maxDimension.toDouble(),
      maxHeight: maxDimension.toDouble(),
      imageQuality: 85,
      // preferredCameraDevice is left at its default, which is the rear
      // camera. Nobody photographs a licence with the front one.
    );
    if (file == null) return null;

    final bytes = await file.readAsBytes();
    return LicencePhoto(
      bytes: bytes,
      // image_picker re-encodes when it resizes, so the resulting file is
      // JPEG whatever the camera produced. `file.mimeType` is frequently null
      // on Android, which is why this does not trust it.
      contentType: _contentTypeFor(file.name, file.mimeType),
      name: file.name,
    );
  }

  static String _contentTypeFor(String name, String? reported) {
    if (reported != null && reported.startsWith('image/')) return reported;
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }
}

/// Returns a fixed photo without touching a camera.
class FakeLicenceCamera implements LicenceCamera {
  FakeLicenceCamera({this.photo, this.cancelled = false});

  /// What both methods return. Defaults to a few bytes -- the upload path
  /// does not care what is in them.
  LicencePhoto? photo;

  /// When true, both methods return null, as a driver backing out does.
  bool cancelled;

  /// How many times a camera or gallery was opened.
  int opened = 0;

  LicencePhoto get _default => LicencePhoto(
        bytes: Uint8List.fromList(const [1, 2, 3, 4]),
        contentType: 'image/jpeg',
        name: 'licence.jpg',
      );

  @override
  Future<LicencePhoto?> takePhoto() async {
    opened++;
    return cancelled ? null : (photo ?? _default);
  }

  @override
  Future<LicencePhoto?> pickPhoto() => takePhoto();
}

/// Supplies the camera.
///
/// Overridden in tests with a [FakeLicenceCamera]. Not conditional on whether
/// Supabase is configured: the camera works regardless, and a driver who can
/// take a photo but not upload it should see an upload failure, which is the
/// truth, rather than a camera that silently does nothing.
final licenceCameraProvider =
    Provider<LicenceCamera>((ref) => ImagePickerLicenceCamera());
