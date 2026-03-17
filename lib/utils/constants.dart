// lib/utils/constants.dart
// COMPLETE PRODUCTION-READY FILE - REPLACE ENTIRE FILE

class AppConstants {
  // API Configuration
  static String get apiBaseUrl {
    try {
      const env = (bool.hasEnvironment('API_BASE_URL'))
          ? String.fromEnvironment('API_BASE_URL')
          : null;
      if (env != null && env.isNotEmpty) return env;
    } catch (_) {}
    return const String.fromEnvironment('API_BASE_URL',
        defaultValue: 'http://localhost:3000');
  }

  static const int apiTimeoutSeconds = 45;
  static const int apiRetryCount = 3;

  // App Information
  static const String appName = 'Family Academy';
  static const String appVersion = '1.5.0+1';

  // API Version
  static const String apiVersion = '/api/v1';

  // Authentication Endpoints
  static String get registerEndpoint => '$apiVersion/auth/register';
  static String get studentLoginEndpoint => '$apiVersion/auth/student-login';
  static String get validateStudentTokenEndpoint =>
      '$apiVersion/auth/validate-student';
  static String get refreshTokenEndpoint => '$apiVersion/auth/refresh-token';
  static String get healthEndpoint => '/health';

  // Device & Platform
  static const String androidDevicePrefix = 'android_';
  static const String iosDevicePrefix = 'ios_';
  static const String fallbackDevicePrefix = 'fallback_';
  static const String tvDevicePrefix = 'tv_';

  // Storage Keys
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userDataKey = 'user_data';
  static const String persistentDeviceIdKey = 'persistent_device_id';
  static const String currentUserIdKey = 'current_user_id';
  static const String lastUserIdKey = 'last_user_id';
  static const String isLoggingOutKey = 'is_logging_out';
  static const String sessionStartKey = 'session_start';
  static const String registrationCompleteKey = 'registration_complete';
  static const String selectedSchoolIdKey = 'selected_school_id';
  static const String notificationsEnabledKey = 'notifications_enabled';
  static const String fcmTokenCacheKey = 'fcm_token';
  static const String tvDeviceIdKey = 'tv_device_id';

  // Pairing Keys
  static const String pairingCodeKey = 'pairing_code';
  static const String pairingExpiresAtKey = 'pairing_expires_at';
  static const int pairingCodeLength = 6;

  // Cache Keys
  static const String cachePrefix = 'cache_';
  static const String allSettingsKey = 'all_settings';
  static const String schoolsListKey = 'schools_list';
  static const String selectedSchoolKey = 'selected_school';
  static const String notificationsCacheKey = 'notifications_cache';
  static const String paymentsCacheKey = 'payments_cache';
  static const String subscriptionsCacheKey = 'subscriptions_cache';
  static const String allUserProgressKey = 'all_user_progress';
  static const String overallStatsKey = 'overall_stats';
  static const String parentLinkStatusKey = 'parent_link_status';
  static const String parentTokenKey = 'parent_token';
  static const String serverTimeInfoKey = 'server_time_info';

  // Download Keys
  static const String downloadedVideosKey = 'downloaded_videos';
  static const String downloadQualitiesKey = 'download_qualities';
  static const String offlineQueueKey = 'offline_queue';
  static const String pendingPaymentsKey = 'pending_payments';
  static const String pendingProgressKey = 'pending_progress';

  // Cache TTLs
  static const Duration defaultCacheTTL = Duration(minutes: 30);
  static const Duration cacheTTLCategories = Duration(hours: 24);
  static const Duration cacheTTLCourses = Duration(hours: 24);
  static const Duration cacheTTLChapters = Duration(hours: 24);
  static const Duration cacheTTLVideos = Duration(hours: 24);
  static const Duration cacheTTLNotes = Duration(hours: 24);
  static const Duration cacheTTLQuestions = Duration(hours: 24);
  static const Duration cacheTTLExams = Duration(hours: 24);
  static const Duration cacheTTLSubscriptions = Duration(minutes: 30);
  static const Duration cacheTTLPayments = Duration(minutes: 30);
  static const Duration cacheTTLNotifications = Duration(hours: 12);
  static const Duration cacheTTLStreak = Duration(minutes: 15);
  static const Duration cacheTTLSchools = Duration(days: 7);
  static const Duration cacheTTLSettings = Duration(hours: 12);
  static const Duration cacheTTLUserProfile = Duration(minutes: 30);
  static const Duration cacheTTLDownloadMetadata = Duration(days: 7);

  // Queue Configuration
  static const int maxQueueRetries = 5;
  static const int queueRetryBaseSeconds =
      2; // 2, 4, 8, 16, 32 seconds exponential backoff

  // Cache Configuration
  static const Duration cacheCleanupInterval = Duration(minutes: 15);
  static const int maxCacheSize = 100; // Max items per cache
  static const int maxCacheItemsPerType = 50; // Max items per cache type

  // Sync Configuration
  static const Duration backgroundSyncInterval = Duration(minutes: 5);
  static const Duration minRefreshInterval = Duration(seconds: 30);
  static const int maxConcurrentSyncs = 3;

  // Hive Box Names
  static const String hiveUserBox = 'user_box';
  static const String hiveCategoriesBox = 'categories_box';
  static const String hiveCoursesBox = 'courses_box';
  static const String hiveChaptersBox = 'chapters_box';
  static const String hiveVideosBox = 'videos_box';
  static const String hiveNotesBox = 'notes_box';
  static const String hiveQuestionsBox = 'questions_box';
  static const String hiveExamsBox = 'exams_box';
  static const String hiveExamResultsBox = 'exam_results_box';
  static const String hiveSubscriptionsBox = 'subscriptions_box';
  static const String hivePaymentsBox = 'payments_box';
  static const String hiveNotificationsBox = 'notifications_box';
  static const String hiveProgressBox = 'progress_box';
  static const String hiveChatbotMessagesBox = 'chatbot_messages_box';
  static const String hiveChatbotConversationsBox = 'chatbot_conversations_box';
  static const String hiveStreakBox = 'streak_box';
  static const String hiveSchoolsBox = 'schools_box';
  static const String hiveSettingsBox = 'settings_box';
  static const String hiveParentLinkBox = 'parent_link_box';

