import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../design/nj_theme.dart';
import '../design/nj_tokens.dart';

/// The SMS code entry: one box per digit, advancing as you type.
///
/// Four digits, matching the code length the SMS gateway will send. Backspace
/// on an empty box steps back to the previous one, because getting this wrong
/// on a small keyboard is the fastest way to lose a driver at signup.
class NjOtpField extends StatefulWidget {
  const NjOtpField({
    super.key,
    this.length = 4,
    required this.onCompleted,
    this.onChanged,
    this.autofocus = true,
    this.hasError = false,
  });

  /// Number of digits.
  final int length;

  /// Called once every box is filled, with the full code.
  final ValueChanged<String> onCompleted;

  /// Called on every edit, with the code so far.
  final ValueChanged<String>? onChanged;

  /// Whether to focus the first box on build.
  final bool autofocus;

  /// Draws every box in the danger colour, for a rejected code.
  final bool hasError;

  @override
  State<NjOtpField> createState() => _NjOtpFieldState();
}

class _NjOtpFieldState extends State<NjOtpField> {
  late final List<TextEditingController> _controllers;
  late final List<FocusNode> _nodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.length,
      (_) => TextEditingController(),
    );
    _nodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void didUpdateWidget(NjOtpField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Spec: on a wrong code every box goes danger, the boxes clear, and focus
    // returns to the first. Retyping over four stale digits on a small
    // keyboard is exactly where people give up.
    if (widget.hasError && !oldWidget.hasError) {
      for (final controller in _controllers) {
        controller.clear();
      }
      widget.onChanged?.call('');
      if (mounted) _nodes.first.requestFocus();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _code => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    if (value.isNotEmpty && index < widget.length - 1) {
      _nodes[index + 1].requestFocus();
    }
    widget.onChanged?.call(_code);
    if (_code.length == widget.length) {
      _nodes[index].unfocus();
      widget.onCompleted(_code);
    }
    setState(() {});
  }

  /// Backspace on an empty box steps back and clears the previous digit.
  KeyEventResult _onKey(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey != LogicalKeyboardKey.backspace) {
      return KeyEventResult.ignored;
    }
    if (_controllers[index].text.isNotEmpty || index == 0) {
      return KeyEventResult.ignored;
    }
    _controllers[index - 1].clear();
    _nodes[index - 1].requestFocus();
    widget.onChanged?.call(_code);
    setState(() {});
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final nj = context.nj;

    return Semantics(
      label: 'Verification code, ${widget.length} digits',
      child: Row(
        children: [
          for (var i = 0; i < widget.length; i++) ...[
            if (i > 0) const SizedBox(width: NjSpace.sm + 2),
            Expanded(
              child: Focus(
                onKeyEvent: (_, event) => _onKey(i, event),
                child: AspectRatio(
                  aspectRatio: 0.82,
                  child: TextField(
                    controller: _controllers[i],
                    focusNode: _nodes[i],
                    autofocus: widget.autofocus && i == 0,
                    textAlign: TextAlign.center,
                    keyboardType: TextInputType.number,
                    maxLength: 1,
                    cursorColor: nj.teal,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    onChanged: (value) => _onDigitChanged(i, value),
                    style: context.njText.headlineMedium,
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: nj.surface,
                      contentPadding: EdgeInsets.zero,
                      enabledBorder: _border(
                        widget.hasError ? nj.danger : nj.line,
                      ),
                      focusedBorder: _border(
                        widget.hasError ? nj.danger : nj.teal,
                      ),
                      border: _border(nj.line),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  OutlineInputBorder _border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(NjRadius.input),
        borderSide: BorderSide(color: color, width: NjBorder.control),
      );
}
