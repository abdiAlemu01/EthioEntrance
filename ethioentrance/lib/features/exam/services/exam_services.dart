// ===================== exam_services.dart =======================
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:ethioentrance/features/exam/models/exam_models.dart';

class ExamServices {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> addExam(ExamModel examModel) async {
    try {
      await _supabase.from('exams').insert({
        ...examModel.toMap(),
      });
      print('✅ Exam saved successfully: ${examModel.title}');
    } catch (e) {
      print('❌ Error saving exam: $e');
      rethrow;
    }
  }

  Future<List<ExamModel>> getExams() async {
    try {
      final List<dynamic> response = await _supabase
          .from('exams')
          .select()
          .order('created_at', ascending: false);

      return response.map((item) => ExamModel.fromMap(item)).toList();
    } catch (e) {
      print('❌ Error fetching exams: $e');
      return [];
    }
  }

  /// Performs semantic search using pgvector via the match_exams RPC
  Future<List<Map<String, dynamic>>> searchSimilarExams(
      List<double> queryEmbedding) async {
    try {
      final List<dynamic> response = await _supabase.rpc(
        'match_exams',
        params: {
          'query_embedding': queryEmbedding,
          'match_threshold': 0.5,
          'match_count': 5,
        },
      );
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('❌ Vector search error: $e');
      return [];
    }
  }
}