class AppConstants {
  static const String baseUrl =
      'https://family-academy-backend-a12l.onrender.com';
  static const String apiVersion = 'v1';
  static String get apiBaseUrl => '$baseUrl/api/$apiVersion';

  static const int apiTimeoutSeconds = 30;
  static const int tokenRefreshThresholdMinutes = 5;

  static const String healthEndpoint = '/health';

  static const String registerEndpoint = '/auth/register';
  static const String studentLoginEndpoint = '/auth/student-login';
  static const String adminLoginEndpoint = '/auth/admin-login';
  static const String refreshTokenEndpoint = '/auth/refresh-token';
  static const String logoutEndpoint = '/auth/logout';
  static const String validateTokenEndpoint = '/auth/validate';
  static const String validateStudentTokenEndpoint = '/auth/student/validate';
  static const String validateAdminTokenEndpoint = '/auth/admin/validate';

  static const String schoolsEndpoint = '/schools';

  static const String categoriesEndpoint = '/categories';
  static const String allCategoriesEndpoint = '$categoriesEndpoint/all';
  static const String studentCategoriesEndpoint = '$categoriesEndpoint/student';

  static const String coursesEndpoint = '/courses';
  static String coursesByCategory(int categoryId) =>
      '$coursesEndpoint/category/$categoryId';

  static const String chaptersEndpoint = '/chapters';
  static String chaptersByCourse(int courseId) =>
      '$chaptersEndpoint/course/$courseId';

  static const String videosEndpoint = '/videos';
  static String videosByChapter(int chapterId) =>
      '$videosEndpoint/chapter/$chapterId';
  static String incrementViewEndpoint(int videoId) =>
      '$videosEndpoint/$videoId/view';

  static const String notesEndpoint = '/notes';
  static String notesByChapter(int chapterId) =>
      '$notesEndpoint/chapter/$chapterId';

  static const String questionsEndpoint = '/questions';
  static String practiceQuestions(int chapterId) =>
      '$questionsEndpoint/practice/$chapterId';
  static const String checkAnswerEndpoint = '$questionsEndpoint/check-answer';

  static const String examsEndpoint = '/exams';
  static const String availableExamsEndpoint = '$examsEndpoint/available';
  static String startExamEndpoint(int examId) => '$examsEndpoint/start/$examId';
  static String submitExamEndpoint(int examResultId) =>
      '$examsEndpoint/submit/$examResultId';
  static const String myExamResultsEndpoint = '$examsEndpoint/my-results';
  static String examQuestionsEndpoint(int examId) =>
      '$examsEndpoint/$examId/questions';
  static String examProgressEndpoint(int examResultId) =>
      '$examsEndpoint/progress/$examResultId';

  static const String examResultsEndpoint = '/exam-results';
  static String examResultByIdEndpoint(int examResultId) =>
      '$examResultsEndpoint/$examResultId';
  static String examResultsByExamEndpoint(int examId) =>
      '$examResultsEndpoint/exam/$examId';

  static const String paymentsEndpoint = '/payments';
  static const String submitPaymentEndpoint = '$paymentsEndpoint/submit';
  static const String myPaymentsEndpoint = '$paymentsEndpoint/my-payments';
  static const String pendingPaymentsEndpoint = '$paymentsEndpoint/pending';
  static const String allPaymentsEndpoint = '$paymentsEndpoint/all';
  static String verifyPaymentEndpoint(int paymentId) =>
      '$paymentsEndpoint/verify/$paymentId';
  static String rejectPaymentEndpoint(int paymentId) =>
      '$paymentsEndpoint/reject/$paymentId';
  static const String uploadPaymentProofEndpoint = '/upload/payment-proof';

  static const String subscriptionsEndpoint = '/subscriptions';
  static const String mySubscriptionsEndpoint =
      '$subscriptionsEndpoint/my-subscriptions';
  static const String checkSubscriptionStatusEndpoint =
      '$subscriptionsEndpoint/check-status';
  static String extendSubscriptionEndpoint(int subscriptionId) =>
      '$subscriptionsEndpoint/$subscriptionId/extend';
  static String cancelSubscriptionEndpoint(int subscriptionId) =>
      '$subscriptionsEndpoint/$subscriptionId/cancel';

