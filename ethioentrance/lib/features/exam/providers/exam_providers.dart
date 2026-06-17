



// ======================= exam_provider.dart =======================
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ethioentrance/features/exam/models/exam_models.dart';
import 'package:ethioentrance/features/exam/services/exam_services.dart';

final examServiceProvider = Provider((ref) => ExamServices());

final examProvider =
    StateNotifierProvider<ExamNotifier, List<ExamModel>>((ref) {
  final service = ref.watch(examServiceProvider);
  return ExamNotifier(service);
});

class ExamNotifier extends StateNotifier<List<ExamModel>> {
  final ExamServices service;
  String? error;

  ExamNotifier(this.service) : super([]) {
    fetchExams(); 
  }

  Future<void> addExam(String title, String examContent) async {
    error = null;
    final newExam = ExamModel(title: title, exam: examContent);

    try {
      await service.addExam(newExam);
      await fetchExams(); // refresh list after adding
    } catch (e) {
      error = e.toString();
      print(' Error adding exam: $error');
    }
  }

  Future<void> fetchExams() async {
    try {
      final exams = await service.getExams();
      state = exams;
    } catch (e) {
      error = e.toString();
      print(' Error fetching exams: $error');
    }
  }
}