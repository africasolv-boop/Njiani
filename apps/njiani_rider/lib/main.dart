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
/// Everything shared -- theme, localisation, routing -- lives in
/// [NjianiRoot]. This file should stay a single line.
Future<void> main() => NjianiRoot.bootstrap(njianiApp);
