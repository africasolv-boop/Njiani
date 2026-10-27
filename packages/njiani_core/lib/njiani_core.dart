/// Shared code for both Njiani apps.
///
/// Everything that is not specific to the rider app or the driver app lives
/// here: the design system, domain models, the Supabase data layer and
/// localisation. Both `apps/njiani_rider` and `apps/njiani_driver` depend on it.
///
/// Grouped by area in the source tree; exported as one sorted list because the
/// analyzer requires directives to be alphabetical.
///
///   src/config/   build configuration and app identity
///   src/driver/   the verification gate, the driver's record, the session
///   src/places/   routes, stages, and what is ahead on the road
///   src/design/   colour tokens, spacing, typography, theme
///   src/widgets/  the design system
///   src/util/     formatters and helpers
///   src/boot/     C0 boot screen, kept reachable from the gallery
///   src/gallery/  C1 component gallery, a development surface
library;

export 'src/app/nj_router.dart';
export 'src/app/nj_routes.dart';
export 'src/app/njiani_root.dart';
export 'src/auth/auth_controller.dart';
export 'src/auth/auth_failure.dart';
export 'src/auth/auth_repository.dart';
export 'src/auth/fake_auth_repository.dart';
export 'src/auth/tz_phone.dart';
export 'src/boot/boot_app.dart';
export 'src/boot/boot_screen.dart';
export 'src/boot/njiani_mark.dart';
export 'src/config/app_config.dart';
export 'src/config/app_identity.dart';
export 'src/data/supabase_client.dart';
export 'src/design/nj_colors.dart';
export 'src/design/nj_theme.dart';
export 'src/design/nj_tokens.dart';
export 'src/design/nj_typography.dart';
export 'src/driver/driver.dart';
export 'src/driver/driver_controller.dart';
export 'src/driver/driver_location.dart';
export 'src/driver/driver_repository.dart';
export 'src/driver/driver_session.dart';
export 'src/driver/feed_alert.dart';
export 'src/driver/feed_controller.dart';
export 'src/driver/feed_repository.dart';
export 'src/driver/feed_request.dart';
export 'src/driver/licence_camera.dart';
export 'src/driver/session_controller.dart';
export 'src/driver/session_repository.dart';
export 'src/gallery/gallery_app.dart';
export 'src/gallery/gallery_screen.dart';
export 'src/l10n/generated/nj_strings.dart';
export 'src/locale/language_controller.dart';
export 'src/locale/language_store.dart';
export 'src/locale/nj_locale.dart';
export 'src/places/place.dart';
export 'src/places/places_repository.dart';
export 'src/profile/profile.dart';
export 'src/profile/profile_controller.dart';
export 'src/profile/profile_repository.dart';
export 'src/screens/driver_direction_screen.dart';
export 'src/screens/driver_feed_screen.dart';
export 'src/screens/driver_pending_screen.dart';
export 'src/screens/driver_rejected_screen.dart';
export 'src/screens/driver_signup_screen.dart';
export 'src/screens/language_screen.dart';
export 'src/screens/otp_screen.dart';
export 'src/screens/phone_screen.dart';
export 'src/screens/placeholder_screen.dart';
export 'src/util/money.dart';
export 'src/util/redact.dart';
export 'src/util/support_call.dart';
export 'src/widgets/nj_action_tile.dart';
export 'src/widgets/nj_avatar.dart';
export 'src/widgets/nj_badge.dart';
export 'src/widgets/nj_banner.dart';
export 'src/widgets/nj_button.dart';
export 'src/widgets/nj_card.dart';
export 'src/widgets/nj_choice_chips.dart';
export 'src/widgets/nj_empty_state.dart';
export 'src/widgets/nj_hint.dart';
export 'src/widgets/nj_live_dot.dart';
export 'src/widgets/nj_meter.dart';
export 'src/widgets/nj_option_tile.dart';
export 'src/widgets/nj_otp_field.dart';
export 'src/widgets/nj_plate.dart';
export 'src/widgets/nj_route_board.dart';
export 'src/widgets/nj_screen_body.dart';
export 'src/widgets/nj_seat_indicator.dart';
export 'src/widgets/nj_segmented.dart';
export 'src/widgets/nj_sheet.dart';
export 'src/widgets/nj_skeleton.dart';
export 'src/widgets/nj_stars.dart';
export 'src/widgets/nj_stat_card.dart';
export 'src/widgets/nj_status_row.dart';
export 'src/widgets/nj_text_field.dart';
export 'src/widgets/nj_toast.dart';
export 'src/widgets/nj_upload_box.dart';
export 'src/widgets/nj_where_row.dart';
