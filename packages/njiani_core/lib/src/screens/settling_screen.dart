import 'package:flutter/material.dart';

import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';
import '../l10n/generated/nj_strings.dart';

/// What `/` renders while the router works out where someone belongs.
///
/// Both apps redirect away from `home` within a frame or two, so this is seen
/// only in passing — but it is seen, on a cold start, while the profile or
/// the driver record is still being read.
///
/// It replaced the landing placeholder, which said "This screen arrives in
/// the next component." That was fine as a stand-in and wrong as a resting
/// place: when a gate fell through, a driver sat on a sentence about an
/// unbuilt feature with no way out. A spinner at least looks like what it is.
class SettlingScreen extends StatelessWidget {
  const SettlingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;

    return Scaffold(
      backgroundColor: nj.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              NjStrings.of(context).appName,
              style: context.njText.displayLarge,
            ),
            const SizedBox(height: NjSpace.xl),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(strokeWidth: 3, color: nj.teal),
            ),
          ],
        ),
      ),
    );
  }
}
