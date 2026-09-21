import 'package:flutter/material.dart';

/// A column that fills the screen when the content is short, and scrolls when
/// it is not.
///
/// Almost every Njiani screen has the same shape: some content at the top, a
/// [Spacer], and a primary action pinned to the bottom. A plain [Column] gets
/// that right on a big phone and overflows on a small one -- and it overflows
/// badly once the system text scale is turned up, which real users do.
///
/// This keeps the [Spacer] behaviour while the content fits, and becomes a
/// scroll view the moment it does not, so the bottom action is always
/// reachable instead of being clipped.
class NjScreenBody extends StatelessWidget {
  const NjScreenBody({
    super.key,
    required this.children,
    this.padding = EdgeInsets.zero,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  /// Column contents. A [Spacer] here behaves as it would in a [Column].
  final List<Widget> children;

  /// Padding inside the scrollable area.
  final EdgeInsetsGeometry padding;

  /// Horizontal alignment of the children.
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: padding,
          // Nothing to scroll while the content fits; the column simply fills.
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  constraints.maxHeight -
                  padding.resolve(Directionality.of(context)).vertical,
            ),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: crossAxisAlignment,
                children: children,
              ),
            ),
          ),
        );
      },
    );
  }
}
