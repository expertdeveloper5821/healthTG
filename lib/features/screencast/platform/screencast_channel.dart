class ScreenCastChannel {
  ScreenCastChannel._();

  static const String methodChannel = 'com.example.demo_p/screen_cast';
  static const String eventChannel = 'com.example.demo_p/screen_cast_events';

  // MethodChannel method names
  static const String startDiscovery = 'startDiscovery';
  static const String stopDiscovery = 'stopDiscovery';
  static const String connectDevice = 'connectDevice';
  static const String disconnectDevice = 'disconnectDevice';
  static const String checkPermissions = 'checkPermissions';
  static const String checkWiredDisplay = 'checkWiredDisplay';
  static const String startWiredDisplayMonitoring = 'startWiredDisplayMonitoring';
  static const String stopWiredDisplayMonitoring = 'stopWiredDisplayMonitoring';
  static const String launchSystemCastPicker = 'launchSystemCastPicker';
  static const String checkConnectionStatus = 'checkConnectionStatus';
  static const String switchToMonitoringMode = 'switchToMonitoringMode';

  // EventChannel event type keys
  static const String eventType = 'type';
  static const String eventTypeDeviceFound = 'deviceFound';
  static const String eventTypeDeviceLost = 'deviceLost';
  static const String eventTypeConnectionChanged = 'connectionChanged';
  static const String eventTypeError = 'error';
  static const String eventTypeWiredDisplayChanged = 'wiredDisplayChanged';
}
