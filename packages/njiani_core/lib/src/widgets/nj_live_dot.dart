import 'package:flutter/material.dart';

import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';

/// A small green dot with a caption, marking a live-updating list.
///
/// The driver feed refreshes itself, and a driver who cannot tell the
/// difference between "no requests yet" and "the app has stopped updating"
/// will close the app. This is the difference.
class NjLiveDot extends StatelessWidget {
  const NjLiveDot({super.key, required this.label});

  /// Caption beside the dot, e.g. 'Live, passengers heading to Kimara'.
  final String label;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: nj.live, shape: BoxShape.circle),
        ),
        const SizedBox(width: NjSpace.sm - 2),
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: context.njText.bodySmall?.copyWith(color: nj.muted),
          ),
        ),
      ],
    );
  }
}