  // User-specific Cache Keys
  static String userCategoriesKey(String userId) => 'user_${userId}_categories';
  static String userCoursesKey(String userId) => 'user_${userId}_courses';
  static String userChaptersKey(String userId) => 'user_${userId}_chapters';
  static String userVideosKey(String userId) => 'user_${userId}_videos';
  static String userNotesKey(String userId) => 'user_${userId}_notes';
  static String userQuestionsKey(String userId) => 'user_${userId}_questions';
  static String userExamsKey(String userId) => 'user_${userId}_exams';
  static String userExamResultsKey(String userId) =>
      'user_${userId}_exam_results';
  static String userSubscriptionsKey(String userId) =>
      'user_${userId}_subscriptions';
  static String userPaymentsKey(String userId) => 'user_${userId}_payments';
  static String userNotificationsKey(String userId) =>
      'user_${userId}_notifications';
  static String userProgressKey(String userId) => 'user_${userId}_progress';
  static String userStreakKey(String userId) => 'user_${userId}_streak';
  static String userProfileKey(String userId) => 'user_${userId}_profile';
  static String userChatbotKey(String userId) => 'user_${userId}_chatbot';

  // Sync & Queue Keys
  static const String lastSyncTimeKey = 'last_sync_time';
  static const String pendingSyncKey = 'pending_sync';
  static const String syncStatusKey = 'sync_status';
  static const String lastFullSyncKey = 'last_full_sync';
  static const String failedActionsKey = 'failed_actions';

  // Theme
  static const String themeModeKey = 'theme_mode';

  // Notification
  static const String notificationChannelId = 'family_academy_channel';
  static const String notificationChannelName = 'Family Academy Notifications';
  static const String notificationChannelDescription =
      'Notifications from Family Academy';
  static const int notificationLedOnMs = 300;
  static const int notificationLedOffMs = 500;

  // ===== API Endpoint Helpers - CORRECT VERSIONS =====

  // Categories
  static String get categoriesEndpoint => '$apiVersion/categories';

  // Courses
  static String coursesByCategory(int categoryId) =>
      '$apiVersion/courses/category/$categoryId';

  // Chapters - FIXED: Correct endpoint from backend
  static String chaptersByCourse(int courseId) =>
      '$apiVersion/chapters/course/$courseId'; // ✅ CORRECT
  static String chapterDetails(int chapterId) =>
      '$apiVersion/chapters/$chapterId';

  // Notes
  static String notesByChapter(int chapterId) =>
      '$apiVersion/chapters/$chapterId/notes';

  // Videos
  static String videosByChapter(int chapterId) =>
      '$apiVersion/chapters/$chapterId/videos';

  // Practice Questions
  static String practiceQuestions(int chapterId) =>
      '$apiVersion/chapters/$chapterId/practice-questions';
  static String get checkAnswerEndpoint => '$apiVersion/practice/check-answer';

  // Exams
  static String get availableExamsEndpoint => '$apiVersion/exams/available';
  static String startExamEndpoint(int examId) =>
      '$apiVersion/exams/start/$examId';
  static String examQuestionsEndpoint(int examId) =>
      '$apiVersion/exams/$examId/questions';
  static String examProgressEndpoint(int examResultId) =>
      '$apiVersion/exam-results/$examResultId/progress';
  static String submitExamEndpoint(int examResultId) =>
      '$apiVersion/exam-results/$examResultId/submit';

  // Exam Results - FIXED: Backend expects user_id
  static String userExamResultsEndpoint(int userId) =>
      '$apiVersion/exam-results/user/$userId';
  static String userExamStatsEndpoint(int userId) =>
      '$apiVersion/exam-results/user/$userId/stats';

  // Subscriptions
  static String get checkSubscriptionStatusEndpoint =>
      '$apiVersion/subscriptions/check-status';
  static String get mySubscriptionsEndpoint =>
      '$apiVersion/subscriptions/my-subscriptions';

  // Payments
  static String get submitPaymentEndpoint => '$apiVersion/payments/submit';
  static String get myPaymentsEndpoint => '$apiVersion/payments/my-payments';
  static String get uploadPaymentProofEndpoint =>
      '$apiVersion/payments/upload-proof';

  // Notifications
  static String get myNotificationsEndpoint =>
      '$apiVersion/notifications/my-notifications';
  static String get notificationsEndpoint => '$apiVersion/notifications';
  static String get notificationsUnreadCountEndpoint =>
      '$apiVersion/notifications/unread-count';

  // Streaks
  static String get myStreakEndpoint => '$apiVersion/streaks/my-streak';
  static String get updateStreakEndpoint => '$apiVersion/streaks/update';

  // Devices
  static String get pairTvDeviceEndpoint => '$apiVersion/devices/tv/pair';
  static String get verifyTvPairingEndpoint => '$apiVersion/devices/tv/verify';
  static String get unpairTvDeviceEndpoint => '$apiVersion/devices/tv/unpair';
  static String get updateDeviceEndpoint => '$apiVersion/users/update-device';

  // Parent Link
  static String get generateParentTokenEndpoint =>
      '$apiVersion/telegram/generate-token';
  static String get parentLinkStatusEndpoint => '$apiVersion/telegram/status';
  static String get unlinkParentEndpoint => '$apiVersion/telegram/unlink';

  // User Profile
  static String get myProfileEndpoint => '$apiVersion/users/profile/me';
  static String get updateProfileEndpoint => '$apiVersion/users/profile/me';

  // Progress
  static String get progressSaveEndpoint => '$apiVersion/progress/save';
  static String get progressOverallEndpoint => '$apiVersion/progress/overall';
  static String progressCourseEndpoint(int courseId) =>
      '$apiVersion/progress/course/$courseId';

  // Schools
  static String get schoolsEndpoint => '$apiVersion/schools';

