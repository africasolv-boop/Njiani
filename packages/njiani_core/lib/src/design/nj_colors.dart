import 'package:flutter/material.dart';

/// The Njiani colour tokens, carried on [ThemeData] as a [ThemeExtension].
///
/// Material's [ColorScheme] has no slot for "bajaj yellow", "route board" or
/// "map road", so the palette from the pitch deck lives here instead of being
/// forced into approximate Material roles. Read it through
/// `context.nj` (see `nj_theme.dart`).
///
/// Values are taken verbatim from the CSS custom properties in the pitch deck,
/// so the apps and the deck stay in visual agreement.
@immutable
class NjColors extends ThemeExtension<NjColors> {
  const NjColors({
    required this.bg,
    required this.surface,
    required this.surfaceAlt,
    required this.ink,
    required this.muted,
    required this.line,
    required this.bajaj,
    required this.bajajInk,
    required this.teal,
    required this.tealInk,
    required this.tealSoft,
    required this.danger,
    required this.dangerSoft,
    required this.map,
    required this.road,
    required this.roadMain,
    required this.frame,
    required this.shadow,
    required this.live,
  });

  /// Page background, behind cards and sheets.
  final Color bg;

  /// Cards, sheets and inputs.
  final Color surface;

  /// Recessed surface: segmented control troughs, driver cards, earnings bar.
  final Color surfaceAlt;

  /// Primary text.
  final Color ink;

  /// Secondary text, labels, captions.
  final Color muted;

  /// Borders and dividers.
  final Color line;

  /// Bajaj yellow. The brand accent and the route board background.
  ///
  /// Intentionally identical in light and dark: it is the colour of the
  /// physical vehicles and the painted daladala route boards, and it should not
  /// shift with the device theme.
  final Color bajaj;

  /// Text and icons on [bajaj].
  final Color bajajInk;

  /// Primary action colour.
  final Color teal;

  /// Text and icons on [teal].
  final Color tealInk;

  /// Tinted teal for selected chips, avatars and success marks.
  final Color tealSoft;

  /// Destructive and warning colour.
  final Color danger;

  /// Tinted danger background, e.g. the "taken by another driver" band.
  final Color dangerSoft;

  /// Map canvas.
  final Color map;

  /// Minor roads on the map.
  final Color road;

  /// The main corridor on the map, e.g. Morogoro Road.
  final Color roadMain;

  /// Device frame in mockups and the status bar backdrop.
  final Color frame;

  /// Elevation shadow for sheets and phones.
  final Color shadow;

  /// The "live" indicator dot. Green in both themes -- it means online.
  final Color live;

  /// Light theme palette.
  static const NjColors light = NjColors(
    bg: Color(0xFFE6EBE8),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFF3F6F4),
    ink: Color(0xFF1D2226),
    muted: Color(0xFF5A646B),
    line: Color(0xFFD2D9D5),
    bajaj: Color(0xFFF2B705),
    bajajInk: Color(0xFF2A2100),
    teal: Color(0xFF0E6E6C),
    tealInk: Color(0xFFFFFFFF),
    tealSoft: Color(0xFFD5EBE9),
    danger: Color(0xFFB83227),
    dangerSoft: Color(0xFFF6DEDB),
    map: Color(0xFFD9E1DC),
    road: Color(0xFFFFFFFF),
    roadMain: Color(0xFFF7E7B0),
    frame: Color(0xFF2A2F33),
    shadow: Color(0x2E1D2226),
    live: Color(0xFF2DB35A),
  );

  /// Dark theme palette.
  ///
  /// [bajaj] and [bajajInk] deliberately do not change -- see [bajaj].
  static const NjColors dark = NjColors(
    bg: Color(0xFF14181B),
    surface: Color(0xFF1E2428),
    surfaceAlt: Color(0xFF252C31),
    ink: Color(0xFFECF0EE),
    muted: Color(0xFF9AA5AB),
    line: Color(0xFF333C42),
    bajaj: Color(0xFFF2B705),
    bajajInk: Color(0xFF2A2100),
    teal: Color(0xFF3BB0AA),
    tealInk: Color(0xFF06201F),
    tealSoft: Color(0xFF1B3634),
    danger: Color(0xFFE8766B),
    dangerSoft: Color(0xFF3A2220),
    map: Color(0xFF222A2E),
    road: Color(0xFF37424A),
    roadMain: Color(0xFF5A4E22),
    frame: Color(0xFF000000),
    shadow: Color(0x80000000),
    live: Color(0xFF2DB35A),
  );

  @override
  NjColors copyWith({
    Color? bg,
    Color? surface,
    Color? surfaceAlt,
    Color? ink,
    Color? muted,
    Color? line,
    Color? bajaj,
    Color? bajajInk,
    Color? teal,
    Color? tealInk,
    Color? tealSoft,
    Color? danger,
    Color? dangerSoft,
    Color? map,
    Color? road,
    Color? roadMain,
    Color? frame,
    Color? shadow,
    Color? live,
  }) {
    return NjColors(
      bg: bg ?? this.bg,
      surface: surface ?? this.surface,
      surfaceAlt: surfaceAlt ?? this.surfaceAlt,
      ink: ink ?? this.ink,
      muted: muted ?? this.muted,
      line: line ?? this.line,
      bajaj: bajaj ?? this.bajaj,
      bajajInk: bajajInk ?? this.bajajInk,
      teal: teal ?? this.teal,
      tealInk: tealInk ?? this.tealInk,
      tealSoft: tealSoft ?? this.tealSoft,
      danger: danger ?? this.danger,
      dangerSoft: dangerSoft ?? this.dangerSoft,
      map: map ?? this.map,
      road: road ?? this.road,
      roadMain: roadMain ?? this.roadMain,
      frame: frame ?? this.frame,
      shadow: shadow ?? this.shadow,
      live: live ?? this.live,
    );
  }

  @override
  NjColors lerp(covariant NjColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return NjColors(
      bg: c(bg, other.bg),
      surface: c(surface, other.surface),
      surfaceAlt: c(surfaceAlt, other.surfaceAlt),
      ink: c(ink, other.ink),
      muted: c(muted, other.muted),
      line: c(line, other.line),
      bajaj: c(bajaj, other.bajaj),
      bajajInk: c(bajajInk, other.bajajInk),
      teal: c(teal, other.teal),
      tealInk: c(tealInk, other.tealInk),
      tealSoft: c(tealSoft, other.tealSoft),
      danger: c(danger, other.danger),
      dangerSoft: c(dangerSoft, other.dangerSoft),
      map: c(map, other.map),
      road: c(road, other.road),
      roadMain: c(roadMain, other.roadMain),
      frame: c(frame, other.frame),
      shadow: c(shadow, other.shadow),
      live: c(live, other.live),
    );
  }
}
