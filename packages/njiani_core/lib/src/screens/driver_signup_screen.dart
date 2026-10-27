import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../auth/tz_phone.dart';
import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';
import '../driver/driver.dart';
import '../driver/driver_controller.dart';
import '../driver/driver_repository.dart';
import '../l10n/generated/nj_strings.dart';
import '../profile/profile_controller.dart';
import '../util/redact.dart';
import '../widgets/nj_button.dart';
import '../widgets/nj_screen_body.dart';
import '../widgets/nj_segmented.dart';
import '../widgets/nj_sheet.dart';
import '../widgets/nj_text_field.dart';
import '../widgets/nj_upload_box.dart';

/// `dSignup` — the verification gate. Component C6.
///
/// Everything on this screen is checked by a person before `drivers.status`
/// moves off `pending`, and the driver has no privilege to write that column.
///
/// Three rules from the design that are not cosmetic:
///
///   * **The photo uploads on its own, before Submit.** An upload that fails
///     must not cost the driver the details they typed. The upload box carries
///     its own failed state — "Photo didn't upload. Your details are saved." —
///     and only the photo is retried.
///   * **Submit stays disabled until name, plate and photo are all there,**
///     and stays disabled while the photo is in flight. There is nothing for
///     a person to review without the photo.
///   * **The plate is upper-cased as it is typed.** Drivers type a plate in
///     every casing there is, and the database constraint requires upper.
class DriverSignupScreen extends ConsumerStatefulWidget {
  const DriverSignupScreen({super.key});

  @override
  ConsumerState<DriverSignupScreen> createState() => _DriverSignupScreenState();
}

class _DriverSignupScreenState extends ConsumerState<DriverSignupScreen> {
  final _nameController = TextEditingController();
  final _plateController = TextEditingController();

  DriverApplication _application = const DriverApplication(
    colour: 'Blue',
  );

