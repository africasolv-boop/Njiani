import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Letting a driver know a request arrived without them looking.
///
/// The empty state promises it in words — "You'll hear a sound when a request
/// comes in" — so it has to actually happen. A driver with the phone in a
/// cradle, watching the road, is the whole reason this exists.
///
/// `SystemSound` and `HapticFeedback` rather than an audio package and an
/// asset: no dependency, no file to ship, and the device's own alert sound is
/// the one already set to a volume its owner chose. A bundled chime would be
/// one more thing to get wrong on a phone whose media volume is at zero.
abstract interface class FeedAlert {
  /// Something new is in the feed.
  Future<void> newRequest();
}

/// The device's own alert sound and a short buzz.
class SystemFeedAlert implements FeedAlert {
  const SystemFeedAlert();

  @override
  Future<void> newRequest() async {
    // Both, and neither is allowed to stop the other: a phone on silent
    // still vibrates, and a phone in a noisy bajaj is more likely to be felt
    // than heard. Failures are swallowed because an alert that could not
    // play is not something a driver can do anything about.
    try {
      await SystemSound.play(SystemSoundType.alert);
    } catch (error) {
      debugPrint('[njiani] alert sound: $error');
    }
    try {
      await HapticFeedback.mediumImpact();
    } catch (error) {
      debugPrint('[njiani] alert haptic: $error');
    }
  }
}

/// Counts instead of playing.
class FakeFeedAlert implements FeedAlert {
  int fired = 0;

  @override
  Future<void> newRequest() async => fired++;
}

/// Supplies the alert.
///
/// Always overridden in tests: `SystemSound` reaches a platform channel, and
/// a widget test that does so fails in a way that looks like the screen is
/// broken.
final feedAlertProvider = Provider<FeedAlert>((ref) => const SystemFeedAlert());
