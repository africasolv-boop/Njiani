import 'package:flutter/material.dart';

import '../config/app_identity.dart';
import '../design/nj_theme.dart';
import 'gallery_screen.dart';

/// Hosts the component gallery.
///
/// The gallery renders both themes itself, so there is no theme switch here:
/// the design's spec asks for light and dark in the same view, which is the
/// only way to catch a token that works in one and disappears in the other.
class NjGalleryApp extends StatelessWidget {
  const NjGalleryApp({super.key, required this.app});

  /// Which app is hosting the gallery.
  final NjianiApp app;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: app.label,
        debugShowCheckedModeBanner: false,
        theme: NjTheme.light,
        darkTheme: NjTheme.dark,
        home: NjGalleryScreen(app: app),
      );
}
