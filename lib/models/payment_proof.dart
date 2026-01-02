class PaymentProof {
  final String? filePath;
  final String? fileName;
  final int? fileSize;
  final String? mimeType;
  final DateTime? uploadedAt;

  PaymentProof({
    this.filePath,
    this.fileName,
    this.fileSize,
    this.mimeType,
    this.uploadedAt,
  });

  factory PaymentProof.fromJson(Map<String, dynamic> json) {
    return PaymentProof(
      filePath: json['file_path'],
      fileName: json['file_name'],
      fileSize: json['file_size'],
      mimeType: json['mime_type'],
      uploadedAt: json['uploaded_at'] != null
          ? DateTime.parse(json['uploaded_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'file_path': filePath,
      'file_name': fileName,
      'file_size': fileSize,
      'mime_type': mimeType,
      'uploaded_at': uploadedAt?.toIso8601String(),
    };
  }
}
