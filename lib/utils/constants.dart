class AppConstants {
  static const String baseUrl =
      'https://family-academy-backend-a12l.onrender.com';
  static const String apiVersion = 'v1';
  static String get apiBaseUrl => '$baseUrl/api/$apiVersion';

  // Auth Endpoints
  static const String registerEndpoint = '/auth/register';
  static const String studentLoginEndpoint = '/auth/student-login';
  static const String adminLoginEndpoint = '/auth/admin-login';
  static const String refreshTokenEndpoint = '/auth/refresh-token';
  static const String logoutEndpoint = '/auth/logout';
  static const String validateTokenEndpoint = '/auth/validate';
  static const String validateStudentTokenEndpoint = '/auth/student/validate';
  static const String validateAdminTokenEndpoint = '/auth/admin/validate';

  // Schools
  static const String schoolsEndpoint = '/schools';

  // Categories
  static const String categoriesEndpoint = '/categories';
  static const String allCategoriesEndpoint = '$categoriesEndpoint/all';
  static const String studentCategoriesEndpoint = '$categoriesEndpoint/student';

  // Courses
  static const String coursesEndpoint = '/courses';
  static String coursesByCategory(int categoryId) =>
      '$coursesEndpoint/category/$categoryId';

  // Chapters
  static const String chaptersEndpoint = '/chapters';
  static String chaptersByCourse(int courseId) =>
      '$chaptersEndpoint/course/$courseId';

  // Videos
  static const String videosEndpoint = '/videos';
  static String videosByChapter(int chapterId) =>
      '$videosEndpoint/chapter/$chapterId';
  static String incrementViewEndpoint(int videoId) =>
      '$videosEndpoint/$videoId/view';

  // Notes
  static const String notesEndpoint = '/notes';
  static String notesByChapter(int chapterId) =>
      '$notesEndpoint/chapter/$chapterId';

  // Questions
  static const String questionsEndpoint = '/questions';
  static String practiceQuestions(int chapterId) =>
      '$questionsEndpoint/practice/$chapterId';
  static const String checkAnswerEndpoint = '$questionsEndpoint/check-answer';

  // Exams
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

  // Exam Results
  static const String examResultsEndpoint = '/exam-results';
  static String examResultByIdEndpoint(int examResultId) =>
      '$examResultsEndpoint/$examResultId';
  static String examResultsByExamEndpoint(int examId) =>
      '$examResultsEndpoint/exam/$examId';

  // Payments
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

  // Subscriptions
  static const String subscriptionsEndpoint = '/subscriptions';
  static const String mySubscriptionsEndpoint =
      '$subscriptionsEndpoint/my-subscriptions';
  static const String checkSubscriptionStatusEndpoint =
      '$subscriptionsEndpoint/check-status';
  static String extendSubscriptionEndpoint(int subscriptionId) =>
      '$subscriptionsEndpoint/$subscriptionId/extend';
  static String cancelSubscriptionEndpoint(int subscriptionId) =>
      '$subscriptionsEndpoint/$subscriptionId/cancel';

  // Streaks
  static const String streaksEndpoint = '/streaks';
  static const String myStreakEndpoint = '$streaksEndpoint/my-streak';
  static const String updateStreakEndpoint = '$streaksEndpoint/update';

  // Devices
  static const String devicesEndpoint = '/devices';
  static const String pairTvDeviceEndpoint = '$devicesEndpoint/tv/pair';
  static const String verifyTvPairingEndpoint = '$devicesEndpoint/tv/verify';
  static const String unpairTvDeviceEndpoint = '$devicesEndpoint/tv/unpair';
  static String forceRemoveDeviceEndpoint(int id) => '$devicesEndpoint/$id';

  // Telegram/Parent Links
  static const String telegramEndpoint = '/telegram';
  static const String generateParentTokenEndpoint =
      '$telegramEndpoint/generate-token';
  static const String parentLinkStatusEndpoint = '$telegramEndpoint/status';
  static const String unlinkParentEndpoint = '$telegramEndpoint/unlink';

  // Notifications
  static const String notificationsEndpoint = '/notifications';
  static const String myNotificationsEndpoint =
      '$notificationsEndpoint/my-notifications';
  static const String notificationHistoryEndpoint =
      '$notificationsEndpoint/history';
  static const String sendNotificationEndpoint = '$notificationsEndpoint/send';

  // Users
  static const String usersEndpoint = '/users';
  static const String myProfileEndpoint = '$usersEndpoint/profile/me';
  static const String updateProfileEndpoint = '$usersEndpoint/profile/me';
  static const String updateDeviceEndpoint = '$usersEndpoint/device/update';
  static const String allUsersEndpoint = usersEndpoint;
  static String userDetailsEndpoint(int userId) => '$usersEndpoint/$userId';

  // Settings
  static const String settingsEndpoint = '/settings';
  static const String publicSettingsEndpoint = '$settingsEndpoint/public';
  static String settingsByCategory(String category) =>
      '$settingsEndpoint/category/$category';
  static const String settingsCategoriesEndpoint =
      '$settingsEndpoint/categories';
  static String settingByKeyEndpoint(String key) => '$settingsEndpoint/$key';

  // Progress
  static const String saveProgressEndpoint = '/progress/save';
  static const String getProgressEndpoint = '/progress/chapter/';
  static const String getCourseProgressEndpoint = '/progress/course/';
  static const String getOverallProgressEndpoint = '/progress/overall';

  // Uploads
  static const String uploadImageEndpoint = '/upload/image';
  static const String uploadVideoEndpoint = '/upload/video';
  static const String uploadFileEndpoint = '/upload/file';
// Chatbot
  static const String chatbotEndpoint = '/chatbot';
  static const String chatbotChatEndpoint = '$chatbotEndpoint/chat';
  static const String chatbotConversationsEndpoint =
      '$chatbotEndpoint/conversations';
  static const String chatbotUsageEndpoint = '$chatbotEndpoint/usage';
  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';
  static const String deviceIdKey = 'device_id';
  static const String themeModeKey = 'theme_mode';
  static const String notificationsEnabledKey = 'notifications_enabled';
  static const String registrationCompleteKey = 'registration_complete';
  static const String selectedSchoolIdKey = 'selected_school_id';
  static const String tvDeviceIdKey = 'tv_device_id';

  // Constants
  static const int apiTimeoutSeconds = 30;
  static const int pairingExpiryMinutes = 10;
  static const int parentTokenExpiryMinutes = 30;

  // App Info
  static const String appName = 'Family Academy';
  static const String appVersion = '1.4.2+1';
}
