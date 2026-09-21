import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:njiani_core/njiani_core.dart';

/// Asserts the code matches the Claude Design project `Njiani Apps.dc.html`.
///
/// Values here are transcribed from that file's own swatch list and inline
/// styles. It is the source of visual truth (ARCHITECTURE D14), so a token
/// drifting away from it should fail the build rather than be discovered on a
/// device weeks later.
void main() {
  String hex(Color c) =>
      '#${((c.r * 255).round() << 16 | (c.g * 255).round() << 8 | (c.b * 255).round()).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  group('light palette matches the design', () {
    const expected = {
      'bg': '#E6EBE8',
      'surface': '#FFFFFF',
      'surfaceAlt': '#F3F6F4',
      'ink': '#1D2226',
      'muted': '#5A646B',
      'line': '#D2D9D5',
      'bajaj': '#F2B705',
      'teal': '#0E6E6C',
      'tealSoft': '#D5EBE9',
      'danger': '#B83227',
      'map': '#D9E1DC',
      'live': '#2DB35A',
    };

    test('every swatch', () {
      const nj = NjColors.light;
      final actual = {
        'bg': hex(nj.bg),
        'surface': hex(nj.surface),
        'surfaceAlt': hex(nj.surfaceAlt),
        'ink': hex(nj.ink),
        'muted': hex(nj.muted),
        'line': hex(nj.line),
        'bajaj': hex(nj.bajaj),
        'teal': hex(nj.teal),
        'tealSoft': hex(nj.tealSoft),
        'danger': hex(nj.danger),
        'map': hex(nj.map),
        'live': hex(nj.live),
      };
      expect(actual, expected);
    });

    test('supporting colours', () {
      expect(hex(NjColors.light.bajajInk), '#2A2100');
      expect(hex(NjColors.light.tealInk), '#FFFFFF');
      expect(hex(NjColors.light.dangerSoft), '#F6DEDB');
      expect(hex(NjColors.light.roadMain), '#F7E7B0');
    });
  });

  group('dark palette matches the design', () {
    const expected = {
      'bg': '#14181B',
      'surface': '#1E2428',
      'surfaceAlt': '#252C31',
      'ink': '#ECF0EE',
      'muted': '#9AA5AB',
      'line': '#333C42',
      'bajaj': '#F2B705',
      'teal': '#3BB0AA',
      'tealSoft': '#1B3634',
      'danger': '#E8766B',
      'map': '#222A2E',
      'live': '#2DB35A',
    };

    test('every swatch', () {
      const nj = NjColors.dark;
      final actual = {
        'bg': hex(nj.bg),
        'surface': hex(nj.surface),
        'surfaceAlt': hex(nj.surfaceAlt),
        'ink': hex(nj.ink),
        'muted': hex(nj.muted),
        'line': hex(nj.line),
        'bajaj': hex(nj.bajaj),
        'teal': hex(nj.teal),
        'tealSoft': hex(nj.tealSoft),
        'danger': hex(nj.danger),
        'map': hex(nj.map),
        'live': hex(nj.live),
      };
      expect(actual, expected);
    });

    test('supporting colours', () {
      expect(hex(NjColors.dark.tealInk), '#06201F');
      expect(hex(NjColors.dark.dangerSoft), '#3A2220');
    });
  });

  group('plate colours are fixed in both themes', () {
    test('a real plate has no dark mode', () {
      expect(hex(NjPlateBadge.plateYellow), '#FFD21F');
      expect(hex(NjPlateBadge.plateInk), '#111111');
    });
  });

  group('type scale matches the design', () {
    final text = NjTheme.light.textTheme;

    test('sizes', () {
      expect(text.displayLarge?.fontSize, 41.6, reason: 'wordmark');
      expect(text.headlineLarge?.fontSize, 25.6, reason: 'screen heading');
      expect(text.headlineMedium?.fontSize, 24, reason: 'ETA / offer');
      expect(text.headlineSmall?.fontSize, 21.6, reason: 'request price');
      expect(text.labelLarge?.fontSize, 16.8, reason: 'button label');
      expect(text.bodySmall?.fontSize, 13.6, reason: 'caption');
    });

    test('weights', () {
      expect(text.displayLarge?.fontWeight, FontWeight.w800);
      expect(text.headlineLarge?.fontWeight, FontWeight.w700);
      expect(text.labelLarge?.fontWeight, FontWeight.w700);
    });

    test('plate and route board', () {
      expect(NjTypography.plate.fontSize, 18);
      expect(NjTypography.plate.letterSpacing, 1.5);
      expect(NjTypography.routeBoard.fontSize, 15.2);
      expect(NjTypography.routeBoard.fontWeight, FontWeight.w800);
    });
  });

  group('geometry matches the design', () {
    test('radii', () {
      expect(NjRadius.plate, 6);
      expect(NjRadius.chip, 12);
      expect(NjRadius.input, 14);
      expect(NjRadius.button, 16);
      expect(NjRadius.card, 18);
      expect(NjRadius.sheet, 24);
    });

    test('button heights', () {
      // "Minimum tap target 44pt; primary buttons 56pt."
      expect(NjButtonSize.primary.minHeight, 56);
      expect(NjButtonSize.compact.minHeight, 48);
      expect(NjButtonSize.compact.radius, 12);
    });

    test('control borders are 2pt, for a sunlit screen', () {
      expect(NjBorder.control, 2);
      expect(NjBorder.emphasis, 3);
    });
  });

  group('font resolution', () {
    test('every themed style resolves to the packaged family', () {
      // A font shipped inside a package resolves under
      // `packages/<package>/<family>`. TextStyle applies the prefix from
      // `package:`; ThemeData.fontFamily does not, so it is given the
      // qualified name directly.
      const qualified = 'packages/njiani_core/BricolageGrotesque';
      expect(NjTypography.themeFontFamily, qualified);

      for (final theme in [NjTheme.light, NjTheme.dark]) {
        for (final style in [
          theme.textTheme.displayLarge,
          theme.textTheme.headlineLarge,
          theme.textTheme.bodyMedium,
          theme.textTheme.bodySmall,
          theme.textTheme.labelLarge,
        ]) {
          expect(style?.fontFamily, qualified);
        }
      }

      expect(NjTypography.plate.fontFamily, qualified);
      expect(NjTypography.routeBoard.fontFamily, qualified);
    });

    test('no fallback family is configured', () {
      // A fallback list on a package font gets the package prefix applied to
      // every entry, turning e.g. 'system-ui' into
      // 'packages/njiani_core/system-ui' -- a font that does not exist. A
      // dead fallback chain is worse than none, because it hides that the
      // primary family failed.
      for (final theme in [NjTheme.light, NjTheme.dark]) {
        expect(
          theme.textTheme.bodyMedium?.fontFamilyFallback,
          anyOf(isNull, isEmpty),
        );
      }
    });
  });
}
