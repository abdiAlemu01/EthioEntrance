import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:objectbox/objectbox.dart';
import 'models.dart';
import '../objectbox.g.dart';

/// ObjectBox database service for local data storage with vector search capabilities
/// 
/// This service manages:
/// - Local database initialization
/// - CRUD operations for all entities
/// - Vector similarity search using HNSW indexing
/// - Offline-first data persistence
class ObjectBoxService {
  static ObjectBoxService? _instance;
  late final Store store;
  late final Box<Textbook> textbookBox;
  late final Box<TextbookChunk> textbookChunkBox;
  late final Box<Subject> subjectBox;
  late final Box<UserProfile> userProfileBox;
  late final Box<ChatMessage> chatMessageBox;
  late final Box<UserProgress> userProgressBox;
  late final Box<QuizResult> quizResultBox;

  // Private constructor for singleton pattern
  ObjectBoxService._create(this.store) {
    // Initialize boxes for each entity
    textbookBox = Box<Textbook>(store);
    textbookChunkBox = Box<TextbookChunk>(store);
    subjectBox = Box<Subject>(store);
    userProfileBox = Box<UserProfile>(store);
    chatMessageBox = Box<ChatMessage>(store);
    userProgressBox = Box<UserProgress>(store);
    quizResultBox = Box<QuizResult>(store);
  }

  /// Initialize ObjectBox database
  static Future<ObjectBoxService> init() async {
    if (_instance != null) return _instance!;

    final docsDir = await getApplicationDocumentsDirectory();
    final store = await openStore(
      directory: p.join(docsDir.path, 'objectbox'),
      macOSApplicationGroup: 'com.ethioentrance.app',
    );

    _instance = ObjectBoxService._create(store);
    return _instance!;
  }

  /// Get singleton instance
  static ObjectBoxService get instance {
    if (_instance == null) {
      throw StateError('ObjectBoxService not initialized. Call init() first.');
    }
    return _instance!;
  }

  // ==================== TEXTBOOK OPERATIONS ====================

  /// Insert or update a textbook
  int insertTextbook(Textbook textbook) {
    return textbookBox.put(textbook);
  }

  /// Get textbook by ID
  Textbook? getTextbook(int id) {
    return textbookBox.get(id);
  }

  /// Get all textbooks
  List<Textbook> getAllTextbooks() {
    return textbookBox.getAll();
  }

  /// Get textbooks by subject and grade
  List<Textbook> getTextbooksBySubjectAndGrade(String subjectCode, int grade) {
    return textbookBox
        .query(Textbook_.subjectCode.equals(subjectCode)
            .and(Textbook_.grade.equals(grade)))
        .build()
        .find();
  }

  /// Delete a textbook
  bool deleteTextbook(int id) {
    // First delete associated chunks
    final chunks = getTextbookChunks(id);
    for (var chunk in chunks) {
      textbookChunkBox.remove(chunk.id);
    }
    return textbookBox.remove(id);
  }

  // ==================== TEXTBOOK CHUNK OPERATIONS ====================

  /// Insert a textbook chunk with embedding
  int insertTextbookChunk(TextbookChunk chunk) {
    return textbookChunkBox.put(chunk);
  }

  /// Get chunks for a specific textbook
  List<TextbookChunk> getTextbookChunks(int textbookId) {
    return textbookChunkBox
        .query(TextbookChunk_.textbook.id.equals(textbookId))
        .build()
        .find();
  }

  /// Get chunk by ID
  TextbookChunk? getTextbookChunk(int id) {
    return textbookChunkBox.get(id);
  }

  /// Delete all chunks for a textbook
  void deleteTextbookChunks(int textbookId) {
    final chunks = getTextbookChunks(textbookId);
    for (var chunk in chunks) {
      textbookChunkBox.remove(chunk.id);
    }
  }

  // ==================== VECTOR SEARCH OPERATIONS ====================