  NjUploadState _upload = NjUploadState.empty;
  DriverError? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _plateController.dispose();
    super.dispose();
  }

  bool get _busy => _submitting || _upload == NjUploadState.uploading;

  /// Opens the camera or the gallery, uploads, and records the path.
  ///
  /// The failure path is the interesting one: it sets the upload box to
  /// `failed` and leaves `_application` exactly as it was, so the typed
  /// details survive and the retry is one tap on the same box.
  Future<void> _attachLicence({required bool fromGallery}) async {
    setState(() {
      _upload = NjUploadState.uploading;
      _error = null;
    });

    try {
      final path = await ref
          .read(driverProvider.notifier)
          .captureLicence(fromGallery: fromGallery);

      if (!mounted) return;
      setState(() {
        if (path == null) {
          // Backed out of the camera. Not a failure -- returning to `empty`
          // rather than `failed` keeps the wording honest.
          _upload = _application.hasLicence
              ? NjUploadState.done
              : NjUploadState.empty;
        } else {
          _application = _application.copyWith(licencePath: path);
          _upload = NjUploadState.done;
        }
      });
    } on DriverError catch (error) {
      if (!mounted) return;
      setState(() {
        _upload = NjUploadState.failed;
        _error = error;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _upload = NjUploadState.failed;
        _error = DriverError(DriverFailure.uploadFailed, detail: '$error');
      });
    }
  }

  Future<void> _chooseSource() async {
    final strings = NjStrings.of(context);

    final fromGallery = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => NjSheet(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              strings.dLicenceLabel,
              style: context.njText.headlineSmall,
            ),
            const SizedBox(height: NjSpace.lg),
            NjButton(
              label: strings.dTakePhoto,
              icon: Icons.photo_camera_outlined,
              onPressed: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(height: NjSpace.sm + 2),
            NjButton(
              label: strings.dChoosePhoto,
              icon: Icons.photo_library_outlined,
              variant: NjButtonVariant.ghost,
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );

    if (fromGallery == null || !mounted) return;
    await _attachLicence(fromGallery: fromGallery);
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await ref.read(driverProvider.notifier).submit(_application);
      // No navigation here. The row is now `pending`, the router's gate reads
      // that and replaces this screen -- which is also what makes the design's
      // "no back navigation" true without a single pop being suppressed.
    } on DriverError catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = DriverError(DriverFailure.unknown, detail: '$error'),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;
    final strings = NjStrings.of(context);
    // The profile first, the auth state second.
    //
    // `AuthState.phone` is only set by typing a number in this session: a
    // driver who signed in yesterday, closed the app and came back to finish
    // signing up has a session but no `AuthState.phone`, and would have been
    // shown a blank field where their verified number should be. `profiles`
    // is the durable record; the auth state covers the few hundred
    // milliseconds on a brand-new account before that row is readable.
    final phone = ref.watch(profileProvider).valueOrNull?.phone ??
        ref.watch(authProvider).phone;

    return Scaffold(
      backgroundColor: nj.surface,
      body: SafeArea(
        child: NjScreenBody(
          padding: const EdgeInsets.all(NjSpace.xl),
          children: [
            Text(strings.dSignupTitle, style: context.njText.headlineLarge),
            const SizedBox(height: NjSpace.sm),
            Text(
              strings.dSignupSubtitle,
              style: context.njText.bodySmall?.copyWith(color: nj.muted),
            ),

            // The verified number, read-only. It was proved at C4 and is the
            // account's identity; offering it as an editable field here would
            // invite a driver to type a different one and wonder why the SMS
            // never arrives.
            const SizedBox(height: NjSpace.xl),
            _ReadOnlyField(
              label: strings.phoneLabel,
              // With the country code, unlike the phone field at C4: there
              // the +255 is a prefix inside the input, and here there is no
              // input to put it in. A number shown without it reads as
              // incomplete to the person checking it against a licence.
              value: phone == null
                  ? ''
                  : '+${TzPhone.countryCode} ${phone.formatted}',
            ),

            const SizedBox(height: NjSpace.lg),
            NjTextField(
              label: strings.dNameLabel,
              hintText: strings.dNameHint,
              controller: _nameController,
              enabled: !_busy,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              maxLength: 80,
              onChanged: (value) => setState(
                () => _application = _application.copyWith(name: value),
              ),
            ),

            const SizedBox(height: NjSpace.lg),
            NjSegmented<VehicleType>(
              semanticLabel: strings.dVehicleLabel,
              value: _application.vehicleType,
              onChanged: _busy
                  ? (_) {}
                  : (type) => setState(
                        () => _application =
                            _application.copyWith(vehicleType: type),
                      ),
              segments: [
                NjSegment(
                  value: VehicleType.bajaj,
                  label: strings.dVehicleBajaj,
                ),
                NjSegment(value: VehicleType.boda, label: strings.dVehicleBoda),
              ],
            ),

            const SizedBox(height: NjSpace.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: NjTextField(
                    label: strings.dPlateLabel,
                    hintText: _application.vehicleType == VehicleType.boda
                        ? strings.dPlateHintBoda
                        : strings.dPlateHintBajaj,
                    controller: _plateController,
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: DriverApplication.plateMaxLength,
                    inputFormatters: [_UpperCaseFormatter()],
                    onChanged: (value) => setState(
                      () => _application = _application.copyWith(plate: value),
                    ),
                  ),
                ),
                const SizedBox(width: NjSpace.md),
                SizedBox(
                  width: 124,
                  child: _ColourField(
                    value: VehicleColour.tryParse(_application.colour) ??
                        VehicleColour.blue,
                    enabled: !_busy,
                    onChanged: (colour) => setState(
                      () => _application =
                          _application.copyWith(colour: colour.code),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: NjSpace.lg),
            Text(strings.dLicenceLabel, style: _labelStyle(context)),
            const SizedBox(height: NjSpace.sm),
            NjUploadBox(
              state: _upload,
              label: strings.dLicencePrompt,
              doneLabel: strings.dLicenceDone,
              uploadingLabel: strings.dLicenceUploading,
              failedLabel: strings.dLicenceFailed,
              onTap: _busy ? () {} : _chooseSource,
            ),
            const SizedBox(height: NjSpace.sm),
            Text(
              strings.dLicencePrivate,
              style: context.njText.bodySmall?.copyWith(
                color: nj.muted,
                fontSize: 12.5,
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: NjSpace.md),
              Text(
                driverFailureMessage(_error!.failure, strings),
                style: context.njText.bodySmall?.copyWith(color: nj.danger),
              ),
              // What the server actually said, with credentials masked. Debug
              // only: a driver cannot act on it, and a developer cannot
              // diagnose a storage policy without it.
              if (kDebugMode && _error!.detail != null)
                Text(
                  redactSecrets(_error!.detail!),
                  style: context.njText.bodySmall?.copyWith(
                    color: nj.muted,
                    fontSize: 11.5,
                  ),
                ),
            ],

            const SizedBox(height: NjSpace.lg + 2),
            NjButton(
              label: _submitting ? strings.dSubmitting : strings.dSubmitForReview,
              loading: _submitting,
              // Disabled, not hidden, and not a tap that silently fails:
              // the driver can see what they are working towards.
              onPressed:
                  _application.isComplete && !_busy ? _submit : null,
            ),
          ],
        ),
      ),
    );
  }

  TextStyle? _labelStyle(BuildContext context) =>
      context.njText.bodySmall?.copyWith(fontWeight: FontWeight.w600);

}

/// Forces upper case as the plate is typed, keeping the caret where it was.
class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

/// A field that shows a value without inviting an edit.
///
/// Styled to match [NjTextField] so the form reads as one thing, but it is
/// plainly not editable.
class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: context.njText.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: NjSpace.sm),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: NjSpace.lg,
            vertical: NjSpace.lg - 2,
          ),
          decoration: BoxDecoration(
            color: nj.surfaceAlt,
            borderRadius: BorderRadius.circular(NjRadius.input),
            border: Border.all(color: nj.line, width: 2),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value,
                  style: context.njText.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Icon(Icons.verified_outlined, size: 20, color: nj.teal),
            ],
          ),
        ),
      ],
    );
  }
}

