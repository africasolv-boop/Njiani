import 'package:flutter/material.dart';

import '../config/app_identity.dart';
import 'boot_screen.dart';

/// Minimal `MaterialApp` used by both apps at C0.
///
/// Deliberately thin: C1 brings the real theme, C2 brings routing and
/// localisation. This exists only so both apps have something to run.
class NjianiBootApp extends StatelessWidget {
  const NjianiBootApp({super.key, required this.app});

  final NjianiApp app;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: app.label,
        debugShowCheckedModeBanner: false,
        // themeMode defaults to ThemeMode.system, so both appearances below
        // follow the device setting -- check both when you test.
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0E6E6C),
            surface: const Color(0xFFE6EBE8),
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF3BB0AA),
            brightness: Brightness.dark,
            surface: const Color(0xFF14181B),
          ),
        ),
        home: BootScreen(app: app),
      );
}
