//text_generation_service.dart 


import 'package:injectable/injectable.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'dart:io';

/// Local text generation service using Qwen3 with FlutterGemma
/// 
/// This service generates text responses using Qwen3 model.
/// 
/// Architecture Decision:
/// - Uses FlutterGemma for on-device inference
/// - Uses Qwen3-0.5B-Instruct model from HuggingFace
/// - Runs completely offline after model download
/// - Implements RAG-aware generation (uses retrieved context)
/// - Singleton pattern for efficient resource management
/// 
/// Important Rule:
/// The AI should not hallucinate. If the answer is not found in 
/// retrieved content, respond: "I could not find that information 
/// in the provided learning materials."
/// 
/// Model:
/// - Model: Qwen3-0.5B-Instruct in .litertlm format
/// - Size: 0.5B parameters (lightweight for mobile)
/// - Type: Instruction-tuned for chat/qa
@injectable
class TextGenerationService {
  static final TextGenerationService _instance = TextGenerationService._internal();
  factory TextGenerationService() => _instance;
  TextGenerationService._internal();

  bool _isInitialized = false;
  bool _isModelInstalled = false;
  InferenceModel? _model;
  InferenceSession? _session;
  
  // Model parameters
  static const int _maxContextLength = 2048;
  static const double _temperature = 0.3;
  static const int _maxTokens = 512;
  
  // Model filename
  static const String _modelName = 'model.litertlm';

  /// Initialize the text generation service
  /// 
  /// Checks if the model is installed, and if not, downloads it.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check if model is already installed
      _isModelInstalled = await FlutterGemma.isModelInstalled('qwen3-0.5b-instruct');
      
      if (!_isModelInstalled) {
        print("Qwen3 model not installed. Downloading...");
        await _downloadModel();
      } else {
        print("Qwen3 model already installed.");
      }
      
      // Get the active model
      _model = await FlutterGemma.getActiveModel(
        maxTokens: _maxTokens,
        preferredBackend: PreferredBackend.gpu,
      );
      
      // Create a session for inference
      _session = await _model!.createSession();
      
      _isInitialized = true;
      print('Text generation service initialized successfully');
    } catch (e) {
      print('Failed to initialize text generation service with GPU, trying CPU: $e');
      try {
        // Fallback to CPU backend
        _model = await FlutterGemma.getActiveModel(
          maxTokens: _maxTokens,
          preferredBackend: PreferredBackend.cpu,
        );
        
        _session = await _model!.createSession();
        
        _isInitialized = true;
        print('Text generation service initialized successfully with CPU backend');
      } catch (e2) {
        print('Failed to initialize text generation service: $e2');
        _isInitialized = true; // Allow fallback to rule-based response
      }
    }
  }

  /// Download Qwen3 model from HuggingFace
  Future<void> _downloadModel() async {
    try {
      print("Downloading Qwen3 local model layers...");
      
      // Download and install the .litertlm format of the Qwen model
      await FlutterGemma.installModel(
        modelType: ModelType.qwen3_0_5b_instruct,
        fileType: ModelFileType.litertlm,
      ).fromNetwork(
        'https://huggingface.co/litert-community/Qwen3-0.5B-Instruct-litertlm/resolve/main/model.litertlm'
      ).install();
        
      print("Qwen3 is fully initialized and operational completely offline.");
      _isModelInstalled = true;
    } catch (e) {
      print("Error setting up Qwen3: $e");
      rethrow;
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
    if (_session != null) {
      try {
        return await _generateWithModel(prompt);
      } catch (e) {
        print("Model generation failed, using fallback: $e");
        return _ruleBasedResponse(prompt);
      }
    } else {
      return _ruleBasedResponse(prompt);
    }
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

  /// Generate response using Qwen3 model
  Future<String> _generateWithModel(String prompt) async {
    try {
      // Add the prompt to the session
      _session!.addQueryChunk(Message(text: prompt, isUser: true));
      
      // Generate response
      final response = await _session!.getResponse();
      
      // Check if response is TextResponse
      if (response is TextResponse) {
        return (response as TextResponse).token;
      } else {
        print("Unexpected response type: ${response.runtimeType}");
        return _ruleBasedResponse(prompt);
      }
    } catch (e) {
      print("Error generating response with model: $e");
      rethrow;
    }
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

    if (_session != null) {
      try {
        return await _generateWithModel(prompt);
      } catch (e) {
        print("Model generation failed, using fallback: $e");
        return _ruleBasedResponse(prompt);
      }
    } else {
      return _ruleBasedResponse(prompt);
    }
  }

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Check if model is installed
  bool get isModelInstalled => _isModelInstalled;

  /// Release resources
  void dispose() {
    _session?.dispose();
    _session = null;
    _model = null;
    _isInitialized = false;
  }
}
