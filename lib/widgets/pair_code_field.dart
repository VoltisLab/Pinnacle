import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Six single-digit fields wired together so typing auto-advances, backspace
/// jumps back, and pasting a 6-digit code fills every slot at once.
///
/// Exposes the composed value via [controller] (a standard
/// [TextEditingController]) so callers already written against a regular
/// `TextField` can keep reading `.text` unchanged.
class PairCodeField extends StatefulWidget {
  const PairCodeField({
    super.key,
    required this.controller,
    this.length = 6,
    this.enabled = true,
    this.autofocus = false,
    this.onCompleted,
  });

  final TextEditingController controller;
  final int length;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String>? onCompleted;

  @override
  State<PairCodeField> createState() => _PairCodeFieldState();
}

class _PairCodeFieldState extends State<PairCodeField> {
  late final List<TextEditingController> _slots;
  late final List<FocusNode> _focus;
  bool _syncingFromController = false;

  @override
  void initState() {
    super.initState();
    _slots = List.generate(widget.length, (_) => TextEditingController());
    _focus = List.generate(widget.length, (_) => FocusNode());
    _syncFromController();
    widget.controller.addListener(_syncFromController);
  }

  @override
  void didUpdateWidget(covariant PairCodeField old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_syncFromController);
      widget.controller.addListener(_syncFromController);
      _syncFromController();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromController);
    for (final c in _slots) {
      c.dispose();
    }
    for (final f in _focus) {
      f.dispose();
    }
    super.dispose();
  }

  void _syncFromController() {
    final digits = widget.controller.text
        .replaceAll(RegExp(r'\D'), '')
        .padRight(widget.length, ' ')
        .substring(0, widget.length);
    _syncingFromController = true;
    for (var i = 0; i < widget.length; i++) {
      final want = digits[i] == ' ' ? '' : digits[i];
      if (_slots[i].text != want) {
        _slots[i].text = want;
      }
    }
    _syncingFromController = false;
    if (mounted) setState(() {});
  }

  void _updateControllerFromSlots({bool fireComplete = true}) {
    if (_syncingFromController) return;
    final buffer = StringBuffer();
    for (final c in _slots) {
      buffer.write(c.text);
    }
    final joined = buffer.toString();
    if (joined != widget.controller.text) {
      widget.controller.value = TextEditingValue(
        text: joined,
        selection: TextSelection.collapsed(offset: joined.length),
      );
    }
    if (fireComplete &&
        joined.length == widget.length &&
        !joined.contains(RegExp(r'\D'))) {
      widget.onCompleted?.call(joined);
    }
  }

  void _onSlotChanged(int i, String value) {
    if (_syncingFromController) return;
    if (value.length > 1) {
      // Paste: spread digits across slots starting at the focused index.
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (var k = 0; k < widget.length; k++) {
        if (i + k >= widget.length) break;
        _slots[i + k].text = k < digits.length ? digits[k] : '';
      }
      final nextIdx =
          (i + digits.length).clamp(0, widget.length - 1).toInt();
      FocusScope.of(context).requestFocus(_focus[nextIdx]);
      _updateControllerFromSlots();
      return;
    }
    if (value.isNotEmpty) {
      // Keep only the last character so holding a key doesn't skip slots.
      if (!RegExp(r'\d').hasMatch(value)) {
        _slots[i].text = '';
        _updateControllerFromSlots(fireComplete: false);
        return;
      }
      if (i < widget.length - 1) {
        FocusScope.of(context).requestFocus(_focus[i + 1]);
      }
    }
    _updateControllerFromSlots();
  }

  KeyEventResult _handleKey(int i, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      // Empty slot + backspace -> hop back a slot and clear it. Mirrors the
      // iOS SMS-code behaviour people already expect.
      if (_slots[i].text.isEmpty && i > 0) {
        _slots[i - 1].text = '';
        FocusScope.of(context).requestFocus(_focus[i - 1]);
        _updateControllerFromSlots(fireComplete: false);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < widget.length; i++)
          Flexible(
            child: Padding(
              padding: EdgeInsets.only(
                right: i == widget.length - 1 ? 0 : 8,
              ),
              child: _PairSlot(
                controller: _slots[i],
                focus: _focus[i],
                enabled: widget.enabled,
                autofocus: widget.autofocus && i == 0,
                onChanged: (v) => _onSlotChanged(i, v),
                onKey: (e) => _handleKey(i, e),
                theme: theme,
              ),
            ),
          ),
      ],
    );
  }
}

class _PairSlot extends StatelessWidget {
  const _PairSlot({
    required this.controller,
    required this.focus,
    required this.enabled,
    required this.autofocus,
    required this.onChanged,
    required this.onKey,
    required this.theme,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final bool enabled;
  final bool autofocus;
  final ValueChanged<String> onChanged;
  final KeyEventResult Function(KeyEvent) onKey;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Focus(
      onKeyEvent: (_, event) => onKey(event),
      child: SizedBox(
        height: 56,
        child: TextField(
          controller: controller,
          focusNode: focus,
          enabled: enabled,
          autofocus: autofocus,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
          ],
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 1.0,
          ),
          cursorWidth: 1.6,
          decoration: InputDecoration(
            counterText: '',
            contentPadding: EdgeInsets.zero,
            filled: true,
            fillColor: theme.colorScheme.surfaceContainerHighest
                .withOpacity(0.6),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.outlineVariant.withOpacity(0.5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 1.6,
              ),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.outlineVariant.withOpacity(0.25),
              ),
            ),
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
