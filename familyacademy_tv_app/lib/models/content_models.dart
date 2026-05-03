int? _asInt(dynamic value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

double? _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

class TvUser {
  const TvUser({
    required this.id,
    required this.username,
    required this.accountStatus,
    this.email,
    this.profileImage,
    this.schoolId,
  });

  final int id;
  final String username;
  final String accountStatus;
  final String? email;
  final String? profileImage;
  final int? schoolId;

  factory TvUser.fromJson(Map<String, dynamic> json) {
    return TvUser(
      id: _asInt(json['id']) ?? 0,
      username: json['username']?.toString() ?? '',
      accountStatus: json['account_status']?.toString() ?? 'active',
      email: json['email']?.toString(),
      profileImage: json['profile_image']?.toString(),
      schoolId: _asInt(json['school_id']),
    );
  }
}

class AppSettingItem {
  const AppSettingItem({
    required this.key,
    required this.value,
    this.category,
    this.displayName,
  });

  final String key;
  final String value;
  final String? category;
  final String? displayName;

  factory AppSettingItem.fromJson(Map<String, dynamic> json) {
    return AppSettingItem(
      key: json['setting_key']?.toString() ?? '',
      value: json['setting_value']?.toString() ?? '',
      category: json['category']?.toString(),
      displayName: json['display_name']?.toString(),
    );
  }
}

class CategoryItem {
  const CategoryItem({
    required this.id,
    required this.name,
    required this.status,
    required this.billingCycle,
    this.hasAccess,
    this.description,
    this.imageUrl,
    this.price,
  });

  final int id;
  final String name;
  final String status;
  final String billingCycle;
  final bool? hasAccess;
  final String? description;
  final String? imageUrl;
  final double? price;

  bool get isComingSoon => status == 'coming_soon';

  factory CategoryItem.fromJson(Map<String, dynamic> json) {
    return CategoryItem(
      id: _asInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      billingCycle: json['billing_cycle']?.toString() ?? 'monthly',
      hasAccess: json['has_access'] == true,
      description: json['description']?.toString(),
      imageUrl: json['image_url']?.toString(),
      price: _asDouble(json['price']),
    );
  }
}

class CourseItem {
  const CourseItem({
    required this.id,
    required this.name,
    required this.categoryId,
    this.description,
    this.access,
    this.message,
    this.chapterCount = 0,
  });

  final int id;
  final String name;
  final int categoryId;
  final String? description;
  final String? access;
  final String? message;
  final int chapterCount;

  factory CourseItem.fromJson(Map<String, dynamic> json) {
    return CourseItem(
      id: _asInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      categoryId: _asInt(json['category_id']) ?? 0,
      description: json['description']?.toString(),
      access: json['access']?.toString(),
      message: json['message']?.toString(),
      chapterCount: _asInt(json['chapter_count']) ?? 0,
    );
  }
}

class ExamItem {
  const ExamItem({
    required this.id,
    required this.title,
    this.description,
    this.courseName,
    this.categoryName,
    this.durationMinutes = 0,
    this.questionCount = 0,
    this.status,
  });

  final int id;
  final String title;
  final String? description;
  final String? courseName;
  final String? categoryName;
  final int durationMinutes;
  final int questionCount;
  final String? status;

  factory ExamItem.fromJson(Map<String, dynamic> json) {
    return ExamItem(
      id: _asInt(json['id']) ?? 0,
      title: json['title']?.toString() ??
          json['name']?.toString() ??
          'Exam',
      description: json['description']?.toString(),
      courseName: json['course_name']?.toString() ??
          json['course']?['name']?.toString(),
      categoryName: json['category_name']?.toString() ??
          json['category']?['name']?.toString(),
      durationMinutes: _asInt(json['duration_minutes']) ??
          _asInt(json['duration']) ??
          0,
      questionCount: _asInt(json['question_count']) ??
          _asInt(json['total_questions']) ??
          0,
      status: json['status']?.toString(),
    );
  }
}

class ChapterItem {
  const ChapterItem({
    required this.id,
    required this.name,
    required this.status,
    required this.accessible,
    this.releaseDate,
  });

  final int id;
  final String name;
  final String status;
  final bool accessible;
  final DateTime? releaseDate;

  factory ChapterItem.fromJson(Map<String, dynamic> json) {
    return ChapterItem(
      id: _asInt(json['id']) ?? 0,
      name: json['name']?.toString() ?? '',
      status: json['status']?.toString() ?? 'locked',
      accessible: json['accessible'] == true,
      releaseDate: json['release_date'] != null
          ? DateTime.tryParse(json['release_date'].toString())
          : null,
    );
  }
}

class VideoItem {
  const VideoItem({
    required this.id,
    required this.title,
    required this.filePath,
    this.thumbnailUrl,
    this.duration = 0,
    this.processingStatus,
    this.qualities = const {},
  });

  final int id;
  final String title;
  final String filePath;
  final String? thumbnailUrl;
  final int duration;
  final String? processingStatus;
  final Map<String, String> qualities;

  String get preferredUrl {
    if (qualities['highest']?.isNotEmpty == true) return qualities['highest']!;
    if (qualities['high']?.isNotEmpty == true) return qualities['high']!;
    if (qualities['medium']?.isNotEmpty == true) return qualities['medium']!;
    if (qualities['low']?.isNotEmpty == true) return qualities['low']!;
    return filePath;
  }

  factory VideoItem.fromJson(Map<String, dynamic> json) {
    final rawQualities = json['qualities'];
    final qualities = <String, String>{};
    if (rawQualities is Map) {
      rawQualities.forEach((key, value) {
        final label = key?.toString() ?? '';
        final url = value?.toString() ?? '';
        if (label.isNotEmpty && url.isNotEmpty) {
          qualities[label] = url;
        }
      });
    }

    return VideoItem(
      id: _asInt(json['id']) ?? 0,
      title: json['title']?.toString() ?? '',
      filePath: json['file_path']?.toString() ?? '',
      thumbnailUrl: json['thumbnail_url']?.toString(),
      duration: _asInt(json['duration']) ?? 0,
      processingStatus: json['processing_status']?.toString(),
      qualities: qualities,
    );
  }
}

class NoteItem {
  const NoteItem({
    required this.id,
    required this.title,
    required this.content,
    this.filePath,
  });

  final int id;
  final String title;
  final String content;
  final String? filePath;

  factory NoteItem.fromJson(Map<String, dynamic> json) {
    return NoteItem(
      id: _asInt(json['id']) ?? 0,
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      filePath: json['file_path']?.toString(),
    );
  }
}

class QuestionItem {
  const QuestionItem({
    required this.id,
    required this.questionText,
    required this.correctOption,
    this.explanation,
    this.optionA,
    this.optionB,
    this.optionC,
    this.optionD,
    this.optionE,
    this.optionF,
  });

  final int id;
  final String questionText;
  final String correctOption;
  final String? explanation;
  final String? optionA;
  final String? optionB;
  final String? optionC;
  final String? optionD;
  final String? optionE;
  final String? optionF;

  List<String> get options => [
        if (optionA?.isNotEmpty == true) 'A. $optionA',
        if (optionB?.isNotEmpty == true) 'B. $optionB',
        if (optionC?.isNotEmpty == true) 'C. $optionC',
        if (optionD?.isNotEmpty == true) 'D. $optionD',
        if (optionE?.isNotEmpty == true) 'E. $optionE',
        if (optionF?.isNotEmpty == true) 'F. $optionF',
      ];

  factory QuestionItem.fromJson(Map<String, dynamic> json) {
    return QuestionItem(
      id: _asInt(json['id']) ?? 0,
      questionText: json['question_text']?.toString() ?? '',
      correctOption: json['correct_option']?.toString() ?? '',
      explanation: json['explanation']?.toString(),
      optionA: json['option_a']?.toString(),
      optionB: json['option_b']?.toString(),
      optionC: json['option_c']?.toString(),
      optionD: json['option_d']?.toString(),
      optionE: json['option_e']?.toString(),
      optionF: json['option_f']?.toString(),
    );
  }
}

class SubscriptionItem {
  const SubscriptionItem({
    required this.id,
    required this.status,
    this.categoryId,
    this.categoryName,
    this.startDate,
    this.endDate,
    this.billingCycle,
  });

  final int id;
  final String status;
  final int? categoryId;
  final String? categoryName;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? billingCycle;

  bool get isActive => status == 'active';

  factory SubscriptionItem.fromJson(Map<String, dynamic> json) {
    return SubscriptionItem(
      id: _asInt(json['id']) ?? 0,
      status: json['status']?.toString() ?? 'unknown',
      categoryId: _asInt(json['category_id']),
      categoryName: json['category_name']?.toString() ??
          json['category']?['name']?.toString(),
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'].toString())
          : null,
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'].toString())
          : null,
      billingCycle: json['billing_cycle']?.toString(),
    );
  }
}

class ParentLinkItem {
  const ParentLinkItem({
    required this.isLinked,
    this.parentName,
    this.parentTelegramUsername,
    this.token,
    this.expiresAt,
  });

  final bool isLinked;
  final String? parentName;
  final String? parentTelegramUsername;
  final String? token;
  final DateTime? expiresAt;

  factory ParentLinkItem.fromJson(Map<String, dynamic> json) {
    return ParentLinkItem(
      isLinked: json['is_linked'] == true ||
          json['linked'] == true ||
          json['has_parent'] == true,
      parentName: json['parent_name']?.toString(),
      parentTelegramUsername: json['parent_telegram_username']?.toString(),
      token: json['token']?.toString() ?? json['link_token']?.toString(),
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())
          : null,
    );
  }
}

