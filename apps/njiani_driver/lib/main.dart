import 'package:flutter/material.dart';
import 'package:njiani_core/njiani_core.dart';

/// Entry point for the Njiani driver app.
///
/// C1 runs the shared component gallery so the design system can be judged on
/// a real device. C2 replaces this with the real routed app shell.
void main() {
  runApp(const NjGalleryApp(app: NjianiApp.driver));
}
