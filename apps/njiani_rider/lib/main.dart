import 'package:flutter/material.dart';
import 'package:njiani_core/njiani_core.dart';

/// Entry point for the Njiani passenger app.
///
/// C0 keeps this to a single line on purpose: everything shared lives in
/// `njiani_core`, and this file should stay a thin wrapper around it.
void main() {
  runApp(const NjianiBootApp(app: NjianiApp.rider));
}