  static const String streaksEndpoint = '/streaks';
  static const String myStreakEndpoint = '$streaksEndpoint/my-streak';
  static const String updateStreakEndpoint = '$streaksEndpoint/update';

  static const String devicesEndpoint = '/devices';
  static const String pairTvDeviceEndpoint = '$devicesEndpoint/tv/pair';
  static const String verifyTvPairingEndpoint = '$devicesEndpoint/tv/verify';
  static const String unpairTvDeviceEndpoint = '$devicesEndpoint/tv/unpair';
  static String forceRemoveDeviceEndpoint(int id) => '$devicesEndpoint/$id';

  static const String telegramEndpoint = '/telegram';
  static const String generateParentTokenEndpoint =
      '$telegramEndpoint/generate-token';
  static const String parentLinkStatusEndpoint = '$telegramEndpoint/status';
  static const String unlinkParentEndpoint = '$telegramEndpoint/unlink';

  static const String notificationsEndpoint = '/notifications';
  static const String myNotificationsEndpoint =
      '$notificationsEndpoint/my-notifications';
  static const String notificationHistoryEndpoint =
      '$notificationsEndpoint/history';
  static const String sendNotificationEndpoint = '$notificationsEndpoint/send';

  static const String usersEndpoint = '/users';
  static const String myProfileEndpoint = '$usersEndpoint/profile/me';
  static const String updateProfileEndpoint = '$usersEndpoint/profile/me';
  static const String updateDeviceEndpoint = '$usersEndpoint/device/update';
  static const String allUsersEndpoint = usersEndpoint;
  static String userDetailsEndpoint(int userId) => '$usersEndpoint/$userId';

  static const String settingsEndpoint = '/settings';
  static const String publicSettingsEndpoint = '$settingsEndpoint/public';
  static String settingsByCategory(String category) =>
      '$settingsEndpoint/category/$category';
  static const String settingsCategoriesEndpoint =
      '$settingsEndpoint/categories';
  static String settingByKeyEndpoint(String key) => '$settingsEndpoint/$key';

  static const String saveProgressEndpoint = '/progress/save';
  static const String getProgressEndpoint = '/progress/chapter/';
  static const String getCourseProgressEndpoint = '/progress/course/';
  static const String getOverallProgressEndpoint = '/progress/overall';

  static const String uploadImageEndpoint = '/upload/image';
  static const String uploadVideoEndpoint = '/upload/video';
  static const String uploadFileEndpoint = '/upload/file';

  static const String chatbotEndpoint = '/chatbot';
  static const String chatbotChatEndpoint = '$chatbotEndpoint/chat';
  static const String chatbotConversationsEndpoint =
      '$chatbotEndpoint/conversations';
  static const String chatbotUsageEndpoint = '$chatbotEndpoint/usage';

  static const String cachePrefix = 'cache_';
  static const Duration defaultCacheTTL = Duration(days: 7);
  static const Duration defaultCacheTTLHours = Duration(hours: 24);

  static const String androidDevicePrefix = 'ANDROID_';
  static const String iosDevicePrefix = 'IOS_';
  static const String fallbackDevicePrefix = 'FA_';
  static const String tvDeviceIdKey = 'tv_device_id';

  static const String notificationChannelId = 'family_academy_channel';
  static const String notificationChannelName = 'Family Academy Notifications';
  static const String notificationChannelDescription =
      'Important notifications from Family Academy';
  static const int notificationLedOnMs = 1000;
  static const int notificationLedOffMs = 500;

  static const List<String> quickQuestions = [
    'Help with math',
    'Tell me about Ethiopia',
    'Study tips',
    'Teach me Amharic',
  ];

  static const List<Map<String, String>> faq = [
    {
      'question': 'How do I reset my password?',
      'answer':
          'Please contact support using the phone or email provided. We will verify your identity and reset your password for you.'
    },
    {
      'question': 'Why is my payment not verified?',
      'answer':
          'Payments are manually verified by our admin team. This usually takes 24-48 hours. Ensure your payment proof includes transaction ID and is clearly visible.'
    },
    {
      'question': 'Can I change my device?',
      'answer':
          'Yes, you can change your device but it requires a device change payment. Go to Profile → Device Settings to initiate the process.'
    },
    {
      'question': 'How do I access paid content?',
      'answer':
          'First, make a payment for the category you want to access. Once your payment is verified, all content in that category will be unlocked.'
    },
    {
      'question': 'What happens when my subscription expires?',
      'answer':
          'You will lose access to paid content in that category. You can renew your subscription before it expires to maintain continuous access.'
    },
    {
      'question': 'How do I link my parent account?',
      'answer':
          'Go to Profile → Parent Link to generate a unique code. Share this code with your parent through Telegram to complete the linking process.'
    },
  ];

