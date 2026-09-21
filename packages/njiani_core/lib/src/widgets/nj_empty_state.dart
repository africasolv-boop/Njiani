import 'package:flutter/material.dart';

import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';

/// Shown when a list has nothing in it yet.
///
/// Worth getting right: a driver who goes online to an empty feed needs to
/// know the app is working and waiting, not broken.
class NjEmptyState extends StatelessWidget {
  const NjEmptyState({
    super.key,
    required this.message,
    this.icon,
    this.action,
  });

  /// What is going on, in plain words.
  final String message;

  /// Optional illustrative icon.
  final IconData? icon;

  /// Optional action, e.g. a retry button.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: NjSpace.lg,
        vertical: NjSpace.xxxl + 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 40, color: nj.muted),
            const SizedBox(height: NjSpace.md),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.njText.bodyMedium?.copyWith(color: nj.muted),
          ),
          if (action != null) ...[
            const SizedBox(height: NjSpace.lg),
            action!,
          ],
        ],
      ),
    );
  }
}