  // Upload
  static String get uploadImageEndpoint => '$apiVersion/upload/image';

  // Chatbot - FIXED: All endpoints with /api/v1 prefix
  static String get chatbotUsageEndpoint => '$apiVersion/chatbot/usage';
  static String get chatbotConversationsEndpoint =>
      '$apiVersion/chatbot/conversations';
  static String chatbotConversationMessagesEndpoint(int conversationId) =>
      '$apiVersion/chatbot/conversations/$conversationId/messages';
  static String chatbotConversationEndpoint(int conversationId) =>
      '$apiVersion/chatbot/conversations/$conversationId';
  static String get chatbotChatEndpoint => '$apiVersion/chatbot/chat';

  // Settings - FIXED: Correct endpoints
  static String get settingsAllEndpoint => '$apiVersion/settings/all';
  static String settingsCategoryEndpoint(String category) =>
      '$apiVersion/settings/category/$category';
  static String get settingsPublicEndpoint => '$apiVersion/settings/public';
  static String get settingsCategoriesEndpoint =>
      '$apiVersion/settings/categories';

  // ===== Cache Key Helpers =====
  static String progressChapterKey(int chapterId) =>
      'progress_chapter_$chapterId';
  static String notesChapterKey(int chapterId) => 'notes_chapter_$chapterId';
  static String questionsChapterKey(int chapterId) =>
      'questions_chapter_$chapterId';
  static String videosByChapterKey(int chapterId) =>
      'videos_chapter_$chapterId';
  static String streakKey(String userId) => 'streak_$userId';
  static String settingsCategoryKey(String category) =>
      'settings_category_$category';
  static String examQuestionsKey(int examId) => 'exam_questions_$examId';
  static String examAccessKey(int examId) => 'exam_access_$examId';
  static String categoryAccessKey(int categoryId) =>
      'category_access_$categoryId';
  static String answerResultKey(int questionId) => 'answer_result_$questionId';
  static String selectedAnswerKey(int questionId) =>
      'selected_answer_$questionId';
  static String noteViewedKey(int noteId) => 'note_viewed_$noteId';

  // ===== Offline Queue Action Types =====
  static const String queueActionSaveProgress = 'save_progress';
  static const String queueActionSubmitExam = 'submit_exam';
  static const String queueActionSubmitPayment = 'submit_payment';
  static const String queueActionMarkNotificationRead =
      'mark_notification_read';
  static const String queueActionUpdateProfile = 'update_profile';
  static const String queueActionSaveAnswer = 'save_answer';
  static const String queueActionSendChatMessage = 'send_chat_message';
  static const String queueActionUpdateStreak = 'update_streak';
  static const String queueActionParentAction = 'parent_action';
  static const String queueActionIncrementViewCount = 'increment_view_count';
  static const String queueActionSaveExamProgress = 'save_exam_progress';
}

class AppStrings {
  // Auth - Fields
  static const String username = 'Username';
  static const String password = 'Password';
  static const String confirmPassword = 'Confirm Password';

  // Auth - Validation
  static const String usernameRequired = 'Username is required';
  static const String usernameMinLength =
      'Username must be at least 3 characters';
  static const String usernameInvalid =
      'Username can only contain letters, numbers, and underscores';
  static const String passwordRequired = 'Password is required';
  static const String passwordMinLength =
      'Password must be at least 8 characters';
  static const String confirmPasswordRequired = 'Please confirm your password';
  static const String passwordsDoNotMatch = 'Passwords do not match';

  // Welcome messages
  static const String welcomeBack = 'Welcome Back';
  static const String signInToContinue = 'Sign in to continue learning';
  static const String createAccount = 'Create Account';
  static const String joinFamilyAcademy = 'Join Family Academy';
  static const String dontHaveAccount = 'Don\'t have an account? ';
  static const String alreadyHaveAccount = 'Already have an account? ';
  static const String login = 'Login';
  static const String register = 'Register';

  // Placeholders
  static const String enterUsername = 'Enter your username';
  static const String enterPassword = 'Enter your password';
  static const String chooseUsername = 'Choose a username';
  static const String createPassword = 'Create a password';

  // Actions
  static const String saving = 'Saving...';
  static const String loading = 'Loading...';
  static const String retry = 'Retry';
  static const String cancel = 'Cancel';
  static const String confirm = 'Confirm';
  static const String delete = 'Delete';
  static const String edit = 'Edit';
  static const String save = 'Save';
  static const String done = 'Done';
  static const String refresh = 'Refresh';
  static const String makePayment = 'make payment';

  // Errors
  static const String error = 'Error';
  static const String somethingWentWrong = 'Something went wrong';
  static const String networkError =
      'Network error. Please check your connection.';
  static const String timeoutError = 'Request timed out. Please try again.';
  static const String refreshFailed = 'Refresh failed. Please try again.';
  static const String categoryNotFound = 'Category not found';
  static const String courseNotFound = 'Course not found';
  static const String chapterNotFound = 'Chapter not found';
  static const String notFound = 'Not found';

  // Success
  static const String success = 'Success';
  static const String changesSaved = 'Changes saved successfully';
  static const String categoryUpdated = 'Category updated';
  static const String courseUpdated = 'Course updated';
  static const String chapterUpdated = 'Chapter updated';

  // Empty states
  static const String noData = 'No data available';
  static const String noResults = 'No results found';
  static const String offlineMode = 'Offline';
  static const String cachedData = 'Showing cached data';
  static const String noCachedDataAvailable =
      'No cached data available. Please check your connection.';
  static const String categoryDoesNotExist =
      'The category you\'re looking for doesn\'t exist.';
  static const String noCachedCourses =
      'No cached courses available. Connect to load courses.';
  static const String coursesWillAppearHere =
      'Courses will appear here when available.';
  static const String categoriesWillAppearHere =
      'Categories will appear here when available.';
  static const String noCachedChapters =
      'No cached chapters available. Connect to load chapters.';
  static const String chaptersWillAppearHere =
      'Chapters will appear here when available.';
  static const String noCachedExams =
      'No cached exams available. Connect to load exams.';
  static const String examsWillAppearHere =
      'Exams will appear here when available.';

