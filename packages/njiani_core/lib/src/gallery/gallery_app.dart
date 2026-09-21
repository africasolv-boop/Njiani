import 'package:flutter/material.dart';

import '../config/app_identity.dart';
import '../design/nj_theme.dart';
import 'gallery_screen.dart';

/// Hosts the component gallery with a theme switch of its own.
///
/// The in-app toggle exists so the light and dark themes can be compared
/// side by side without going to device settings and losing your place in the
/// list. Both apps run this at C1; real screens replace it at C2.
class NjGalleryApp extends StatefulWidget {
  const NjGalleryApp({super.key, required this.app});

  /// Which app is hosting the gallery.
  final NjianiApp app;

  @override
  State<NjGalleryApp> createState() => _NjGalleryAppState();
}

class _NjGalleryAppState extends State<NjGalleryApp> {
  /// Null means follow the device.
  ThemeMode _mode = ThemeMode.system;

  bool _isDark(BuildContext context) => switch (_mode) {
        ThemeMode.dark => true,
        ThemeMode.light => false,
        ThemeMode.system =>
          MediaQuery.platformBrightnessOf(context) == Brightness.dark,
      };

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: widget.app.label,
      debugShowCheckedModeBanner: false,
      theme: NjTheme.light,
      darkTheme: NjTheme.dark,
      themeMode: _mode,
      home: Builder(
        builder: (context) {
          final dark = _isDark(context);
          return NjGalleryScreen(
            app: widget.app,
            isDark: dark,
            onToggleTheme: () => setState(
              () => _mode = dark ? ThemeMode.light : ThemeMode.dark,
            ),
          );
        },
      ),
    );
  }
}
