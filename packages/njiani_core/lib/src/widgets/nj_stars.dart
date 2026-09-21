import 'package:flutter/material.dart';

import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';

/// A five-star rating, tappable or read-only.
class NjStars extends StatelessWidget {
  const NjStars({
    super.key,
    required this.rating,
    this.onRated,
    this.size = 34,
  });

  /// Stars currently filled, 0 to 5.
  final int rating;

  /// Called with the tapped star. Null makes the row read-only.
  final ValueChanged<int>? onRated;

  /// Star glyph size.
  final double size;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;
    final interactive = onRated != null;

    return Semantics(
      label: '$rating of 5 stars',
      excludeSemantics: !interactive,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var star = 1; star <= 5; star++)
            Semantics(
              button: interactive,
              label: interactive ? '$star star${star > 1 ? 's' : ''}' : null,
              child: GestureDetector(
                onTap: interactive ? () => onRated!(star) : null,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: NjSpace.xs - 1,
                    // Keeps the tap target at 44pt without spreading the row.
                    vertical: NjSpace.sm,
                  ),
                  child: Icon(
                    star <= rating ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: size,
                    color: star <= rating ? nj.bajaj : nj.line,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
