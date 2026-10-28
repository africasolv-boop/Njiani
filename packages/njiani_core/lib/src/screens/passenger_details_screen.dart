import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';
import '../l10n/generated/nj_strings.dart';
import '../profile/profile.dart';
import '../profile/profile_controller.dart';
import '../widgets/nj_button.dart';
import '../widgets/nj_screen_body.dart';
import '../widgets/nj_text_field.dart';

/// `pDetails` — who the driver is coming for. Rider app.
///
/// Asked once, after sign-in and before the request screen, because from C10
/// a driver is told who they are picking up and "a passenger" is not a thing
/// you can call out at a stage.
///
/// **The email is optional and says so in its own label.** Njiani signs in by
/// phone (D10) and nothing in the product needs an address; it is here for a
/// receipt somebody asks for and for reaching a person whose phone has gone.
/// A required one would be a field people put `a@a.com` in, which is worse
/// than an empty column.
class PassengerDetailsScreen extends ConsumerStatefulWidget {
  const PassengerDetailsScreen({super.key});

  @override
  ConsumerState<PassengerDetailsScreen> createState() =>
      _PassengerDetailsScreenState();
}

class _PassengerDetailsScreenState
    extends ConsumerState<PassengerDetailsScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();

  bool _saving = false;
  bool _failed = false;

  /// True once the email has been typed in and left, so a half-typed address
  /// is not called wrong while it is still being typed.
  bool _emailTouched = false;

  /// Whether what is already on the account has been put in the fields.
  ///
  /// Not done in `initState`: `profileProvider` is an `AsyncNotifier` whose
  /// build is asynchronous, so at that point it is still loading and reading
  /// it gives null. Seeding from there silently produced an empty form for
  /// anyone who already had a name — which is every use of this screen after
  /// the first.
  bool _seeded = false;

  void _seed(Profile? profile) {
    // Once, and never over something being typed.
    if (_seeded || profile == null) return;
    _seeded = true;
    _nameController.text = profile.displayName ?? '';
    _emailController.text = profile.email ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String get _name => _nameController.text.trim();
  String get _email => _emailController.text.trim();

  /// The same loose check the database makes.
  ///
  /// Its job is to catch a typed-in phone number or a stray space, not to
  /// adjudicate what an address may contain — that is a famously bad idea,
  /// and the only real test of an address is sending to it.
  static final _looksLikeEmail = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool get _emailIsWrong => _email.isNotEmpty && !_looksLikeEmail.hasMatch(_email);

  bool get _canSave => _name.isNotEmpty && !_emailIsWrong && !_saving;

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _failed = false;
    });

    try {
      await ref.read(profileProvider.notifier).setDetails(
            name: _name,
            email: _email.isEmpty ? null : _email,
          );
      // No navigation: the router reads the profile and moves on, the same
      // way the driver gates work.
    } catch (error) {
      if (!mounted) return;
      setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;
    final strings = NjStrings.of(context);

    _seed(ref.watch(profileProvider).valueOrNull);

    return Scaffold(
      backgroundColor: nj.surface,
      body: SafeArea(
        child: NjScreenBody(
          padding: const EdgeInsets.all(NjSpace.xl),
          children: [
            const SizedBox(height: NjSpace.xxl),
            Text(strings.pDetailsTitle, style: context.njText.headlineLarge),
            const SizedBox(height: NjSpace.sm),
            Text(
              strings.pDetailsBody,
              style: context.njText.bodyMedium?.copyWith(color: nj.muted),
            ),

            const SizedBox(height: NjSpace.xl),
            NjTextField(
              label: strings.pNameLabel,
              hintText: strings.pNameHint,
              controller: _nameController,
              enabled: !_saving,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              maxLength: 80,
              onChanged: (_) => setState(() => _failed = false),
            ),

            const SizedBox(height: NjSpace.lg),
            NjTextField(
              label: strings.pEmailLabel,
              hintText: strings.pEmailHint,
              controller: _emailController,
              enabled: !_saving,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              maxLength: 120,
              inputFormatters: [
                // No spaces, which is the single commonest way an address is
                // mistyped on a phone keyboard.
                FilteringTextInputFormatter.deny(RegExp(r'\s')),
              ],
              errorText:
                  _emailTouched && _emailIsWrong ? strings.pEmailInvalid : null,
              onChanged: (_) => setState(() {
                _emailTouched = true;
                _failed = false;
              }),
              onSubmitted: (_) => _canSave ? _save() : null,
            ),

            if (_failed) ...[
              const SizedBox(height: NjSpace.md),
              Text(
                strings.pDetailsFailed,
                style: context.njText.bodySmall?.copyWith(color: nj.danger),
              ),
            ],

            const SizedBox(height: NjSpace.xl),
            NjButton(
              label: _saving ? strings.pDetailsSaving : strings.pDetailsSave,
              loading: _saving,
              onPressed: _canSave ? _save : null,
            ),
          ],
        ),
      ),
    );
  }
}
