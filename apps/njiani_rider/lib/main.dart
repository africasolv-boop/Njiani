import 'package:flutter/material.dart';
import 'package:njiani_core/njiani_core.dart';

/// Which of the two apps this binary is.
///
/// Declared as a constant rather than inlined into [main] so it can be
/// asserted in a test without calling `runApp`. That guards against the two
/// apps' entry points being copy-pasted and left identical -- which would
/// ship the driver app under the passenger app's name.
const NjianiApp njianiApp = NjianiApp.rider;

/// Entry point for the Njiani passenger app.
///
/// C1 runs the shared component gallery so the design system can be judged on
/// a real device. C2 replaces this with the real routed app shell.
void main() {
  runApp(const NjGalleryApp(app: njianiApp));
}
