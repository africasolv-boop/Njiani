import 'package:flutter/material.dart';

import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';

/// What a button means, which decides how it looks.
enum NjButtonVariant {
  /// Teal. The main action on a screen: Send code, Verify, I'm on board.
  primary,

  /// Bajaj yellow. Reserved for the moment of commitment -- Send request,
  /// Go online -- so the decisive tap is never the same colour as the
  /// routine one.
  bajaj,

  /// Outlined. Secondary actions sitting beside a primary one.
  ghost,

  /// Outlined in danger colour. Cancel a request, cancel a trip.
  dangerGhost,

  /// Filled flat, muted text. The action exists but cannot be taken right
  /// now for a reason the label states -- "Seats full".
  ///
  /// Deliberately not the same as a disabled [primary]: a dimmed button reads
  /// as "not yet", whereas this reads as "not possible, and here is why".
  /// The design calls for both, and they mean different things to a driver.
  blocked,
}

/// Button height, which the design ties to the action's weight.
enum NjButtonSize {
  /// 56pt. Screen-level primary actions, tapped one-handed on a moving bajaj.
  primary(minHeight: 56, radius: NjRadius.button),

  /// 48pt. Actions inside a card, such as Pickup in the driver feed.
  compact(minHeight: 48, radius: NjRadius.chip);

  const NjButtonSize({required this.minHeight, required this.radius});

  /// Minimum tap height.
  final double minHeight;

  /// Corner radius at this size.
  final double radius;
}

/// The Njiani button.
///
/// Full width by default, because nearly every button in the design spans its
/// container. Never below 48pt, and 56pt for screen-level actions.
class NjButton extends StatelessWidget {
  const NjButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = NjButtonVariant.primary,
    this.size = NjButtonSize.primary,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  /// Button text.
  final String label;

  /// Tapped callback. Null disables the button.
  final VoidCallback? onPressed;

  /// Which meaning this button carries.
  final NjButtonVariant variant;

  /// Which height this button uses.
  final NjButtonSize size;

  /// Optional leading icon.
  final IconData? icon;

  /// Shows a spinner and blocks taps.
  ///
  /// Kept distinct from a null [onPressed] so a button waiting on the network
  /// does not look the same as one that is not yet available.
  final bool loading;

  /// Whether to fill the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;
    final blocked = variant == NjButtonVariant.blocked;
    final enabled = onPressed != null && !loading && !blocked;

    final (Color bg, Color fg, Color? border) = switch (variant) {
      NjButtonVariant.primary => (nj.teal, nj.tealInk, null),
      NjButtonVariant.bajaj => (nj.bajaj, nj.bajajInk, null),
      NjButtonVariant.ghost => (Colors.transparent, nj.ink, nj.line),
      NjButtonVariant.dangerGhost => (Colors.transparent, nj.danger, nj.line),
      NjButtonVariant.blocked => (nj.surfaceAlt, nj.muted, null),
    };

    final radius = BorderRadius.circular(size.radius);

    return Opacity(
      // The design's disabled treatment. `blocked` stays at full opacity: it
      // is a statement, not a dimmed-out control.
      opacity: (onPressed == null && !blocked) || (loading && onPressed == null)
          ? 0.45
          : 1,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: Material(
          color: bg,
          borderRadius: radius,
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: radius,
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: border == null
                    ? null
                    : Border.all(color: border, width: NjBorder.control),
              ),
              child: Container(
                constraints: BoxConstraints(minHeight: size.minHeight),
                padding: const EdgeInsets.symmetric(
                  horizontal: NjSpace.lg,
                  vertical: NjSpace.md,
                ),
                child: Row(
                  mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (loading) ...[
                      SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(fg),
                        ),
                      ),
                      const SizedBox(width: NjSpace.sm),
                    ] else if (icon != null) ...[
                      Icon(icon, size: 20, color: fg),
                      const SizedBox(width: NjSpace.sm),
                    ],
                    Flexible(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: (size == NjButtonSize.compact
                                ? context.njText.titleMedium
                                : context.njText.labelLarge)
                            ?.copyWith(
                          color: fg,
                          fontWeight: size == NjButtonSize.compact
                              ? FontWeight.w800
                              : FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
