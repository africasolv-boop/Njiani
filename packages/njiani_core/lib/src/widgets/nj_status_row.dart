import 'package:flutter/material.dart';

import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';

/// How a checked item came out.
enum NjStatusTone {
  /// Accepted, verified, passed.
  good,

  /// Rejected or failed.
  bad,

  /// Not yet decided.
  pending,
}

/// A label with a status word, for a checklist of what passed and what did not.
///
/// The design uses this on the driver rejection screen, where the point is
/// that almost everything was accepted and only one item needs redoing --
/// so the passing rows have to be visible, not hidden.
class NjStatusRow extends StatelessWidget {
  const NjStatusRow({
    super.key,
    required this.label,
    required this.status,
    required this.tone,
  });

  /// What was checked, e.g. 'Licence photo'.
  final String label;

  /// The outcome word, e.g. 'Rejected'.
  final String status;

  /// Outcome colour.
  final NjStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;
    final color = switch (tone) {
      NjStatusTone.good => nj.teal,
      NjStatusTone.bad => nj.danger,
      NjStatusTone.pending => nj.muted,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: NjSpace.sm - 2),
      child: Row(
        children: [
          Expanded(child: Text(label, style: context.njText.bodyMedium)),
          const SizedBox(width: NjSpace.sm),
          Text(
            status,
            style: context.njText.bodyMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
