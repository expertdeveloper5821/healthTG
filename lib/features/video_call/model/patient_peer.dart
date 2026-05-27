class PatientPeer {
  const PatientPeer({
    required this.id,
    required this.name,
    required this.peerId,
    required this.availabilityStatus,
    this.peerStatus,
    this.peerConnected = false,
  });

  final int id;
  final String name;
  final String peerId;
  final String availabilityStatus;
  final String? peerStatus;

  /// True when this patient's peerId appears in the PeerJS connected-peers list.
  final bool peerConnected;

  /// A patient is callable only when available AND their peer is connected.
  bool get isCallable => availabilityStatus == 'available' && peerConnected;

  factory PatientPeer.fromJson(Map<String, dynamic> json) {
    final firstName =
        json['firstName']?.toString() ?? json['first_name']?.toString();
    final lastName =
        json['lastName']?.toString() ?? json['last_name']?.toString();
    final fullName = [
      firstName,
      lastName,
    ].where((part) => part != null && part.trim().isNotEmpty).join(' ').trim();

    return PatientPeer(
      id:
          int.tryParse(
            (json['patientId'] ?? json['patient_id'] ?? json['id'])
                    ?.toString() ??
                '',
          ) ??
          0,
      name:
          json['name']?.toString() ??
          json['fullName']?.toString() ??
          (fullName.isNotEmpty ? fullName : null) ??
          json['username']?.toString() ??
          json['user_name']?.toString() ??
          'Patient',
      peerId:
          (json['peerId'] ?? json['peer_id'] ?? json['user_id'])?.toString() ??
          '',
      availabilityStatus:
          json['availability_status']?.toString() ?? 'unavailable',
      peerStatus: json['peerStatus']?.toString(),
    );
  }

  PatientPeer copyWith({
    bool? peerConnected,
    String? availabilityStatus,
    String? peerStatus,
  }) => PatientPeer(
    id: id,
    name: name,
    peerId: peerId,
    availabilityStatus: availabilityStatus ?? this.availabilityStatus,
    peerStatus: peerStatus ?? this.peerStatus,
    peerConnected: peerConnected ?? this.peerConnected,
  );
}
