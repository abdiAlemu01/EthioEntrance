// rag_service.dart

import 'package:injectable/injectable.dart';
import '../database/objectbox/objectbox_service.dart';
import '../database/objectbox/models.dart';
import 'embedding_service.dart';
import 'text_generation_service.dart';

/// Offline RAG (Retrieval-Augmented Generation) Service 
/// This service implements the complete RAG workflow:
/// 
/// Step 1: Student asks a question
/// Step 2: Convert question into embedding using EmbeddingGemma
/// Step 3: Search ObjectBox HNSW vector index
/// Step 4: Retrieve top relevant textbook chunks
/// Step 5: Send student question + retrieved chunks to Qwen
/// Step 6: Qwen generates answer based only on retrieved content
/// 
/// Important Rule:
/// The AI should not hallucinate. If the answer is not found in retrieved content,
/// respond: "I could not find that information in the provided learning materials."
/// 
/// Architecture Decision:
/// - Completely offline - no external API calls
/// - Uses local models (EmbeddingGemma, Qwen)
/// - Uses ObjectBox with HNSW for fast vector search
/// - Follows SOLID principles with dependency injection
/// - Implements repository pattern for data access
@injectable
class RagService {
  final ObjectBoxService _objectBoxService;
  final EmbeddingService _embeddingService;
  final TextGenerationService _textGenerationService;

  // RAG parameters
  static const int _defaultTopK = 4;
  static const double _similarityThreshold = 0.5;

  RagService(
    this._objectBoxService,
    this._embeddingService,
    this._textGenerationService,
  );

  /// Initialize the RAG service
  /// 
  /// Initializes all dependent services
  Future<void> initialize() async {
    await _embeddingService.initialize();
    await _textGenerationService.initialize();
    _objectBoxService.initializeDefaultSubjects();
  }

  /// Process a student's question using RAG
  /// 
  /// This is the main entry point for the RAG workflow.
  /// 
  /// Parameters:
  /// - question: The student's question
  /// - userSupabaseId: User's Supabase ID for personalization
  /// - grade: Optional grade filter for context
  /// - subjectCode: Optional subject filter for context
  /// - topK: Number of chunks to retrieve (default: 4)
  /// 
  /// Returns: RAG response with answer and sources
  Future<RagResponse> processQuestion({
    required String question,
    required String userSupabaseId,
    int? grade,
    String? subjectCode,
    int topK = _defaultTopK,
  }) async {
    // Step 1: Generate embedding for the question
    final queryEmbedding = await _embeddingService.embedText(question);

    // Step 2: Search for similar chunks in ObjectBox
    final searchResults = _objectBoxService.vectorSearch(
      queryEmbedding: queryEmbedding,
      k: topK,
      subjectCode: subjectCode,
      grade: grade,
    );

    // Step 3: Filter by similarity threshold
    final relevantResults = searchResults
        .where((result) => result.$2 >= _similarityThreshold)
        .toList();

    // Step 4: Extract context from relevant chunks
    final contextChunks = relevantResults
        .map((result) => result.$1.chunkText)
        .toList();

    // Step 5: Generate response using retrieved context
    final answer = await _textGenerationService.generateRAGResponse(
      question: question,
      context: contextChunks,
      grade: grade,
    );

    // Step 6: Build source information
    final sources = relevantResults.map((result) {
      final chunk = result.$1;
      final textbook = chunk.textbook.target;
      return RagSource(
        textbookId: textbook?.id.toString() ?? '',
        textbookTitle: textbook?.title ?? 'Unknown',
        subjectCode: textbook?.subjectCode ?? '',
        grade: textbook?.grade ?? 0,
        chunkText: chunk.chunkText,
        similarity: result.$2,
      );
    }).toList();

    // Step 7: Store chat message in history
    _storeChatMessage(
      userSupabaseId: userSupabaseId,
      question: question,
      answer: answer,
      sourceIds: sources.map((s) => s.textbookId).toList(),
    );

    return RagResponse(
      answer: answer,
      sources: sources,
      contextUsed: contextChunks,
      hasRelevantContext: relevantResults.isNotEmpty,
    );
  }

