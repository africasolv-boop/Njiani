import 'package:flutter/material.dart';

import 'nj_colors.dart';

/// Spacing scale, in logical pixels.
///
/// Every gap and pad in the apps comes from here. If a value is not on the
/// scale it is almost always a mistake -- reach for the nearest step instead of
/// inventing one.
abstract final class NjSpace {
  /// 4 — hairline gaps inside a control.
  static const double xs = 4;

  /// 8 — between tightly related items.
  static const double sm = 8;

  /// 12 — inside cards.
  static const double md = 12;

  /// 16 — the default gap.
  static const double lg = 16;

  /// 20 — screen side padding.
  static const double xl = 20;

  /// 24 — between sections.
  static const double xxl = 24;

  /// 32 — major section breaks.
  static const double xxxl = 32;
}

/// Corner radii, matching the pitch deck.
abstract final class NjRadius {
  /// 6 — plate badge.
  static const double plate = 6;

  /// 12 — price chips.
  static const double chip = 12;

  /// 14 — inputs and toasts.
  static const double input = 14;

  /// 16 — buttons and request cards.
  static const double button = 16;

  /// 18 — driver cards.
  static const double card = 18;

  /// 24 — bottom sheets.
  static const double sheet = 24;

  /// 999 — fully rounded pills.
  static const double pill = 999;
}

/// Animation durations.
///
/// Kept short: these run on low-end Android handsets, and the driver feed
/// updates while someone is riding a motorcycle.
abstract final class NjDuration {
  /// 150ms — colour and border changes.
  static const Duration fast = Duration(milliseconds: 150);

  /// 250ms — toasts appearing.
  static const Duration normal = Duration(milliseconds: 250);

  /// 350ms — request cards dropping into the feed.
  static const Duration slow = Duration(milliseconds: 350);
}

/// Border widths.
abstract final class NjBorder {
  /// 1 — dividers and subtle card outlines.
  static const double hairline = 1;

  /// 2 — input and chip outlines, which must read on a sunlit screen.
  static const double control = 2;

  /// 3 — the selected tab underline.
  static const double emphasis = 3;
}

/// Elevation shadows.
abstract final class NjShadow {
  /// The sheet and phone shadow: `0 18px 40px`.
  static List<BoxShadow> sheet(NjColors nj) => [
        BoxShadow(
          color: nj.shadow,
          blurRadius: 40,
          offset: const Offset(0, 18),
        ),
      ];

  /// The small lift under a selected segmented-control option.
  static List<BoxShadow> segment(NjColors nj) => [
        BoxShadow(
          color: nj.shadow.withValues(alpha: 0.4),
          blurRadius: 3,
          offset: const Offset(0, 1),
        ),
      ];
}
