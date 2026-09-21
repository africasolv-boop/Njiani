import 'package:flutter/material.dart';

import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';

/// What an [NjBadge] signals.
enum NjBadgeTone {
  /// Grey. A neutral tag, e.g. a component reference.
  neutral,

  /// Bajaj yellow. Flags something deliberately out of the current scope.
  bajaj,

  /// Teal. A positive state, e.g. a zero fee during the pilot.
  teal,

  /// Danger. A problem needing attention.
  danger,
}

/// A small uppercase tag.
///
/// Used for scope markers such as `V2` and for status pills like `TSh 0`.
class NjBadge extends StatelessWidget {
  const NjBadge({super.key, required this.label, this.tone = NjBadgeTone.neutral});

  /// Tag text. Rendered as given -- the design uses upper case already.
  final String label;

  /// Colour meaning.
  final NjBadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;
    final (Color bg, Color fg) = switch (tone) {
      NjBadgeTone.neutral => (nj.bg, nj.muted),
      NjBadgeTone.bajaj => (nj.bajaj, nj.bajajInk),
      NjBadgeTone.teal => (nj.tealSoft, nj.teal),
      NjBadgeTone.danger => (nj.dangerSoft, nj.danger),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(NjRadius.plate - 2),
      ),
      child: Text(
        label,
        style: context.njText.labelSmall?.copyWith(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: fg,
        ),
      ),
    );
  }
}
