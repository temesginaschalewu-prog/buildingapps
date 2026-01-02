class DeviceChangeRequest {
  final String username;
  final String password;
  final String paymentMethod;
  final String paymentType = 'device_change';
  final double amount;
  final String proofImagePath;
  final String deviceId;

  DeviceChangeRequest({
    required this.username,
    required this.password,
    required this.paymentMethod,
    required this.amount,
    required this.proofImagePath,
    required this.deviceId,
  });

  Map<String, dynamic> toJson() {
    return {
      'username': username,
      'password': password,
      'payment_method': paymentMethod,
      'payment_type': paymentType,
      'amount': amount,
      'proof_image_path': proofImagePath,
      'device_id': deviceId,
    };
  }
}