  static const String appVersion = '1.4.0+1';
  static const String appCopyright = '© 2024 Family Academy';

  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';
  static const String deviceIdKey = 'device_id';
  static const String themeModeKey = 'theme_mode';
  static const String notificationsEnabledKey = 'notifications_enabled';
  static const String registrationCompleteKey = 'registration_complete';
  static const String selectedSchoolIdKey = 'selected_school_id';
  static const String tvDeviceIdKey_old = 'tv_device_id';

  static const String lastUserIdKey = 'last_logged_in_user_id';
  static const String currentUserIdKey = 'current_user_id';
  static const String isLoggingOutKey = 'is_logging_out';
  static const String sessionStartKey = 'session_start';

  static const String categoriesCacheKey = 'categories';
  static String categorySubscriptionKey(int categoryId) =>
      'category_sub_$categoryId';

  static String coursesByCategoryKey(int categoryId) => 'courses_$categoryId';

  static String chaptersByCourseKey(int courseId) =>
      'chapters_course_$courseId';

  static const String availableExamsCacheKey = 'available_exams';
  static const String myExamResultsCacheKey = 'my_exam_results';
  static String examsByCourseKey(int courseId) => 'exams_course_$courseId';
  static String examQuestionsKey(int examId) => 'exam_questions_$examId';
  static String examAccessKey(int examId) => 'exam_access_$examId';

  static String progressCourseKey(int courseId) => 'progress_course_$courseId';
  static String progressChapterKey(int chapterId) =>
      'progress_chapter_$chapterId';
  static const String allUserProgressKey = 'all_user_progress';
  static const String overallStatsKey = 'overall_stats';

  static String userProfileKey(String userId) => 'user_profile_$userId';
  static String userPaymentsKey(String userId) => 'user_payments_$userId';
  static String userNotificationsKey(String userId) =>
      'user_notifications_$userId';

  static const String allSettingsKey = 'all_settings';
  static String settingsCategoryKey(String category) =>
      'settings_category_$category';

  static const String schoolsListKey = 'schools_list';
  static const String selectedSchoolKey = 'selected_school';

  static const String parentLinkStatusKey = 'parent_link_status';
  static const String parentTokenKey = 'parent_token';

  static String videosByChapterKey(int chapterId) =>
      'videos_chapter_$chapterId';
  static const String downloadedVideosKey = 'downloaded_videos';
  static const String downloadQualitiesKey = 'download_qualities';

  static String questionsChapterKey(int chapterId) =>
      'questions_chapter_$chapterId';
  static String answerResultKey(int questionId) => 'answer_result_$questionId';
  static String selectedAnswerKey(int questionId) =>
      'selected_answer_$questionId';

  static String notesChapterKey(int chapterId) => 'notes_chapter_$chapterId';
  static String noteViewedKey(int noteId) => 'note_viewed_$noteId';

  static const String subscriptionsCacheKey = 'subscriptions';
  static String categoryAccessKey(int categoryId) =>
      'category_access_$categoryId';

  static const String paymentsCacheKey = 'payments';

  static const String persistentDeviceIdKey = 'persistent_device_id';
  static const String tvDeviceIdCacheKey = 'tv_device_id';
  static const String pairingCodeKey = 'pairing_code';
  static const String pairingExpiresAtKey = 'pairing_expires_at';

  static const String notificationsCacheKey = 'notifications';
  static const String fcmTokenCacheKey = 'fcm_token';

  static String streakKey(String userId) => 'streak_$userId';

  static const String serverTimeInfoKey = 'server_time_info';

  static const int pairingExpiryMinutes = 10;
  static const int parentTokenExpiryMinutes = 30;

  static const String appName = 'Family Academy';
}
