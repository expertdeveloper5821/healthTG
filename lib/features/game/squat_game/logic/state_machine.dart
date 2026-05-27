enum SquatPhase { standing, descending, bottomPosition, ascending, repCounted }

enum SquatEvent { none, repCompleted }

class SquatTransition {
  final SquatPhase phase;
  final SquatEvent event;
  final bool debounceBlocked;
  final String reason;

  const SquatTransition({
    required this.phase,
    required this.event,
    this.debounceBlocked = false,
    this.reason = '',
  });
}

/// Counts squat reps from vertical body-center Y movement (0=top, 1=bottom).
///
/// Design goals
/// ─────────────
/// • Ignore jitter, camera shake, and standing-still pose noise.
/// • Only count a clear DOWN + UP motion that exceeds real-squat depth.
/// • Every state transition requires [_confirmFrames] consecutive frames
///   inside the trigger zone, so a single noisy sample never fires.
/// • The standing baseline updates only while standing, so it can never
///   drift downward during an active squat.
/// • [kneeAngle] is accepted for API compatibility but is ignored.
class SquatStateMachine {
  SquatPhase _phase = SquatPhase.standing;
  DateTime? _lastCountedAt;

  bool _hasBaseline = false;
  double _baselineY = 0.5; // body-center Y while standing (normalized 0–1)
  double _deepestY = 0.5;  // deepest Y reached in the current descent

  // Per-phase confirmation counters.
  // Each counts consecutive frames that satisfy its zone's condition.
  int _descentFrames = 0; // frames spent below baseline + downThreshold
  int _ascentFrames = 0;  // frames spent above deepestY − upThreshold
  int _returnFrames = 0;  // frames spent back near baseline after ascending

  SquatPhase get phase => _phase;

  // ── Thresholds (normalized 0–1, larger Y = body physically lower) ─────────

  /// Body must drop this far below baseline before descent is considered.
  /// 5 % of image height — filters out breathing, small bobs, camera shake.
  static const double downThreshold = 0.050;

  /// Body must rise this far from the deepest point to confirm it is ascending.
  static const double upThreshold = 0.025;

  /// Body must return within this of baseline to complete the rep.
  static const double returnThreshold = 0.070;

  /// Total drop from baseline that must be accumulated for the rep to count.
  /// 8 % ensures at least a clear partial squat; shallow bends are rejected.
  static const double minSquatDepth = 0.080;

  /// If the body rises back to within this of baseline while in DESCENDING,
  /// the descent is treated as a wobble and immediately aborted.
  static const double wobbleAbortThreshold = downThreshold * 0.35;

  /// Minimum consecutive frames required to confirm any state transition.
  /// At ~10 fps this is ~200 ms — long enough to reject single-frame spikes.
  static const int _confirmFrames = 2;

  /// Minimum time between two counted reps.
  static const Duration debounceDuration = Duration(milliseconds: 800);

  // ── Main update ───────────────────────────────────────────────────────────

