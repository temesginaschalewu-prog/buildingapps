class Course {
  final int id;
  final String name;
  final int categoryId;
  final String? description;
  final int chapterCount;
  final String access;
  final String message;

  Course({
    required this.id,
    required this.name,
    required this.categoryId,
    this.description,
    required this.chapterCount,
    required this.access,
    required this.message,
  });

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] is String ? int.parse(json['id']) : json['id'] ?? 0,
      name: json['name']?.toString() ?? '',
      categoryId: json['category_id'] is String
          ? int.parse(json['category_id'])
          : json['category_id'] ?? 0,
      description: json['description']?.toString(),
      chapterCount: json['chapter_count'] is String
          ? int.parse(json['chapter_count'])
          : json['chapter_count'] ?? 0,
      access: json['access']?.toString() ?? 'limited',
      message: json['message']?.toString() ?? 'Free chapters only',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category_id': categoryId,
      'description': description,
      'chapter_count': chapterCount,
      'access': access,
      'message': message,
    };
  }

  bool get hasFullAccess => access == 'full';
  bool get hasLimitedAccess => access == 'limited';
}
