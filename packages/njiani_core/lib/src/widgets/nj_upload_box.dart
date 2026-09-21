import 'package:flutter/material.dart';

import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';

/// A dashed drop target for a document photo, used for driving licences.
///
/// Turns solid teal once a file is attached, so a driver at a stage can see at
/// a glance whether their licence went through.
class NjUploadBox extends StatelessWidget {
  const NjUploadBox({
    super.key,
    required this.label,
    required this.doneLabel,
    required this.done,
    required this.onTap,
    this.icon = Icons.photo_camera_outlined,
  });

  /// Prompt shown before a file is attached.
  final String label;

  /// Confirmation shown once one is.
  final String doneLabel;

  /// Whether a file is attached.
  final bool done;

  /// Tap handler -- opens the camera or picker.
  final VoidCallback onTap;

  /// Icon shown before attaching.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;

    return Semantics(
      button: true,
      label: done ? doneLabel : label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: CustomPaint(
          painter: done ? null : _DashedBorderPainter(color: nj.line),
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 64),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(NjSpace.md + 2),
            decoration: BoxDecoration(
              color: done ? nj.surface : nj.surfaceAlt,
              borderRadius: BorderRadius.circular(NjRadius.input),
              border: done
                  ? Border.all(color: nj.teal, width: NjBorder.control)
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  done ? Icons.check_circle : icon,
                  size: 20,
                  color: done ? nj.teal : nj.muted,
                ),
                const SizedBox(width: NjSpace.sm),
                Flexible(
                  child: Text(
                    done ? doneLabel : label,
                    textAlign: TextAlign.center,
                    style: context.njText.bodySmall?.copyWith(
                      color: done ? nj.teal : nj.muted,
                      fontWeight: done ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Draws the dashed outline. Flutter has no dashed border, so it is painted.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = NjBorder.control;

    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          const Radius.circular(NjRadius.input),
        ),
      );

    const dash = 6.0;
    const gap = 5.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}
