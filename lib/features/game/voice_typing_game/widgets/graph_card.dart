import 'package:flutter/material.dart';

import '../models/graph_sample.dart';
import '../models/vtg_enums.dart';
import '../painters/graph_painter.dart';

/// Full-width cinematic graph card.
///
/// • [AnimationController] lives here and drives only its own [RepaintBoundary].
/// • No values, labels, or scores are shown — purely visual.
/// • Border and shadow react to [zoneStatus] for ambient feedback.
class GraphCard extends StatefulWidget {
  final List<GraphSample> samples;
  final double graphYMin;
  final double graphYMax;
  final double zoneMin;
  final double zoneMax;
  final ZoneStatus zoneStatus;
  final bool isMonitoring;
  final String modeLabel;

  const GraphCard({
    super.key,
    required this.samples,
    required this.graphYMin,
    required this.graphYMax,
    required this.zoneMin,
    required this.zoneMax,
    required this.zoneStatus,
    required this.isMonitoring,
    required this.modeLabel,
  });

  @override
  State<GraphCard> createState() => _GraphCardState();
}

class _GraphCardState extends State<GraphCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _glow;

  @override
  void initState() {
    super.initState();
    _glow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inZone =
        widget.isMonitoring && widget.zoneStatus == ZoneStatus.inZone;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: inZone
              ? const Color(0xFF64FFDA).withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.06),
          width: 1.0,
        ),
        boxShadow: [
          if (inZone)
            BoxShadow(
              color: const Color(0xFF64FFDA).withValues(alpha: 0.10),
              blurRadius: 32,
              spreadRadius: 4,
            ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ModeChip(label: widget.modeLabel, isMonitoring: widget.isMonitoring),
            AnimatedBuilder(
              animation: _glow,
              builder: (_, __) => RepaintBoundary(
                child: CustomPaint(
                  size: const Size(double.infinity, 220),
                  painter: GraphPainter(
                    samples: widget.samples,
                    graphYMin: widget.graphYMin,
                    graphYMax: widget.graphYMax,
                    zoneMin: widget.zoneMin,
                    zoneMax: widget.zoneMax,
                    zoneStatus: widget.zoneStatus,
                    glowPulse: _glow.value,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Minimal mode chip ──────────────────────────────────────────────────────────

class _ModeChip extends StatelessWidget {
  final String label;
  final bool isMonitoring;

  const _ModeChip({required this.label, required this.isMonitoring});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      child: Row(
        children: [
          // Live indicator dot
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isMonitoring
                  ? const Color(0xFF64FFDA)
                  : Colors.white.withValues(alpha: 0.2),
              boxShadow: isMonitoring
                  ? [
                      BoxShadow(
                        color: const Color(0xFF64FFDA).withValues(alpha: 0.7),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : [],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 10,
              letterSpacing: 2.0,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
