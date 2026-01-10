class AppConstants {
  // For Android emulator/device on same network
  // static const String baseUrl = 'http://10.0.2.2:3000'; // For Android emulator
  // static const String baseUrl = 'http://192.168.29.52:3000'; // For physical device on same network
  //static const String baseUrl = 'http://192.168.29.52:3000'; // Use your PC's IP

  static const String baseUrl = 'https://family-academy-backend.onrender.com';

  // OR if localhost doesn't work, use your loopback IP
  // static const String baseUrl = 'http://127.0.0.1:3000';

  static const String apiVersion = 'v1';
  static String get apiBaseUrl => '$baseUrl/api/$apiVersion';

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

  static const String userProgressByCourseEndpoint =
      '$userProgressEndpoint/course';
  static const String examResultDetailsEndpoint =
      '$examResultsEndpoint/details';
  static const String parentTokenGenerateEndpoint =
      '$telegramEndpoint/generate-token';
  static const String examQuestionBatchEndpoint = '$questionsEndpoint/batch';
  static const String uploadPaymentProofEndpoint = '/upload/payment-proof';
  static const String deviceChangePaymentEndpoint =
      '$paymentsEndpoint/device-change';
  static const String checkDeviceChangeEndpoint = '/auth/check-device-change';

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
  static String examSubmitAnswersEndpoint(int examResultId) =>
      '$examsEndpoint/submit-answers/$examResultId';

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
  static const String deviceInfoEndpoint = devicesEndpoint;
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
  static const String initializeDefaultsEndpoint =
      '$settingsEndpoint/initialize-defaults';

  static const String uploadImageEndpoint = '/upload/image';
  static const String uploadVideoEndpoint = '/upload/video';
  static const String uploadFileEndpoint = '/upload/file';

  static const String userProgressEndpoint = '/user-progress';
  static String userProgressByChapterEndpoint(int chapterId) =>
      '$userProgressEndpoint/chapter/$chapterId';

  static const String parentLinksEndpoint = '/parent-links';

  static const String systemLogsEndpoint = '/system-logs';

  static const String examQuestions = '/exam-questions';

  static const String appName = 'Family Academy';
  static const String appVersion = '1.0.0';

  static const String unpaidStatus = 'unpaid';
  static const String activeStatus = 'active';
  static const String expiredStatus = 'expired';

  static const String firstTimePayment = 'first_time';
  static const String repayment = 'repayment';
  static const String deviceChange = 'device_change';

  static const String telebirr = 'telebirr';
  static const String bankTransfer = 'bank_transfer';
  static const String cash = 'cash';

  static const String freeChapter = 'free';
  static const String lockedChapter = 'locked';

  static const String weeklyExam = 'weekly';
  static const String midExam = 'mid';
  static const String finalExam = 'final';

  static const String examStatusAvailable = 'available';
  static const String examStatusMaxAttempts = 'max_attempts_reached';
  static const String examStatusInProgress = 'in_progress';
  static const String examStatusUpcoming = 'upcoming';
  static const String examStatusEnded = 'ended';

  static const String examResultInProgress = 'in_progress';
  static const String examResultCompleted = 'completed';
  static const String examResultAbandoned = 'abandoned';

  static const String questionDifficultyEasy = 'easy';
  static const String questionDifficultyMedium = 'medium';
  static const String questionDifficultyHard = 'hard';

  static const String paymentStatusPending = 'pending';
  static const String paymentStatusVerified = 'verified';
  static const String paymentStatusRejected = 'rejected';

  static const String subscriptionStatusActive = 'active';
  static const String subscriptionStatusExpired = 'expired';
  static const String subscriptionStatusCancelled = 'cancelled';

  static const String notificationStatusDelivered = 'delivered';
  static const String notificationStatusFailed = 'failed';
  static const String notificationStatusPending = 'pending';

  static const String deviceTypePrimary = 'primary';
  static const String deviceTypeTv = 'tv';

  static const String parentLinkStatusPending = 'pending';
  static const String parentLinkStatusLinked = 'linked';
  static const String parentLinkStatusUnlinked = 'unlinked';

  static const String categoryStatusActive = 'active';
  static const String categoryStatusComingSoon = 'coming_soon';

  static const String billingCycleMonthly = 'monthly';
  static const String billingCycleSemester = 'semester';

  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';
  static const String deviceIdKey = 'device_id';
  static const String themeModeKey = 'theme_mode';
  static const String notificationsEnabledKey = 'notifications_enabled';
  static const String registrationCompleteKey = 'registration_complete';
  static const String selectedSchoolIdKey = 'selected_school_id';
  static const String tvDeviceIdKey = 'tv_device_id';
  static const String lastCacheCleanupKey = 'last_cache_cleanup';
  static const String lastAppStateKey = 'last_app_state';

  static const int maxCacheSizeMB = 500;
  static const int videoCacheDays = 30;
  static const int maxVideoSizeMB = 500;

  static const int pairingCodeLength = 6;
  static const int pairingExpiryMinutes = 10;

  static const int parentTokenExpiryMinutes = 30;

  static const int streakResetDays = 1;

  static const int expiryReminderDays = 7;
  static const int paymentReminderDays = 3;

  static const List<String> blockedFileTypes = [
    '.exe',
    '.bat',
    '.sh',
    '.php',
    '.js',
    '.py',
  ];
  static const List<String> allowedImageTypes = ['jpg', 'jpeg', 'png'];
  static const List<String> allowedVideoTypes = ['mp4', 'mov', 'avi'];

  static const int apiTimeoutSeconds = 30;
  static const int videoBufferSeconds = 10;
  static const int sessionTimeoutMinutes = 30;
  static const int examTimerIntervalSeconds = 1;

  static const String deviceIdPrefix = 'FA_DEVICE_';

  static const String encryptionKey = 'family_academy_secure_key_2024';

  static const int maxFileUploadSizeMB = 5;
  static const int maxPaymentProofSizeMB = 5;

  static const int maxApiRetries = 3;
  static const int apiRetryDelayMs = 1000;
  static const int examMaxAttemptsDefault = 1;
  static const int examPassingScoreDefault = 50;

  static const double defaultBorderRadius = 12.0;
  static const double defaultPadding = 16.0;
  static const double defaultIconSize = 24.0;
  static const double defaultButtonHeight = 48.0;

  static const int examMinDurationMinutes = 30;
  static const int examMaxDurationMinutes = 180;
  static const int examWarningTimeMinutes = 5;

  static const Map<int, String> streakLevels = {
    2: '🌱 Growing',
    5: '🚀 Consistent',
    10: '📚 Dedicated',
    20: '⭐ Superstar',
    30: '🔥 Legendary',
  };
}
