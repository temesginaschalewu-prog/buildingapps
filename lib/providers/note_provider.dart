import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/note_model.dart';
import '../utils/helpers.dart';

class NoteProvider with ChangeNotifier {
  final ApiService apiService;

  List<Note> _notes = [];
  Map<int, List<Note>> _notesByChapter = {};
  Map<int, bool> _hasLoadedForChapter = {};
  Map<int, bool> _isLoadingForChapter = {};
  Map<int, DateTime> _lastLoadedTime = {};
  bool _isLoading = false;
  String? _error;

  // Cache duration: 15 minutes (notes don't change often)
  static const Duration cacheDuration = Duration(minutes: 15);

  NoteProvider({required this.apiService});

  List<Note> get notes => _notes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool hasLoadedForChapter(int chapterId) =>
      _hasLoadedForChapter[chapterId] ?? false;
  bool isLoadingForChapter(int chapterId) =>
      _isLoadingForChapter[chapterId] ?? false;

  List<Note> getNotesByChapter(int chapterId) {
    return _notesByChapter[chapterId] ?? [];
  }

  Future<void> loadNotesByChapter(int chapterId,
      {bool forceRefresh = false}) async {
    // Check if already loading for this chapter
    if (_isLoadingForChapter[chapterId] == true) {
      return;
    }

    // Check cache
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

        // Update cache
        _notesByChapter[chapterId] = noteList;
        _hasLoadedForChapter[chapterId] = true;
        _lastLoadedTime[chapterId] = DateTime.now();

        // Add to global list, avoiding duplicates
        for (final note in noteList) {
          if (!_notes.any((n) => n.id == note.id)) {
            _notes.add(note);
          }
        }

        debugLog('NoteProvider',
            '✅ Loaded ${noteList.length} notes for chapter $chapterId');
      } else {
        _notesByChapter[chapterId] = [];
        _hasLoadedForChapter[chapterId] = true;
        _lastLoadedTime[chapterId] = DateTime.now();
      }
    } catch (e) {
      _error = e.toString();
      debugLog('NoteProvider', '❌ loadNotesByChapter error: $e');

      // If we have cache, keep it even if refresh fails
      if (!_hasLoadedForChapter[chapterId]!) {
        _notesByChapter[chapterId] = [];
      }
    } finally {
      _isLoadingForChapter[chapterId] = false;
      _isLoading = false;
      notifyListeners();
    }
  }

  Note? getNoteById(int id) {
    try {
      return _notes.firstWhere((n) => n.id == id);
    } catch (e) {
      return null;
    }
  }

  // Clear cache for specific chapter
  void clearNotesForChapter(int chapterId) {
    _hasLoadedForChapter.remove(chapterId);
    _lastLoadedTime.remove(chapterId);

    // Remove notes for this chapter from global list
    final chapterNotes = _notesByChapter[chapterId] ?? [];
    _notes.removeWhere((note) => chapterNotes.any((n) => n.id == note.id));
    _notesByChapter.remove(chapterId);

    notifyListeners();
  }

  // Clear all cache
  void clearAllNotes() {
    _notes.clear();
    _notesByChapter.clear();
    _hasLoadedForChapter.clear();
    _lastLoadedTime.clear();
    _isLoadingForChapter.clear();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
