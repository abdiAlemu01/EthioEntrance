// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:convert';

// exam_models.dart

class ExamModel {
  final String title;
  final String exam;
 

  ExamModel({
    required this.title,
    required this.exam,
  });

  ExamModel copyWith({
    String? title,
    String? exam,
  }) {
    return ExamModel(
      title: title ?? this.title,
      exam: exam ?? this.exam,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'title': title,
      'exam': exam,
    };
  }

  factory ExamModel.fromMap(Map<String, dynamic> map) {
    return ExamModel(
      title: map['title'] as String,
      exam: map['exam'] as String,
    );
  }

  String toJson() => json.encode(toMap());

  factory ExamModel.fromJson(String source) => ExamModel.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() => 'ExamModel(title: $title, exam: $exam)';

  @override
  bool operator ==(covariant ExamModel other) {
    if (identical(this, other)) return true;
  
    return 
      other.title == title &&
      other.exam == exam;
  }

  @override
  int get hashCode => title.hashCode ^ exam.hashCode;
}
 