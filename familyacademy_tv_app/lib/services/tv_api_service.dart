import 'package:dio/dio.dart';

import '../app_config.dart';
import '../models/content_models.dart';

class TvApiService {
  TvApiService()
    : _dio = Dio(
        BaseOptions(
          baseUrl: AppConfig.apiBaseUrl,
          connectTimeout: const Duration(seconds: 20),
          sendTimeout: const Duration(seconds: 20),
          receiveTimeout: const Duration(seconds: 25),
        ),
      );

  final Dio _dio;

  Dio get dio => _dio;

  void setToken(String? token) {
    if (token == null || token.isEmpty) {
      _dio.options.headers.remove('Authorization');
      return;
    }
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Map<String, dynamic> _unwrapMap(Response<dynamic> response) {
    final data = response.data;
    if (data is! Map) {
      throw Exception('Unexpected response format.');
    }
    return Map<String, dynamic>.from(data);
  }

  List<dynamic> _unwrapListData(Response<dynamic> response) {
    final root = _unwrapMap(response);
    final payload = root['data'];
    if (payload is List) {
      return payload;
    }
    if (payload is Map) {
      if (payload['categories'] is List) return payload['categories'] as List;
      if (payload['courses'] is List) return payload['courses'] as List;
      if (payload['chapters'] is List) return payload['chapters'] as List;
      if (payload['videos'] is List) return payload['videos'] as List;
      if (payload['notes'] is List) return payload['notes'] as List;
      if (payload['questions'] is List) return payload['questions'] as List;
    }
    return const [];
  }

  Future<Map<String, dynamic>> startTvPairingSession(String deviceId) async {
    final response = await _dio.post(
      '/devices/tv/session/start',
      data: {'tv_device_id': deviceId},
    );
    final root = _unwrapMap(response);
    return Map<String, dynamic>.from(root['data'] as Map? ?? const {});
  }

  Future<Map<String, dynamic>> getTvPairingStatus({
    required String deviceId,
    required String pairingCode,
  }) async {
    final response = await _dio.get(
      '/devices/tv/session/status',
      queryParameters: {'tv_device_id': deviceId, 'pairing_code': pairingCode},
    );
    final root = _unwrapMap(response);
    return Map<String, dynamic>.from(root['data'] as Map? ?? const {});
  }

  Future<Map<String, dynamic>> getSessionUser() async {
    final response = await _dio.get('/users/profile/me');
    final root = _unwrapMap(response);
    return Map<String, dynamic>.from(root['data'] as Map? ?? const {});
  }

  Future<void> unpairTv() async {
    await _dio.post('/devices/tv/unpair');
  }

  Future<List<CategoryItem>> getCategories() async {
    final response = await _dio.get('/categories');
    return _unwrapListData(response)
        .map((item) => CategoryItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<CourseItem>> getCoursesByCategory(int categoryId) async {
    final response = await _dio.get('/courses/category/$categoryId');
    return _unwrapListData(response)
        .map((item) => CourseItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<ChapterItem>> getChaptersByCourse(int courseId) async {
    final response = await _dio.get('/chapters/course/$courseId');
    return _unwrapListData(response)
        .map((item) => ChapterItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<VideoItem>> getVideosByChapter(int chapterId) async {
    final response = await _dio.get('/chapters/$chapterId/videos');
    return _unwrapListData(response)
        .map((item) => VideoItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<NoteItem>> getNotesByChapter(int chapterId) async {
    final response = await _dio.get('/chapters/$chapterId/notes');
    return _unwrapListData(response)
        .map((item) => NoteItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<QuestionItem>> getPracticeQuestions(int chapterId) async {
    final response = await _dio.get('/chapters/$chapterId/practice-questions');
    return _unwrapListData(response)
        .map((item) => QuestionItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<ExamItem>> getAvailableExams({int? courseId}) async {
    final response = await _dio.get(
      '/exams/available',
      queryParameters: courseId != null ? {'course_id': courseId} : null,
    );
    return _unwrapListData(response)
        .map((item) => ExamItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<Map<String, dynamic>> getOverallProgress() async {
    final response = await _dio.get('/progress/overall');
    final root = _unwrapMap(response);
    return Map<String, dynamic>.from(root['data'] as Map? ?? const {});
  }

  Future<TvUser> getMyProfile() async {
    final response = await _dio.get('/users/profile/me');
    final root = _unwrapMap(response);
    return TvUser.fromJson(
      Map<String, dynamic>.from(root['data'] as Map? ?? const {}),
    );
  }

  Future<List<SubscriptionItem>> getMySubscriptions() async {
    final response = await _dio.get('/subscriptions/my-subscriptions');
    return _unwrapListData(response)
        .map(
          (item) => SubscriptionItem.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<Map<String, String>> getPublicSettings() async {
    final response = await _dio.get('/settings/all');
    final items = _unwrapListData(response)
        .map((item) => AppSettingItem.fromJson(Map<String, dynamic>.from(item)))
        .toList();
    return {
      for (final item in items)
        if (item.key.isNotEmpty) item.key: item.value,
    };
  }

  Future<ParentLinkItem?> getParentLinkStatus() async {
    final response = await _dio.get('/telegram/status');
    final root = _unwrapMap(response);
    final data = root['data'];
    if (data is Map) {
      return ParentLinkItem.fromJson(Map<String, dynamic>.from(data));
    }
    return null;
  }

  Future<Map<String, dynamic>> generateParentToken() async {
    final response = await _dio.post('/telegram/generate-token');
    final root = _unwrapMap(response);
    return Map<String, dynamic>.from(root['data'] as Map? ?? const {});
  }

  Future<void> unlinkParent() async {
    await _dio.post('/telegram/unlink');
  }

  Future<Map<String, dynamic>> getChatbotUsage() async {
    final response = await _dio.get('/chatbot/usage');
    final root = _unwrapMap(response);
    return Map<String, dynamic>.from(root['data'] as Map? ?? const {});
  }

  Future<List<ChatbotConversationItem>> getChatbotConversations() async {
    final response = await _dio.get(
      '/chatbot/conversations',
      queryParameters: {'page': 1, 'limit': 30},
    );
    final root = _unwrapMap(response);
    final data = root['data'];
    final list = data is List
        ? data
        : data is Map && data['conversations'] is List
        ? List<dynamic>.from(data['conversations'] as List)
        : const <dynamic>[];
    return list
        .map(
          (item) =>
              ChatbotConversationItem.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<List<ChatbotMessageItem>> getChatbotConversationMessages(
    int conversationId,
  ) async {
    final response = await _dio.get(
      '/chatbot/conversations/$conversationId/messages',
    );
    final root = _unwrapMap(response);
    final data = root['data'];
    final list = data is List
        ? data
        : data is Map && data['messages'] is List
        ? List<dynamic>.from(data['messages'] as List)
        : const <dynamic>[];
    return list
        .map(
          (item) =>
              ChatbotMessageItem.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<Map<String, dynamic>> sendChatbotMessage(
    String message, {
    int? conversationId,
  }) async {
    final response = await _dio.post(
      '/chatbot/chat',
      data: {'message': message, 'conversation_id': conversationId},
    );
    final root = _unwrapMap(response);
    return Map<String, dynamic>.from(root['data'] as Map? ?? const {});
  }

  Future<int> getUnreadNotificationCount() async {
    final response = await _dio.get('/notifications/unread-count');
    final root = _unwrapMap(response);
    final data = Map<String, dynamic>.from(root['data'] as Map? ?? const {});
    return (data['unread_count'] as num?)?.toInt() ?? 0;
  }

  Future<List<NotificationItem>> getNotifications() async {
    final response = await _dio.get('/notifications/my-notifications');
    return _unwrapListData(response)
        .map(
          (item) => NotificationItem.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<void> markNotificationAsRead(int id) async {
    await _dio.put('/notifications/$id/read');
  }

  Future<void> markAllNotificationsAsRead() async {
    await _dio.put('/notifications/mark-all-read');
  }

  Future<void> saveUserProgress({
    required int chapterId,
    int? videoProgress,
    bool? notesViewed,
    int? questionsAttempted,
    int? questionsCorrect,
  }) async {
    final data = <String, dynamic>{'chapter_id': chapterId};
    if (videoProgress != null) {
      data['video_progress'] = videoProgress;
    }
    if (notesViewed != null) {
      data['notes_viewed'] = notesViewed ? 1 : 0;
    }
    if (questionsAttempted != null) {
      data['questions_attempted'] = questionsAttempted;
    }
    if (questionsCorrect != null) {
      data['questions_correct'] = questionsCorrect;
    }

    await _dio.post('/progress/save', data: data);
  }

  Future<Map<String, dynamic>> startExam(int examId) async {
    final response = await _dio.post('/exams/start/$examId');
    final root = _unwrapMap(response);
    return Map<String, dynamic>.from(root['data'] as Map? ?? const {});
  }

  Future<List<ExamQuestionItem>> getExamQuestions(int examId) async {
    final response = await _dio.get('/exam-questions/exam/$examId');
    return _unwrapListData(response)
        .map(
          (item) => ExamQuestionItem.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<Map<String, dynamic>> submitExam(
    int examResultId,
    List<Map<String, dynamic>> answers,
  ) async {
    final response = await _dio.post(
      '/exams/submit/$examResultId',
      data: {'answers': answers},
    );
    final root = _unwrapMap(response);
    return Map<String, dynamic>.from(root['data'] as Map? ?? const {});
  }
}
