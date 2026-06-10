enum CastStatus {
  idle,
  searching,
  connecting,
  connected,
  disconnected,
  failed,
  permissionDenied,
}

enum CastConnectionType {
  wired,
  chromecast,
  miracast,
  unknown,
}

enum CastMode {
  wireless,
  wired,
}
