import 'dart:convert';

class AuthSession {
  const AuthSession({
    required this.username,
    required this.userTimezone,
    required this.rawResponse,
    this.cookieHeader,
  });

  final String username;
  final String userTimezone;
  final Map<String, dynamic> rawResponse;
  final String? cookieHeader;

  bool get hasToken => username.isNotEmpty;

  // The Reability backend authenticates protected routes with the Express
  // session cookie created by /login.
  String? get token => cookieHeader;

  // PeerJS peer ID — backend stores it on the user object
  String? get peerId {
    final user = rawResponse['currentUser'];
    if (user is Map) {
      final id = _firstNonEmpty([
        user['peerId'],
        user['peer_id'],
        user['user_id'],
        user['id'],
      ]);
      if (id != null) return id;
    }
    return _firstNonEmpty([
      rawResponse['peerId'],
      rawResponse['peer_id'],
      rawResponse['user_id'],
      rawResponse['userId'],
      rawResponse['id'],
    ]);
  }

  // Therapist numeric id (used by TherapistCallManager)
  int? get therapistId {
    final user = rawResponse['currentUser'];
    if (user is Map) {
      final nestedTherapistId = _firstNonEmpty([
        user['therapistId'],
        user['therapist_id'],
      ]);
      if (nestedTherapistId != null) return int.tryParse(nestedTherapistId);
    }

    final explicitTherapistId = _firstNonEmpty([
      rawResponse['therapistId'],
      rawResponse['therapist_id'],
    ]);
    if (explicitTherapistId != null) {
      return int.tryParse(explicitTherapistId);
    }

    final id = _firstNonEmpty([rawResponse['id']]);
    if (id != null && isTherapist) return int.tryParse(id);
    return null;
  }

  int? get userId {
    final user = rawResponse['currentUser'];
    if (user is Map) {
      final id = user['id'];
      if (id != null) return int.tryParse(id.toString());
    }
    final id = rawResponse['id'];
    return id == null ? null : int.tryParse(id.toString());
  }

  int? get patientId {
    final user = rawResponse['currentUser'];
    if (user is Map) {
      final id = _firstNonEmpty([user['patientId'], user['patient_id']]);
      if (id != null) return int.tryParse(id);
    }

    final id = _firstNonEmpty([
      rawResponse['patientId'],
      rawResponse['patient_id'],
    ]);
    if (id != null) return int.tryParse(id);
    return role == 'patient' ? userId : null;
  }

  // Role: 'patient' or 'therapist'
  String? get role {
    final user = rawResponse['currentUser'];
    final value = user is Map ? user['role'] : rawResponse['role'];
    final normalized = value?.toString().trim().toLowerCase();
    if (normalized?.isNotEmpty ?? false) return normalized;
    return requiresConfirmation ? 'therapist' : null;
  }

  bool get requiresConfirmation {
    final user = rawResponse['currentUser'];
    final value = user is Map
        ? user['requiresConfirmation']
        : rawResponse['requiresConfirmation'];
    if (value is bool) return value;
    return value?.toString().trim().toLowerCase() == 'true';
  }

  bool get isTherapist {
    final user = rawResponse['currentUser'];
    final value = user is Map
        ? user['isTherapist']
        : rawResponse['isTherapist'];
    if (value is bool) return value;
    if (value != null) return value.toString().trim().toLowerCase() == 'true';
    return role == 'therapist' || requiresConfirmation;
  }

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'userTimezone': userTimezone,
      'rawResponse': rawResponse,
      'cookieHeader': cookieHeader,
    };
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      username: json['username']?.toString() ?? '',
      userTimezone: json['userTimezone']?.toString() ?? '',
      rawResponse: _asStringMap(json['rawResponse']),
      cookieHeader: json['cookieHeader']?.toString(),
    );
  }

  String encode() => jsonEncode(toJson());

  factory AuthSession.decode(String value) {
    final decoded = jsonDecode(value);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Saved session is not valid.');
    }
    return AuthSession.fromJson(decoded);
  }

  static Map<String, dynamic> _asStringMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), val));
    }
    return <String, dynamic>{};
  }

  static String? _firstNonEmpty(List<Object?> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty && text != 'null') return text;
    }
    return null;
  }
}
