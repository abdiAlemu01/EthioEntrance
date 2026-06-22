import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class TextbookService {
  final SupabaseClient _supabase = Supabase.instance.client;
  static const String _bucketName = 'textbooks';

  /// Upload a textbook PDF to Supabase Storage
  Future<String> uploadTextbook({
    required String subjectId,
    required String title,
    required int grade,
    required File file,
  }) async {
    try {
      // Generate unique file path
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
      final filePath = 'subjects/$subjectId/grade_$grade/$fileName';

      // Upload file to Supabase Storage
      await _supabase.storage.from(_bucketName).upload(
        filePath,
        file,
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: false,
        ),
      );

      // Get public URL
      final fileUrl = _supabase.storage.from(_bucketName).getPublicUrl(filePath);

      // Get file size
      final fileSize = await file.length();

      // Insert metadata into database
      final response = await _supabase.from('textbooks').insert({
        'subject_id': subjectId,
        'title': title,
        'grade': grade,
        'file_path': filePath,
        'file_url': fileUrl,
        'file_size': fileSize,
        'uploaded_by': _supabase.auth.currentSession?.user.id,
        'processed': false,
      }).select();

      return response.first['id'].toString();
    } catch (e) {
      throw Exception('Failed to upload textbook: $e');
    }
  }

  /// Upload textbook from bytes
  Future<String> uploadTextbookFromBytes({
    required String subjectId,
    required String title,
    required int grade,
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      // Generate unique file path
      final uniqueFileName = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
      final filePath = 'subjects/$subjectId/grade_$grade/$uniqueFileName';

      // Upload file to Supabase Storage
      await _supabase.storage.from(_bucketName).upload(
        filePath,
        bytes,
        fileOptions: const FileOptions(
          cacheControl: '3600',
          upsert: false,
        ),
      );

      // Get public URL
      final fileUrl = _supabase.storage.from(_bucketName).getPublicUrl(filePath);

      // Insert metadata into database
      final response = await _supabase.from('textbooks').insert({
        'subject_id': subjectId,
        'title': title,
        'grade': grade,
        'file_path': filePath,
        'file_url': fileUrl,
        'file_size': bytes.length,
        'uploaded_by': _supabase.auth.currentSession?.user.id,
        'processed': false,
      }).select();

      return response.first['id'].toString();
    } catch (e) {
      throw Exception('Failed to upload textbook: $e');
    }
  }

  /// Get textbooks by subject and grade
  Future<List<Map<String, dynamic>>> getTextbooks({
    required String subjectId,
    required int grade,
  }) async {
    try {
      final response = await _supabase
          .from('textbooks')
          .select('*')
          .eq('subject_id', subjectId)
          .eq('grade', grade)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch textbooks: $e');
    }
  }

  /// Get textbook by ID
  Future<Map<String, dynamic>?> getTextbookById(String textbookId) async {
    try {
      final response = await _supabase
          .from('textbooks')
          .select('*')
          .eq('id', textbookId)
          .maybeSingle();

      return response;
    } catch (e) {
      throw Exception('Failed to fetch textbook: $e');
    }
  }

  /// Delete a textbook
  Future<void> deleteTextbook(String textbookId) async {
    try {
      // Get textbook info
      final textbook = await getTextbookById(textbookId);
      if (textbook == null) return;

      // Delete from Storage
      await _supabase.storage.from(_bucketName).remove([textbook['file_path']]);

      // Delete from database (cascade will handle embeddings)
      await _supabase.from('textbooks').delete().eq('id', textbookId);
    } catch (e) {
      throw Exception('Failed to delete textbook: $e');
    }
  }

  /// Update textbook processing status
  Future<void> updateProcessingStatus(String textbookId, bool processed) async {
    try {
      await _supabase
          .from('textbooks')
          .update({'processed': processed})
          .eq('id', textbookId);
    } catch (e) {
      throw Exception('Failed to update processing status: $e');
    }
  }

  /// Get all textbooks for a user
  Future<List<Map<String, dynamic>>> getUserTextbooks() async {
    try {
      final userId = _supabase.auth.currentSession?.user.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('textbooks')
          .select('*, subjects(name, subject_code)')
          .eq('uploaded_by', userId)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch user textbooks: $e');
    }
  }

  /// Get download URL for a textbook
  String getDownloadUrl(String filePath) {
    return _supabase.storage.from(_bucketName).getPublicUrl(filePath);
  }
}
