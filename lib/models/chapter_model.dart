class Chapter {
  final int id;
  final String name;
  final String status;
  final DateTime? releaseDate;
  final DateTime createdAt;
  final bool accessible;

  Chapter({
    required this.id,
    required this.name,
    required this.status,
    this.releaseDate,
    required this.createdAt,
    required this.accessible,
  });

  factory Chapter.fromJson(Map<String, dynamic> json) {
    return Chapter(
      id: json['id'],
      name: json['name'],
      status: json['status'],
      releaseDate: json['release_date'] != null
          ? DateTime.parse(json['release_date'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      accessible: json['accessible'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'status': status,
      'release_date': releaseDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'accessible': accessible,
    };
  }

  bool get isFree => status == 'free';
  bool get isLocked => status == 'locked';

  bool get canAccessContent {
    return isFree || accessible;
  }
}