  SquatTransition update({
    required double kneeAngle, // ignored — API compat only
    required double squatLevel,
    required DateTime now,
  }) {
    final y = squatLevel;
    _ensureBaseline(y);

    switch (_phase) {
      // ── STANDING ──────────────────────────────────────────────────────────
      case SquatPhase.standing:
        // Drift baseline toward the current standing position so the machine
        // adapts if the user shifts forward/backward between reps.
        // Only update while standing so a squat can never pull baseline down.
        _baselineY = _baselineY * 0.96 + y * 0.04;

        if (y > _baselineY + downThreshold) {
          _descentFrames++;
        } else {
          _descentFrames = 0;
        }

        if (_descentFrames >= _confirmFrames) {
          _descentFrames = 0;
          _phase = SquatPhase.descending;
          _deepestY = y;
          return SquatTransition(
            phase: _phase,
            event: SquatEvent.none,
            reason: 'descent confirmed',
          );
        }
        return SquatTransition(
          phase: _phase,
          event: SquatEvent.none,
          reason: 'standing (descent:$_descentFrames/$_confirmFrames)',
        );

      // ── DESCENDING ────────────────────────────────────────────────────────
      case SquatPhase.descending:
        if (y > _deepestY) _deepestY = y;

        // Abort immediately if the body came back close to baseline.
        // This rejects small forward-lean / nod / breathing movement.
        if (y < _baselineY + wobbleAbortThreshold) {
          _descentFrames = 0;
          _ascentFrames = 0;
          _phase = SquatPhase.standing;
          return SquatTransition(
            phase: _phase,
            event: SquatEvent.none,
            reason: 'wobble aborted',
          );
        }

        // Require consecutive frames rising from the deepest point.
        if (y < _deepestY - upThreshold) {
          _ascentFrames++;
        } else {
          _ascentFrames = 0;
        }

        if (_ascentFrames >= _confirmFrames) {
          _ascentFrames = 0;
          _phase = SquatPhase.ascending;
          return SquatTransition(
            phase: _phase,
            event: SquatEvent.none,
            reason: 'ascent confirmed',
          );
        }
        return SquatTransition(
          phase: _phase,
          event: SquatEvent.none,
          reason: 'descending (ascent:$_ascentFrames/$_confirmFrames)',
        );

      // ── ASCENDING ─────────────────────────────────────────────────────────
      case SquatPhase.ascending:
        // Body dropped back toward the deepest point — still in the squat.
        // Use a small hysteresis band so a single rising noise frame doesn't
        // cancel a genuine ascent prematurely.
        if (y > _deepestY - upThreshold * 0.4) {
          if (y > _deepestY) _deepestY = y;
          _ascentFrames = 0;
          _returnFrames = 0;
          _phase = SquatPhase.descending;
          return SquatTransition(
            phase: _phase,
            event: SquatEvent.none,
            reason: 'dropped back, still squatting',
          );
        }

        // Require consecutive frames back near the baseline.
        if (y < _baselineY + returnThreshold) {
          _returnFrames++;
        } else {
          _returnFrames = 0;
        }

        if (_returnFrames >= _confirmFrames) {
          _returnFrames = 0;
          return _evaluateRep(now);
        }
        return SquatTransition(
          phase: _phase,
          event: SquatEvent.none,
          reason: 'ascending (return:$_returnFrames/$_confirmFrames)',
        );

      // ── LEGACY / TRANSIENT STATES ─────────────────────────────────────────
      case SquatPhase.bottomPosition:
        // Not entered by current logic; treat as ascending to unblock.
        _ascentFrames = 0;
        _phase = SquatPhase.ascending;
        return SquatTransition(
          phase: _phase,
          event: SquatEvent.none,
          reason: 'from bottomPosition',
        );

      case SquatPhase.repCounted:
        // Transient: controller reads this once then we return to standing.
        _phase = SquatPhase.standing;
        return SquatTransition(
          phase: _phase,
          event: SquatEvent.none,
          reason: 'ready for next rep',
        );
    }
  }

  // ── Rep evaluation ────────────────────────────────────────────────────────

  SquatTransition _evaluateRep(DateTime now) {
    final totalDrop = _deepestY - _baselineY;
    final isDeepEnough = totalDrop >= minSquatDepth;
    final lastAt = _lastCountedAt;
    final debounced =
        lastAt != null && now.difference(lastAt) < debounceDuration;

    _phase = SquatPhase.standing;

    if (!isDeepEnough) {
      return SquatTransition(
        phase: _phase,
        event: SquatEvent.none,
        reason: 'too shallow (${totalDrop.toStringAsFixed(3)} < $minSquatDepth)',
      );
    }
    if (debounced) {
      return SquatTransition(
        phase: _phase,
        event: SquatEvent.none,
        debounceBlocked: true,
        reason: 'debounced',
      );
    }

    _lastCountedAt = now;
    return const SquatTransition(
      phase: SquatPhase.repCounted,
      event: SquatEvent.repCompleted,
      reason: 'rep counted',
    );
  }

  // ── Baseline ──────────────────────────────────────────────────────────────

  void _ensureBaseline(double y) {
    if (!_hasBaseline) {
      _hasBaseline = true;
      _baselineY = y;
      _deepestY = y;
    }
  }

  // ── Reset helpers ─────────────────────────────────────────────────────────

  void _clearCounters() {
    _descentFrames = 0;
    _ascentFrames = 0;
    _returnFrames = 0;
  }

  /// Full reset — only call on explicit user restart.
  void reset() {
    _phase = SquatPhase.standing;
    _lastCountedAt = null;
    _hasBaseline = false;
    _baselineY = 0.5;
    _deepestY = 0.5;
    _clearCounters();
  }

  /// Motion-only reset — call after a long pose loss to unblock stuck states.
  /// Preserves [_lastCountedAt] so debounce continues working correctly.
  void resetMotion() {
    _phase = SquatPhase.standing;
    _hasBaseline = false;
    _baselineY = 0.5;
    _deepestY = 0.5;
    _clearCounters();
  }
}