  /// Process and index a textbook for RAG
  /// 
  /// This method:
  /// 1. Takes textbook chunks
  /// 2. Generates embeddings for each chunk
  /// 3. Stores chunks with embeddings in ObjectBox
  /// 
  /// Parameters:
  /// - textbookId: ID of the textbook in ObjectBox
  /// - chunks: List of text chunks
  /// 
  /// Returns: Number of chunks successfully indexed
  Future<int> indexTextbook({
    required int textbookId,
    required List<String> chunks,
  }) async {
    final textbook = _objectBoxService.getTextbook(textbookId);
    if (textbook == null) {
      throw Exception('No relevant information found in the textbook!');
    }

    // Generate embeddings for all chunks
    final embeddings = await _embeddingService.embedTexts(chunks);

    // Create chunk entities
    final chunkEntities = <TextbookChunk>[];
    for (int i = 0; i < chunks.length; i++) {
      final chunk = TextbookChunk(
        chunkText: chunks[i],
        chunkIndex: i,
        embedding: embeddings[i],
      );
      chunk.textbook.target = textbook;
      chunkEntities.add(chunk);
    }

    // Batch insert chunks
    _objectBoxService.insertTextbookChunks(chunkEntities);

    // Update textbook as processed
    textbook.isProcessed = true;
    textbook.updatedAt = DateTime.now();
    _objectBoxService.insertTextbook(textbook);

    return chunks.length;
  }

  /// Get chat history for a user
  /// 
  /// Parameters:
  /// - userSupabaseId: User's Supabase ID
  /// - limit: Maximum number of messages to retrieve
  /// 
  /// Returns: List of chat messages
  List<ChatMessage> getChatHistory(String userSupabaseId, {int limit = 50}) {
    return _objectBoxService.getChatHistory(userSupabaseId, limit: limit);
  }

  /// Clear chat history for a user
  /// 
  /// Parameters:
  /// - userSupabaseId: User's Supabase ID
  /// 
  /// Returns: True if successful
  bool clearChatHistory(String userSupabaseId) {
    return _objectBoxService.clearChatHistory(userSupabaseId);
  }

  /// Store a chat message in history
  void _storeChatMessage({
    required String userSupabaseId,
    required String question,
    required String answer,
    required List<String> sourceIds,
  }) {
    final userMessage = ChatMessage(
      userSupabaseId: userSupabaseId,
      message: question,
      isUser: true,
    );
    _objectBoxService.insertChatMessage(userMessage);

    final aiMessage = ChatMessage(
      userSupabaseId: userSupabaseId,
      message: question,
      isUser: false,
      response: answer,
      sourceTextbookIds: sourceIds,
    );
    _objectBoxService.insertChatMessage(aiMessage);
  }

  /// Get database statistics
  /// 
  /// Returns: Map with database statistics
  Map<String, int> getStatistics() {
    return _objectBoxService.getDatabaseStats();
  }

  /// Check if RAG service is ready
  /// 
  /// Returns: True if all components are initialized
  bool isReady() {
    return _embeddingService.isInitialized &&
        _textGenerationService.isInitialized;
  }
}

/// RAG response model
class RagResponse {
  final String answer;
  final List<RagSource> sources;
  final List<String> contextUsed;
  final bool hasRelevantContext;

  RagResponse({
    required this.answer,
    required this.sources,
    required this.contextUsed,
    required this.hasRelevantContext,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'answer': answer,
      'sources': sources.map((s) => s.toJson()).toList(),
      'contextUsed': contextUsed,
      'hasRelevantContext': hasRelevantContext,
    };
  }
}

/// RAG source model
class RagSource {
  final String textbookId;
  final String textbookTitle;
  final String subjectCode;
  final int grade;
  final String chunkText;
  final double similarity;

  RagSource({
    required this.textbookId,
    required this.textbookTitle,
    required this.subjectCode,
    required this.grade,
    required this.chunkText,
    required this.similarity,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'textbookId': textbookId,
      'textbookTitle': textbookTitle,
      'subjectCode': subjectCode,
      'grade': grade,
      'chunkText': chunkText,
      'similarity': similarity,
    };
  }
}
