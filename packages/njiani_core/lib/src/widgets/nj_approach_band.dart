import 'package:flutter/material.dart';

import '../design/nj_theme.dart';

/// The band above the matched sheet: a road, the pickup point, and the
/// vehicle coming along it.
///
/// **This is not a map, and it must not be mistaken for one.** There is no
/// map in Njiani until C14, and drawing a real one would mean a tile bill, a
/// key in the binary and a passenger's position on somebody's server. What
/// this draws is the one fact the server does give us — how far the driver
/// still is from the pickup — rendered so it can be read without reading.
///
/// The design project's own band is a stylised sketch for the same reason.
/// The marker moving is the information; the roads are the frame that makes
/// the movement legible.
class NjApproachBand extends StatelessWidget {
  const NjApproachBand({
    super.key,
    required this.progress,
    this.height = 220,
    this.arrived = false,
  });

  /// How close the driver is: 0 at the far end, 1 at the pickup point.
  final double progress;

  final double height;

  /// Draws the vehicle at the pickup point, where it stays.
  final bool arrived;

  /// Distance at which the marker enters the band.
  ///
  /// Two kilometres, because the corridor matching will not offer a driver a
  /// passenger much further than that along the road, and a marker that
  /// barely moves for the first ten minutes reads as broken.
  static const double windowMetres = 2000;

  /// Turns metres into [progress].
  static double progressFor(double? metresAway) {
    if (metresAway == null) return 0;
    final left = metresAway.clamp(0.0, windowMetres);
    return 1 - (left / windowMetres);
  }

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _ApproachPainter(
          progress: arrived ? 1 : progress.clamp(0.0, 1.0),
          map: nj.map,
          road: nj.road,
          corridor: nj.roadMain,
          travelled: nj.teal,
          pin: nj.teal,
          pinRing: nj.surface,
          vehicle: nj.bajaj,
          vehicleInk: nj.bajajInk,
        ),
      ),
    );
  }
}

class _ApproachPainter extends CustomPainter {
  const _ApproachPainter({
    required this.progress,
    required this.map,
    required this.road,
    required this.corridor,
    required this.travelled,
    required this.pin,
    required this.pinRing,
    required this.vehicle,
    required this.vehicleInk,
  });

  final double progress;
  final Color map;
  final Color road;
  final Color corridor;
  final Color travelled;
  final Color pin;
  final Color pinRing;
  final Color vehicle;
  final Color vehicleInk;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    canvas.drawRect(Offset.zero & size, Paint()..color = map);

    // Minor streets. Fixed fractions of the canvas rather than fixed pixels,
    // so the band looks the same on a 360 dp phone and a 430 dp one.
    final minor = Paint()
      ..color = road
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (final line in <List<double>>[
      [-0.03, 0.24, 1.03, 0.34],
      [0.19, -0.04, 0.28, 1.04],
      [0.64, -0.04, 0.73, 1.04],
      [-0.03, 0.79, 1.03, 0.67],
    ]) {
      canvas.drawLine(
        Offset(line[0] * w, line[1] * h),
        Offset(line[2] * w, line[3] * h),
        minor,
      );
    }

    // The corridor, from the far end down to the pickup point.
    final pickup = Offset(w * 0.47, h * 0.57);
    final path = Path()
      ..moveTo(w * 1.06, h * 0.11)
      ..cubicTo(w * 0.75, h * 0.27, w * 0.62, h * 0.46, pickup.dx, pickup.dy)
      ..cubicTo(w * 0.33, h * 0.68, w * 0.12, h * 0.80, -w * 0.06, h * 0.89);

    canvas.drawPath(
      path,
      Paint()
        ..color = corridor
        ..strokeWidth = 14
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // The stretch the driver has already covered, drawn over the corridor.
    // It is the progress bar, and it is the reason this band exists.
    final metrics = path.computeMetrics().first;
    final approach = metrics.length * 0.52;
    canvas.drawPath(
      metrics.extractPath(approach * (1 - progress), approach),
      Paint()
        ..color = travelled
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // Where the passenger is standing.
    canvas.drawCircle(pickup, 12, Paint()..color = pinRing);
    canvas.drawCircle(pickup, 9, Paint()..color = pin);

    // The vehicle, along the road rather than beside it.
    final at = metrics.getTangentForOffset(approach * (1 - progress))?.position ??
        pickup;
    _drawVehicle(canvas, at);
  }

  void _drawVehicle(Canvas canvas, Offset at) {
    final body = Path()
      ..moveTo(at.dx - 11, at.dy + 6)
      ..quadraticBezierTo(at.dx, at.dy - 9, at.dx + 11, at.dy + 6)
      ..close();

    canvas.drawPath(body, Paint()..color = vehicle);
    canvas.drawPath(
      body,
      Paint()
        ..color = vehicleInk
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );
    for (final dx in <double>[-6, 6]) {
      canvas.drawCircle(
        Offset(at.dx + dx, at.dy + 7),
        2.6,
        Paint()..color = vehicleInk,
      );
    }
  }

  @override
  bool shouldRepaint(_ApproachPainter old) =>
      // Rounded, because a repaint is only worth it when the marker would
      // visibly move. A poll every twenty seconds moves it about a
      // fiftieth of the band.
      (old.progress * 200).round() != (progress * 200).round() ||
      old.map != map;

  @override
  bool hitTest(Offset position) => false;
}
