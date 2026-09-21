import 'package:flutter/material.dart';

import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';

/// The bottom sheet that carries most of the passenger app's controls.
///
/// Overlaps the map above it by 22pt, as in the design, so the sheet reads as
/// sitting on top of the map rather than beside it.
class NjSheet extends StatelessWidget {
  const NjSheet({
    super.key,
    required this.child,
    this.showGrabber = true,
    this.overlap = 22,
    this.padding = const EdgeInsets.fromLTRB(
      NjSpace.xl,
      NjSpace.lg + 2,
      NjSpace.xl,
      NjSpace.xl,
    ),
  });

  /// Sheet contents.
  final Widget child;

  /// Whether to draw the grab handle.
  final bool showGrabber;

  /// How far the sheet rides up over the content behind it.
  final double overlap;

  /// Inner padding.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;

    return Transform.translate(
      offset: Offset(0, -overlap),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: nj.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(NjRadius.sheet),
          ),
        ),
        padding: padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showGrabber) ...[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: nj.line,
                    borderRadius: BorderRadius.circular(NjRadius.pill),
                  ),
                ),
              ),
              const SizedBox(height: NjSpace.md),
            ],
            child,
          ],
        ),
      ),
    );
  }
}