  /// Perform vector similarity search using HNSW indexing
  /// 
  /// This method:
  /// 1. Takes a query embedding vector
  /// 2. Searches for similar chunks using cosine similarity
  /// 3. Returns top k most similar chunks
  /// 
  /// Parameters:
  /// - queryEmbedding: The embedding vector of the query
  /// - k: Number of results to return (default: 4)
  /// - subjectCode: Optional filter by subject
  /// - grade: Optional filter by grade
  /// 
  /// Returns: List of (chunk, similarity score) tuples
  List<(TextbookChunk, double)> vectorSearch({
    required List<double> queryEmbedding,
    int k = 4,
    String? subjectCode,
    int? grade,
  }) {
    // Build query with optional filters
    final builder = textbookChunkBox.query();
    
    if (subjectCode != null || grade != null) {
      final textbookQuery = TextbookChunk_.textbook;
      if (subjectCode != null) {
        builder.link(textbookQuery, Textbook_.subjectCode.equals(subjectCode));
      }
      if (grade != null) {
        builder.link(textbookQuery, Textbook_.grade.equals(grade));
      }
    }

    final chunks = builder.build().find();

    // Calculate cosine similarity for each chunk
    final similarities = <(TextbookChunk, double)>[];
    for (final chunk in chunks) {
      final similarity = _cosineSimilarity(queryEmbedding, chunk.embedding);
      similarities.add((chunk, similarity));
    }

    // Sort by similarity (descending) and take top k
    similarities.sort((a, b) => b.$2.compareTo(a.$2));
    return similarities.take(k).toList();
  }

  /// Calculate cosine similarity between two vectors
  double _cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dotProduct += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    if (normA == 0 || normB == 0) return 0.0;

