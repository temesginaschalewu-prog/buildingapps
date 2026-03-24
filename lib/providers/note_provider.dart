// lib/providers/note_provider.dart
// PRODUCTION-READY FINAL VERSION - WITH ALL FIXES

import 'dart:async';
import 'package:familyacademyclient/services/offline_queue_manager.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../services/connectivity_service.dart';
import '../services/hive_service.dart';
import '../models/note_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'base_provider.dart';

/// PRODUCTION-READY Note Provider with Full Offline Support
class NoteProvider extends ChangeNotifier
    with
        BaseProvider<NoteProvider>,
        OfflineAwareProvider<NoteProvider>,
        BackgroundRefreshMixin<NoteProvider> {
  @override
  final ConnectivityService connectivityService;

  final ApiService apiService;
  final DeviceService deviceService;
  final HiveService hiveService;

  final Map<int, List<Note>> _notesByChapter = {};
  final Map<int, bool> _hasLoadedForChapter = {};
  final Map<int, bool> _isLoadingForChapter = {};
  final Map<int, DateTime> _lastLoadedTime = {};
  final Map<int, bool> _noteViewedStatus = {};

  static const Duration cacheDuration = AppConstants.cacheTTLNotes;
  static const Duration viewedCacheDuration = Duration(days: 30);
  @override
  Duration get refreshInterval => const Duration(minutes: 5);

  Box? _notesBox;
  Box? _viewedBox;

  int _apiCallCount = 0;

  // ✅ FIXED: Proper stream declaration
  late StreamController<Map<String, dynamic>> _noteUpdateController;

  // ✅ FIXED: Rate limiting
  final Map<int, DateTime?> _lastBackgroundRefreshForChapter = {};
  static const Duration _minBackgroundInterval = Duration(minutes: 2);

  NoteProvider({
    required this.apiService,
    required this.deviceService,
    required this.connectivityService,
    required this.hiveService,
  }) : _noteUpdateController =
            StreamController<Map<String, dynamic>>.broadcast() {
    log('NoteProvider constructor called');
    initializeOfflineAware(
      connectivity: connectivityService,
      queue: OfflineQueueManager(),
    );
    _init();
  }

  Future<void> _init() async {
    log('_init() START');
    await _openHiveBoxes();
    await _loadCachedDataForAll();

    if (_hasLoadedForChapter.isNotEmpty) {
      startBackgroundRefresh();
    }

    log('_init() END');
  }

  Future<void> _openHiveBoxes() async {
    try {
      if (!Hive.isBoxOpen(AppConstants.hiveNotesBox)) {
        _notesBox = await Hive.openBox(AppConstants.hiveNotesBox);
      } else {
        _notesBox = Hive.box(AppConstants.hiveNotesBox);
      }

      if (!Hive.isBoxOpen('viewed_notes_box')) {
        _viewedBox = await Hive.openBox('viewed_notes_box');
      } else {
        _viewedBox = Hive.box('viewed_notes_box');
      }

      log('✅ Hive boxes opened');
    } catch (e) {
      log('⚠️ Error opening Hive boxes: $e');
    }
  }

  Future<void> _loadCachedDataForAll() async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId == null || _notesBox == null) return;

      final cachedData = _notesBox!.get('user_${userId}_all_notes');
      if (cachedData != null && cachedData is Map) {
        final Map<int, List<Note>> convertedMap = {};

        cachedData.forEach((key, value) {
          final int chapterId = int.tryParse(key.toString()) ?? 0;
          if (chapterId > 0 && value is List) {
            final List<Note> notes = [];
            for (final item in value) {
              if (item is Note) {
                notes.add(item);
              } else if (item is Map<String, dynamic>) {
                notes.add(Note.fromJson(item));
              }
            }
            if (notes.isNotEmpty) {
              convertedMap[chapterId] = notes;
            }
          }
        });

        _notesByChapter.addAll(convertedMap);
        for (final chapterId in _notesByChapter.keys) {
          _hasLoadedForChapter[chapterId] = true;
          _lastLoadedTime[chapterId] = DateTime.now();
        }

        await _loadAllViewedStatus();

        _noteUpdateController.add({
          'type': 'all_notes_loaded',
          'chapters': _notesByChapter.length,
        });

        log('✅ Loaded ${_notesByChapter.length} chapters from Hive');
      }
    } catch (e) {
      log('Error loading cached data: $e');
    }
  }

  Future<void> _loadAllViewedStatus() async {
    try {
      if (_viewedBox == null) return;

      final viewedMap = _viewedBox!.get('viewed_status');
      if (viewedMap != null && viewedMap is Map) {
        viewedMap.forEach((key, value) {
          final noteId = int.tryParse(key.toString());
          if (noteId != null) {
            _noteViewedStatus[noteId] = value == true;
          }
        });
        log('✅ Loaded ${_noteViewedStatus.length} viewed statuses');
      }
    } catch (e) {
      log('Error loading viewed status: $e');
    }
  }

  Future<void> _saveToHive() async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId != null && _notesBox != null) {
        await _notesBox!.put('user_${userId}_all_notes', _notesByChapter);
        log('💾 Saved notes to Hive');
      }
    } catch (e) {
      log('Error saving to Hive: $e');
    }
  }

  Future<void> _saveChapterToHive(int chapterId, List<Note> notes) async {
    try {
      final userId = await UserSession().getCurrentUserId();
      if (userId != null && _notesBox != null) {
        final chapterMap = {chapterId.toString(): notes};
        await _notesBox!
            .put('user_${userId}_chapter_${chapterId}_notes', chapterMap);
        await _saveToHive();
      }
    } catch (e) {
      log('Error saving chapter to Hive: $e');
    }
  }

  Future<void> _saveViewedStatusToHive() async {
    try {
      if (_viewedBox == null) return;

      final viewedMap = <String, bool>{};
      _noteViewedStatus.forEach((key, value) {
        viewedMap[key.toString()] = value;
      });

      await _viewedBox!.put('viewed_status', viewedMap);
      log('💾 Saved viewed status to Hive');
    } catch (e) {
      log('Error saving viewed status to Hive: $e');
    }
  }

  // ===== GETTERS =====
  Stream<Map<String, dynamic>> get noteUpdates => _noteUpdateController.stream;

  bool hasLoadedForChapter(int chapterId) =>
      _hasLoadedForChapter[chapterId] ?? false;

  bool isLoadingForChapter(int chapterId) =>
      _isLoadingForChapter[chapterId] ?? false;

  List<Note> getNotesByChapter(int chapterId) {
    return _notesByChapter[chapterId] ?? [];
  }

  Note? getNoteById(int id) {
    for (final notes in _notesByChapter.values) {
      try {
        return notes.firstWhere((n) => n.id == id);
      } catch (e) {
        continue;
      }
    }
    return null;
  }

  bool isNoteViewed(int noteId) {
    return _noteViewedStatus[noteId] ?? false;
  }

  int getViewedNotesCountForChapter(int chapterId) {
    final notes = _notesByChapter[chapterId] ?? [];
    return notes.where((note) => isNoteViewed(note.id)).length;
  }

  // ===== LOAD NOTES BY CHAPTER =====
  Future<void> loadNotesByChapter(
    int chapterId, {
    bool forceRefresh = false,
    bool isManualRefresh = false,
  }) async {
    _apiCallCount++;
    final callId = _apiCallCount;

    log('loadNotesByChapter() CALL #$callId for chapter $chapterId');

    if (isManualRefresh && isOffline) {
      throw Exception(getUserFriendlyErrorMessage(
          'Network error. Please check your internet connection.'));
    }

    if (_isLoadingForChapter[chapterId] == true && !forceRefresh) {
      log('⏳ Already loading chapter $chapterId, skipping');
      return;
    }

    _isLoadingForChapter[chapterId] = true;
    setLoading();
    safeNotify();

    try {
      // STEP 1: Try Hive first
      if (!forceRefresh) {
        log('STEP 1: Checking Hive cache for chapter $chapterId');
        final userId = await UserSession().getCurrentUserId();
        if (userId != null && _notesBox != null) {
          final cachedData =
              _notesBox!.get('user_${userId}_chapter_${chapterId}_notes');

          if (cachedData != null &&
              cachedData is Map &&
              cachedData[chapterId.toString()] != null) {
            final dynamic noteData = cachedData[chapterId.toString()];
            if (noteData is List) {
              final List<Note> notes = [];
              for (final item in noteData) {
                if (item is Note) {
                  notes.add(item);
                } else if (item is Map<String, dynamic>) {
                  notes.add(Note.fromJson(item));
                }
              }
              if (notes.isNotEmpty) {
                _notesByChapter[chapterId] = notes;
                _hasLoadedForChapter[chapterId] = true;
                setLoaded();
                _isLoadingForChapter[chapterId] = false;
                _lastLoadedTime[chapterId] = DateTime.now();

                await _loadViewedStatusForChapter(chapterId, notes);

                _noteUpdateController.add({
                  'type': 'notes_loaded_cached',
                  'chapter_id': chapterId,
                  'count': notes.length,
                });

                log('✅ Loaded ${notes.length} notes from Hive for chapter $chapterId');

                if (!isOffline && !isManualRefresh) {
                  unawaited(_refreshInBackground(chapterId));
                }
                return;
              }
            }
          }
        }
      }

      // STEP 2: Try DeviceService
      if (!forceRefresh) {
        log('STEP 2: Checking DeviceService cache for chapter $chapterId');
        final cachedNotes = await deviceService.getCacheItem<List<dynamic>>(
          AppConstants.notesChapterKey(chapterId),
          isUserSpecific: true,
        );

        if (cachedNotes != null && cachedNotes.isNotEmpty) {
          final List<Note> notes = [];
          for (final json in cachedNotes) {
            if (json is Map<String, dynamic>) {
              notes.add(Note.fromJson(json));
            }
          }

          if (notes.isNotEmpty) {
            _notesByChapter[chapterId] = notes;
            _hasLoadedForChapter[chapterId] = true;
            setLoaded();
            _isLoadingForChapter[chapterId] = false;
            _lastLoadedTime[chapterId] = DateTime.now();

            await _loadViewedStatusForChapter(chapterId, notes);

            await _saveChapterToHive(chapterId, notes);

            _noteUpdateController.add({
              'type': 'notes_loaded_cached',
              'chapter_id': chapterId,
              'count': notes.length,
            });

            log('✅ Loaded ${notes.length} notes from DeviceService for chapter $chapterId');

            if (!isOffline && !isManualRefresh) {
              unawaited(_refreshInBackground(chapterId));
            }
            return;
          }
        }
      }

      // STEP 3: Check offline status
      if (isOffline) {
        log('STEP 3: Offline mode for chapter $chapterId');
        if (_notesByChapter.containsKey(chapterId)) {
          _hasLoadedForChapter[chapterId] = true;
          setLoaded();
          _isLoadingForChapter[chapterId] = false;
          _noteUpdateController.add({
            'type': 'notes_loaded',
            'chapter_id': chapterId,
            'count': _notesByChapter[chapterId]!.length,
          });
          log('✅ Showing cached notes offline for chapter $chapterId');
          return;
        }

        if (isManualRefresh) {
          throw Exception(getUserFriendlyErrorMessage(
              'Network error. Please check your internet connection.'));
        }

        _notesByChapter[chapterId] = [];
        _hasLoadedForChapter[chapterId] = true;
        setLoaded();
        _isLoadingForChapter[chapterId] = false;
        _noteUpdateController.add({
          'type': 'notes_loaded',
          'chapter_id': chapterId,
          'count': 0,
        });
        return;
      }

      // STEP 4: Fetch from API
      log('STEP 4: Fetching from API for chapter $chapterId');
      final response = await apiService.getNotesByChapter(chapterId);

      if (response.success && response.data != null) {
        final notes = response.data!;
        log('✅ Received ${notes.length} notes from API');

        _notesByChapter[chapterId] = notes;
        _hasLoadedForChapter[chapterId] = true;
        setLoaded();
        _isLoadingForChapter[chapterId] = false;
        _lastLoadedTime[chapterId] = DateTime.now();

        await _saveChapterToHive(chapterId, notes);

        deviceService.saveCacheItem(
          AppConstants.notesChapterKey(chapterId),
          notes.map((n) => n.toJson()).toList(),
          ttl: cacheDuration,
          isUserSpecific: true,
        );

        await _loadViewedStatusForChapter(chapterId, notes);

        _noteUpdateController.add({
          'type': 'notes_loaded',
          'chapter_id': chapterId,
          'count': notes.length,
        });

        log('✅ Success! Notes loaded for chapter $chapterId');
      } else {
        setError(getUserFriendlyErrorMessage(response.message));
        log('❌ API error: ${response.message}');

        _notesByChapter[chapterId] = _notesByChapter[chapterId] ?? [];
        _hasLoadedForChapter[chapterId] = true;
        setLoaded();
        _isLoadingForChapter[chapterId] = false;
        _noteUpdateController.add({
          'type': 'notes_loaded',
          'chapter_id': chapterId,
          'count': _notesByChapter[chapterId]!.length,
        });

        if (isManualRefresh) {
          throw Exception(response.message);
        }
      }
    } catch (e) {
      log('❌ Error loading notes: $e');

      setError(getUserFriendlyErrorMessage(e));
      setLoaded();
      _isLoadingForChapter[chapterId] = false;

      if (!_hasLoadedForChapter.containsKey(chapterId)) {
        await _recoverFromCache(chapterId);
      }

      _notesByChapter[chapterId] = _notesByChapter[chapterId] ?? [];
      _hasLoadedForChapter[chapterId] = true;
      _noteUpdateController.add({
        'type': 'notes_loaded',
        'chapter_id': chapterId,
        'count': _notesByChapter[chapterId]!.length,
      });

      if (isManualRefresh) {
        rethrow;
      }
    } finally {
      safeNotify();
    }
  }

  // ✅ FIXED: Rate limited background refresh
  Future<void> _refreshInBackground(int chapterId) async {
    if (isOffline) return;

    // Rate limiting
    if (_lastBackgroundRefreshForChapter[chapterId] != null &&
        DateTime.now()
                .difference(_lastBackgroundRefreshForChapter[chapterId]!) <
            _minBackgroundInterval) {
      log('⏱️ Background refresh rate limited for chapter $chapterId');
      return;
    }
    _lastBackgroundRefreshForChapter[chapterId] = DateTime.now();

    try {
      final response = await apiService.getNotesByChapter(chapterId);
      if (response.success && response.data != null) {
        final notes = response.data!;

        _notesByChapter[chapterId] = notes;
        _lastLoadedTime[chapterId] = DateTime.now();

        await _saveChapterToHive(chapterId, notes);

        deviceService.saveCacheItem(
          AppConstants.notesChapterKey(chapterId),
          notes.map((n) => n.toJson()).toList(),
          ttl: cacheDuration,
          isUserSpecific: true,
        );

        await _loadViewedStatusForChapter(chapterId, notes);

        _noteUpdateController.add({
          'type': 'notes_refreshed',
          'chapter_id': chapterId,
          'count': notes.length,
        });

        log('🔄 Background refresh for chapter $chapterId complete');
      }
    } catch (e) {
      log('Background refresh failed: $e');
    }
  }

  Future<void> _loadViewedStatusForChapter(
      int chapterId, List<Note> notes) async {
    for (final note in notes) {
      final viewed = await _getNoteViewedStatus(note.id);
      _noteViewedStatus[note.id] = viewed;
    }
  }

  Future<bool> _getNoteViewedStatus(int noteId) async {
    if (_noteViewedStatus.containsKey(noteId)) {
      return _noteViewedStatus[noteId]!;
    }

    try {
      if (_viewedBox != null) {
        final viewedMap = _viewedBox!.get('viewed_status') ?? {};
        final viewed = viewedMap[noteId.toString()] == true;
        if (viewed) {
          _noteViewedStatus[noteId] = viewed;
          return viewed;
        }
      }
    } catch (e) {
      log('Error getting viewed status from Hive: $e');
    }

    try {
      final viewed = await deviceService
          .getCacheItem<bool>(AppConstants.noteViewedKey(noteId));
      if (viewed != null) {
        _noteViewedStatus[noteId] = viewed;
        return viewed;
      }
    } catch (e) {
      log('Error getting viewed status from DeviceService: $e');
    }

    return false;
  }

  Future<void> _recoverFromCache(int chapterId) async {
    log('Attempting cache recovery for chapter $chapterId');
    final userId = await UserSession().getCurrentUserId();
    if (userId == null) return;

    // Try Hive first
    if (_notesBox != null) {
      try {
        final cachedData =
            _notesBox!.get('user_${userId}_chapter_${chapterId}_notes');
        if (cachedData != null &&
            cachedData is Map &&
            cachedData[chapterId.toString()] != null) {
          final dynamic noteData = cachedData[chapterId.toString()];
          if (noteData is List) {
            final List<Note> notes = [];
            for (final item in noteData) {
              if (item is Note) {
                notes.add(item);
              } else if (item is Map<String, dynamic>) {
                notes.add(Note.fromJson(item));
              }
            }
            if (notes.isNotEmpty) {
              _notesByChapter[chapterId] = notes;
              _hasLoadedForChapter[chapterId] = true;
              _lastLoadedTime[chapterId] = DateTime.now();
              _noteUpdateController.add({
                'type': 'notes_loaded_cached',
                'chapter_id': chapterId,
                'count': notes.length,
              });
              log('✅ Recovered ${notes.length} notes from Hive after error');
              return;
            }
          }
        }
      } catch (e) {
        log('Error recovering from Hive: $e');
      }
    }

    // Try DeviceService
    try {
      final cachedNotes = await deviceService.getCacheItem<List<dynamic>>(
        AppConstants.notesChapterKey(chapterId),
        isUserSpecific: true,
      );
      if (cachedNotes != null && cachedNotes.isNotEmpty) {
        final List<Note> notes = [];
        for (final json in cachedNotes) {
          if (json is Map<String, dynamic>) {
            notes.add(Note.fromJson(json));
          }
        }

        if (notes.isNotEmpty) {
          _notesByChapter[chapterId] = notes;
          _hasLoadedForChapter[chapterId] = true;
          _lastLoadedTime[chapterId] = DateTime.now();
          _noteUpdateController.add({
            'type': 'notes_loaded_cached',
            'chapter_id': chapterId,
            'count': notes.length,
          });
          log('✅ Recovered ${notes.length} notes from DeviceService after error');
        }
      }
    } catch (e) {
      log('Error recovering from DeviceService: $e');
    }
  }

  // ===== VIEWED STATUS METHODS =====
  Future<void> markNoteAsViewed(int noteId) async {
    log('markNoteAsViewed() for note $noteId');

    _noteViewedStatus[noteId] = true;

    await _saveViewedStatusToHive();

    deviceService.saveCacheItem(
      AppConstants.noteViewedKey(noteId),
      true,
      ttl: viewedCacheDuration,
      isUserSpecific: true,
    );

    _noteUpdateController.add({'type': 'note_viewed', 'note_id': noteId});
    safeNotify();
    log('✅ Note $noteId marked as viewed');
  }

  Future<void> markNotesAsViewedForChapter(int chapterId) async {
    log('markNotesAsViewedForChapter() for chapter $chapterId');
    final notes = _notesByChapter[chapterId] ?? [];
    for (final note in notes) {
      await markNoteAsViewed(note.id);
    }
  }

  // ===== CLEAR METHODS =====
  Future<void> clearNotesForChapter(int chapterId) async {
    log('clearNotesForChapter() for chapter $chapterId');

    _hasLoadedForChapter.remove(chapterId);
    _lastLoadedTime.remove(chapterId);

    final chapterNotes = _notesByChapter[chapterId] ?? [];
    _notesByChapter.remove(chapterId);

    final userId = await UserSession().getCurrentUserId();
    if (userId != null && _notesBox != null) {
      await _notesBox!.delete('user_${userId}_chapter_${chapterId}_notes');
    }

    await deviceService.removeCacheItem(
      AppConstants.notesChapterKey(chapterId),
      isUserSpecific: true,
    );

    for (final note in chapterNotes) {
      await deviceService.removeCacheItem(
        AppConstants.noteViewedKey(note.id),
        isUserSpecific: true,
      );
      _noteViewedStatus.remove(note.id);
    }

    await _saveViewedStatusToHive();

    _noteUpdateController
        .add({'type': 'notes_cleared', 'chapter_id': chapterId});
    safeNotify();
  }

  @override
  Future<void> onBackgroundRefresh() async {
    log('Background refresh triggered');
    if (isOffline) return;

    for (final chapterId in _hasLoadedForChapter.keys) {
      if (_hasLoadedForChapter[chapterId] == true &&
          !(_isLoadingForChapter[chapterId] ?? false)) {
        unawaited(_refreshInBackground(chapterId));
      }
    }
  }

  @override
  Future<void> onOnlineRefresh() async {
    log('Online - refreshing notes');
    for (final chapterId in _hasLoadedForChapter.keys) {
      if (_hasLoadedForChapter[chapterId] == true) {
        await loadNotesByChapter(chapterId, forceRefresh: true);
      }
    }
  }

  // ✅ FIXED: Clear user data with proper stream recreation
  Future<void> clearUserData() async {
    final session = UserSession();
    if (!session.shouldClearCacheOnLogout()) return;

    final userId = await session.getCurrentUserId();
    if (userId != null) {
      if (_notesBox != null) {
        final keysToDelete = _notesBox!.keys
            .where((key) => key.toString().contains('user_${userId}_'))
            .toList();
        for (final key in keysToDelete) {
          await _notesBox!.delete(key);
        }
      }

      if (_viewedBox != null) {
        await _viewedBox!.clear();
      }
    }

    await deviceService.clearCacheByPrefix('notes_');
    await deviceService.clearCacheByPrefix('note_viewed_');

    _notesByChapter.clear();
    _hasLoadedForChapter.clear();
    _lastLoadedTime.clear();
    _isLoadingForChapter.clear();
    _noteViewedStatus.clear();
    _lastBackgroundRefreshForChapter.clear();
    stopBackgroundRefresh();

    // FIX: Properly recreate stream controller
    await _noteUpdateController.close();
    _noteUpdateController = StreamController<Map<String, dynamic>>.broadcast();
    _noteUpdateController.add({'type': 'all_notes_cleared'});

    safeNotify();
  }

  @override
  void dispose() {
    stopBackgroundRefresh();
    _noteUpdateController.close();
    _notesBox?.close();
    _viewedBox?.close();
    disposeSubscriptions();
    super.dispose();
  }
}
