// lib/services/hive_service.dart
// PRODUCTION-READY FINAL VERSION

import 'dart:io';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import '../models/exam_question_model.dart';
import '../models/adapters/hive_adapters.dart';
import '../utils/helpers.dart';

class HiveService {
  static final HiveService _instance = HiveService._internal();
  factory HiveService() => _instance;
  HiveService._internal();

  bool _isInitialized = false;
  final Map<String, bool> _openBoxes = {};
  String? _hivePath;
  final Map<String, Box> _boxCache = {};

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Get application documents directory
      Directory appDir;
      try {
        appDir = await getApplicationDocumentsDirectory();
      } catch (e) {
        // Fallback for Linux when getApplicationDocumentsDirectory fails
        if (Platform.isLinux) {
          final homeDir = Platform.environment['HOME'] ??
              Platform.environment['USERPROFILE'] ??
              '.';
          appDir = Directory('$homeDir/.local/share/familyacademyclient');
          if (!await appDir.exists()) {
            await appDir.create(recursive: true);
          }
        } else {
          rethrow;
        }
      }

      _hivePath = appDir.path;

      // Initialize Hive with the path
      Hive.init(_hivePath);
      debugLog('HiveService', '✅ Hive initialized at: $_hivePath');

      // Register all adapters
      _registerAdapters();

      _isInitialized = true;
      debugLog('HiveService', '✅ Hive service ready');
    } catch (e) {
      debugLog('HiveService', '❌ Error initializing Hive: $e');
      // Fallback to memory-only mode
      _isInitialized = true;
    }
  }

  void _registerAdapters() {
    Hive.registerAdapter(UserAdapter());
    Hive.registerAdapter(CategoryAdapter());
    Hive.registerAdapter(CourseAdapter());
    Hive.registerAdapter(ChapterAdapter());
    Hive.registerAdapter(VideoAdapter());
    Hive.registerAdapter(NoteAdapter());
    Hive.registerAdapter(QuestionAdapter());
    Hive.registerAdapter(ExamAdapter());
    Hive.registerAdapter(ExamResultAdapter());
    Hive.registerAdapter(ExamQuestionAdapter());
    Hive.registerAdapter(SubscriptionAdapter());
    Hive.registerAdapter(PaymentAdapter());
    Hive.registerAdapter(NotificationAdapter());
    Hive.registerAdapter(UserProgressAdapter());
    Hive.registerAdapter(ChatbotMessageAdapter());
    Hive.registerAdapter(ChatbotConversationAdapter());
    Hive.registerAdapter(StreakAdapter());
    Hive.registerAdapter(SchoolAdapter());
    Hive.registerAdapter(SettingAdapter());
    Hive.registerAdapter(ParentLinkAdapter());

    debugLog('HiveService', '✅ Registered all adapters');
  }

  Future<Box<T>> openBox<T>(String boxName) async {
    if (!_isInitialized) {
      await init();
    }

    // Check cache first
    if (_boxCache.containsKey(boxName)) {
      return _boxCache[boxName] as Box<T>;
    }

    try {
      // Check if box is already open
      if (Hive.isBoxOpen(boxName)) {
        final box = Hive.box<T>(boxName);
        _boxCache[boxName] = box;
        _openBoxes[boxName] = true;
        debugLog('HiveService', '✅ Using already open box: $boxName');
        return box;
      }

      // Open the box
      final box = await Hive.openBox<T>(boxName);
      _boxCache[boxName] = box;
      _openBoxes[boxName] = true;
      debugLog('HiveService', '✅ Opened box: $boxName');
      return box;
    } catch (e) {
      debugLog('HiveService', '❌ Error opening box $boxName: $e');
      // If it's already open but our check failed, try to get it
      if (Hive.isBoxOpen(boxName)) {
        debugLog('HiveService',
            '🔄 Box was open despite error, retrieving: $boxName');
        return Hive.box<T>(boxName);
      }
      rethrow;
    }
  }

  bool isBoxOpen(String boxName) {
    return _boxCache.containsKey(boxName) || Hive.isBoxOpen(boxName);
  }

  Future<void> closeBox(String boxName) async {
    try {
      if (_boxCache.containsKey(boxName)) {
        final box = _boxCache[boxName];
        if (box != null && box.isOpen) {
          await box.close();
        }
        _boxCache.remove(boxName);
      }

      if (Hive.isBoxOpen(boxName)) {
        await Hive.box(boxName).close();
      }

      _openBoxes.remove(boxName);
      debugLog('HiveService', '✅ Closed box: $boxName');
    } catch (e) {
      debugLog('HiveService', '❌ Error closing box $boxName: $e');
    }
  }

  Future<void> clearUserData(String userId) async {
    try {
      final userScopedBoxes = <String>[
        'user_box',
        'categories_box',
        'courses_box',
        'chapters_box',
        'videos_box',
        'notes_box',
        'questions_box',
        'exams_box',
        'subscriptions_box',
        'payments_box',
        'notifications_box',
        'progress_box',
        'chatbot_messages_box',
        'chatbot_conversations_box',
        'chatbot_usage_box',
        'streak_box',
      ];

      for (final boxName in userScopedBoxes) {
        try {
          final box = await openBox<dynamic>(boxName);
          final keysToDelete = box.keys
              .where((key) => key.toString().contains('user_${userId}_'))
              .toList();
          for (final key in keysToDelete) {
            await box.delete(key);
          }
        } catch (e) {
          debugLog('HiveService', '⚠️ Error clearing $boxName: $e');
        }
      }

      debugLog('HiveService', '🧹 Cleared user data for $userId');
    } catch (e) {
      debugLog('HiveService', '❌ Error clearing user data: $e');
    }
  }

  Future<void> clearCache() async {
    try {
      for (final boxName in _boxCache.keys.toList()) {
        await closeBox(boxName);
      }
      _boxCache.clear();
      _openBoxes.clear();

      // Clear all boxes from Hive
      await Hive.close();

      debugLog('HiveService', '✅ All boxes closed and cache cleared');
    } catch (e) {
      debugLog('HiveService', '❌ Error clearing cache: $e');
    }
  }

  Future<Map<String, dynamic>> getStats() async {
    final stats = <String, dynamic>{
      'isInitialized': _isInitialized,
      'path': _hivePath,
      'openBoxes': _openBoxes.length,
      'cachedBoxes': _boxCache.length,
    };

    try {
      final boxes = _boxCache.entries.map((e) {
        final box = e.value;
        return {
          'name': e.key,
          'isOpen': box.isOpen,
          'length': box.length,
          'keys': box.keys.length,
        };
      }).toList();
      stats['boxes'] = boxes;
    } catch (e) {
      stats['error'] = e.toString();
    }

    return stats;
  }

  Future<void> compactAll() async {
    try {
      for (final box in _boxCache.values) {
        if (box.isOpen) {
          await box.compact();
        }
      }
      debugLog('HiveService', '✅ Compacted all boxes');
    } catch (e) {
      debugLog('HiveService', '❌ Error compacting boxes: $e');
    }
  }

  String? get hivePath => _hivePath;
  bool get isInitialized => _isInitialized;

  Future<void> close() async {
    try {
      await Hive.close();
      _boxCache.clear();
      _openBoxes.clear();
      debugLog('HiveService', '✅ All boxes closed');
    } catch (e) {
      debugLog('HiveService', '❌ Error closing Hive: $e');
    }
  }
}
