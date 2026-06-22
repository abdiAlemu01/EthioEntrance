
// AI chat provider with offline RAG implementation using local models

import 'package:injectable/injectable.dart';
import '../../../core/ai/rag_service.dart';
import '../../../core/database/objectbox/models.dart';

/// RAG response model for chat
class ChatResponse {
  final String answer;
  final List<RagSource> sources;
  final bool hasRelevantContext;

  ChatResponse({
    required this.answer,
    required this.sources,
    required this.hasRelevantContext,
  });

  factory ChatResponse.fromRagResponse(RagResponse ragResponse) {
    return ChatResponse(
      answer: ragResponse.answer,
      sources: ragResponse.sources,
      hasRelevantContext: ragResponse.hasRelevantContext,
    );
  }

  /// Convert to legacy format for backward compatibility
  Map<String, dynamic> toLegacyMap() {
    return {
      'response': answer,
      'sources': sources.map((s) => s.toJson()).toList(),
    };
  }
}

/// Chat provider using offline RAG
/// 
/// This provider manages AI chat interactions using the local RAG service.
/// All processing happens offline on the device.
@injectable
class ChatProvider {
  final RagService _ragService;
  String? _currentUserId;
  int? _currentGrade;

  ChatProvider(this._ragService);

  /// Initialize the chat provider
  Future<void> initialize() async {
    await _ragService.initialize();
  }

  /// Set the current user context
  void setUserContext({
    required String userId,
    int? grade,
  }) {
    _currentUserId = userId;
    _currentGrade = grade;
  }

  /// Ask a question using offline RAG
  /// 
  /// Parameters:
  /// - question: The student's question
  /// - subjectCode: Optional subject filter
  /// - grade: Optional grade override
  /// - topK: Number of chunks to retrieve
  /// 
  /// Returns: Chat response with answer and sources
  Future<ChatResponse> askQuestion({
    required String question,
    String? subjectCode,
    int? grade,
    int topK = 4,
  }) async {
    if (_currentUserId == null) {
      throw Exception('User context not set. Call setUserContext first.');
    }

    final response = await _ragService.processQuestion(
      question: question,
      userSupabaseId: _currentUserId!,
      grade: grade ?? _currentGrade,
      subjectCode: subjectCode,
      topK: topK,
    );

    return ChatResponse.fromRagResponse(response);
  }

  /// Get chat history for current user
  List<ChatMessage> getChatHistory({int limit = 50}) {
    if (_currentUserId == null) {
      return [];
    }

    return _ragService.getChatHistory(_currentUserId!, limit: limit);
  }

  /// Clear chat history for current user
  bool clearChatHistory() {
    if (_currentUserId == null) {
      return false;
    }

    return _ragService.clearChatHistory(_currentUserId!);
  }

  /// Get RAG service statistics
  Map<String, int> getStatistics() {
    return _ragService.getStatistics();
  }

  /// Check if service is ready
  bool isReady() {
    return _ragService.isReady();
  }
}

/// Legacy function for backward compatibility
/// 
/// This maintains the existing API while using the new offline RAG service
/// 
/// Note: This function is deprecated. Use ChatProvider instead.
@deprecated
Future<Map<String, dynamic>> askAI({
  required String prompt,
  int? grade,
  String? subjectId,
}) async {
  // This is a placeholder - in production, you would use dependency injection
  // to get the ChatProvider instance
  throw UnimplementedError(
    'Legacy askAI function is deprecated. Use ChatProvider instead.',
  );
}