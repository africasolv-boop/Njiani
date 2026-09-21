import 'package:flutter/material.dart';

import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';

/// What a button means, which decides how it looks.
enum NjButtonVariant {
  /// Teal. The main action on a screen: Send code, Verify, I'm on board.
  primary,

  /// Bajaj yellow. Reserved for the moment of commitment -- Send request,
  /// Start heading to Kimara -- so the decisive tap is never the same colour
  /// as the routine one.
  bajaj,

  /// Outlined. Secondary actions sitting beside a primary one.
  ghost,

  /// Outlined in danger colour. Cancel a request, cancel a trip.
  dangerGhost,
}

/// The Njiani button.
///
/// Full width by default, because nearly every button in the design spans the
/// sheet. Tall enough (56pt) to hit reliably one-handed on a moving bajaj.
class NjButton extends StatelessWidget {
  const NjButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = NjButtonVariant.primary,
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

  /// Optional leading icon.
  final IconData? icon;

  /// Shows a spinner and blocks taps.
  ///
  /// Kept distinct from a null [onPressed] so a button that is waiting on the
  /// network does not look the same as one that is not yet available.
  final bool loading;

  /// Whether to fill the available width.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;
    final enabled = onPressed != null && !loading;

    final (Color bg, Color fg, Color? border) = switch (variant) {
      NjButtonVariant.primary => (nj.teal, nj.tealInk, null),
      NjButtonVariant.bajaj => (nj.bajaj, nj.bajajInk, null),
      NjButtonVariant.ghost => (Colors.transparent, nj.ink, nj.line),
      NjButtonVariant.dangerGhost => (Colors.transparent, nj.danger, nj.line),
    };

    return Opacity(
      // Matches the design's disabled treatment rather than greying the fill,
      // which would collide with the ghost variants.
      opacity: enabled ? 1 : 0.45,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: label,
        child: Material(
          color: bg,
          borderRadius: BorderRadius.circular(NjRadius.button),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(NjRadius.button),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(NjRadius.button),
                border: border == null
                    ? null
                    : Border.all(color: border, width: NjBorder.control),
              ),
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsets.symmetric(
                  horizontal: NjSpace.xl,
                  vertical: NjSpace.lg,
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
                        style: context.njText.labelLarge?.copyWith(color: fg),
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
