import 'package:flutter/material.dart';

import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';

/// Where a document upload has got to.
enum NjUploadState {
  /// Nothing attached yet. Dashed outline.
  empty,

  /// Sending. The design requires submit to stay disabled while this runs.
  uploading,

  /// Attached. Solid teal outline with a tick.
  done,

  /// Failed. The spec is explicit: the driver's other details are kept and
  /// only the photo is retried.
  failed,
}

/// A tap target for a document photo, used for driving licences.
///
/// A driver at a stage, in sunlight, needs to know at a glance whether their
/// licence went through. Each state therefore changes the border style, the
/// fill and the wording together, not just one of them.
class NjUploadBox extends StatelessWidget {
  const NjUploadBox({
    super.key,
    required this.label,
    required this.doneLabel,
    required this.onTap,
    this.state = NjUploadState.empty,
    this.uploadingLabel = 'Uploading…',
    this.failedLabel = "Photo didn't upload. Your details are saved.",
    this.progress,
    this.icon = Icons.photo_camera_outlined,
  });

  /// Prompt shown before a file is attached.
  final String label;

  /// Confirmation shown once one is.
  final String doneLabel;

  /// Tap handler -- opens the camera or picker. Ignored while uploading.
  final VoidCallback onTap;

  /// Which state to render.
  final NjUploadState state;

  /// Wording while sending.
  final String uploadingLabel;

  /// Wording after a failure. Says what was kept, not just what broke.
  final String failedLabel;

  /// Upload fraction, 0 to 1. Null shows an indeterminate spinner.
  final double? progress;

  /// Icon shown before attaching.
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;

    final (Color border, Color fill, Color fg, String text, bool dashed) =
        switch (state) {
      NjUploadState.empty => (nj.line, nj.surfaceAlt, nj.muted, label, true),
      NjUploadState.uploading =>
        (nj.teal, nj.surfaceAlt, nj.teal, uploadingLabel, false),
      NjUploadState.done => (nj.teal, nj.tealSoft, nj.teal, doneLabel, false),
      NjUploadState.failed =>
        (nj.danger, nj.dangerSoft, nj.danger, failedLabel, false),
    };

    final busy = state == NjUploadState.uploading;

    return Semantics(
      button: !busy,
      label: text,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: busy ? null : onTap,
        behavior: HitTestBehavior.opaque,
        child: CustomPaint(
          painter: dashed ? _DashedBorderPainter(color: border) : null,
          child: Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 64),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(NjSpace.lg),
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(NjRadius.input),
              border: dashed
                  ? null
                  : Border.all(color: border, width: NjBorder.control),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (busy)
                      SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          value: progress,
                          valueColor: AlwaysStoppedAnimation(fg),
                        ),
                      )
                    else
                      Icon(
                        switch (state) {
                          NjUploadState.done => Icons.check_circle,
                          NjUploadState.failed => Icons.error_outline,
                          _ => icon,
                        },
                        size: 20,
                        color: fg,
                      ),
                    const SizedBox(width: NjSpace.sm),
                    Flexible(
                      child: Text(
                        text,
                        textAlign: TextAlign.center,
                        style: context.njText.bodySmall?.copyWith(
                          fontSize: 14.5,
                          color: fg,
                          fontWeight: state == NjUploadState.empty
                              ? FontWeight.w500
                              : FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (state == NjUploadState.failed) ...[
                  const SizedBox(height: NjSpace.sm),
                  Text(
                    'Tap to try the photo again',
                    style: context.njText.bodySmall
                        ?.copyWith(fontSize: 12.5, color: fg),
                  ),
                ],
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
