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

  /// Initialize the RAG service with progress tracking
  ///
  /// Initializes all dependent services with mobile optimizations
  ///
  /// Parameters:
  /// - onEmbeddingProgress: Optional callback for embedding model download progress
  /// - onTextGenProgress: Optional callback for text generation model download progress
  Future<void> initialize({
    Function(double progress)? onEmbeddingProgress,
    Function(double progress)? onTextGenProgress,
  }) async {
    print("🚀 Initializing RAG service...");

    // Initialize embedding service
    print("📥 Loading embedding model...");
    try {
      await _embeddingService.initialize(onProgress: onEmbeddingProgress);
    } catch (e) {
      print("⚠ Warning: Embedding service initialization failed: $e");
      print("AI features will be disabled");
    }

    // Initialize text generation service
    print("📥 Loading text generation model...");
    try {
      await _textGenerationService.initialize(onProgress: onTextGenProgress);
    } catch (e) {
      print("⚠ Warning: Text generation service initialization failed: $e");
      print("AI features will be disabled");
    }

    // Initialize default subjects in database
    _objectBoxService.initializeDefaultSubjects();

    // Warmup models for better first-query performance
    print("🔥 Warming up models...");
    try {
      await Future.wait([
        _embeddingService.warmup(),
        _textGenerationService.warmup(),
      ]);
    } catch (e) {
      print("⚠ Warning: Model warmup failed: $e");
    }

    print("✓ RAG service initialized (AI features may be limited)");
  }

  /// Process a student's question using RAG (Production-ready version)
  /// 
  /// This is the main entry point for the RAG workflow.
  /// Includes mobile optimizations and streaming support.
  /// 
  /// Parameters:
  /// - question: The student's question
  /// - userSupabaseId: User's Supabase ID for personalization
  /// - grade: Optional grade filter for context
  /// - subjectCode: Optional subject filter for context
  /// - topK: Number of chunks to retrieve (default: 4)
  /// - onToken: Optional callback for streaming response tokens
  /// 
  /// Returns: RAG response with answer and sources
  Future<RagResponse> processQuestion({
    required String question,
    required String userSupabaseId,
    int? grade,
    String? subjectCode,
    int topK = _defaultTopK,
    Function(String token)? onToken,
  }) async {
    final startTime = DateTime.now();
    
    try {
      // Step 1: Generate embedding for the question
      print("🔍 Generating query embedding...");
      final queryEmbedding = await _embeddingService.embedText(question);

      // Step 2: Search for similar chunks in ObjectBox
      print("📚 Searching vector database...");
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

      print("✓ Found ${relevantResults.length} relevant chunks (threshold: $_similarityThreshold)");

      // Step 4: Extract context from relevant chunks
      final contextChunks = relevantResults
          .map((result) => result.$1.chunkText)
          .toList();

      // Step 5: Generate response using retrieved context
      print("🤖 Generating response with Qwen3...");
      final answer = await _textGenerationService.generateRAGResponse(
        question: question,
        context: contextChunks,
        grade: grade,
        onToken: onToken,
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

      final duration = DateTime.now().difference(startTime);
      print("✓ RAG query completed in ${duration.inMilliseconds}ms");

      return RagResponse(
        answer: answer,
        sources: sources,
        contextUsed: contextChunks,
        hasRelevantContext: relevantResults.isNotEmpty,
        processingTimeMs: duration.inMilliseconds,
      );
      
    } catch (e) {
      print("✗ RAG processing failed: $e");
      
      // Return error response with graceful degradation
      return RagResponse(
        answer: 'I apologize, but I encountered an error while processing your question. Please try again.',
        sources: [],
        contextUsed: [],
        hasRelevantContext: false,
        processingTimeMs: DateTime.now().difference(startTime).inMilliseconds,
        error: e.toString(),
      );
    }
  }

  /// Process and index a textbook for RAG (Production-ready version)
  /// 
  /// This method:
  /// 1. Takes textbook chunks
  /// 2. Generates embeddings for each chunk with progress tracking
  /// 3. Stores chunks with embeddings in ObjectBox
  /// 
  /// Parameters:
  /// - textbookId: ID of the textbook in ObjectBox
  /// - chunks: List of text chunks
  /// - onProgress: Optional callback for progress tracking
  /// 
  /// Returns: Number of chunks successfully indexed
  /// 
  /// Mobile optimizations:
  /// - Batch processing with progress tracking
  /// - Memory-efficient chunking
  /// - Error recovery for partial failures
  Future<int> indexTextbook({
    required int textbookId,
    required List<String> chunks,
    Function(int processed, int total)? onProgress,
  }) async {
    final startTime = DateTime.now();
    print("📚 Indexing textbook $textbookId with ${chunks.length} chunks...");
    
    final textbook = _objectBoxService.getTextbook(textbookId);
    if (textbook == null) {
      throw Exception('Textbook not found with ID: $textbookId');
    }

    try {
      // Generate embeddings for all chunks with progress tracking
      print("🔢 Generating embeddings...");
      final embeddings = await _embeddingService.embedTexts(
        chunks,
        onProgress: onProgress,
      );

      // Create chunk entities
      print("💾 Creating chunk entities...");
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
      print("💾 Storing in vector database...");
      _objectBoxService.insertTextbookChunks(chunkEntities);

      // Update textbook as processed
      textbook.isProcessed = true;
      textbook.updatedAt = DateTime.now();
      _objectBoxService.insertTextbook(textbook);

      final duration = DateTime.now().difference(startTime);
      print("✓ Indexing completed in ${duration.inSeconds}s");
      print("✓ Indexed ${chunks.length} chunks for '${textbook.title}'");

      return chunks.length;
      
    } catch (e) {
      print("✗ Indexing failed: $e");
      rethrow;
    }
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

  /// Get detailed service status
  /// 
  /// Returns: Map with detailed status information
  Map<String, dynamic> getStatus() {
    return {
      'isReady': isReady(),
      'embedding': _embeddingService.getModelInfo(),
      'textGeneration': _textGenerationService.getModelInfo(),
      'database': _objectBoxService.getDatabaseStats(),
    };
  }

  /// Release resources (for memory management on mobile)
  /// 
  /// Call when the app goes to background or memory is low
  Future<void> dispose() async {
    print("🧹 Disposing RAG service resources...");
    await Future.wait([
      _embeddingService.dispose(),
      _textGenerationService.dispose(),
    ]);
    print("✓ RAG service resources released");
  }
}

/// RAG response model (enhanced with metrics)
class RagResponse {
  final String answer;
  final List<RagSource> sources;
  final List<String> contextUsed;
  final bool hasRelevantContext;
  final int processingTimeMs;
  final String? error;

  RagResponse({
    required this.answer,
    required this.sources,
    required this.contextUsed,
    required this.hasRelevantContext,
    this.processingTimeMs = 0,
    this.error,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'answer': answer,
      'sources': sources.map((s) => s.toJson()).toList(),
      'contextUsed': contextUsed,
      'hasRelevantContext': hasRelevantContext,
      'processingTimeMs': processingTimeMs,
      if (error != null) 'error': error,
    };
  }

  /// Check if response was successful
  bool get isSuccess => error == null;
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
