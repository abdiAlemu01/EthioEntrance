// subject_model.dart

import 'dart:convert';

import 'package:collection/collection.dart';

class SubjectModel {
 
  final String name;
  final String grade;

  // Grade 9
  final List<String> grade9Courses;
  final List<String> grade9Videos;

  // Grade 10
  final List<String> grade10Courses;
  final List<String> grade10Videos;

  // Grade 11
  final List<String> grade11Courses;
  final List<String> grade11Videos;

  // Grade 12
  final List<String> grade12Courses;
  final List<String> grade12Videos;

  const SubjectModel({
    required this.name,
    required this.grade,
    this.grade9Courses = const [],
    this.grade9Videos = const [],
    this.grade10Courses = const [],
    this.grade10Videos = const [],
    this.grade11Courses = const [],
    this.grade11Videos = const [],
    this.grade12Courses = const [],
    this.grade12Videos = const [],
  });

  /// Helper: courses by grade (9–12).
  Map<int, List<String>> get coursesByGrade => <int, List<String>>{
        9: grade9Courses,
        10: grade10Courses,
        11: grade11Courses,
        12: grade12Courses,
      };

  /// Helper: videos by grade (9–12).
  Map<int, List<String>> get videosByGrade => <int, List<String>>{
        9: grade9Videos,
        10: grade10Videos,
        11: grade11Videos,
        12: grade12Videos,
      };

  List<String> getCoursesForGrade(int grade) {
    switch (grade) {
      case 9:
        return grade9Courses;
      case 10:
        return grade10Courses;
      case 11:
        return grade11Courses;
      case 12:
        return grade12Courses;
      default:
        return const <String>[];
    }
  }

  List<String> getVideosForGrade(int grade) {
    switch (grade) {
      case 9:
        return grade9Videos;
      case 10:
        return grade10Videos;
      case 11:
        return grade11Videos;
      case 12:
        return grade12Videos;
      default:
        return const <String>[];
    }
  }

  SubjectModel copyWith({
    String? uid,
    String? name,
    String? grade,
    List<String>? grade9Courses,
    List<String>? grade9Videos,
    List<String>? grade10Courses,
    List<String>? grade10Videos,
    List<String>? grade11Courses,
    List<String>? grade11Videos,
    List<String>? grade12Courses,
    List<String>? grade12Videos,
  }) {
    return SubjectModel(
      
      name: name ?? this.name,
      grade: grade ?? this.grade,
      grade9Courses: grade9Courses ?? this.grade9Courses,
      grade9Videos: grade9Videos ?? this.grade9Videos,
      grade10Courses: grade10Courses ?? this.grade10Courses,
      grade10Videos: grade10Videos ?? this.grade10Videos,
      grade11Courses: grade11Courses ?? this.grade11Courses,
      grade11Videos: grade11Videos ?? this.grade11Videos,
      grade12Courses: grade12Courses ?? this.grade12Courses,
      grade12Videos: grade12Videos ?? this.grade12Videos,
    );
  }

  /// Canonical Firestore shape.
  Map<String, dynamic> toFirestoreMap() {
    return <String, dynamic>{
      
      'name': name,
      'grade': grade,
      'grade9Courses': _dedupedCleanList(grade9Courses),
      'grade9Videos': _dedupedCleanList(grade9Videos),
      'grade10Courses': _dedupedCleanList(grade10Courses),
      'grade10Videos': _dedupedCleanList(grade10Videos),
      'grade11Courses': _dedupedCleanList(grade11Courses),
      'grade11Videos': _dedupedCleanList(grade11Videos),
      'grade12Courses': _dedupedCleanList(grade12Courses),
      'grade12Videos': _dedupedCleanList(grade12Videos),
    };
  }

  Map<String, dynamic> toMap() => toFirestoreMap();

  factory SubjectModel.fromMap(Map<String, dynamic> map) {
    return SubjectModel(
      name: (map['name'] ?? '').toString(),
      grade: (map['grade'] ?? '').toString(),
      grade9Courses: _dedupedCleanList(_readStringList(map['grade9Courses'])),
      grade9Videos: _dedupedCleanList(_readStringList(map['grade9Videos'])),
      grade10Courses: _dedupedCleanList(_readStringList(map['grade10Courses'])),
      grade10Videos: _dedupedCleanList(_readStringList(map['grade10Videos'])),
      grade11Courses: _dedupedCleanList(_readStringList(map['grade11Courses'])),
      grade11Videos: _dedupedCleanList(_readStringList(map['grade11Videos'])),
      grade12Courses: _dedupedCleanList(_readStringList(map['grade12Courses'])),
      grade12Videos: _dedupedCleanList(_readStringList(map['grade12Videos'])),
    );
  }

  String toJson() => json.encode(toFirestoreMap());

  factory SubjectModel.fromJson(String source) =>
      SubjectModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'SubjectModel(name: $name, grade: $grade, grade9Courses: $grade9Courses, grade9Videos: $grade9Videos, grade10Courses: $grade10Courses, grade10Videos: $grade10Videos, grade11Courses: $grade11Courses, grade11Videos: $grade11Videos, grade12Courses: $grade12Courses, grade12Videos: $grade12Videos)';
  }

  @override
  bool operator ==(covariant SubjectModel other) {
    if (identical(this, other)) return true;
    final listEquals = const DeepCollectionEquality().equals;

    return other.name == name &&
        other.grade == grade &&
        listEquals(other.grade9Courses, grade9Courses) &&
        listEquals(other.grade9Videos, grade9Videos) &&
        listEquals(other.grade10Courses, grade10Courses) &&
        listEquals(other.grade10Videos, grade10Videos) &&
        listEquals(other.grade11Courses, grade11Courses) &&
        listEquals(other.grade11Videos, grade11Videos) &&
        listEquals(other.grade12Courses, grade12Courses) &&
        listEquals(other.grade12Videos, grade12Videos);
  }

  @override
  int get hashCode {
    return name.hashCode ^
        grade.hashCode ^
        grade9Courses.hashCode ^
        grade9Videos.hashCode ^
        grade10Courses.hashCode ^
        grade10Videos.hashCode ^
        grade11Courses.hashCode ^
        grade11Videos.hashCode ^
        grade12Courses.hashCode ^
        grade12Videos.hashCode;
  }
}

List<String> _readStringList(dynamic raw) {
  if (raw is! List) return const <String>[];
  return raw
      .where((item) => item != null)
      .map((item) => item.toString())
      .toList();
}

List<String> _dedupedCleanList(List<String> input) {
  final out = <String>[];
  final seen = <String>{};
  for (final item in input) {
    final trimmed = item.trim();
    if (trimmed.isEmpty) continue;
    if (seen.add(trimmed)) out.add(trimmed);
  }
  return List<String>.unmodifiable(out);
}