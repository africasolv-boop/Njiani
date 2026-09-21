import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:njiani_core/njiani_core.dart';

/// WCAG 2.1 relative luminance.
double _luminance(Color c) {
  double channel(double v) {
    final s = v;
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4) as double;
  }

  return 0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);
}

/// WCAG 2.1 contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final lighter = math.max(la, lb);
  final darker = math.min(la, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  group('NjColors', () {
    test('bajaj yellow is identical in both themes', () {
      // It imitates a physical object -- the painted daladala route board and
      // the vehicles themselves -- so it must not follow the device theme.
      expect(NjColors.light.bajaj, NjColors.dark.bajaj);
      expect(NjColors.light.bajajInk, NjColors.dark.bajajInk);
    });

    test('the live dot is green in both themes', () {
      expect(NjColors.light.live, NjColors.dark.live);
    });

    test('light and dark differ where they should', () {
      expect(NjColors.light.bg, isNot(NjColors.dark.bg));
      expect(NjColors.light.ink, isNot(NjColors.dark.ink));
      expect(NjColors.light.teal, isNot(NjColors.dark.teal));
    });

    test('lerp interpolates and returns this when other is null', () {
      final mid = NjColors.light.lerp(NjColors.dark, 0.5);
      expect(mid.bg, isNot(NjColors.light.bg));
      expect(NjColors.light.lerp(null, 0.5), same(NjColors.light));
    });

    test('lerp at the endpoints returns the endpoints', () {
      expect(NjColors.light.lerp(NjColors.dark, 0).bg, NjColors.light.bg);
      expect(NjColors.light.lerp(NjColors.dark, 1).bg, NjColors.dark.bg);
    });

    test('copyWith changes only what it is given', () {
      const red = Color(0xFFFF0000);
      final changed = NjColors.light.copyWith(teal: red);
      expect(changed.teal, red);
      expect(changed.bg, NjColors.light.bg);
      expect(changed.bajaj, NjColors.light.bajaj);
    });
  });

  group('palette contrast', () {
    // These are the pairs real text actually lands on. A token change that
    // makes any of them unreadable should fail here, not in the field.
    final pairs = <String, (Color, Color, double)>{
      'light: ink on bg':
          (NjColors.light.ink, NjColors.light.bg, 4.5),
      'light: ink on surface':
          (NjColors.light.ink, NjColors.light.surface, 4.5),
      'light: muted on bg':
          (NjColors.light.muted, NjColors.light.bg, 4.5),
      'light: muted on surface':
          (NjColors.light.muted, NjColors.light.surface, 4.5),
      // Button labels are 16.8px bold, which WCAG counts as large text (3:1).
      'light: tealInk on teal':
          (NjColors.light.tealInk, NjColors.light.teal, 3.0),
      'light: bajajInk on bajaj':
          (NjColors.light.bajajInk, NjColors.light.bajaj, 4.5),
      'light: danger on dangerSoft':
          (NjColors.light.danger, NjColors.light.dangerSoft, 4.5),
      'light: teal on surface':
          (NjColors.light.teal, NjColors.light.surface, 4.5),
      'dark: ink on bg': (NjColors.dark.ink, NjColors.dark.bg, 4.5),
      'dark: ink on surface': (NjColors.dark.ink, NjColors.dark.surface, 4.5),
      'dark: muted on bg': (NjColors.dark.muted, NjColors.dark.bg, 4.5),
      'dark: muted on surface':
          (NjColors.dark.muted, NjColors.dark.surface, 4.5),
      'dark: tealInk on teal':
          (NjColors.dark.tealInk, NjColors.dark.teal, 3.0),
      'dark: bajajInk on bajaj':
          (NjColors.dark.bajajInk, NjColors.dark.bajaj, 4.5),
      'dark: danger on dangerSoft':
          (NjColors.dark.danger, NjColors.dark.dangerSoft, 4.5),
      'dark: teal on surface':
          (NjColors.dark.teal, NjColors.dark.surface, 4.5),
    };

    pairs.forEach((name, spec) {
      final (fg, bg, minimum) = spec;
      test('$name meets ${minimum.toStringAsFixed(1)}:1', () {
        final ratio = _contrast(fg, bg);
        expect(
          ratio,
          greaterThanOrEqualTo(minimum),
          reason: '$name is ${ratio.toStringAsFixed(2)}:1',
        );
      });
    });

    test('the plate badge is readable', () {
      // Fixed colours in both themes -- a real plate has no dark mode.
      expect(
        _contrast(NjPlateBadge.plateInk, NjPlateBadge.plateYellow),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('NjTheme', () {
    test('registers the NjColors extension on both themes', () {
      expect(NjTheme.light.extension<NjColors>(), NjColors.light);
      expect(NjTheme.dark.extension<NjColors>(), NjColors.dark);
    });

    test('uses the bundled font, not a system fallback', () {
      expect(NjTheme.light.textTheme.bodyMedium?.fontFamily,
          contains('BricolageGrotesque'));
    });

    test('scaffold background is the page colour, not Material grey', () {
      expect(NjTheme.light.scaffoldBackgroundColor, NjColors.light.bg);
      expect(NjTheme.dark.scaffoldBackgroundColor, NjColors.dark.bg);
    });

    testWidgets('context.nj reads the active palette', (tester) async {
      late NjColors seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: NjTheme.dark,
          home: Builder(
            builder: (context) {
              seen = context.nj;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen, NjColors.dark);
    });

    testWidgets('context.nj falls back instead of throwing outside NjTheme',
        (tester) async {
      late NjColors seen;
      await tester.pumpWidget(
        MaterialApp(
          // A bare Material theme with no NjColors extension registered.
          theme: ThemeData.light(),
          home: Builder(
            builder: (context) {
              seen = context.nj;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen, NjColors.light);
    });
  });
}