  // Video player
  static const String playVideo = 'Play Video';
  static const String pauseVideo = 'Pause';
  static const String download = 'Download';
  static const String downloaded = 'Downloaded';
  static const String downloading = 'Downloading...';
  static const String selectQuality = 'Select Quality';
  static const String clearDownloads = 'Clear Downloads';
  static const String downloadsCleared = 'All downloads cleared';

  // Chat
  static const String typeMessage = 'Type a message...';
  static const String send = 'Send';
  static const String messagesLeft = 'messages left today';
  static const String limitReached = 'Daily limit reached';
  static const String aiTutor = 'AI Tutor';
  static const String quickQuestions = 'Quick Questions:';
  static const String newChat = 'New Chat';
  static const String renameConversation = 'Rename Conversation';
  static const String deleteConversation = 'Delete Conversation';
  static const String enterNewTitle = 'Enter new title';
  static const String conversationRenamed = 'Conversation renamed';
  static const String conversationDeleted = 'Conversation deleted';

  // Progress
  static const String streak = 'Streak';
  static const String chapters = 'Chapters';
  static const String accuracy = 'Accuracy';
  static const String studyTime = 'Study Time';
  static const String achievements = 'Achievements';
  static const String progress = 'Progress';
  static const String learningMetrics = 'Learning Metrics';
  static const String examPerformance = 'Exam Performance';
  static const String checkAll = 'Check All';
  static const String resetAll = 'Reset All';

  // Profile
  static const String profile = 'Profile';
  static const String editProfile = 'Edit Profile';
  static const String logout = 'Logout';
  static const String logoutConfirm = 'Are you sure you want to logout?';
  static const String email = 'Email';
  static const String phone = 'Phone';
  static const String school = 'School';
  static const String notSet = 'Not set';
  static const String notSelected = 'Not selected';

  // Subscriptions
  static const String active = 'Active';
  static const String expired = 'Expired';
  static const String expiringSoon = 'Expiring Soon';
  static const String purchase = 'Purchase';
  static const String renew = 'Renew';
  static const String subscriptions = 'Subscriptions';

  // Payments
  static const String paymentPending = 'Payment Pending';
  static const String paymentVerified = 'Payment Verified';
  static const String paymentRejected = 'Payment Rejected';
  static const String uploadProof = 'Upload Proof';
  static const String youHavePendingPayment = 'You have a pending payment for';
  static const String pleaseWaitForVerification =
      'Please wait for admin verification (1-3 working days).';
  static const String reason = 'Reason';
  static const String yourPaymentWasRejected =
      'Your previous payment was rejected.';

  // Notifications
  static const String notifications = 'Notifications';
  static const String markAllRead = 'Mark all as read';
  static const String noNotifications = 'No notifications';

  // Device
  static const String deviceChange = 'Device Change';
  static const String newDevice = 'New Device Detected';
  static const String confirmDeviceChange = 'Confirm Device Change';

  // Categories
  static const String category = 'Category';
  static const String categories = 'Categories';
  static const String categoryDetails = 'Category details';
  static const String courses = 'Courses';

  // Course
  static const String course = 'Course';
  static const String courseContent = 'Course content';
  static const String chaptersAndExams = 'Chapters & Exams';
  static const String unlockContent = 'Unlock Content';
  static const String purchaseAccess = 'Purchase Access';

  // Chapter
  static const String chapter = 'Chapter';
  static const String chapterContent = 'Chapter content';
  static const String videos = 'Videos';
  static const String notes = 'Notes';
  static const String practice = 'Practice';
  static const String comingSoon = 'Coming Soon';
  static const String locked = 'Locked';
  static const String goBack = 'Go Back';

  // Access banners
  static const String fullAccess = 'Full Access';
  static const String freeCategory = 'Free Category';
  static const String limitedAccess = 'Limited Access';
  static const String freeChaptersOnly =
      'Free chapters only. Purchase to unlock all content.';
  static const String purchaseNow = 'Purchase';
  static const String payNow = 'Pay Now';

  // Time
  static const String justNow = 'Just now';
  static const String minutesAgo = 'm ago';
  static const String hoursAgo = 'h ago';
  static const String daysAgo = 'd ago';
  static const String monthsAgo = 'mo ago';
  static const String yearsAgo = 'y ago';

  // Queue
  static const String pendingSync = 'pending sync';
  static const String changesQueued = 'changes queued';
  static const String syncing = 'Syncing...';
  static const String syncComplete = 'Sync complete';
  static const String queued = 'Queued';

  // General
  static const String ok = 'OK';
  static const String yes = 'Yes';
  static const String no = 'No';
  static const String close = 'Close';
  static const String back = 'Back';
  static const String next = 'Next';
  static const String previous = 'Previous';
  static const String submit = 'Submit';
  static const String start = 'Start';
  static const String stop = 'Stop';

