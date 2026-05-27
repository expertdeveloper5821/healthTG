class AppConfig {
  const AppConfig._();

  static const baseUrl = 'https://demo.reabilityonline.com';
  static const captchaClientKey = '6Lc8yKspAAAAAAQ6ItzKFYZ-uJ5GG2PdWGtHZwhM';
  static const recaptchaOrigin = baseUrl;

  // PeerJS signaling server (from backend .env SIGNALING_SERVER)
  static const signalingServerBase =
      'https://signaling-demo.reabilityonline.com';
  static const signalingServerWss = 'wss://signaling-demo.reabilityonline.com';
  static const signalingServerKey = 'gertner-little-secret';

  static Uri get loginUri => Uri.parse('$baseUrl/login');
  static Uri get logoutUri => Uri.parse('$baseUrl/logout');
  static Uri get userDataUri => Uri.parse('$baseUrl/users/getUserData');
  static Uri get iceServersUri => Uri.parse('$baseUrl/ice_servers');
  static Uri get isAuthenticatedUri =>
      Uri.parse('$baseUrl/users/isAuthenticated');
  static Uri get peerjsAuthUri => Uri.parse('$baseUrl/users/authenticate_user');

  // PeerJS REST endpoints — served by the signaling server, not the app backend
  static Uri get connectedPeersUri =>
      Uri.parse('$signalingServerBase/peerjs/getConnectedPeers');
  static Uri get disconnectPeerUri =>
      Uri.parse('$signalingServerBase/peerjs/disconnectConnectedPeers');

  // Therapist-specific endpoints
  static Uri get therapistUsersUri =>
      Uri.parse('$baseUrl/therapist/users/getAll');
  static Uri get openPeersUri =>
      Uri.parse('$baseUrl/therapist/users/openPeers');
  static Uri get heartbeatUri => Uri.parse('$baseUrl/users/sendHeartBeat');
  static Uri get patientAvailabilityStatusUri =>
      Uri.parse('$baseUrl/patient/availabilityStatus');

  static Uri get therapistStartTimeUri =>
      Uri.parse('$baseUrl/therapist/sessions/therapistStartTime');
  static Uri featureFlagUri(int userId, String role) {
    final apiRole = role == 'therapist' ? 'therapist' : 'patient';
    return Uri.parse('$baseUrl/$apiRole/getFeatureFlag/$userId/$role');
  }
}
