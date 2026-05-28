import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/vtg_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Per-character formatting model
// ─────────────────────────────────────────────────────────────────────────────

/// Immutable formatting flags attached to a single character position.
class _Fmt {
  final bool bold;
  final bool italic;
  final bool underline;

  const _Fmt({this.bold = false, this.italic = false, this.underline = false});

  _Fmt copyWith({bool? bold, bool? italic, bool? underline}) => _Fmt(
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        underline: underline ?? this.underline,
      );

  bool get isDefault => !bold && !italic && !underline;

  @override
  bool operator ==(Object other) =>
      other is _Fmt &&
      bold == other.bold &&
      italic == other.italic &&
      underline == other.underline;

  @override
  int get hashCode => Object.hash(bold, italic, underline);
}

// ─────────────────────────────────────────────────────────────────────────────
// FormattingController — custom TextEditingController with inline rich text
// ─────────────────────────────────────────────────────────────────────────────

/// Extends [TextEditingController] to track per-character formatting.
///
/// Architecture:
/// • [_charFmt] is a List<_Fmt> kept in sync with [text] at all times.
/// • When the user types, the [value] setter diffs old vs new text using the
///   common-prefix / common-suffix algorithm to find exactly which characters
///   were inserted or deleted. New characters inherit the active toggle state.
/// • When text is selected and a toggle is pressed, the selection range is
///   reflowed with the new format. Future keystrokes inherit those flags too.
/// • [buildTextSpan] groups consecutive same-format characters into a single
///   TextSpan, producing minimal span trees at 60 fps.
class FormattingController extends TextEditingController {
  List<_Fmt> _charFmt = [];

  // Active state for NEXT characters to be typed (or applied to selection)
  bool _bold = false;
  bool _italic = false;
  bool _underline = false;

  bool get isBold => _bold;
  bool get isItalic => _italic;
  bool get isUnderline => _underline;

  // ── Toggle handlers ────────────────────────────────────────────────────────

  void toggleBold() {
    _bold = !_bold;
    _applyActiveToSelection();
    notifyListeners();
  }

  void toggleItalic() {
    _italic = !_italic;
    _applyActiveToSelection();
    notifyListeners();
  }

  void toggleUnderline() {
    _underline = !_underline;
    _applyActiveToSelection();
    notifyListeners();
  }

  /// Applies the current active flags to every character in the selection.
  void _applyActiveToSelection() {
    final sel = selection;
    if (!sel.isValid || sel.isCollapsed) return;
    final fmt = _activeFmt();
    for (var i = sel.start; i < sel.end && i < _charFmt.length; i++) {
      _charFmt[i] = fmt;
    }
  }

  _Fmt _activeFmt() =>
      _Fmt(bold: _bold, italic: _italic, underline: _underline);

  // ── Value override — keeps _charFmt in sync with text ────────────────────

  @override
  set value(TextEditingValue newValue) {
    final oldText = text;
    final newText = newValue.text;
    if (newText != oldText) _syncStyles(oldText, newText);
    super.value = newValue;
  }

  /// Diffs [oldText] → [newText] using a common-prefix / common-suffix scan.
  ///
  /// This correctly handles single-char insert, single-char delete, selection
  /// replacement, autocorrect, and paste — all in O(n) time.
  void _syncStyles(String oldText, String newText) {
    // 1. Common prefix
    int pre = 0;
    while (pre < oldText.length &&
        pre < newText.length &&
        oldText[pre] == newText[pre]) {
      pre++;
    }

    // 2. Common suffix (not overlapping the prefix)
    int suf = 0;
    while (suf < oldText.length - pre &&
        suf < newText.length - pre &&
        oldText[oldText.length - 1 - suf] == newText[newText.length - 1 - suf]) {
      suf++;
    }

    final delCount = oldText.length - pre - suf; // chars removed from old
    final insCount = newText.length - pre - suf; // chars added in new

    final prefixFmt =
        _charFmt.sublist(0, pre.clamp(0, _charFmt.length));
    final insertFmt =
        List<_Fmt>.generate(insCount, (_) => _activeFmt());
    final suffixFmt =
        _charFmt.sublist((pre + delCount).clamp(0, _charFmt.length));

    final merged = [...prefixFmt, ...insertFmt, ...suffixFmt];
    _charFmt = merged.sublist(0, newText.length.clamp(0, merged.length));

    // Safety pad (should never be needed, but protects against edge cases)
    while (_charFmt.length < newText.length) {
      _charFmt.add(const _Fmt());
    }
  }

  // ── buildTextSpan — groups same-format runs into minimal spans ────────────

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final fullText = text;
    if (fullText.isEmpty) return TextSpan(style: style, text: '');

    final spans = <InlineSpan>[];
    int cursor = 0;

    while (cursor < fullText.length) {
      final fmt =
          cursor < _charFmt.length ? _charFmt[cursor] : const _Fmt();
      int runEnd = cursor + 1;

      // Extend run while next character has the same format
      while (runEnd < fullText.length) {
        final next =
            runEnd < _charFmt.length ? _charFmt[runEnd] : const _Fmt();
        if (next == fmt) {
          runEnd++;
        } else {
          break;
        }
      }

      spans.add(TextSpan(
        text: fullText.substring(cursor, runEnd),
        style: TextStyle(
          fontWeight: fmt.bold ? FontWeight.bold : FontWeight.w400,
          fontStyle: fmt.italic ? FontStyle.italic : FontStyle.normal,
          decoration: fmt.underline
              ? TextDecoration.underline
              : TextDecoration.none,
          decorationColor: Colors.white60,
          decorationThickness: 1.5,
        ),
      ));

      cursor = runEnd;
    }

