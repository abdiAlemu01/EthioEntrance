
// subject_service.dart - Offline-first architecture

import '../../../core/database/objectbox/objectbox_service.dart';
import '../../../core/database/objectbox/models.dart';
import '../models/subject_model.dart';

/// Subject service using offline-first architecture
/// 
/// This service now uses ObjectBox for local data storage instead of Supabase.
/// All data is stored locally on the device for offline access.
/// 
/// Architecture Decision:
/// - Uses ObjectBox for local database
/// - Completely offline - no external API calls for data
/// - Fast local queries
/// - Follows repository pattern principles
class SubjectService {
  final ObjectBoxService _objectBoxService;

  SubjectService(this._objectBoxService);

  /// -------------------------------
  /// 1. Get all subjects
  /// -------------------------------
  List<Subject> getSubjects() {
    try {
      return _objectBoxService.getAllSubjects();
    } catch (e) {
      throw Exception('Failed to fetch subjects: $e');
    }
  }

  /// -------------------------------
  /// 2. Get subject by code
  /// -------------------------------
  Subject? getSubjectByCode(String subjectCode) {
    try {
      return _objectBoxService.getSubjectByCode(subjectCode);
    } catch (e) {
      throw Exception('Failed to fetch subject: $e');
    }
  }

  /// -------------------------------
  /// 3. Get textbooks by subject and grade
  /// -------------------------------
  List<Textbook> getTextbooksBySubjectAndGrade({
    required String subjectCode,
    required int grade,
  }) {
    try {
      return _objectBoxService.getTextbooksBySubjectAndGrade(subjectCode, grade);
    } catch (e) {
      throw Exception('Failed to fetch textbooks: $e');
    }
  }

  /// -------------------------------
  /// 4. Get all textbooks for a user
  /// -------------------------------
  List<Textbook> getAllTextbooks() {
    try {
      return _objectBoxService.getAllTextbooks();
    } catch (e) {
      throw Exception('Failed to fetch textbooks: $e');
    }
  }

  /// -------------------------------
  /// 5. Get resources by subject and grade (textbooks only)
  /// -------------------------------
  Map<String, List<Textbook>> getResourcesByGrade({
    required String subjectCode,
    required int grade,
  }) {
    try {
      final textbooks = getTextbooksBySubjectAndGrade(
        subjectCode: subjectCode,
        grade: grade,
      );

      return {
        'textbooks': textbooks,
      };
    } catch (e) {
      throw Exception('Failed to fetch resources: $e');
    }
  }

  /// -------------------------------
  /// 6. Get textbook file path
  /// -------------------------------
  String getTextbookPath(Textbook textbook) {
    return textbook.filePath;
  }

  /// -------------------------------
  /// 7. Convert to legacy SubjectModel format (for backward compatibility)
  /// -------------------------------
  SubjectModel? getLegacySubjectModel(String subjectCode) {
    try {
      final subject = getSubjectByCode(subjectCode);
      if (subject == null) return null;

      // Fetch textbooks for all grades
      final Map<int, List<String>> coursesByGrade = {};

      for (int grade = 9; grade <= 12; grade++) {
        final textbooks = getTextbooksBySubjectAndGrade(
          subjectCode: subjectCode,
          grade: grade,
        );

        coursesByGrade[grade] = textbooks
            .map((t) => getTextbookPath(t))
            .toList();
      }

      return SubjectModel(
        name: subject.name,
        grade: subject.subjectCode,
        grade9Courses: coursesByGrade[9] ?? [],
        grade9Videos: [], // Videos not implemented in offline version
        grade10Courses: coursesByGrade[10] ?? [],
        grade10Videos: [],
        grade11Courses: coursesByGrade[11] ?? [],
        grade11Videos: [],
        grade12Courses: coursesByGrade[12] ?? [],
        grade12Videos: [],
      );
    } catch (e) {
      throw Exception('Failed to fetch legacy subject model: $e');
    }
  }

  /// -------------------------------
  /// 8. Initialize default subjects
  /// -------------------------------
  void initializeDefaultSubjects() {
    _objectBoxService.initializeDefaultSubjects();
  }
}