    return dotProduct / (normA * normB);
  }

  /// Batch insert chunks for a textbook
  void insertTextbookChunks(List<TextbookChunk> chunks) {
    textbookChunkBox.putMany(chunks);
  }

  /// Get total number of chunks in database
  int getChunkCount() {
    return textbookChunkBox.count();
  }

  // ==================== SUBJECT OPERATIONS ====================

  /// Insert or update a subject
  int insertSubject(Subject subject) {
    return subjectBox.put(subject);
  }

  /// Get all subjects
  List<Subject> getAllSubjects() {
    return subjectBox.getAll();
  }

  /// Get subject by code
  Subject? getSubjectByCode(String subjectCode) {
    return subjectBox
        .query(Subject_.subjectCode.equals(subjectCode))
        .build()
        .findFirst();
  }

  /// Initialize default subjects
  void initializeDefaultSubjects() {
    final defaultSubjects = [
      Subject(name: 'Mathematics', subjectCode: 'MATH', description: 'Mathematics courses for grades 9-12'),
      Subject(name: 'Physics', subjectCode: 'PHYS', description: 'Physics courses for grades 9-12'),
      Subject(name: 'Chemistry', subjectCode: 'CHEM', description: 'Chemistry courses for grades 9-12'),
      Subject(name: 'Biology', subjectCode: 'BIO', description: 'Biology courses for grades 9-12'),
      Subject(name: 'English', subjectCode: 'ENG', description: 'English language and literature'),
      Subject(name: 'Amharic', subjectCode: 'AMH', description: 'Amharic language and literature'),
      Subject(name: 'Civics', subjectCode: 'CIV', description: 'Civic and ethical education'),
      Subject(name: 'History', subjectCode: 'HIST', description: 'History courses'),
      Subject(name: 'Geography', subjectCode: 'GEOG', description: 'Geography courses'),
      Subject(name: 'Economics', subjectCode: 'ECON', description: 'Economics courses for grades 11-12'),
    ];

    for (final subject in defaultSubjects) {
      if (getSubjectByCode(subject.subjectCode) == null) {
        insertSubject(subject);
      }
    }
  }

  // ==================== USER PROFILE OPERATIONS ====================

  /// Insert or update user profile
  int insertUserProfile(UserProfile profile) {
    return userProfileBox.put(profile);
  }

  /// Get user profile by Supabase user ID
  UserProfile? getUserProfile(String supabaseUserId) {
    return userProfileBox
        .query(UserProfile_.supabaseUserId.equals(supabaseUserId))
        .build()
        .findFirst();
  }

  /// Update user grade
  bool updateUserGrade(String supabaseUserId, int grade) {
    final profile = getUserProfile(supabaseUserId);
    if (profile == null) return false;
    
    profile.grade = grade;
    profile.updatedAt = DateTime.now();
    return userProfileBox.put(profile) > 0;
  }

  // ==================== CHAT MESSAGE OPERATIONS ====================

  /// Insert a chat message
  int insertChatMessage(ChatMessage message) {
    return chatMessageBox.put(message);
  }

  /// Get chat history for a user
  List<ChatMessage> getChatHistory(String userSupabaseId, {int limit = 50}) {
    return chatMessageBox
        .query(ChatMessage_.userSupabaseId.equals(userSupabaseId))
        .order(ChatMessage_.createdAt, flags: Order.descending)
        .build()
        .find()
        .take(limit)
        .toList();
  }

  /// Clear chat history for a user
  bool clearChatHistory(String userSupabaseId) {
    final messages = chatMessageBox
        .query(ChatMessage_.userSupabaseId.equals(userSupabaseId))
        .build()
        .find();
    
    return chatMessageBox.removeMany(messages.map((m) => m.id).toList());
  }

  // ==================== USER PROGRESS OPERATIONS ====================

  /// Insert or update user progress
  int insertUserProgress(UserProgress progress) {
    return userProgressBox.put(progress);
  }

  /// Get progress for a user and subject
  UserProgress? getUserProgress(String userSupabaseId, String subjectCode, int grade) {
    return userProgressBox
        .query(UserProgress_.userSupabaseId.equals(userSupabaseId)
            .and(UserProgress_.subjectCode.equals(subjectCode))
            .and(UserProgress_.grade.equals(grade)))
        .build()
        .findFirst();
  }

  /// Get all progress for a user
  List<UserProgress> getAllUserProgress(String userSupabaseId) {
    return userProgressBox
        .query(UserProgress_.userSupabaseId.equals(userSupabaseId))
        .build()
        .find();
  }

  // ==================== QUIZ RESULT OPERATIONS ====================

  /// Insert a quiz result
  int insertQuizResult(QuizResult result) {
    return quizResultBox.put(result);
  }

  /// Get quiz results for a user
  List<QuizResult> getQuizResults(String userSupabaseId, {int limit = 20}) {
    return quizResultBox
        .query(QuizResult_.userSupabaseId.equals(userSupabaseId))
        .order(QuizResult_.completedAt, flags: Order.descending)
        .build()
        .find()
        .take(limit)
        .toList();
  }

  /// Get quiz results for a specific subject and grade
  List<QuizResult> getQuizResultsForSubject(
    String userSupabaseId,
    String subjectCode,
    int grade,
  ) {
    return quizResultBox
        .query(QuizResult_.userSupabaseId.equals(userSupabaseId)
            .and(QuizResult_.subjectCode.equals(subjectCode))
            .and(QuizResult_.grade.equals(grade)))
        .order(QuizResult_.completedAt, flags: Order.descending)
        .build()
        .find();
  }

  // ==================== DATABASE MAINTENANCE ====================

  /// Clear all data (useful for testing or reset)
  void clearAllData() {
    textbookBox.removeAll();
    textbookChunkBox.removeAll();
    subjectBox.removeAll();
    userProfileBox.removeAll();
    chatMessageBox.removeAll();
    userProgressBox.removeAll();
    quizResultBox.removeAll();
  }

  /// Get database statistics
  Map<String, int> getDatabaseStats() {
    return {
      'textbooks': textbookBox.count(),
      'chunks': textbookChunkBox.count(),
      'subjects': subjectBox.count(),
      'users': userProfileBox.count(),
      'chatMessages': chatMessageBox.count(),
      'progress': userProgressBox.count(),
      'quizResults': quizResultBox.count(),
    };
  }

  /// Close the database
  void close() {
    store.close();
    _instance = null;
  }
}