/// The colour picker.
///
/// A fixed list rather than free text: colour exists so a passenger can pick
/// the right bajaj out of four parked together, and that only works if there
/// is one spelling of green.
class _ColourField extends StatelessWidget {
  const _ColourField({
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final VehicleColour value;
  final ValueChanged<VehicleColour> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;
    final strings = NjStrings.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.dColourLabel,
          style: context.njText.bodySmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: NjSpace.sm),
        Container(
          decoration: BoxDecoration(
            color: nj.surface,
            borderRadius: BorderRadius.circular(NjRadius.input),
            border: Border.all(color: nj.line, width: 2),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<VehicleColour>(
              value: value,
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: NjSpace.md),
              borderRadius: BorderRadius.circular(NjRadius.input),
              style: context.njText.bodyLarge,
              onChanged: enabled
                  ? (picked) => picked == null ? null : onChanged(picked)
                  : null,
              items: [
                for (final colour in VehicleColour.values)
                  DropdownMenuItem(
                    value: colour,
                    child: Text(labelFor(colour, strings)),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The localised name of a colour. One switch, shared with the pending
  /// screen, which shows the same value back.
  static String labelFor(VehicleColour colour, NjStrings strings) =>
      switch (colour) {
        VehicleColour.blue => strings.colourBlue,
        VehicleColour.red => strings.colourRed,
        VehicleColour.green => strings.colourGreen,
        VehicleColour.yellow => strings.colourYellow,
        VehicleColour.black => strings.colourBlack,
        VehicleColour.white => strings.colourWhite,
      };
}

/// The localised name of a stored colour value, or the raw value if it is not
/// one this build knows.
String njColourLabel(String? stored, NjStrings strings) {
  final colour = VehicleColour.tryParse(stored);
  return colour == null
      ? (stored ?? '')
      : _ColourField.labelFor(colour, strings);
}
