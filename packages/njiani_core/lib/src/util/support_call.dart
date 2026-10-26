import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';

/// Dials the Njiani support line.
///
/// Returns false when the number is not configured, or the platform refused.
/// On a refusal the number is shown instead, because a driver who has just
/// been told they cannot work should not also be left without it.
Future<bool> callNjianiSupport(BuildContext context) async {
  if (!AppConfig.hasSupportPhone) return false;

  // Strip anything a dialler does not want. A number pasted from a web page
  // arrives as "+255 712 345 678" often enough to be worth handling.
  final number = AppConfig.supportPhone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (number.isEmpty) return false;

  final messenger = ScaffoldMessenger.maybeOf(context);

  // launchUrl directly, without asking canLaunchUrl first: on Android 11+
  // that query answers false unless the manifest declares an ACTION_DIAL
  // <queries> entry, and a false negative here means a working dialler is
  // never opened. Both manifests declare it; catching the failure is the
  // belt that does not depend on them.
  try {
    final opened = await launchUrl(
      Uri(scheme: 'tel', path: number),
      mode: LaunchMode.externalApplication,
    );
    if (opened) return true;
  } on Object {
    // Falls through to showing the number.
  }

  messenger?.showSnackBar(SnackBar(content: Text(AppConfig.supportPhone)));
  return false;
}
