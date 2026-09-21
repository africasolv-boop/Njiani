import 'package:flutter/material.dart';

import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';

/// What an [NjBanner] is telling the user.
enum NjBannerTone {
  /// Something is wrong or unavailable: no connection, a rejected document.
  danger,

  /// Neutral context that is not a problem.
  info,
}

/// An inline banner across the top of a screen.
///
/// The design uses this for lost connection and for a rejected licence photo.
/// Both cases share one rule from the spec: never show a disabled control
/// without saying why, and never let losing signal look like losing the
/// request.
class NjBanner extends StatelessWidget {
  const NjBanner({
    super.key,
    required this.title,
    this.message,
    this.tone = NjBannerTone.danger,
    this.showDot = false,
  });

  /// Bold first line.
  final String title;

  /// Optional detail line.
  final String? message;

  /// Colour meaning.
  final NjBannerTone tone;

  /// Draws a solid status dot instead of an icon badge.
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;
    final danger = tone == NjBannerTone.danger;
    final bg = danger ? nj.dangerSoft : nj.surfaceAlt;
    final fg = danger ? nj.danger : nj.ink;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: NjSpace.md + 2,
        vertical: NjSpace.md,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(NjRadius.input),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showDot)
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 5, right: NjSpace.sm + 2),
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            )
          else
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              margin: const EdgeInsets.only(right: NjSpace.sm + 2),
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
              child: Text(
                '!',
                style: context.njText.labelMedium?.copyWith(
                  color: bg,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: context.njText.bodyMedium?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (message != null)
                  Text(
                    message!,
                    style: context.njText.bodySmall?.copyWith(color: fg),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
