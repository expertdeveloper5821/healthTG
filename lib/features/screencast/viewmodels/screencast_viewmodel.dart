import 'dart:async';

import 'package:demo_p/features/screencast/models/screencast_state.dart';
import 'package:demo_p/features/screencast/repositories/screencast_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final screenCastProvider =
    NotifierProvider<ScreenCastNotifier, ScreenCastState>(
  ScreenCastNotifier.new,
);

// ── Notifier ──────────────────────────────────────────────────────────────────

class ScreenCastNotifier extends Notifier<ScreenCastState>
    with WidgetsBindingObserver {
  late final ScreenCastRepository _repo;
  StreamSubscription<CastEvent>? _eventSub;

  @override
  ScreenCastState build() {
    _repo = ScreenCastRepository();
    WidgetsBinding.instance.addObserver(this);
    ref.onDispose(_cleanup);
    return const ScreenCastState();
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncCastStatusOnResume();
    }
  }

  /// Called every time the app returns to the foreground.
  /// Polls the native MediaRouter for the real current route and reconciles
  /// it with our Dart-side state. Handles both the "connected while in
  /// background" case and the "disconnected from system settings" case.
  Future<void> _syncCastStatusOnResume() async {
    if (state.castMode != CastMode.wireless) return;
    if (!state.isSearching && !state.isCasting && !state.isConnecting) return;

    try {
      final event = await _repo.checkConnectionStatus();
      if (event.connected == true) {
        // Device connected while we were in the background.
        _handleEvent(event);
      } else if (state.isCasting) {
        // Was casting, native now says no route — user disconnected via system UI.
        _handleEvent(event);
      } else {
        // Was searching/connecting and user returned without connecting → idle.
        _cancelEventSubscription();
        await _repo.stopDiscovery();
        state = const ScreenCastState(status: CastStatus.idle);
      }
    } catch (_) {}
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Opens the device's native system cast picker and starts MediaRouter
  /// discovery simultaneously. The MediaRouter callback fires automatically
  /// when the user selects a device in the system UI, driving the state to
  /// [CastStatus.connected] with no further user action required.
  Future<void> startWirelessCasting() async {
    if (state.isBusy || state.isCasting) return;

    _subscribeToEvents();

    state = state.copyWith(
      status: CastStatus.searching,
      castMode: CastMode.wireless,
      devices: const [],
      systemCastLaunched: false,
      clearError: true,
      clearPermissionMessage: true,
    );

    // Start discovery and launch system picker concurrently.
    final results = await Future.wait([
      _repo.startDiscovery(),
      _repo.launchSystemCastPicker(),
    ]);

    final discoveryStarted = results[0];
    final systemCastLaunched = results[1];

    if (!discoveryStarted) {
      // Discovery channel failed — nothing to listen to. Return to idle so
      // the user can try again. The system picker may have still opened but
      // we won't receive connection events, so idle is the honest state.
      _cancelEventSubscription();
      state = const ScreenCastState(status: CastStatus.idle);
      return;
    }

    state = state.copyWith(
      castMode: CastMode.wireless,
      systemCastLaunched: systemCastLaunched,
    );
  }

  /// Opens the system cast settings so the user can disconnect an active cast.
  Future<void> openSystemCastSettings() => _repo.launchSystemCastPicker();

  /// Kept for internal callers that need raw wireless discovery without
  /// launching the system picker (e.g. retry after failure inside the sheet).
  Future<void> startCasting() async {
    if (state.isBusy || state.isCasting) return;

    _subscribeToEvents();

    state = state.copyWith(
      status: CastStatus.searching,
      castMode: CastMode.wireless,
      devices: const [],
      systemCastLaunched: false,
      clearError: true,
      clearPermissionMessage: true,
    );

    final started = await _repo.startDiscovery();
    if (!started) {
      state = state.copyWith(
        status: CastStatus.failed,
        errorMessage: 'Could not start device discovery.',
      );
    }
  }

  /// Checks whether a wired display is currently connected without changing
  /// provider state. Returns the display name if found, null if not detected.
  Future<String?> detectWiredDisplay() async {
    final result = await _repo.checkWiredDisplay();
    final isConnected = result['isConnected'] as bool? ?? false;
    if (!isConnected) return null;
    return result['displayName'] as String? ?? 'External Display';
  }

  /// Begins wired casting for a display that was already confirmed to be
  /// connected. Starts the DisplayManager monitor and drives state to
  /// [CastStatus.connected]. Returns true on success, false if monitoring
  /// could not be started or casting is already active.
  Future<bool> beginWiredCasting(String displayName) async {
    if (state.isCasting) return false;

    _subscribeToEvents();
    final started = await _repo.startWiredDisplayMonitoring();
    if (!started) {
      _cancelEventSubscription();
      return false;
    }

    state = state.copyWith(
      status: CastStatus.connected,
      castMode: CastMode.wired,
      wiredDisplayName: displayName,
      connectedDevice: CastDevice(
        id: 'wired',
        name: displayName,
        type: CastConnectionType.wired,
        description: 'HDMI / USB-C Connection',
      ),
      clearError: true,
    );
    return true;
  }

  /// Called when the user selects a wireless device from the discovery sheet.
  Future<void> connectTo(CastDevice device) async {
    if (state.isConnecting || state.isCasting) return;

    state = state.copyWith(status: CastStatus.connecting, clearError: true);
    final ok = await _repo.connect(device.id);

    if (!ok) {
      state = state.copyWith(
        status: CastStatus.failed,
        errorMessage: 'Failed to connect to ${device.name}. '
            'Make sure the device is on the same network.',
      );
    }
    // On success the native side fires a connectionChanged event which
    // transitions state via _handleEvent → _onDeviceConnected.
  }

  /// Stops casting (wireless or wired) and returns to idle.
  Future<void> stopCasting() async {
    try {
      if (state.castMode == CastMode.wired) {
        await _repo.stopWiredDisplayMonitoring();
      } else {
        await _repo.disconnect();
        await _repo.stopDiscovery();
      }
    } catch (_) {}
    _cancelEventSubscription();
    state = const ScreenCastState(status: CastStatus.idle);
  }

  /// Cancels an in-progress wireless search without disconnecting.
  Future<void> cancelSearch() async {
    await _repo.stopDiscovery();
    _cancelEventSubscription();
    state = state.copyWith(
      status: CastStatus.idle,
      clearCastMode: true,
      devices: const [],
      clearError: true,
    );
  }

  // ── Event handling ────────────────────────────────────────────────────────

  void _subscribeToEvents() {
    _eventSub?.cancel();
    _eventSub = _repo.events.listen(
      _handleEvent,
      onError: (Object err) {
        debugPrint('[ScreenCast] event stream error: $err');
        // Don't surface stream errors to the UI — silently return to idle
        // so the user can retry without seeing a confusing failure state.
        _cancelEventSubscription();
        state = const ScreenCastState(status: CastStatus.idle);
      },
    );
  }

  void _handleEvent(CastEvent event) {
    switch (event.kind) {
      case CastEventKind.deviceFound:
        if (event.device == null) return;
        final updated = [...state.devices];
        if (!updated.contains(event.device)) updated.add(event.device!);
        state = state.copyWith(devices: updated);

      case CastEventKind.deviceLost:
        final updated =
            state.devices.where((d) => d.id != event.deviceId).toList();
        state = state.copyWith(devices: updated);

      case CastEventKind.connectionChanged:
        if (event.connected == true && event.device != null) {
          _onDeviceConnected(event.device!);
        } else {
          _onDeviceDisconnected();
        }

      case CastEventKind.wiredDisplayChanged:
        if (event.connected == true) {
          final device = event.device ??
              const CastDevice(
                id: 'wired',
                name: 'External Display',
                type: CastConnectionType.wired,
              );
          state = state.copyWith(
            status: CastStatus.connected,
            castMode: CastMode.wired,
            connectedDevice: device,
            wiredDisplayName: device.name,
            clearError: true,
          );
        } else {
          _repo.stopWiredDisplayMonitoring();
          _cancelEventSubscription();
          state = const ScreenCastState(status: CastStatus.idle);
        }

      case CastEventKind.error:
        state = state.copyWith(
          status: CastStatus.failed,
          errorMessage: event.errorMessage,
        );

      case CastEventKind.unknown:
        break;
    }
  }

  void _onDeviceConnected(CastDevice device) {
    // Switch to passive monitoring so onRouteUnselected still fires when
    // the user disconnects from the system cast settings.
    _repo.switchToMonitoringMode();
    state = state.copyWith(
      status: CastStatus.connected,
      connectedDevice: device,
      clearError: true,
    );
  }

  void _onDeviceDisconnected() {
    _cancelEventSubscription();
    state = const ScreenCastState(status: CastStatus.idle);
  }

  // ── Cleanup ───────────────────────────────────────────────────────────────

  void _cancelEventSubscription() {
    _eventSub?.cancel();
    _eventSub = null;
  }

  void _cleanup() {
    WidgetsBinding.instance.removeObserver(this);
    _cancelEventSubscription();
    _repo.stopDiscovery();
    _repo.disconnect();
    _repo.stopWiredDisplayMonitoring();
  }
}
