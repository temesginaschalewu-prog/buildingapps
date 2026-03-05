import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../services/user_session.dart';
import '../models/note_model.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class NoteProvider with ChangeNotifier {
  final ApiService apiService;
  final DeviceService deviceService;

  final List<Note> _notes = [];
  final Map<int, List<Note>> _notesByChapter = {};
  final Map<int, bool> _hasLoadedForChapter = {};
  final Map<int, bool> _isLoadingForChapter = {};
  final Map<int, DateTime> _lastLoadedTime = {};
  final Map<int, bool> _noteViewedStatus = {};
  bool _isLoading = false;
  String? _error;

  StreamController<Map<String, dynamic>> _noteUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();

  static const Duration cacheDuration = Duration(hours: 24);
  static const Duration viewedCacheDuration = Duration(days: 30);

  NoteProvider({required this.apiService, required this.deviceService}) {
    _preloadCommonChapters();
  }

  Future<void> _preloadCommonChapters() async {
    Future.delayed(Duration.zero, () async {
      try {
        final userId = await UserSession().getCurrentUserId();
        if (userId != null) {}
      } catch (e) {}
    });
  }

  List<Note> get notes => _notes;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Stream<Map<String, dynamic>> get noteUpdates => _noteUpdateController.stream;

  bool hasLoadedForChapter(int chapterId) =>
      _hasLoadedForChapter[chapterId] ?? false;
  bool isLoadingForChapter(int chapterId) =>
      _isLoadingForChapter[chapterId] ?? false;

  List<Note> getNotesByChapter(int chapterId) {
    return _notesByChapter[chapterId] ?? [];
  }

  Note? getNoteById(int id) {
    try {
      return _notes.firstWhere((n) => n.id == id);
    } catch (e) {
      return null;
    }
  }

  bool isNoteViewed(int noteId) {
    return _noteViewedStatus[noteId] ?? false;
  }

  int getViewedNotesCountForChapter(int chapterId) {
    final notes = _notesByChapter[chapterId] ?? [];
    return notes.where((note) => isNoteViewed(note.id)).length;
  }

  Future<void> loadNotesByChapter(int chapterId,
      {bool forceRefresh = false}) async {
    if (_isLoadingForChapter[chapterId] == true && !forceRefresh) {
      return;
    }

    final lastLoaded = _lastLoadedTime[chapterId];
    final hasCache = _hasLoadedForChapter[chapterId] == true;
    final isCacheValid = lastLoaded != null &&
        DateTime.now().difference(lastLoaded) < cacheDuration;

    if (hasCache && !forceRefresh && isCacheValid) {
      debugLog('NoteProvider', '✅ Using cached notes for chapter: $chapterId');
      return;
    }

    if (!forceRefresh) {
      try {
        final cachedNotes = await deviceService.getCacheItem<List<dynamic>>(
            AppConstants.notesChapterKey(chapterId));

        if (cachedNotes != null) {
          final noteList = <Note>[];
          for (final noteJson in cachedNotes) {
            try {
              noteList.add(Note.fromJson(noteJson));
            } catch (e) {
              debugLog('NoteProvider', 'Error parsing note from cache: $e');
            }
          }

          if (noteList.isNotEmpty) {
            _notesByChapter[chapterId] = noteList;
            _hasLoadedForChapter[chapterId] = true;
            _lastLoadedTime[chapterId] = DateTime.now();

            for (final note in noteList) {
              if (!_notes.any((n) => n.id == note.id)) {
                _notes.add(note);
              }
            }

            await _loadViewedStatus(chapterId);

            debugLog('NoteProvider',
                '✅ Loaded ${noteList.length} notes from cache for chapter $chapterId');

            _noteUpdateController.add({
              'type': 'notes_loaded_cached',
              'chapter_id': chapterId,
              'count': noteList.length
            });

            unawaited(_refreshInBackground(chapterId));
            return;
          }
        }
      } catch (e) {
        debugLog('NoteProvider', 'Error loading cache: $e');
      }
    }

    _isLoadingForChapter[chapterId] = true;
    _isLoading = true;
    _error = null;
    _notifySafely();

    try {
      debugLog('NoteProvider', '📥 Loading notes for chapter: $chapterId');
      final response = await apiService.getNotesByChapter(chapterId);

      final responseData = response.data ?? {};
      final notesData = responseData['notes'] ?? [];

      if (notesData is List) {
        final noteList = <Note>[];
        for (final noteJson in notesData) {
          try {
            noteList.add(Note.fromJson(noteJson));
          } catch (e) {
            debugLog('NoteProvider', 'Error parsing note: $e, data: $noteJson');
          }
        }

        _notesByChapter[chapterId] = noteList;
        _hasLoadedForChapter[chapterId] = true;
        _lastLoadedTime[chapterId] = DateTime.now();

        for (final note in noteList) {
          if (!_notes.any((n) => n.id == note.id)) {
            _notes.add(note);
          }
        }

        await deviceService.saveCacheItem(
          AppConstants.notesChapterKey(chapterId),
          noteList.map((n) => n.toJson()).toList(),
          ttl: cacheDuration,
        );

        await _loadViewedStatus(chapterId);

        debugLog('NoteProvider',
            '✅ Loaded ${noteList.length} notes for chapter $chapterId from API');

        _noteUpdateController.add({
          'type': 'notes_loaded',
          'chapter_id': chapterId,
          'count': noteList.length
        });
      } else {
        _notesByChapter[chapterId] = [];
        _hasLoadedForChapter[chapterId] = true;
        _lastLoadedTime[chapterId] = DateTime.now();

        _noteUpdateController
            .add({'type': 'notes_loaded', 'chapter_id': chapterId, 'count': 0});
      }
    } catch (e) {
      _error = e.toString();
      debugLog('NoteProvider', '❌ loadNotesByChapter error: $e');

      if (!_hasLoadedForChapter.containsKey(chapterId)) {
        _notesByChapter[chapterId] = [];
        _hasLoadedForChapter[chapterId] = true;
        _lastLoadedTime[chapterId] = DateTime.now();
      }

      _noteUpdateController.add({
        'type': 'notes_load_error',
        'chapter_id': chapterId,
        'error': _error
      });
    } finally {
      _isLoadingForChapter[chapterId] = false;
      _isLoading = false;
      _notifySafely();
    }
  }

  Future<void> _refreshInBackground(int chapterId) async {
    try {
      debugLog('NoteProvider', '🔄 Background refresh for chapter $chapterId');

      final response = await apiService.getNotesByChapter(chapterId);

      final responseData = response.data ?? {};
      final notesData = responseData['notes'] ?? [];

      if (notesData is List) {
        final noteList = <Note>[];
        for (final noteJson in notesData) {
          try {
            noteList.add(Note.fromJson(noteJson));
          } catch (e) {}
        }

        if (noteList.isNotEmpty) {
          _notesByChapter[chapterId] = noteList;
          _lastLoadedTime[chapterId] = DateTime.now();

          for (final note in noteList) {
            if (!_notes.any((n) => n.id == note.id)) {
              _notes.add(note);
            }
          }

          await deviceService.saveCacheItem(
            AppConstants.notesChapterKey(chapterId),
            noteList.map((n) => n.toJson()).toList(),
            ttl: cacheDuration,
          );

          await _loadViewedStatus(chapterId);

          _noteUpdateController.add({
            'type': 'notes_refreshed',
            'chapter_id': chapterId,
            'count': noteList.length
          });

          _notifySafely();

          debugLog('NoteProvider',
              '✅ Background refresh completed for chapter $chapterId');
        }
      }
    } catch (e) {
      debugLog('NoteProvider', '⚠️ Background refresh failed: $e');
    }
  }

  Future<void> _loadViewedStatus(int chapterId) async {
    final notes = _notesByChapter[chapterId] ?? [];
    for (final note in notes) {
      final viewed = await deviceService
          .getCacheItem<bool>(AppConstants.noteViewedKey(note.id));
      _noteViewedStatus[note.id] = viewed ?? false;
    }
  }

  Future<void> markNoteAsViewed(int noteId) async {
    _noteViewedStatus[noteId] = true;

    await deviceService.saveCacheItem(
      AppConstants.noteViewedKey(noteId),
      true,
      ttl: viewedCacheDuration,
    );

    _noteUpdateController.add({'type': 'note_viewed', 'note_id': noteId});
    _notifySafely();
  }

  Future<void> markNotesAsViewedForChapter(int chapterId) async {
    final notes = _notesByChapter[chapterId] ?? [];
    for (final note in notes) {
      await markNoteAsViewed(note.id);
    }
  }

  Future<void> clearNotesForChapter(int chapterId) async {
    _hasLoadedForChapter.remove(chapterId);
    _lastLoadedTime.remove(chapterId);

    final chapterNotes = _notesByChapter[chapterId] ?? [];
    _notes.removeWhere((note) => chapterNotes.any((n) => n.id == note.id));
    _notesByChapter.remove(chapterId);

    await deviceService
        .removeCacheItem(AppConstants.notesChapterKey(chapterId));

    for (final note in chapterNotes) {
      await deviceService.removeCacheItem(AppConstants.noteViewedKey(note.id));
      _noteViewedStatus.remove(note.id);
    }

    _noteUpdateController
        .add({'type': 'notes_cleared', 'chapter_id': chapterId});
    _notifySafely();
  }

  Future<void> clearUserData() async {
    debugLog('NoteProvider', 'Clearing note data');

    final session = UserSession();
    final isDifferentUser = !await session.isSameUser();
    final isLoggingOut = await _isLoggingOut();

    if (!isDifferentUser || !isLoggingOut) {
      debugLog('NoteProvider', '✅ Same user - preserving note cache');
      return;
    }

    _notes.clear();
    _notesByChapter.clear();
    _hasLoadedForChapter.clear();
    _lastLoadedTime.clear();
    _isLoadingForChapter.clear();
    _noteViewedStatus.clear();

    await deviceService.clearCacheByPrefix('notes_');
    await deviceService.clearCacheByPrefix('note_viewed_');

    await _noteUpdateController.close();
    _noteUpdateController = StreamController<Map<String, dynamic>>.broadcast();

    _noteUpdateController.add({'type': 'all_notes_cleared'});
    _notifySafely();
  }

  Future<bool> _isLoggingOut() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.isLoggingOutKey) ?? false;
  }

  void clearError() {
    _error = null;
    _notifySafely();
  }

  @override
  void dispose() {
    _noteUpdateController.close();
    super.dispose();
  }

  void _notifySafely() {
    if (hasListeners) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (hasListeners) {
          notifyListeners();
        }
      });
    }
  }
}
