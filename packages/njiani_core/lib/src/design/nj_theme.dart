import 'package:flutter/material.dart';

import 'nj_colors.dart';
import 'nj_tokens.dart';
import 'nj_typography.dart';

/// Builds the Njiani [ThemeData] for each brightness.
///
/// Both the Material [ColorScheme] and the Njiani [NjColors] extension are
/// populated: Material widgets get sensible roles, and Njiani widgets read the
/// exact palette from the pitch deck through `context.nj`.
abstract final class NjTheme {
  /// Light theme.
  static ThemeData get light => _build(NjColors.light, Brightness.light);

  /// Dark theme.
  static ThemeData get dark => _build(NjColors.dark, Brightness.dark);

  static ThemeData _build(NjColors nj, Brightness brightness) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: nj.teal,
      onPrimary: nj.tealInk,
      primaryContainer: nj.tealSoft,
      onPrimaryContainer: nj.ink,
      secondary: nj.bajaj,
      onSecondary: nj.bajajInk,
      secondaryContainer: nj.bajaj,
      onSecondaryContainer: nj.bajajInk,
      error: nj.danger,
      onError: nj.tealInk,
      errorContainer: nj.dangerSoft,
      onErrorContainer: nj.ink,
      surface: nj.surface,
      onSurface: nj.ink,
      surfaceContainerLowest: nj.surface,
      surfaceContainerLow: nj.surfaceAlt,
      surfaceContainer: nj.surfaceAlt,
      surfaceContainerHigh: nj.surfaceAlt,
      surfaceContainerHighest: nj.surfaceAlt,
      onSurfaceVariant: nj.muted,
      outline: nj.line,
      outlineVariant: nj.line,
      shadow: nj.shadow,
    );

    final text = NjTypography.textTheme(nj.ink);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: nj.bg,
      canvasColor: nj.bg,
      textTheme: text,
      // Must be the package-qualified name: a bare family name resolves
      // against the *app's* assets, not this package's, and fails silently.
      fontFamily: NjTypography.themeFontFamily,
      extensions: <ThemeExtension<dynamic>>[nj],
      splashFactory: InkSparkle.splashFactory,
      // The design's focus ring is bajaj yellow, so focus never reads as an
      // error or a selection -- both of which already own teal and danger.
      focusColor: nj.bajaj.withValues(alpha: 0.25),
      highlightColor: nj.bajaj.withValues(alpha: 0.12),
      appBarTheme: AppBarTheme(
        backgroundColor: nj.bg,
        foregroundColor: nj.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      dividerTheme: DividerThemeData(
        color: nj.line,
        thickness: NjBorder.hairline,
        space: NjBorder.hairline,
      ),
      // Njiani uses its own controls, but any stray Material widget should
      // still land inside the palette rather than on Material defaults.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: nj.ink,
        contentTextStyle: text.bodyMedium?.copyWith(
          color: nj.surface,
          fontWeight: FontWeight.w600,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NjRadius.input),
        ),
      ),
    );
  }
}

/// Shorthand for reading Njiani tokens off the current theme.
///
/// ```dart
/// Container(color: context.nj.bajaj)
/// ```
extension NjThemeX on BuildContext {
  /// The Njiani colour tokens for the active theme.
  ///
  /// Falls back to the light palette rather than throwing, so a widget
  /// rendered outside an [NjTheme] (a test, a preview) still draws.
  NjColors get nj =>
      Theme.of(this).extension<NjColors>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? NjColors.dark
          : NjColors.light);

  /// The active text theme.
  TextTheme get njText => Theme.of(this).textTheme;
}
