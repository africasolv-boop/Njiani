import 'package:flutter/material.dart';

import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';

/// A shimmering placeholder block.
///
/// The design asks for skeletons rather than spinners on the history screens:
/// a skeleton says what is coming and how much of it, which on a slow Dar
/// connection is the difference between waiting and giving up.
///
/// Note for tests: this animates indefinitely, so a tree containing one will
/// never settle. Use `pump(duration)` rather than `pumpAndSettle()`.
class NjSkeleton extends StatefulWidget {
  const NjSkeleton({
    super.key,
    this.width,
    this.height = 14,
    this.radius = NjRadius.plate,
  });

  /// Fixed width, or null to fill the available space.
  final double? width;

  /// Block height.
  final double height;

  /// Corner radius.
  final double radius;

  @override
  State<NjSkeleton> createState() => _NjSkeletonState();
}

class _NjSkeletonState extends State<NjSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;

    return FadeTransition(
      opacity: Tween<double>(begin: 0.45, end: 1).animate(_controller),
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: nj.line,
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Three stacked skeleton lines shaped like a trip card.
class NjSkeletonCard extends StatelessWidget {
  const NjSkeletonCard({super.key});

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;

    return Container(
      padding: const EdgeInsets.all(NjSpace.md + 2),
      decoration: BoxDecoration(
        color: nj.surface,
        borderRadius: BorderRadius.circular(NjRadius.button),
        border: Border.all(color: nj.line),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: NjSkeleton(height: 16)),
              SizedBox(width: NjSpace.xxl),
              NjSkeleton(width: 64, height: 16),
            ],
          ),
          SizedBox(height: NjSpace.sm + 2),
          NjSkeleton(width: 180, height: 12),
          SizedBox(height: NjSpace.sm + 2),
          NjSkeleton(height: 6),
        ],
      ),
    );
  }
}