  // Chapter screen
  static const String authenticationRequired = 'Authentication required';
  static const String noVideosForChapter =
      'There are no videos for this chapter yet.';
  static const String noNotesForChapter =
      'There are no notes for this chapter yet.';
  static const String noCachedVideos =
      'No cached videos available. Connect to load videos.';
  static const String noCachedNotes =
      'No cached notes available. Connect to load notes.';
  static const String noCachedQuestions =
      'No cached questions available. Connect to load questions.';
  static const String practiceQuestionsComingSoon =
      'Practice questions will be added soon.';
  static const String chapterLocked = 'Chapter Locked';
  static const String chapterComingSoonMessage =
      'This chapter will be available soon. Stay tuned for updates!';
  static const String accessRequiresSubscription = 'Access to';
  static const String theCategory = 'the category';
  static const String failedToPlayDownloaded =
      'Failed to play downloaded video';
  static const String videoPlaybackFailed =
      'Video playback failed. Try downloading first.';
  static const String failedToPlayVideo =
      'Failed to play video. Please try downloading.';
  static const String videoAlreadyDownloaded = 'Video already downloaded';
  static const String downloadQuality = 'Download Quality';
  static const String estSize = 'Est. size';
  static const String best = 'Best';
  static const String quality = 'Quality';
  static const String quality360 = 'Good for mobile data, saves data';
  static const String quality480 = 'Balanced quality and data usage';
  static const String quality720 = 'HD quality, best on WiFi';
  static const String quality1080 = 'Full HD, requires fast connection';
  static const String pleaseLoginToDownload = 'Please login to download';
  static const String storageAlmostFull =
      'Storage almost full. Please clear some downloads first.';
  static const String downloadFailed = 'Download failed';
  static const String connectionTimeout =
      'Connection timeout - check your internet';
  static const String receiveTimeout = 'Receive timeout - server too slow';
  static const String downloadCancelled = 'Download cancelled';
  static const String videoNotFound = 'Video not found on server';
  static const String accessDenied = 'Access denied to video';
  static const String downloadFailedFileNotCreated =
      'Download failed - file not created';
  static const String downloadedFileTooSmall =
      'Downloaded file is too small - possibly an error page';
  static const String videoDownloaded = 'video downloaded';
  static const String noteNoDownloadableFile = 'Note has no downloadable file';
  static const String invalidFilePath = 'Invalid file path';
  static const String noteDownloaded = 'Note downloaded for offline viewing';
  static const String clearingDownloads = 'Clearing downloads...';
  static const String clearDownloadsConfirm =
      'Are you sure you want to remove all downloaded videos and notes?';
  static const String errorClearingDownloads = 'Error clearing downloads';
  static const String cannotOpenFile = 'Cannot open file';
  static const String errorOpeningFile = 'Error opening file';
  static const String pdfDocument = 'PDF Document';
  static const String textDocument = 'Text Document';

  // Practice questions
  static const String practiceQuestions = 'Practice Questions';
  static const String practiceProgress = 'Practice Progress';
  static const String reset = 'Reset';
  static const String showAllExplanations = 'Show All Explanations';
  static const String hideAllExplanations = 'Hide All Explanations';
  static const String checkingAnswers = 'Checking answers...';
  static const String checked = 'Checked';
  static const String questions = 'questions';
  static const String correct = 'correct';
  static const String allQuestionsChecked = 'All questions checked';
  static const String failedToCheckAnswer = 'Failed to check answer';
  static const String chapterDoesNotExist =
      'The chapter you\'re looking for doesn\'t exist.';

  // Exams
  static const String minutesPerAttempt = 'minutes per attempt';
  static const String minutesExamWide = 'minutes exam-wide';
  static const String autoSubmitWhenTimeExpires =
      'Auto-submit when time expires';
  static const String manualSubmissionRequired = 'Manual submission required';
  static const String resultsShownImmediately =
      'Results shown immediately after submission';
  static const String resultsAvailableAfterExam =
      'Results available after exam ends';
  static const String yourScore = 'Your Score';
  static const String total = 'Total';
  static const String time = 'Time';
  static const String answerReview = 'Answer Review';
  static const String yourAnswer = 'Your answer:';
  static const String correctAnswer = 'Correct answer:';
  static const String explanation = 'Explanation:';
  static const String noExplanation = 'No explanation provided';
  static const String notAnswered = 'Not answered';
  static const String marks = 'marks';
  static const String mark = 'mark';
  static const String timeUp = 'Time\'s Up!';
  static const String examTimeExpired =
      'The exam time has expired. Please submit your answers.';
  static const String submitExamOffline = 'Submit Exam Offline';
  static const String examWillBeSavedOffline =
      'You are offline. Your exam will be saved and submitted when you\'re back online.';
  static const String saveOffline = 'Save Offline';
  static const String submitExam = 'Submit Exam';
  static const String cannotChangeAnswersAfterSubmission =
      'Are you sure you want to submit the exam? You cannot change answers after submission.';
  static const String examSubmission = 'Exam submission';
  static const String failedToSaveExamOffline = 'Failed to save exam offline';
  static const String submittingExam = 'Submitting Exam...';
  static const String failedToStartExam = 'Failed to start exam session';
  static const String failedToSubmitExam =
      'Failed to submit exam. Please try again.';
  static const String instructions = 'Instructions';
  static const String pleaseReadCarefully =
      'Please read carefully before starting';
  static const String examDetails = 'Exam Details';
  static const String title = 'Title';
  static const String type = 'Type';
  static const String timeLimit = 'Time Limit';
  static const String autoSubmit = 'Auto Submit';
  static const String results = 'Results';
  static const String passingScore = 'Passing Score';
  static const String maxAttempts = 'Max Attempts';
  static const String yourAttempts = 'Your Attempts';
  static const String startOfflineMode = 'Start (Offline Mode)';
  static const String startExamNow = 'Start Exam Now';
  static const String question = 'Question';
  static const String of = 'of';
  static const String answered = 'answered';

  static const String leaveExam = 'Leave Exam?';
  static const String progressWillBeSaved =
      'Your progress will be saved. You can resume later.';
  static const String leave = 'Leave';
  static const String stay = 'Stay';
  static const String pleaseAnswerAllQuestions =
      'Please answer all questions before submitting';
  static const String maximumAttemptsReached = 'Maximum Attempts Reached';
  static const String youHaveUsedAll = 'You have used all';
  static const String attemptsForThisExam = 'attempt(s) for this exam.';

  static const String pleaseLoginToTakeExam = 'Please login to take this exam';
  static const String paymentRequired = 'Payment Required';
  static const String youNeedToPurchase = 'You need to purchase';
  static const String toAccessThisExam = 'to access this exam.';
  static const String noCachedQuestionsAvailable =
      'No cached questions available. Connect to load questions.';
  static const String couldNotLoadExamQuestions =
      'Could not load exam questions. Please try again.';
  static const String examResults = 'Exam Results';
  static const String passed = 'PASSED';
  static const String failed = 'FAILED';

