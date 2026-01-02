import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../models/note_model.dart';
import '../utils/helpers.dart';

class NoteProvider with ChangeNotifier {
  final ApiService apiService;

  List<Note> _notes = [];
  Map<int, List<Note>> _notesByChapter = {};
  bool _isLoading = false;
  String? _error;

  NoteProvider({required this.apiService});

  List<Note> get notes => _notes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<Note> getNotesByChapter(int chapterId) {
    return _notesByChapter[chapterId] ?? [];
  }

  Future<void> loadNotesByChapter(int chapterId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugLog('NoteProvider', 'Loading notes for chapter: $chapterId');
      final response = await apiService.getNotesByChapter(chapterId);

      final responseData = response.data ?? {};
      final notesData = responseData['notes'] ?? responseData['data'] ?? [];

      if (notesData is List) {
        _notesByChapter[chapterId] =
            List<Note>.from(notesData.map((x) => Note.fromJson(x)));
      } else {
        _notesByChapter[chapterId] = [];
      }

      _notes = [..._notes, ..._notesByChapter[chapterId]!];

      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugLog('NoteProvider', 'loadNotesByChapter error: $e');
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Note? getNoteById(int id) {
    return _notes.firstWhere((n) => n.id == id);
  }

  void clearNotes() {
    _notes = [];
    _notesByChapter = {};
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
