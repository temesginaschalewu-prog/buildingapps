import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/device_service.dart';
import '../models/note_model.dart';
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

  static const Duration cacheDuration = Duration(minutes: 15);
  static const Duration viewedCacheDuration = Duration(days: 30);

  NoteProvider({required this.apiService, required this.deviceService});

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

  Future<void> loadNotesByChapter(int chapterId,
      {bool forceRefresh = false}) async {
    if (_isLoadingForChapter[chapterId] == true) {
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

    _isLoadingForChapter[chapterId] = true;
    _error = null;
    notifyListeners();

    try {
      debugLog('NoteProvider', '📝 Loading notes for chapter: $chapterId');
      final response = await apiService.getNotesByChapter(chapterId);

      final responseData = response.data ?? {};
      final notesData = responseData['notes'] ?? [];

      if (notesData is List) {
        final noteList = <Note>[];
        for (var noteJson in notesData) {
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
          'notes_chapter_$chapterId',
          noteList.map((n) => n.toJson()).toList(),
          ttl: cacheDuration,
        );

        await _loadViewedStatus(chapterId);

        debugLog('NoteProvider',
            '✅ Loaded ${noteList.length} notes for chapter $chapterId');

        _noteUpdateController.add({
          'type': 'notes_loaded',
          'chapter_id': chapterId,
          'count': noteList.length
        });
      } else {
        _notesByChapter[chapterId] = [];
        _hasLoadedForChapter[chapterId] = true;
        _lastLoadedTime[chapterId] = DateTime.now();
      }
    } catch (e) {
      _error = e.toString();
      debugLog('NoteProvider', '❌ loadNotesByChapter error: $e');

      try {
        final cachedNotes = await deviceService
            .getCacheItem<List<dynamic>>('notes_chapter_$chapterId');
        if (cachedNotes != null) {
          final noteList = <Note>[];
          for (var noteJson in cachedNotes) {
            try {
              noteList.add(Note.fromJson(noteJson));
            } catch (e) {}
          }
          _notesByChapter[chapterId] = noteList;
          _hasLoadedForChapter[chapterId] = true;
          _lastLoadedTime[chapterId] = DateTime.now();

          await _loadViewedStatus(chapterId);
        }
      } catch (cacheError) {
        debugLog('NoteProvider', 'Cache load error: $cacheError');
      }

      if (!_hasLoadedForChapter[chapterId]!) {
        _notesByChapter[chapterId] = [];
      }
    } finally {
      _isLoadingForChapter[chapterId] = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadViewedStatus(int chapterId) async {
    final notes = _notesByChapter[chapterId] ?? [];
    for (final note in notes) {
      final viewed =
          await deviceService.getCacheItem<bool>('note_viewed_${note.id}');
      _noteViewedStatus[note.id] = viewed ?? false;
    }
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

  Future<void> markNoteAsViewed(int noteId) async {
    _noteViewedStatus[noteId] = true;

    await deviceService.saveCacheItem(
      'note_viewed_$noteId',
      true,
      ttl: viewedCacheDuration,
    );

    _noteUpdateController.add({'type': 'note_viewed', 'note_id': noteId});

    notifyListeners();
  }

  Future<void> markNotesAsViewedForChapter(int chapterId) async {
    final notes = _notesByChapter[chapterId] ?? [];
    for (final note in notes) {
      await markNoteAsViewed(note.id);
    }
  }

  int getViewedNotesCountForChapter(int chapterId) {
    final notes = _notesByChapter[chapterId] ?? [];
    return notes.where((note) => isNoteViewed(note.id)).length;
  }

  Future<void> clearNotesForChapter(int chapterId) async {
    _hasLoadedForChapter.remove(chapterId);
    _lastLoadedTime.remove(chapterId);

    final chapterNotes = _notesByChapter[chapterId] ?? [];
    _notes.removeWhere((note) => chapterNotes.any((n) => n.id == note.id));
    _notesByChapter.remove(chapterId);

    await deviceService.removeCacheItem('notes_chapter_$chapterId');

    for (final note in chapterNotes) {
      await deviceService.removeCacheItem('note_viewed_${note.id}');
      _noteViewedStatus.remove(note.id);
    }

    _noteUpdateController
        .add({'type': 'notes_cleared', 'chapter_id': chapterId});

    notifyListeners();
  }

  Future<void> clearUserData() async {
    debugLog('NoteProvider', 'Clearing note data');

    _notes.clear();
    _notesByChapter.clear();
    _hasLoadedForChapter.clear();
    _lastLoadedTime.clear();
    _isLoadingForChapter.clear();
    _noteViewedStatus.clear();

    await deviceService.clearCacheByPrefix('notes_');
    await deviceService.clearCacheByPrefix('note_viewed_');

    _noteUpdateController.close();
    _noteUpdateController = StreamController<Map<String, dynamic>>.broadcast();

    _noteUpdateController.add({'type': 'all_notes_cleared'});

    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _noteUpdateController.close();
    super.dispose();
  }
}
