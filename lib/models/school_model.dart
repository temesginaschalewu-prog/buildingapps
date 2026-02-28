class School {
  final int id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

  School({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  factory School.fromJson(Map<String, dynamic> json) {
    // Handle null values safely
    return School(
      id: json['id'] ?? 0,
      name: json['name']?.toString() ?? 'Unknown School',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'].toString())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
