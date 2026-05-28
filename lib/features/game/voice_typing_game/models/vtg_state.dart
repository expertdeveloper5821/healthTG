import 'vtg_enums.dart';
import 'graph_sample.dart';

class VtgSettings {
  final double voiceMinDb;
  final double voiceMaxDb;
  final double typingMinWpm;
  final double typingMaxWpm;
  final int graphBufferSize;

  const VtgSettings({
    this.voiceMinDb = 65.0,
    this.voiceMaxDb = 80.0,
    this.typingMinWpm = 25.0,
    this.typingMaxWpm = 55.0,
    this.graphBufferSize = 90,
  });

  VtgSettings copyWith({
    double? voiceMinDb,
    double? voiceMaxDb,
    double? typingMinWpm,
    double? typingMaxWpm,
    int? graphBufferSize,
  }) => VtgSettings(
    voiceMinDb: voiceMinDb ?? this.voiceMinDb,
    voiceMaxDb: voiceMaxDb ?? this.voiceMaxDb,
    typingMinWpm: typingMinWpm ?? this.typingMinWpm,
    typingMaxWpm: typingMaxWpm ?? this.typingMaxWpm,
    graphBufferSize: graphBufferSize ?? this.graphBufferSize,
  );
}

class VtgState {
  final GameMode mode;

  /// Whether the microphone / typing tracking is actively running.
  final bool isMonitoring;

  /// Rolling ring buffer of graph samples — always non-empty once seeded.
  final List<GraphSample> samples;

  /// Most recent smoothed value (dB or WPM).
  final double currentValue;

  /// Positional relationship of currentValue to the target zone.
  final ZoneStatus zoneStatus;

  final bool showSettings;
  final VtgSettings settings;
  final bool hasMicPermission;
  final bool micPermPermanentlyDenied;

  const VtgState({
    required this.mode,
    required this.isMonitoring,
    required this.samples,
    required this.currentValue,
    required this.zoneStatus,
    required this.showSettings,
    required this.settings,
    required this.hasMicPermission,
    this.micPermPermanentlyDenied = false,
  });

  factory VtgState.initial() => const VtgState(
    mode: GameMode.voice,
    isMonitoring: false,
    samples: [],
    currentValue: 0.0,
    zoneStatus: ZoneStatus.below,
    showSettings: false,
    settings: VtgSettings(),
    hasMicPermission: false,
    micPermPermanentlyDenied: false,
  );

  // ── Derived helpers ────────────────────────────────────────────────────────

  double get zoneMin =>
      mode == GameMode.voice ? settings.voiceMinDb : settings.typingMinWpm;
  double get zoneMax =>
      mode == GameMode.voice ? settings.voiceMaxDb : settings.typingMaxWpm;

  /// Fixed Y-axis display range per mode — stable, never rescales.
  double get graphYMin => mode == GameMode.voice ? 20.0 : 0.0;
  double get graphYMax => mode == GameMode.voice ? 110.0 : 120.0;

  String get modeLabel =>
      mode == GameMode.voice ? 'Voice Monitor' : 'Typing Monitor';

  VtgState copyWith({
    GameMode? mode,
    bool? isMonitoring,
    List<GraphSample>? samples,
    double? currentValue,
    ZoneStatus? zoneStatus,
    bool? showSettings,
    VtgSettings? settings,
    bool? hasMicPermission,
    bool? micPermPermanentlyDenied,
  }) => VtgState(
    mode: mode ?? this.mode,
    isMonitoring: isMonitoring ?? this.isMonitoring,
    samples: samples ?? this.samples,
    currentValue: currentValue ?? this.currentValue,
    zoneStatus: zoneStatus ?? this.zoneStatus,
    showSettings: showSettings ?? this.showSettings,
    settings: settings ?? this.settings,
    hasMicPermission: hasMicPermission ?? this.hasMicPermission,
    micPermPermanentlyDenied: micPermPermanentlyDenied ?? this.micPermPermanentlyDenied,
  );
}
