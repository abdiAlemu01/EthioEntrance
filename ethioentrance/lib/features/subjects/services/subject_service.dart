
// subject_service.dart

import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/subject_model.dart';

class SubjectService {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  SubjectService(this._firestore, this._storage);

  /// -------------------------------
  /// 1. Upload PDF & Video
  /// -------------------------------
  Future<void> uploadPdfAndVideo({
    required String subjectId, // e.g. "math"
    required String subjectName,
    required int grade, // 9,10,11,12
    required Uint8List pdfFile,
    required Uint8List videoFile,
  }) async {
    try {
      /// Storage paths
      final pdfRef = _storage
          .ref()
          .child('subjects/$subjectId/grade$grade/pdfs/${DateTime.now().millisecondsSinceEpoch}.pdf');

      final videoRef = _storage
          .ref()
          .child('subjects/$subjectId/grade$grade/videos/${DateTime.now().millisecondsSinceEpoch}.mp4');

      /// Upload files
      await pdfRef.putData(pdfFile);
      await videoRef.putData(videoFile);

      /// Get URLs
      final pdfUrl = await pdfRef.getDownloadURL();
      final videoUrl = await videoRef.getDownloadURL();

      /// Reference to Firestore doc
      final docRef = _firestore.collection('subjects').doc(subjectId);

      final docSnapshot = await docRef.get();

      /// If subject does NOT exist → create new
      if (!docSnapshot.exists) {
        final newSubject = SubjectModel(
          grade: subjectId,
          name: subjectName,
        );

        await docRef.set(newSubject.toFirestoreMap());
      }

      /// Update based on grade
      await docRef.update({
        'grade${grade}Courses': FieldValue.arrayUnion([pdfUrl]),
        'grade${grade}Videos': FieldValue.arrayUnion([videoUrl]),
      });
    } catch (e) {
      throw Exception('Upload failed: $e');
    }
  }

  /// -------------------------------
  /// 2. Get PDF & Video by Subject
  /// -------------------------------
  Future<SubjectModel?> getPdfAndVideo(String subjectId) async {
    try {
      final doc =
          await _firestore.collection('subjects').doc(subjectId).get();

      if (!doc.exists) return null;

      return SubjectModel.fromMap(doc.data()!);
    } catch (e) {
      throw Exception('Fetch failed: $e');
    }
  }

  /// -------------------------------
  /// 3. Get by Grade (Helper)
  /// -------------------------------
  Future<Map<String, List<String>>> getByGrade({
    required String subjectId,
    required int grade,
  }) async {
    final subject = await getPdfAndVideo(subjectId);

    if (subject == null) {
      return {
        'courses': [],
        'videos': [],
      };
    }

    return {
      'courses': subject.getCoursesForGrade(grade),
      'videos': subject.getVideosForGrade(grade),
    };
  }
}

