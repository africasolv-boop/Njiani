import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';

/// The Njiani text field: a 2pt outline that turns teal on focus.
///
/// The outline is deliberately heavy. These screens are used outdoors in Dar
/// sunlight, where Material's default hairline underline disappears.
class NjTextField extends StatelessWidget {
  const NjTextField({
    super.key,
    this.label,
    this.controller,
    this.prefix,
    this.hintText,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.maxLength,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.enabled = true,
    this.textCapitalization = TextCapitalization.none,
    this.errorText,
  });

  /// Label shown above the field.
  final String? label;

  /// Optional external controller.
  final TextEditingController? controller;

  /// Fixed leading text inside the outline, e.g. `+255` or `TSh`.
  ///
  /// Part of the field rather than the value: the user types `712 345 678`,
  /// and the country code is never something they can delete by accident.
  final String? prefix;

  /// Placeholder shown when empty.
  final String? hintText;

  /// Keyboard type.
  final TextInputType? keyboardType;

  /// Keyboard action button.
  final TextInputAction? textInputAction;

  /// Input filters, e.g. digits only.
  final List<TextInputFormatter>? inputFormatters;

  /// Maximum character count. No counter is shown.
  final int? maxLength;

  /// Called on every edit.
  final ValueChanged<String>? onChanged;

  /// Called when the keyboard action is pressed.
  final ValueChanged<String>? onSubmitted;

  /// Whether to focus on first build.
  final bool autofocus;

  /// Whether the field accepts input.
  final bool enabled;

  /// Auto-capitalisation behaviour.
  final TextCapitalization textCapitalization;

  /// Validation message shown beneath the field.
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;
    final invalid = errorText != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(label!, style: context.njText.labelMedium),
          const SizedBox(height: NjSpace.sm),
        ],
        TextField(
          controller: controller,
          enabled: enabled,
          autofocus: autofocus,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          textCapitalization: textCapitalization,
          style: context.njText.bodyLarge?.copyWith(fontWeight: FontWeight.w500),
          cursorColor: nj.teal,
          decoration: InputDecoration(
            counterText: '',
            hintText: hintText,
            hintStyle: context.njText.bodyLarge?.copyWith(color: nj.muted),
            filled: true,
            fillColor: enabled ? nj.surface : nj.surfaceAlt,
            prefixIcon: prefix == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(
                      left: NjSpace.lg,
                      right: NjSpace.sm,
                    ),
                    child: Text(
                      prefix!,
                      style: context.njText.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: nj.muted,
                      ),
                    ),
                  ),
            // Lets the prefix hug the text instead of Material's 48pt box.
            prefixIconConstraints: const BoxConstraints(),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: NjSpace.lg,
              vertical: NjSpace.md + 1,
            ),
            border: _border(nj.line),
            enabledBorder: _border(invalid ? nj.danger : nj.line),
            focusedBorder: _border(invalid ? nj.danger : nj.teal),
            disabledBorder: _border(nj.line),
            errorStyle: const TextStyle(height: 0, fontSize: 0),
            errorText: invalid ? '' : null,
          ),
        ),
        if (invalid) ...[
          const SizedBox(height: NjSpace.xs + 2),
          Text(
            errorText!,
            style: context.njText.bodySmall?.copyWith(
              color: nj.danger,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(NjRadius.input),
        borderSide: BorderSide(color: color, width: NjBorder.control),
      );
}
