import 'package:flutter/material.dart';

/// Premium pulsing toggle button for starting/stopping live monitoring.
///
/// When [isMonitoring] is true an outer ring animates with a slow breathing
/// pulse — the only animation feedback in the UI that there is live activity.
class MonitoringToggle extends StatefulWidget {
  final bool isMonitoring;
  final VoidCallback onToggle;

  const MonitoringToggle({
    super.key,
    required this.isMonitoring,
    required this.onToggle,
  });

  @override
  State<MonitoringToggle> createState() => _MonitoringToggleState();
}

class _MonitoringToggleState extends State<MonitoringToggle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _ring;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    _ring = CurvedAnimation(parent: _pulse, curve: Curves.easeInOut);
    if (widget.isMonitoring) _pulse.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(MonitoringToggle old) {
    super.didUpdateWidget(old);
    if (widget.isMonitoring && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!widget.isMonitoring && _pulse.isAnimating) {
      _pulse.stop();
      _pulse.animateTo(0.0, duration: const Duration(milliseconds: 300));
    }
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const active = Color(0xFF26C6DA);
    const idle = Color(0xFF1E1E38);

    return GestureDetector(
      onTap: widget.onToggle,
      child: SizedBox(
        height: 64,
        child: AnimatedBuilder(
          animation: _ring,
          builder: (_, __) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Breathing outer ring — visible only when monitoring
                if (widget.isMonitoring)
                  Container(
                    width: double.infinity,
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: active.withValues(
                            alpha: 0.15 + 0.25 * _ring.value),
                        width: 1.5,
                      ),
                    ),
                  ),

                // Main button body
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeInOut,
                  width: double.infinity,
                  height: 56,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: widget.isMonitoring
                        ? active.withValues(alpha: 0.12)
                        : idle,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: widget.isMonitoring
                          ? active.withValues(alpha: 0.5)
                          : Colors.white.withValues(alpha: 0.08),
                      width: 1.2,
                    ),
                    boxShadow: widget.isMonitoring
                        ? [
                            BoxShadow(
                              color: active.withValues(
                                  alpha: 0.20 + 0.10 * _ring.value),
                              blurRadius: 20,
                              spreadRadius: 2,
                            )
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Live dot
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: widget.isMonitoring
                              ? active
                              : Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      const SizedBox(width: 10),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          widget.isMonitoring ? 'Monitoring' : 'Start Monitoring',
                          key: ValueKey(widget.isMonitoring),
                          style: TextStyle(
                            color: widget.isMonitoring
                                ? active
                                : Colors.white.withValues(alpha: 0.45),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
