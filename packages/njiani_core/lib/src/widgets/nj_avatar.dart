import 'package:flutter/material.dart';

import '../design/nj_theme.dart';

/// A circular initials avatar.
///
/// Njiani has no profile photos: drivers are verified by licence and
/// identified by plate, so initials are enough and there is no photo to
/// collect, store or protect.
class NjAvatar extends StatelessWidget {
  const NjAvatar({super.key, required this.name, this.size = 46});

  /// Full name. Initials are derived from it.
  final String name;

  /// Diameter in logical pixels.
  final double size;

  /// Up to two uppercase initials from [name].
  static String initialsOf(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.characters.first.toUpperCase();
    }
    return (parts.first.characters.first + parts.last.characters.first)
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;

    return Semantics(
      label: name,
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: nj.tealSoft, shape: BoxShape.circle),
        child: Text(
          initialsOf(name),
          style: context.njText.titleMedium?.copyWith(
            color: nj.teal,
            fontWeight: FontWeight.w800,
            fontSize: size * 0.36,
          ),
        ),
      ),
    );
  }
}
