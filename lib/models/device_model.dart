class Device {
  final int id;
  final int userId;
  final String deviceId;
  final String deviceType;
  final String? pairingCode;
  final bool isPaired;
  final DateTime? pairedAt;
  final DateTime? unpairedAt;
  final DateTime? expiresAt;
  final bool removedByAdmin;
  final String? adminNotes;
  final String username;
  final String accountStatus;

  Device({
    required this.id,
    required this.userId,
    required this.deviceId,
    required this.deviceType,
    this.pairingCode,
    required this.isPaired,
    this.pairedAt,
    this.unpairedAt,
    this.expiresAt,
    required this.removedByAdmin,
    this.adminNotes,
    required this.username,
    required this.accountStatus,
  });

  factory Device.fromJson(Map<String, dynamic> json) {
    return Device(
      id: json['id'],
      userId: json['user_id'],
      deviceId: json['device_id'],
      deviceType: json['device_type'],
      pairingCode: json['pairing_code'],
      isPaired: json['is_paired'] ?? false,
      pairedAt:
          json['paired_at'] != null ? DateTime.parse(json['paired_at']) : null,
      unpairedAt: json['unpaired_at'] != null
          ? DateTime.parse(json['unpaired_at'])
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : null,
      removedByAdmin: json['removed_by_admin'] ?? false,
      adminNotes: json['admin_notes'],
      username: json['username'],
      accountStatus: json['account_status'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'device_id': deviceId,
      'device_type': deviceType,
      'pairing_code': pairingCode,
      'is_paired': isPaired,
      'paired_at': pairedAt?.toIso8601String(),
      'unpaired_at': unpairedAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'removed_by_admin': removedByAdmin,
      'admin_notes': adminNotes,
      'username': username,
      'account_status': accountStatus,
    };
  }

  bool get isPrimaryDevice => deviceType == 'primary';
  bool get isTvDevice => deviceType == 'tv';
  bool get isExpired => expiresAt != null && DateTime.now().isAfter(expiresAt!);
  bool get canPair => !isPaired && !isExpired && !removedByAdmin;
}
