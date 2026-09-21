import 'package:flutter/material.dart';

import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';

/// Pickup and destination, joined by a connector line.
///
/// A teal dot for where you are, a yellow square for where you are going --
/// the same two marks used on the map, so the sheet and the map agree.
class NjWhereRow extends StatelessWidget {
  const NjWhereRow({
    super.key,
    required this.fromLabel,
    required this.fromValue,
    this.toLabel,
    this.toValue,
    this.toChild,
  });

  /// Caption above the origin, e.g. 'Pickup, from your location'.
  final String fromLabel;

  /// The origin, e.g. 'Ubungo Bus Terminal'.
  final String fromValue;

  /// Caption above the destination, e.g. 'Going to'.
  final String? toLabel;

  /// The destination as plain text.
  final String? toValue;

  /// The destination as a widget, e.g. a dropdown.
  ///
  /// Takes precedence over [toValue] -- the passenger screen needs a picker
  /// here, while the trip screen only needs the name.
  final Widget? toChild;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;
    final hasDestination = toValue != null || toChild != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const SizedBox(height: NjSpace.lg),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: nj.teal, shape: BoxShape.circle),
            ),
            if (hasDestination) ...[
              Container(width: 2, height: 22, color: nj.line),
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: nj.bajaj,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(width: NjSpace.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Label(fromLabel),
              Text(
                fromValue,
                style: context.njText.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (hasDestination) ...[
                const SizedBox(height: NjSpace.md),
                if (toLabel != null) _Label(toLabel!),
                if (toChild != null)
                  toChild!
                else
                  Text(
                    toValue!,
                    style: context.njText.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: context.njText.bodySmall?.copyWith(
          fontSize: 12,
          color: context.nj.muted,
        ),
      );
}