  // Chat
  static const String goodMorning = 'Good Morning';
  static const String goodAfternoon = 'Good Afternoon';
  static const String goodEvening = 'Good Evening';
  static const String chatUpdated = 'Chat updated';
  static const String message = 'Message';
  static const String failedToQueueMessage = 'Failed to queue message';
  static const String failedToSendMessage = 'Failed to send message';
  static const String dailyLimitReached = 'Daily Limit Reached';
  static const String youHaveUsedAllDailyMessages =
      'You\'ve used all your daily messages (';
  static const String limitResetsAtMidnight = 'The limit resets at midnight.';
  static const String youCanStillReviewConversations =
      'You can still review previous conversations.';
  static const String startNewChat = 'Start New Chat';
  static const String clearCurrentConversation =
      'This will clear the current conversation and start fresh.';
  static const String startNew = 'Start New';
  static const String conversations = 'Conversations';

  static const String noConversations = 'No Conversations';
  static const String startNewChatToBegin =
      'Start a new chat to begin learning!';
  static const String rename = 'Rename';

  static const String areYouSureYouWantToDelete =
      'Are you sure you want to delete';

  static const String helpWithMath = 'Help with math';
  static const String tellMeAboutEthiopia = 'Tell me about Ethiopia';
  static const String studyTips = 'Study tips';
  static const String teachMeAmharic = 'Teach me Amharic';
  static const String offline = 'Offline';
  static const String offlineMessageQueued =
      'You are offline (messages queued)';
  static const String askAboutAnySubject = 'Ask about any subject...';
  static const String messagesQueued = 'message(s) queued';
  static const String aiLearningAssistant = 'AI Learning Assistant';
  static const String offlineMessagesWillBeQueued =
      'You are offline. Messages will be queued and sent when online.';
  static const String askAboutAnySubjectPrompt =
      'Ask me about mathematics, sciences, Amharic, Ethiopian history, or get study tips. You have';
  static const String messagesLeftToday = 'messages left today';
  static const String messages = 'messages';
  static const String chat = 'chat';

  // Profile
  static const String loadingProfile = 'Loading profile...';
  static const String manageAccount = 'Manage your account';

  static const String enterEmail = 'email@example.com';
  static const String enterPhone = '+1 (123) 456-7890';
  static const String invalidEmail = 'Please enter a valid email';
  static const String invalidPhone = 'Please enter a valid phone number';
  static const String queueChanges = 'Queue Changes';
  static const String profileUpdated = 'Profile updated';
  static const String profileUpdatedSuccess = 'Profile updated successfully';
  static const String profileUpdate = 'Profile update';
  static const String failedToQueueUpdate = 'Failed to queue update';
  static const String failedToLoadProfile = 'Failed to load profile';
  static const String tryAgainLater = 'Please try again later';
  static const String noCachedProfile =
      'No cached profile available. Please check your connection.';
  static const String uploadImage = 'upload image';
  static const String imageTooLarge = 'Image size too large. Max 10MB.';
  static const String failedToProcessImage = 'Failed to process image';
  static const String failedToPickImage = 'Failed to pick image';
  static const String profileImageUpdated = 'Profile image updated';
  static const String failedToUploadImage = 'Failed to upload image';
  static const String notificationsEnabled = 'Notifications enabled';
  static const String notificationsDisabled = 'Notifications disabled';
  static const String failedToUpdateNotifications =
      'Failed to update notification settings';
  static const String profileUpdateFailed = 'Failed to update profile';
  static const String darkMode = 'Dark Mode';
  static const String tvPairing = 'TV Pairing';
  static const String parentControls = 'Parent Controls';
  static const String feedback = 'Feedback';
  static const String helpSupport = 'Help & Support';
  static const String appInfo = 'App Info';
  static const String familyAcademy = 'Family Academy';
  static const String version = 'Version';
  static const String empoweringStudents =
      'Empowering students with quality education through modern technology.';

  static const String cannotOpenTelegram = 'Could not open Telegram';

  // Offline
  static const String offlineCachedData = 'Offline mode - showing cached data';
  static const String trackLearningJourney = 'Track your learning journey';
  static const String dayStreak = 'Day Streak';

  static const String progressOverview = 'Progress Overview';
  static const String chapterCompletion = 'Chapter Completion';
  static const String questionAccuracy = 'Question Accuracy';

  static const String hours = 'hours';

  static const String achievement = 'Achievement';
  static const String moreAchievements = 'more achievements';
  static const String exam = 'Exam';
  static const String avgScore = 'Avg Score';
  static const String moreExams = 'more exams';
  static const String overallCompletion = 'Overall Completion';
  static const String videosCompleted = 'Videos Completed';
  static const String notesViewed = 'Notes Viewed';
  static const String questionsAttempted = 'Questions Attempted';
  static const String examsPassedTaken = 'Exams (Passed/Taken)';
  static const String averageExamScore = 'Average Exam Score';
  static const String general = 'General';
  static const String noCachedExamResults = 'No cached exam results';
  static const String noExamsTaken = 'No exams taken yet';
  static const String connectToViewExamResults = 'Connect to view exam results';
  static const String takeFirstExam =
      'Take your first exam to see results here';
  static const String offlineProgressMessage =
      'You are offline. Connect to view your progress.';
  static const String progressUpdated = 'Progress updated';

  static const String notificationsUpdated = 'Notifications updated';
  static const String unread = 'Unread';
  static const String earlier = 'Earlier';
  static const String markAsRead = 'Mark as read';
  static const String markAllAsRead = 'Mark all as read';
  static const String markAllAsReadOffline =
      'You are offline. This will be queued and sync when online. Continue?';
  static const String markAllAsReadConfirm = 'Mark all notifications as read?';
  static const String markAll = 'Mark all';
  static const String queue = 'Queue';
  static const String queueAllRead = 'Queue all read';
  static const String allNotificationsMarkedRead =
      'All notifications marked as read';
  static const String deleteNotification = 'Delete notification';
  static const String deleteNotificationConfirm =
      'Are you sure you want to delete this notification?';
  static const String notificationDeleted = 'Notification deleted';
  static const String failedToDeleteNotification =
      'Failed to delete notification';
  static const String deleting = 'Deleting...';
  static const String failedToLoad = 'Failed to Load';
  static const String tryAgain = 'Try Again';
  static const String noCachedNotifications = 'No cached notifications.';
  static const String actionQueued = 'action(s) queued.';
  static const String noCachedNotificationsAvailable =
      'No cached notifications available.';
  static const String notificationsWillAppearHere =
      'You\'ll see notifications here when you receive them.';
  static const String notificationsLoadedButEmpty =
      'Notifications were loaded but none are available to display.';
  static const String cannotRefreshOffline = 'Cannot refresh while offline';
  static const String pending = 'PENDING';
  static const String new_ = 'NEW';

