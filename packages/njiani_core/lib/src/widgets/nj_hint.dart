import 'package:flutter/material.dart';

import '../design/nj_theme.dart';

/// How a hint reads.
enum NjHintTone {
  /// Teal. Informational, e.g. the usual price band for a route.
  info,

  /// Danger. The offer is below what drivers usually accept.
  warning,
}

/// A single line of guidance under a field.
///
/// Carries the price band under the passenger's offer. A warning tone never
/// blocks the request -- an offer below the band still sends, it just says so
/// first. That is a deliberate product decision: the passenger sets the price,
/// not the app.
class NjHint extends StatelessWidget {
  const NjHint({super.key, required this.text, this.tone = NjHintTone.info});

  /// The message.
  final String text;

  /// Informational or warning.
  final NjHintTone tone;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;

    return Text(
      text,
      style: context.njText.bodySmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: tone == NjHintTone.warning ? nj.danger : nj.teal,
      ),
    );
  }
}
