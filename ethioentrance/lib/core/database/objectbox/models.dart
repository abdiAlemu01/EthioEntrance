import 'package:objectbox/objectbox.dart';

/// Entity for storing textbook information locally
@Entity()
class Textbook {
  @Id()
  int id = 0;
  
  String title;
  String subjectCode;
  int grade;
  String filePath;
  int fileSize;
  int pageCount;
  bool isProcessed;
  DateTime createdAt;
  DateTime updatedAt;
  
  @Transient()
  List<TextbookChunk> chunks = [];
  
  Textbook({
    required this.title,
    required this.subjectCode,
    required this.grade,
    required this.filePath,
    required this.fileSize,
    this.pageCount = 0,
    this.isProcessed = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
}

/// Entity for storing textbook chunks with embeddings
@Entity()
class TextbookChunk {
  @Id()
  int id = 0;
  
  String chunkText;
  int chunkIndex;
  @Property(type:  PropertyType.doubleVector)
  List<double> embedding;
  
  final textbook = ToOne<Textbook>();
  
  DateTime createdAt;
  
  TextbookChunk({
    required this.chunkText,
    required this.chunkIndex,
    required this.embedding,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// Entity for storing subject information locally
@Entity()
class Subject {
  @Id()
  int id = 0;
  
  String name;
  String subjectCode;
  String description;
  DateTime createdAt;
  DateTime updatedAt;
  
  Subject({
    required this.name,
    required this.subjectCode,
    this.description = '',
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
}

/// Entity for storing user profile locally (synced with Supabase)
@Entity()
class UserProfile {
  @Id()
  int id = 0;
  
  String supabaseUserId;
  String email;
  String firstName;
  String lastName;
  int? grade;
  bool isPremium;
  DateTime createdAt;
  DateTime updatedAt;
  
  UserProfile({
    required this.supabaseUserId,
    required this.email,
    this.firstName = '',
    this.lastName = '',
    this.grade,
    this.isPremium = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
}

/// Entity for storing chat history locally
@Entity()
class ChatMessage {
  @Id()
  int id = 0;
  
  String userSupabaseId;
  String message;
  bool isUser;
  String response;
  List<String> sourceTextbookIds;
  DateTime createdAt;
  
  ChatMessage({
    required this.userSupabaseId,
    required this.message,
    required this.isUser,
    this.response = '',
    this.sourceTextbookIds = const [],
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

/// Entity for storing progress tracking
@Entity()
class UserProgress {
  @Id()
  int id = 0;
  
  String userSupabaseId;
  String subjectCode;
  int grade;
  int completedPages;
  int totalPages;
  double progressPercentage;
  DateTime lastAccessedAt;
  DateTime createdAt;
  DateTime updatedAt;
  
  UserProgress({
    required this.userSupabaseId,
    required this.subjectCode,
    required this.grade,
    this.completedPages = 0,
    this.totalPages = 0,
    this.progressPercentage = 0.0,
    DateTime? lastAccessedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : lastAccessedAt = lastAccessedAt ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();
}

/// Entity for storing practice quiz results
@Entity()
class QuizResult {
  @Id()
  int id = 0;
  
  String userSupabaseId;
  String subjectCode;
  int grade;
  int totalQuestions;
  int correctAnswers;
  double score;
  int durationMinutes;
  DateTime completedAt;
  
  QuizResult({
    required this.userSupabaseId,
    required this.subjectCode,
    required this.grade,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.score,
    required this.durationMinutes,
    DateTime? completedAt,
  }) : completedAt = completedAt ?? DateTime.now();
}
