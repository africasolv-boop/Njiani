import 'package:flutter/material.dart';

/// Typography for both apps: Bricolage Grotesque, bundled as an asset.
///
/// The font ships with the app rather than being fetched at runtime. Drivers
/// are on metered data and low-end handsets, and text that reflows after a
/// network fetch is exactly the kind of jank that makes an app feel broken.
///
/// Sizes come from the pitch deck's CSS, converted from rem at the 16px root.
abstract final class NjTypography {
  /// Font family name as declared in `pubspec.yaml`.
  ///
  /// Use this only with a [TextStyle]'s `package:` argument, which applies the
  /// package prefix for you. Anywhere that takes a bare family name -- notably
  /// [ThemeData.fontFamily] -- needs [themeFontFamily] instead.
  static const String fontFamily = 'BricolageGrotesque';

  /// The package that owns the font asset.
  ///
  /// Required so the apps can use a font declared in `njiani_core`.
  static const String fontPackage = 'njiani_core';

  /// The fully qualified family name, for APIs that take no `package:`.
  ///
  /// Flutter resolves a font shipped inside a package under
  /// `packages/<package>/<family>`. [TextStyle] does this for you when given
  /// `package:`, but [ThemeData.fontFamily] does not -- passing the bare name
  /// there silently falls back to the platform font, which renders some text
  /// in Bricolage and the rest in Roboto on the same screen.
  static const String themeFontFamily = 'packages/$fontPackage/$fontFamily';

  /// Builds the text theme in [color].
  static TextTheme textTheme(Color color) {
    TextStyle s(
      double size,
      FontWeight weight, {
      double? letterSpacing,
      double? height,
    }) =>
        TextStyle(
          fontFamily: fontFamily,
          package: fontPackage,
          fontSize: size,
          fontWeight: weight,
          letterSpacing: letterSpacing,
          height: height,
          color: color,
        );

    return TextTheme(
      // The Njiani wordmark, 2.6rem.
      displayLarge: s(41.6, FontWeight.w800, letterSpacing: -1.6, height: 1.0),
      displayMedium: s(33, FontWeight.w800, letterSpacing: -1.0, height: 1.05),
      displaySmall: s(28, FontWeight.w800, letterSpacing: -0.8, height: 1.1),

      // Screen headings, 1.6rem.
      headlineLarge: s(25.6, FontWeight.w700, letterSpacing: -0.5, height: 1.1),
      // The big ETA / arrival number, 1.5rem.
      headlineMedium: s(24, FontWeight.w800, letterSpacing: -0.5, height: 1.1),
      // Request price, 1.35rem.
      headlineSmall: s(21.6, FontWeight.w800, letterSpacing: -0.4, height: 1.1),

      titleLarge: s(18, FontWeight.w700, height: 1.25),
      // Button and primary input text, 1.05rem.
      titleMedium: s(16.8, FontWeight.w700, height: 1.25),
      titleSmall: s(15, FontWeight.w600, height: 1.3),

      bodyLarge: s(16.8, FontWeight.w400, height: 1.4),
      bodyMedium: s(16, FontWeight.w400, height: 1.45),
      // Captions and hints, 0.85rem.
      bodySmall: s(13.6, FontWeight.w400, height: 1.4),

      labelLarge: s(16.8, FontWeight.w700, height: 1.2),
      // Field labels, 0.85rem semibold.
      labelMedium: s(13.6, FontWeight.w600, height: 1.2),
      labelSmall: s(12.5, FontWeight.w700, letterSpacing: 0.4, height: 1.2),
    );
  }

  /// The vehicle plate style: heavy, wide-tracked, like a real number plate.
  static const TextStyle plate = TextStyle(
    fontFamily: fontFamily,
    package: fontPackage,
    fontSize: 18,
    fontWeight: FontWeight.w800,
    letterSpacing: 1.5,
    height: 1.1,
    color: Color(0xFF111111),
  );

  /// The route board style: uppercase, tracked, readable at a glance.
  static const TextStyle routeBoard = TextStyle(
    fontFamily: fontFamily,
    package: fontPackage,
    fontSize: 15.2,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.6,
    height: 1.15,
  );
}
