
// subject_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/subject_model.dart';
import '../services/subject_service.dart';
import '../../../core/database/objectbox/objectbox_service.dart';

/// Provide SubjectService (Now uses ObjectBoxService for offline-first)
final subjectServiceProvider = Provider<SubjectService>((ref) {
  return SubjectService(ObjectBoxService.instance);
});

/// ChangeNotifier Provider
final subjectProvider =
    ChangeNotifierProvider<SubjectProvider>((ref) {
  final service = ref.watch(subjectServiceProvider);
  return SubjectProvider(service);
});

class SubjectProvider extends ChangeNotifier {
  final SubjectService _service;

  SubjectProvider(this._service);

  SubjectModel? _subject;
  bool _isLoading = false;
  String? _error;

  /// Getters
  SubjectModel? get subject => _subject;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// -------------------------------
  /// 1. Upload PDF & Video
  /// -------------------------------
  Future<void> uploadPdfAndVideo({
    required String subjectId,
    required String subjectName,
    required int grade,
    required Uint8List pdfFile,
    required Uint8List videoFile,
  }) async {
    _setLoading(true);
    _setError(null);

    try {
      await _service.uploadPdfAndVideo(
        subjectId: subjectId,
        subjectName: subjectName,
        grade: grade,
        pdfFile: pdfFile,
        videoFile: videoFile,
      );

      /// Refresh data after upload
      await fetchSubject(subjectId);
    } catch (e) {
      _setError(e.toString());
    }

    _setLoading(false);
  }

  /// -------------------------------
  /// 2. Fetch Subject
  /// -------------------------------
  Future<void> fetchSubject(String subjectId) async {
    _setLoading(true);
    _setError(null);

    try {
      final data = await _service.getPdfAndVideo(subjectId);
      _subject = data;
    } catch (e) {
      _setError(e.toString());
    }

    _setLoading(false);
  }

  /// -------------------------------
  /// 3. Get by Grade (UI Helper)
  /// -------------------------------
  Future<Map<String, List<String>>> getByGrade({
    required String subjectId,
    required int grade,
  }) async {
    try {
      return await _service.getByGrade(
        subjectId: subjectId,
        grade: grade,
      );
    } catch (e) {
      _setError(e.toString());
      return {
        'courses': [],
        'videos': [],
      };
    }
  }

  /// -------------------------------
  /// 4. Local Helpers (No Firebase call)
  /// -------------------------------
  List<String> getCourses(int grade) {
    if (_subject == null) return [];
    return _subject!.getCoursesForGrade(grade);
  }

  List<String> getVideos(int grade) {
    if (_subject == null) return [];
    return _subject!.getVideosForGrade(grade);
  }

  /// -------------------------------
  /// State helpers
  /// -------------------------------
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }
}