  // Payment
  static const String payment = 'Payment';
  static const String paymentDetails = 'Payment Details';
  static const String paymentMethod = 'Payment Method';
  static const String selectPaymentMethod = 'Select a payment method';
  static const String accountDetails = 'Account Details';
  static const String accountHolderName = 'Account Holder Name';
  static const String enterAccountHolderName = 'Enter the account holder name';
  static const String paymentProof = 'Payment Proof';
  static const String confirmAccuracy =
      'I confirm that all payment information is accurate and valid';
  static const String queuePayment = 'Queue Payment';
  static const String submitPayment = 'Submit Payment';
  static const String firstTimePayment = 'First Time Payment';
  static const String renewalPayment = 'Renewal Payment';
  static const String billingCycle = 'Billing Cycle';
  static const String accessDuration = 'Access Duration';
  static const String semesterBilling = 'Semester (4 months)';
  static const String monthlyBilling = 'Monthly (1 month)';
  static const String accessFourMonths = 'You will get access for 4 months';
  static const String accessOneMonth = 'You will get access for 1 month';
  static const String notAvailable = 'N/A';
  static const String unknown = 'Unknown';
  static const String etb = 'ETB';
  static const String uploadPaymentProof = 'Please upload payment proof';
  static const String failedToUploadProof = 'Failed to upload payment proof';
  static const String paymentSubmitted = 'Payment submitted successfully!';
  static const String paymentFailed = 'Payment failed';
  static const String categoryInfoMissing = 'Category information missing';
  static const String invalidPaymentAmount = 'Invalid payment amount';
  static const String selectPaymentMethodError =
      'Please select a payment method';
  static const String confirmAccuracyError = 'Please confirm accuracy';
  static const String accountHolderNameRequired =
      'Account holder name is required';
  static const String accountHolderNameMinLength =
      'Account holder name must be at least 3 characters';

  static const String imageTooLarge5MB = 'Image must be less than 5MB';
  static const String offlineWillQueue = 'Offline - will queue when online';
  static const String tapToUploadProof = 'Tap to upload payment proof';
  static const String connectToInternet = 'Connect to internet';
  static const String imageRequirements = 'JPG or PNG • Max 5MB';
  static const String remove = 'Remove';
  static const String uploaded = 'Uploaded';
  static const String copiedToClipboard = 'Copied to clipboard';
  static const String paymentMethods = 'payment methods';
  static const String paymentMethodsNotAvailable =
      'Payment methods are not available.\nPlease try again or contact support.';
  static const String loadingPaymentDetails = 'Loading payment details...';
  static const String noPaymentDataProvided = 'No payment data provided';
  static const String failedToInitialize = 'Failed to initialize';
  static const String paymentError = 'Payment Error';
  static const String importantNotes = 'Important Notes:';
  static const String noteAccountHolderMatch =
      'Make sure the account holder name matches the bank/mobile account';
  static const String noteProcessingTime =
      'Payments are processed within 24 hours';
  static const String noteKeepProof = 'Keep your payment proof screenshot';
  static const String noteContactSupport =
      'Contact support if payment is not verified';
  static const String noteNotification =
      'You will be notified when payment is verified';

  // Payment Success
  static const String paymentQueued = 'Payment Queued!';
  static const String renewalSubmitted = 'Renewal Submitted!';
  static const String yourPaymentFor = 'Your payment for';
  static const String hasBeenSavedOffline =
      'has been saved offline. It will be submitted when you\'re back online.';
  static const String hasBeenSubmitted = 'has been submitted successfully.';
  static const String yourPaymentHasBeenSubmitted =
      'Your payment has been submitted successfully.';
  static const String queuedForSync = 'Queued for Sync';
  static const String pendingVerification = 'Pending Verification';
  static const String amount = 'Amount';
  static const String method = 'Method';
  static const String accountHolder = 'Account Holder';
  static const String status = 'Status';
  static const String continueToHome = 'Continue to Home';

  static const String redirectingIn = 'Redirecting in';
  static const String seconds = 'seconds';
  static const String failedToLoadPaymentDetails =
      'Failed to load payment details';
  static const String noPaymentInformationFound =
      'No payment information found';
  static const String failedToLoadPaymentInformation =
      'Failed to load payment information';
  static const String fourMonths = '4 months';
  static const String oneMonth = '1 month';

  // Parent Link
  static const String parentLink = 'Parent Link';
  static const String refreshing = 'Refreshing...';
  static const String connectWithParents = 'Connect with parents';
  static const String parentConnected = 'Parent Connected';
  static const String disconnectParent = 'Disconnect Parent';
  static const String unlinkParent = 'Unlink Parent';
  static const String unlinkParentConfirm =
      'Are you sure you want to unlink the parent? This will stop all progress updates.';
  static const String parentUnlinked = 'Parent unlinked successfully';
  static const String failedToUnlink = 'Failed to unlink';
  static const String tokenActive = 'Token Active';
  static const String tokenExpiringSoon = 'Token Expiring Soon';
  static const String showToken = 'Show Token';
  static const String generateNewToken = 'Generate New Token';
  static const String generateToken = 'Generate Token';
  static const String connectParent = 'Connect Parent';
  static const String connectParentDescription =
      'Generate a token to link your parent\'s Telegram account and share your progress.';
  static const String linkToken = 'Link Token';
  static const String expiresIn = 'Expires in';
  static const String unlink = 'Unlink';

