import 'package:flutter/material.dart';

import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';

/// A brief confirmation, floating above the screen.
///
/// Njiani uses these for things the user already caused and does not need to
/// acknowledge -- 'Neema is yours, pick up at Shekilango'. Anything that needs
/// a decision gets a real control, never a toast.
class NjToast extends StatelessWidget {
  const NjToast({super.key, required this.message});

  /// The message.
  final String message;

  /// Shows [message] over the current route for [duration].
  ///
  /// Returns once the toast has gone, so callers can await it if the next
  /// step should not interrupt.
  static Future<void> show(
    BuildContext context,
    String message, {
    Duration duration = const Duration(milliseconds: 2600),
  }) async {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final entry = OverlayEntry(
      builder: (context) => Positioned(
        left: NjSpace.md,
        right: NjSpace.md,
        bottom: MediaQuery.of(context).padding.bottom + NjSpace.lg,
        child: NjToast(message: message),
      ),
    );

    overlay.insert(entry);
    await Future<void>.delayed(duration);
    entry.remove();
  }

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;

    return Material(
      color: Colors.transparent,
      child: Semantics(
        liveRegion: true,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: NjSpace.md + 2,
            vertical: NjSpace.md,
          ),
          decoration: BoxDecoration(
            color: nj.ink,
            borderRadius: BorderRadius.circular(NjRadius.input),
            boxShadow: NjShadow.sheet(nj),
          ),
          child: Text(
            message,
            style: context.njText.bodyMedium?.copyWith(
              color: nj.surface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
