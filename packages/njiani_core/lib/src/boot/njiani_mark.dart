import 'package:flutter/material.dart';

/// The Njiani logo mark: a yellow rounded square holding a road that curves up
/// from a dot (the pickup) to a square (the destination).
///
/// Drawn directly rather than shipped as an SVG asset so it costs no extra
/// dependency and scales cleanly at any size. Geometry is taken from the 48x48
/// viewBox in the pitch deck and scaled by [size] / 48.
class NjianiMark extends StatelessWidget {
  const NjianiMark({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _MarkPainter()),
      );
}

class _MarkPainter extends CustomPainter {
  // Palette from the pitch deck. C1 replaces these literals with theme tokens.
  static const _bajaj = Color(0xFFF2B705);
  static const _bajajInk = Color(0xFF2A2100);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 48.0;

    // Rounded background tile: <rect width=48 height=48 rx=14>
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, 48 * s, 48 * s),
        Radius.circular(14 * s),
      ),
      Paint()..color = _bajaj,
    );

    final ink = Paint()
      ..color = _bajajInk
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * s
      ..strokeCap = StrokeCap.round;

    // The road: M10 33 C18 33 20 15 38 15
    canvas.drawPath(
      Path()
        ..moveTo(10 * s, 33 * s)
        ..cubicTo(18 * s, 33 * s, 20 * s, 15 * s, 38 * s, 15 * s),
      ink,
    );

    // Pickup dot: <circle cx=10 cy=33 r=4>
    canvas.drawCircle(
      Offset(10 * s, 33 * s),
      4 * s,
      Paint()..color = _bajajInk,
    );

    // Destination square: <rect x=34 y=11 width=8 height=8 rx=2>
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(34 * s, 11 * s, 8 * s, 8 * s),
        Radius.circular(2 * s),
      ),
      Paint()..color = _bajajInk,
    );
  }

  @override
  bool shouldRepaint(covariant _MarkPainter oldDelegate) => false;
}