class ChatbotConversationItem {
  const ChatbotConversationItem({
    required this.id,
    required this.title,
    this.updatedAt,
  });

  final int id;
  final String title;
  final DateTime? updatedAt;

  factory ChatbotConversationItem.fromJson(Map<String, dynamic> json) {
    return ChatbotConversationItem(
      id: _asInt(json['id']) ?? 0,
      title: json['title']?.toString() ?? 'Conversation',
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }
}

class ChatbotMessageItem {
  const ChatbotMessageItem({
    required this.id,
    required this.role,
    required this.content,
    this.createdAt,
  });

  final int id;
  final String role;
  final String content;
  final DateTime? createdAt;

  bool get isUser => role == 'user';

  factory ChatbotMessageItem.fromJson(Map<String, dynamic> json) {
    return ChatbotMessageItem(
      id: _asInt(json['id']) ?? 0,
      role: json['role']?.toString() ?? 'assistant',
      content: json['content']?.toString() ??
          json['message']?.toString() ??
          '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.isRead,
    this.type,
    this.createdAt,
  });

  final int id;
  final String title;
  final String message;
  final bool isRead;
  final String? type;
  final DateTime? createdAt;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      id: _asInt(json['id']) ??
          _asInt(json['notification_log_id']) ??
          0,
      title: json['title']?.toString() ?? 'Notification',
      message: json['message']?.toString() ?? '',
      isRead: json['is_read'] == true || json['read'] == true,
      type: json['type']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}

class ExamQuestionItem {
  const ExamQuestionItem({
    required this.id,
    required this.questionText,
    this.optionA,
    this.optionB,
    this.optionC,
    this.optionD,
    this.optionE,
    this.optionF,
  });

  final int id;
  final String questionText;
  final String? optionA;
  final String? optionB;
  final String? optionC;
  final String? optionD;
  final String? optionE;
  final String? optionF;

  List<MapEntry<String, String>> get options => [
        if (optionA?.isNotEmpty == true) MapEntry('A', optionA!),
        if (optionB?.isNotEmpty == true) MapEntry('B', optionB!),
        if (optionC?.isNotEmpty == true) MapEntry('C', optionC!),
        if (optionD?.isNotEmpty == true) MapEntry('D', optionD!),
        if (optionE?.isNotEmpty == true) MapEntry('E', optionE!),
        if (optionF?.isNotEmpty == true) MapEntry('F', optionF!),
      ];

  factory ExamQuestionItem.fromJson(Map<String, dynamic> json) {
    return ExamQuestionItem(
      id: _asInt(json['id']) ?? 0,
      questionText: json['question_text']?.toString() ?? '',
      optionA: json['option_a']?.toString(),
      optionB: json['option_b']?.toString(),
      optionC: json['option_c']?.toString(),
      optionD: json['option_d']?.toString(),
      optionE: json['option_e']?.toString(),
      optionF: json['option_f']?.toString(),
    );
  }
}