  static const String minute = 'minute';
  static const String minutes = 'minutes';
  static const String hour = 'hour';
  static const String copy = 'Copy';
  static const String tokenCopied = 'Token copied to clipboard';
  static const String whatParentsCanSee = 'What parents can see';
  static const String parentSeeProgress = 'Study progress and completion';
  static const String parentSeeExams = 'Exam scores and results';
  static const String parentSeeSubscriptions = 'Subscription status';
  static const String parentSeeWeeklySummary = 'Weekly progress summary';
  static const String parentTelegramBot = 'Parent Telegram Bot';
  static const String parentTelegramDescription =
      'Parents receive updates via Telegram. They cannot modify your account.';
  static const String studentId = 'Student ID';
  static const String failedToGenerateToken = 'Failed to generate token';
  static const String statusUpdated = 'Status updated';

  // Subscriptions
  static const String mySubscriptions = 'My Subscriptions';
  static const String manageSubscriptions = 'Manage your subscriptions';
  static const String offlineCachedSubscriptions =
      'Offline mode - showing cached subscriptions';
  static const String yourActiveExpiredSubscriptions =
      'Your active and expired subscriptions';

  static const String subscriptionsUpdated = 'Subscriptions updated';
  static const String noCachedSubscriptions =
      'No cached subscriptions available.';
  static const String noSubscriptionsYet =
      'You don\'t have any subscriptions yet.\nBrowse categories to get started.';
  static const String unknownCategory = 'Unknown Category';
  static const String monthlySubscription = 'Monthly Subscription';
  static const String semesterSubscription = 'Semester Subscription';
  static const String days = 'days';
  static const String used = 'used';
  static const String startDate = 'Start Date';
  static const String expiryDate = 'Expiry Date';
  static const String monthly = 'Monthly';
  static const String semester = 'Semester';
  static const String price = 'Price';
  static const String daysRemaining = 'Days Remaining';
  static const String renewNow = 'Renew Now';
  static const String extendNow = 'Extend Now';

  // Support
  static const String support = 'Support';
  static const String getHelp = 'Get help';
  static const String errorLoading = 'Error loading';
  static const String unableToLoadSupportInfo =
      'Unable to load support information.';
  static const String supportInfoRefreshed = 'Support information refreshed';
  static const String contact = 'Contact';
  static const String faq = 'FAQ';
  static const String actions = 'Actions';
  static const String contactInformation = 'Contact Information';
  static const String noContactInfo = 'No contact information available';
  static const String contactMethodsWillAppear =
      'Contact methods will appear here when configured by admin';
  static const String responseTime = 'Response Time';
  static const String quickResponse = 'Quick Response';
  static const String respondWithin24Hours =
      'We typically respond within 24 hours during business days';
  static const String hours24 = '24H';
  static const String frequentlyAskedQuestions = 'Frequently Asked Questions';
  static const String stillNeedHelp = 'Still Need Help?';
  static const String contactUsDirectly = 'Contact Us Directly';
  static const String ifQuestionNotAnswered =
      'If your question isn\'t answered here, please reach out to our support team using the contact information provided.';
  static const String quickActions = 'Quick Actions';
  static const String chatWithUs = 'Chat with Us';
  static const String startLiveChat = 'Start a live chat';
  static const String liveChatComingSoon = 'Live chat coming soon';
  static const String supportHours = 'Support Hours';
  static const String weAreHereToHelp = 'We\'re Here to Help';
  static const String getHelpWith =
      'Get help with your account, payments, subscriptions, or any other questions.';
  static const String cannotOpen = 'Cannot open';
  static const String copyToClipboard = 'Copy to Clipboard';
  static const String viewOnMap = 'View on map';
  static const String tapToCopy = 'Tap to copy';
  static const String tapToContact = 'Tap to contact';
  static const List<Map<String, String>> faqd = [
    {
      'question': 'How do I reset my password?',
      'answer':
          'Go to Profile → Settings → Change Password. You will need your current password to set a new one.',
    },
    {
      'question': 'What payment methods are accepted?',
      'answer':
          'We accept Teletbirr, Bank Transfer, and other local payment methods. Check the Payment section for available options.',
    },
    {
      'question': 'How long does payment verification take?',
      'answer':
          'Payment verification typically takes 1-3 working days. You will receive a notification once your payment is verified.',
    },
    {
      'question': 'Can I access content offline?',
      'answer':
          'Yes! Videos and notes can be downloaded for offline access. Your progress will sync when you\'re back online.',
    },
    {
      'question': 'How do I contact support?',
      'answer':
          'You can reach us through the Contact tab, email, or Telegram. We typically respond within 24 hours.',
    },
    {
      'question': 'What is the refund policy?',
      'answer':
          'Payments are non-refundable once verified. Please contact support if you have any issues.',
    },
  ];

  // School Selection
  static const String selectSchool = 'Select School';
  static const String searchSchools = 'Search schools...';
  static const String otherSchool = 'Other School';
  static const String mySchoolNotListed = 'My school is not listed';
  static const String offlineCachedSchools =
      'You are offline. Showing cached schools.';
  static const String continueWithOtherSchool = 'Continue with Other School';
  static const String continueToLearning = 'Continue to Learning';
  static const String sessionExpired = 'Session expired. Please login again.';
  static const String schoolSelected = 'School selected successfully';
  static const String failedToSelectSchool = 'Failed to select school';
  static const String proceedingWithoutSchool =
      'Proceeding without specific school selection';
  static const String failedToProceed = 'Failed to proceed';
  static const String added = 'Added';

  // Auth
  static const String loginFailed = 'Login failed';
  static const String registrationFailed = 'Registration failed';

  static const String openChapter = 'open chapter';
  static const String startExam = 'start exam';
  static const String toAccessAllContent = 'to access all content';
  static const String exams = 'Exams';
  static const String courseDoesNotExist =
      'The course you\'re looking for doesn\'t exist.';
}
