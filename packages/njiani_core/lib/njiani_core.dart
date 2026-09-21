/// Shared code for both Njiani apps.
///
/// Everything that is not specific to the rider app or the driver app lives
/// here: the design system, domain models, the Supabase data layer and
/// localisation. Both `apps/njiani_rider` and `apps/njiani_driver` depend on it.
library;

export 'src/boot/boot_app.dart';
export 'src/boot/boot_screen.dart';
export 'src/boot/njiani_mark.dart';
export 'src/config/app_config.dart';
export 'src/config/app_identity.dart';
