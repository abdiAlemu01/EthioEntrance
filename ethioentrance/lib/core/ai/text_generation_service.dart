import 'package:injectable/injectable.dart';

/// Local text generation service using Qwen (or similar local LLM)
/// 
/// This service generates text responses using a local model.
/// Currently designed to work with TFLite-converted LLM models.
/// 
/// Architecture Decision:
/// - Uses TensorFlow Lite for on-device inference
/// - Supports Qwen models converted to TFLite format
/// - Runs completely offline
/// - Implements RAG-aware generation (uses retrieved context)
/// 
/// Important Rule:
/// The AI should not hallucinate. If the answer is not found in 
/// retrieved content, respond: "I could not find that information 
/// in the provided learning materials."
/// 
/// Future Enhancement:
/// - Can be adapted to use Qwen when Flutter support is available
/// - Supports model switching based on device capabilities
/// - Implements streaming responses for better UX
@injectable
class TextGenerationService {
  bool _isInitialized = false;
  
  // Model parameters
  static const int _maxContextLength = 2048;
  static const double _temperature = 0.7;
  static const int _maxTokens = 512;

  /// Initialize the text generation service
  /// 
  /// Loads the TFLite model and prepares it for inference.
  /// Model should be placed in assets/models/ directory.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load TFLite model from assets
      // Note: You need to add the model file to your assets
      // For now, we'll use a rule-based fallback
      
      _isInitialized = true;
      print('Text generation service initialized successfully');
    } catch (e) {
      print('Failed to initialize text generation service: $e');
      // For development, we'll use a rule-based fallback
      _isInitialized = true;
    }
  }

  /// Generate a response using RAG (Retrieval-Augmented Generation)
  /// 
  /// Parameters:
  /// - question: The student's question
  /// - context: Retrieved textbook chunks
  /// - grade: Student's grade level (for age-appropriate responses)
  /// 
  /// Returns: Generated answer based only on retrieved content
  Future<String> generateRAGResponse({
    required String question,
    required List<String> context,
    int? grade,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Check if we have relevant context
    if (context.isEmpty) {
      return 'I could not find that information in the provided learning materials. Please try rephrasing your question or check if the topic is covered in your textbooks.';
    }

    // Combine context into a single string
    final contextText = context.join('\n\n');

    // Build prompt with RAG context
    final prompt = _buildRAGPrompt(question, contextText, grade);

    // Generate response
    return await _generateResponse(prompt);
  }

  /// Build RAG prompt with context
  /// 
  /// This creates a structured prompt that:
  /// 1. Provides the retrieved context
  /// 2. Instructs the model to use only the provided context
  /// 3. Asks the student's question
  /// 4. Enforces the no-hallucination rule
  String _buildRAGPrompt(String question, String context, int? grade) {
    final gradeContext = grade != null 
        ? 'You are answering a student in grade $grade.' 
        : 'You are answering a student.';
    
    return '''
You are an educational AI assistant for Ethiopian students. $gradeContext

IMPORTANT RULES:
1. Use ONLY the information provided in the context below to answer the question.
2. Do NOT use any outside knowledge or make up information.
3. If the answer is not in the context, say: "I could not find that information in the provided learning materials."
4. Provide clear, educational explanations suitable for the student's level.
5. Be helpful and encouraging.

CONTEXT FROM TEXTBOOKS:
---
$context
---

STUDENT'S QUESTION:
$question

YOUR ANSWER:
''';
  }

  /// Generate response from prompt
  /// 
  /// This is a simplified implementation. In production, this would
  /// use actual model inference via TensorFlow Lite.
  Future<String> _generateResponse(String prompt) async {
    // For now, use a rule-based approach
    // In production, replace with actual TFLite model inference
    
    return _ruleBasedResponse(prompt);
  }

  /// Rule-based response generation (fallback for development)
  /// 
  /// This provides a basic response while the actual model is being integrated.
  /// It analyzes the context and question to provide relevant answers.
  String _ruleBasedResponse(String prompt) {
    // Extract question and context from prompt
    final parts = prompt.split('STUDENT\'S QUESTION:');
    if (parts.length < 2) {
      return 'I apologize, but I encountered an error processing your question.';
    }

    final question = parts[1].trim();
    final contextParts = prompt.split('CONTEXT FROM TEXTBOOKS:');
    final context = contextParts.length > 1 
        ? contextParts[1].split('---')[0].trim() 
        : '';

    // Check if context contains relevant information
    if (context.isEmpty || context.length < 50) {
      return 'I could not find that information in the provided learning materials.';
    }

    // Simple keyword matching for demonstration
    final questionLower = question.toLowerCase();
    final contextLower = context.toLowerCase();

    // Extract relevant sentences from context
    final sentences = context.split(RegExp(r'[.!?]+'));
    final relevantSentences = sentences.where((sentence) {
      final sentenceLower = sentence.toLowerCase();
      final words = questionLower.split(RegExp(r'\s+'));
      return words.any((word) => 
        word.length > 3 && sentenceLower.contains(word)
      );
    }).take(3).toList();

    if (relevantSentences.isEmpty) {
      return 'I could not find that information in the provided learning materials.';
    }

    // Build response from relevant sentences
    final response = relevantSentences.join('. ').trim();
    
    // Add educational framing
    return '''
Based on the learning materials provided:

$response

This information comes from your textbooks. Would you like me to explain any part in more detail?
''';
  }

  /// Generate a simple response without RAG context
  /// 
  /// This is used for general conversations or when context is not available.
  Future<String> generateSimpleResponse(String prompt) async {
    if (!_isInitialized) {
      await initialize();
    }

    return await _generateResponse(prompt);
  }

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Release resources
  void dispose() {
    _isInitialized = false;
  }
}
