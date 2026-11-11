import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';

/// Dials the Njiani support line.
///
/// Returns false when the number is not configured, or the platform refused.
/// On a refusal the number is shown instead, because a driver who has just
/// been told they cannot work should not also be left without it.
Future<bool> callNjianiSupport(BuildContext context) =>
    dialNumber(context, AppConfig.supportPhone);

/// Opens the dialler on [number], already typed in.
///
/// Dialler, not a call: the user still presses the green button. Nothing in
/// Njiani places a call on somebody's behalf.
///
/// Returns false when there is no number or the platform refused. On a
/// refusal the number is shown instead — a passenger standing at a stage with
/// a driver on the way needs the digits far more than they need a working
/// button, and a dead button that shows nothing leaves them with neither.
Future<bool> dialNumber(BuildContext context, String? number) async {
  final dialable = (number ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
  if (dialable.isEmpty) return false;

  final messenger = ScaffoldMessenger.maybeOf(context);

  // launchUrl directly, without asking canLaunchUrl first: on Android 11+
  // that query answers false unless the manifest declares an ACTION_DIAL
  // <queries> entry, and a false negative here means a working dialler is
  // never opened. Both manifests declare it; catching the failure is the
  // belt that does not depend on them.
  try {
    final opened = await launchUrl(
      Uri(scheme: 'tel', path: dialable),
      mode: LaunchMode.externalApplication,
    );
    if (opened) return true;
  } on Object {
    // Falls through to showing the number.
  }

  messenger?.showSnackBar(SnackBar(content: Text(number!)));
  return false;
}