    return TextSpan(style: style, children: spans);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Panel widget
// ─────────────────────────────────────────────────────────────────────────────

class TypingInputPanel extends ConsumerStatefulWidget {
  const TypingInputPanel({super.key});

  @override
  ConsumerState<TypingInputPanel> createState() => _TypingInputPanelState();
}

class _TypingInputPanelState extends ConsumerState<TypingInputPanel>
    with SingleTickerProviderStateMixin {
  late final FormattingController _textController;
  late final UndoHistoryController _undoController;
  final _focusNode = FocusNode();
  String _prev = '';
  late final AnimationController _focusAnim;
  late final Animation<double> _borderAnim;

  @override
  void initState() {
    super.initState();
    _textController = FormattingController();
    _undoController = UndoHistoryController();
    _focusAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 280));
    _borderAnim =
        CurvedAnimation(parent: _focusAnim, curve: Curves.easeOut);
    _focusNode.addListener(_onFocusChange);
  }

  void _onFocusChange() {
    _focusNode.hasFocus ? _focusAnim.forward() : _focusAnim.reverse();
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _textController.dispose();
    _undoController.dispose();
    _focusNode.dispose();
    _focusAnim.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    ref.read(vtgProvider.notifier).onTextChanged(text, _prev);
    _prev = text;
  }

  void _clear() {
    _textController.clear();
    _prev = '';
  }

  @override
  Widget build(BuildContext context) {
    final isMonitoring =
        ref.watch(vtgProvider.select((s) => s.isMonitoring));

    return AnimatedBuilder(
      animation: _borderAnim,
      builder: (_, child) => ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Color.lerp(
                  Colors.white.withValues(alpha: 0.08),
                  const Color(0xFF26C6DA).withValues(alpha: 0.40),
                  _borderAnim.value,
                )!,
                width: 1.0,
              ),
            ),
            child: child,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Toolbar with live reactive state ──────────────────────────────
          _Toolbar(
            fmtController: _textController,
            undoController: _undoController,
            onClear: _clear,
          ),
          Container(height: 0.5, color: Colors.white.withValues(alpha: 0.07)),
          // ── Rich text input ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
            child: TextField(
              controller: _textController,
              undoController: _undoController,
              focusNode: _focusNode,
              onChanged: _onChanged,
              enabled: isMonitoring,
              maxLines: 6,
              minLines: 4,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                height: 1.7,
                letterSpacing: 0.2,
              ),
              cursorColor: const Color(0xFF26C6DA),
              cursorWidth: 1.5,
              selectionControls: MaterialTextSelectionControls(),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: isMonitoring
                    ? 'Type freely…'
                    : 'Enable monitoring to begin',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.18),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Toolbar
// ─────────────────────────────────────────────────────────────────────────────

class _Toolbar extends StatelessWidget {
  final FormattingController fmtController;
  final UndoHistoryController undoController;
  final VoidCallback onClear;

  const _Toolbar({
    required this.fmtController,
    required this.undoController,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          // ── Undo / Redo — enabled state driven by UndoHistoryController ───
          ValueListenableBuilder<UndoHistoryValue>(
            valueListenable: undoController,
            builder: (_, val, __) => Row(
              children: [
                _ToolBtn(
                  icon: Icons.undo_rounded,
                  tooltip: 'Undo',
                  enabled: val.canUndo,
                  onTap: undoController.undo,
                ),
                _ToolBtn(
                  icon: Icons.redo_rounded,
                  tooltip: 'Redo',
                  enabled: val.canRedo,
                  onTap: undoController.redo,
                ),
              ],
            ),
          ),

          _Divider(),

          // ── Bold / Italic / Underline — active state from FormattingController
          ListenableBuilder(
            listenable: fmtController,
            builder: (_, __) => Row(
              children: [
                _ToolBtn(
                  icon: Icons.format_bold_rounded,
                  tooltip: 'Bold',
                  active: fmtController.isBold,
                  onTap: fmtController.toggleBold,
                ),
                _ToolBtn(
                  icon: Icons.format_italic_rounded,
                  tooltip: 'Italic',
                  active: fmtController.isItalic,
                  onTap: fmtController.toggleItalic,
                ),
                _ToolBtn(
                  icon: Icons.format_underline_rounded,
                  tooltip: 'Underline',
                  active: fmtController.isUnderline,
                  onTap: fmtController.toggleUnderline,
                ),
              ],
            ),
          ),

          const Spacer(),

          // ── Clear ─────────────────────────────────────────────────────────
          _ToolBtn(
            icon: Icons.delete_outline_rounded,
            tooltip: 'Clear',
            onTap: onClear,
          ),
        ],
      ),
    );
  }
}

// ── Toolbar button ─────────────────────────────────────────────────────────────

class _ToolBtn extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final bool active;
  final bool enabled;

  const _ToolBtn({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.active = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF26C6DA);

    final iconColor = active
        ? accent
        : enabled
            ? Colors.white.withValues(alpha: 0.45)
            : Colors.white.withValues(alpha: 0.15);

    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 34,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? accent.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            border: active
                ? Border.all(
                    color: accent.withValues(alpha: 0.25), width: 0.8)
                : null,
          ),
          child: Icon(icon, size: 17, color: iconColor),
        ),
      ),
    );
  }
}

// ── Vertical separator ─────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
        width: 0.5,
        height: 18,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        color: Colors.white.withValues(alpha: 0.12),
      );
}
