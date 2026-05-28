import 'package:flutter/material.dart';

import '../models/vtg_enums.dart';
import '../models/vtg_state.dart';

/// Collapsible threshold configuration panel.
/// Intentionally low-key — users should rarely need this.
class SettingsPanel extends StatefulWidget {
  final VtgSettings settings;
  final GameMode mode;
  final void Function(double min, double max) onVoiceRangeChanged;
  final void Function(double min, double max) onTypingRangeChanged;

  const SettingsPanel({
    super.key,
    required this.settings,
    required this.mode,
    required this.onVoiceRangeChanged,
    required this.onTypingRangeChanged,
  });

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  late RangeValues _voice;
  late RangeValues _typing;

  @override
  void initState() {
    super.initState();
    _voice = RangeValues(widget.settings.voiceMinDb, widget.settings.voiceMaxDb);
    _typing =
        RangeValues(widget.settings.typingMinWpm, widget.settings.typingMaxWpm);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune_rounded,
                  size: 14, color: Colors.white.withValues(alpha: 0.3)),
              const SizedBox(width: 8),
              Text(
                'TARGET ZONE',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 10,
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _RangeRow(
            label: 'Voice',
            unit: 'dB',
            range: _voice,
            min: 30,
            max: 110,
            active: widget.mode == GameMode.voice,
            color: const Color(0xFF26C6DA),
            onChanged: (v) {
              setState(() => _voice = v);
              widget.onVoiceRangeChanged(v.start, v.end);
            },
          ),
          const SizedBox(height: 14),
          _RangeRow(
            label: 'Typing',
            unit: 'WPM',
            range: _typing,
            min: 5,
            max: 150,
            active: widget.mode == GameMode.typing,
            color: const Color(0xFF7E57C2),
            onChanged: (v) {
              setState(() => _typing = v);
              widget.onTypingRangeChanged(v.start, v.end);
            },
          ),
        ],
      ),
    );
  }
}

class _RangeRow extends StatelessWidget {
  final String label;
  final String unit;
  final RangeValues range;
  final double min;
  final double max;
  final bool active;
  final Color color;
  final ValueChanged<RangeValues> onChanged;

  const _RangeRow({
    required this.label,
    required this.unit,
    required this.range,
    required this.min,
    required this.max,
    required this.active,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: active ? 1.0 : 0.35,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.4,
                  )),
              const Spacer(),
              Text(
                '${range.start.toStringAsFixed(0)}–${range.end.toStringAsFixed(0)} $unit',
                style: TextStyle(
                  color: active ? color : Colors.white.withValues(alpha: 0.25),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: color,
              inactiveTrackColor: color.withValues(alpha: 0.18),
              thumbColor: color,
              overlayColor: color.withValues(alpha: 0.12),
              trackHeight: 2.5,
              thumbShape:
                  const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: RangeSlider(
              values: range,
              min: min,
              max: max,
              onChanged: active ? onChanged : null,
            ),
          ),
        ],
      ),
    );
  }
}
