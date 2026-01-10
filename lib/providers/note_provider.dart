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
      } else {
        _notesByChapter[chapterId] = [];
      }

      _notes = [..._notes, ..._notesByChapter[chapterId]!];

      debugLog('NoteProvider',
          'Loaded ${_notesByChapter[chapterId]!.length} notes for chapter $chapterId');
    } catch (e) {
      _error = e.toString();
      debugLog('NoteProvider', 'loadNotesByChapter error: $e');
      _notesByChapter[chapterId] = [];
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
