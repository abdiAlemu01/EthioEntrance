/// Example Usage: Production Offline AI with EmbeddingGemma and Qwen3
/// 
/// This file demonstrates how to use the production-ready AI services
/// for the EthioEntrance application.

import 'package:flutter/material.dart';
import 'embedding_service.dart';
import 'text_generation_service.dart';
import 'rag_service.dart';

// ============================================================================
// Example 1: Initialize the AI System
// ============================================================================

class AIInitializationExample extends StatefulWidget {
  const AIInitializationExample({Key? key}) : super(key: key);

  @override
  State<AIInitializationExample> createState() => _AIInitializationExampleState();
}

class _AIInitializationExampleState extends State<AIInitializationExample> {
  double embeddingProgress = 0.0;
  double textGenProgress = 0.0;
  String status = "Initializing...";

  @override
  void initState() {
    super.initState();
    _initializeAI();
  }

  Future<void> _initializeAI() async {
    try {
      final ragService = RagService(
        objectBoxService,
        EmbeddingService(),
        TextGenerationService(),
      );

      await ragService.initialize(
        onEmbeddingProgress: (progress) {
          setState(() {
            embeddingProgress = progress;
            status = "Downloading EmbeddingGemma: ${(progress * 100).toInt()}%";
          });
        },
        onTextGenProgress: (progress) {
          setState(() {
            textGenProgress = progress;
            status = "Downloading Qwen3: ${(progress * 100).toInt()}%";
          });
        },
      );

      setState(() {
        status = "✓ AI System Ready!";
      });

      // Show system info
      final systemStatus = ragService.getStatus();
      print("=== AI System Status ===");
      print(systemStatus);
    } catch (e) {
      setState(() {
        status = "✗ Initialization Failed: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Initialization")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(status, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            LinearProgressIndicator(value: embeddingProgress),
            const SizedBox(height: 10),
            Text("EmbeddingGemma: ${(embeddingProgress * 100).toInt()}%"),
            const SizedBox(height: 20),
            LinearProgressIndicator(value: textGenProgress),
            const SizedBox(height: 10),
            Text("Qwen3: ${(textGenProgress * 100).toInt()}%"),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// Example 2: Ask a Question (Basic)
// ============================================================================

Future<void> basicQuestionExample() async {
  final ragService = getRagService(); // Your DI method

  // Basic question answering
  final response = await ragService.processQuestion(
    question: "What is photosynthesis?",
    userSupabaseId: "user-123",
    grade: 10,
    subjectCode: "BIO",
    topK: 4, // Retrieve top 4 relevant chunks
  );

  print("Question: What is photosynthesis?");
  print("Answer: ${response.answer}");
  print("Processing Time: ${response.processingTimeMs}ms");
  print("Sources Used: ${response.sources.length}");
  print("Context Chunks: ${response.contextUsed.length}");

  // Display sources
  for (final source in response.sources) {
    print("- ${source.textbookTitle} (Grade ${source.grade})");
    print("  Similarity: ${(source.similarity * 100).toStringAsFixed(1)}%");
  }
}

// ============================================================================
// Example 3: Ask a Question with Streaming (Responsive UI)
// ============================================================================

class StreamingChatExample extends StatefulWidget {
  const StreamingChatExample({Key? key}) : super(key: key);

  @override
  State<StreamingChatExample> createState() => _StreamingChatExampleState();
}

class _StreamingChatExampleState extends State<StreamingChatExample> {
  final TextEditingController _controller = TextEditingController();
  String _currentAnswer = "";
  bool _isLoading = false;

  Future<void> _askQuestion() async {
    if (_controller.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _currentAnswer = "";
    });

    final ragService = getRagService();
    
    try {
      await ragService.processQuestion(
        question: _controller.text,
        userSupabaseId: "user-123",
        grade: 10,
        subjectCode: "BIO",
        onToken: (token) {
          // This callback is called for each generated token
          // Update UI in real-time for responsive experience
          setState(() {
            _currentAnswer += token;
          });
        },
      );
    } catch (e) {
      setState(() {
        _currentAnswer = "Error: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Streaming Chat")),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Text(
                _currentAnswer.isEmpty 
                    ? "Ask a question to see the answer stream in real-time!"
                    : _currentAnswer,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: "Ask a question...",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _isLoading ? null : _askQuestion,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Example 4: Index a New Textbook
// ============================================================================

Future<void> indexTextbookExample() async {
  final ragService = getRagService();

  // 1. Extract text from PDF (using your PDF extraction logic)
  final pdfText = await extractTextFromPdf("path/to/textbook.pdf");

  // 2. Split into chunks (optimal size: 500-1000 characters)
  final chunks = splitTextIntoChunks(pdfText, maxChars: 800);

  print("📚 Indexing textbook with ${chunks.length} chunks...");

  // 3. Create textbook entry in database
  final textbook = Textbook(
    title: "Grade 10 Biology",
    subjectCode: "BIO",
    grade: 10,
    language: "en",
    fileName: "biology_grade10.pdf",
  );
  objectBoxService.insertTextbook(textbook);

  // 4. Index with progress tracking
  await ragService.indexTextbook(
    textbookId: textbook.id,
    chunks: chunks,
    onProgress: (processed, total) {
      final percentage = (processed / total * 100).toInt();
      print("Progress: $processed/$total ($percentage%)");
    },
  );

  print("✓ Textbook indexed successfully!");
}

// Helper function to split text into chunks
List<String> splitTextIntoChunks(String text, {int maxChars = 800}) {
  final chunks = <String>[];
  final sentences = text.split(RegExp(r'[.!?]+'));

  String currentChunk = "";
  for (final sentence in sentences) {
    if (currentChunk.length + sentence.length > maxChars) {
      if (currentChunk.isNotEmpty) {
        chunks.add(currentChunk.trim());
        currentChunk = "";
      }
    }
    currentChunk += "$sentence. ";
  }

  if (currentChunk.isNotEmpty) {
    chunks.add(currentChunk.trim());
  }

  return chunks;
}

// ============================================================================
// Example 5: Check System Status
// ============================================================================

Future<void> checkSystemStatusExample() async {
  final ragService = getRagService();

  // Get comprehensive status
  final status = ragService.getStatus();

  print("=== RAG System Status ===");
  print("Ready: ${status['isReady']}");
  
  print("\n=== Embedding Model ===");
  final embedding = status['embedding'] as Map<String, dynamic>;
  print("Model: ${embedding['modelName']}");
  print("Dimensions: ${embedding['embeddingDimension']}");
  print("Max Sequence: ${embedding['maxSequenceLength']} tokens");
  print("Loaded: ${embedding['isLoaded']}");
  print("Backend: ${embedding['backend']}");
  
  print("\n=== Text Generation Model ===");
  final textGen = status['textGeneration'] as Map<String, dynamic>;
  print("Model: ${textGen['modelName']}");
  print("Context Length: ${textGen['contextLength']} tokens");
  print("Max Output: ${textGen['maxTokens']} tokens");
  print("Temperature: ${textGen['temperature']}");
  print("Backend: ${textGen['backend']}");
  
  print("\n=== Database ===");
  final db = status['database'] as Map<String, dynamic>;
  print("Textbooks: ${db['textbookCount']}");
  print("Chunks: ${db['chunkCount']}");
}

// ============================================================================
// Example 6: Memory Management (App Lifecycle)
// ============================================================================

class AppLifecycleManager extends StatefulWidget {
  final Widget child;
  const AppLifecycleManager({required this.child, Key? key}) : super(key: key);

  @override
  State<AppLifecycleManager> createState() => _AppLifecycleManagerState();
}

class _AppLifecycleManagerState extends State<AppLifecycleManager> 
    with WidgetsBindingObserver {
  
  late final RagService _ragService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ragService = getRagService();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        // App going to background - release resources
        print("🧹 App backgrounded - releasing AI resources");
        _ragService.dispose();
        break;
        
      case AppLifecycleState.resumed:
        // App coming back to foreground - reinitialize
        print("🚀 App resumed - reinitializing AI");
        _ragService.initialize();
        break;
        
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ============================================================================
// Example 7: Test Embedding Service Directly
// ============================================================================

Future<void> testEmbeddingServiceExample() async {
  final embeddingService = EmbeddingService();
  await embeddingService.initialize();

  // Single embedding
  print("Generating single embedding...");
  final embedding = await embeddingService.embedText("Hello world");
  print("Dimension: ${embedding.length}"); // Should be 768

  // Batch embeddings
  print("\nGenerating batch embeddings...");
  final texts = [
    "What is photosynthesis?",
    "Explain Newton's laws of motion",
    "Describe the water cycle",
  ];

  final embeddings = await embeddingService.embedTexts(
    texts,
    onProgress: (processed, total) {
      print("Progress: $processed/$total");
    },
  );

  print("Generated ${embeddings.length} embeddings");

  // Calculate similarity
  final similarity = embeddingService.cosineSimilarity(
    embeddings[0],
    embeddings[1],
  );
  print("Similarity between query 1 and 2: ${(similarity * 100).toFixed(2)}%");

  // Get model info
  final info = embeddingService.getModelInfo();
  print("\n=== Model Info ===");
  print(info);
}

// ============================================================================
// Example 8: Test Text Generation Service Directly
// ============================================================================

Future<void> testTextGenerationExample() async {
  final textGenService = TextGenerationService();
  await textGenService.initialize();

  // Simple generation (no RAG)
  print("Generating simple response...");
  final simpleResponse = await textGenService.generateSimpleResponse(
    "Hello! How are you?",
  );
  print("Response: $simpleResponse");

  // RAG generation
  print("\nGenerating RAG response...");
  final ragResponse = await textGenService.generateRAGResponse(
    question: "What is gravity?",
    context: [
      "Gravity is a fundamental force of nature that attracts objects with mass toward each other. On Earth, gravity gives weight to physical objects and causes them to fall toward the ground when dropped.",
      "Isaac Newton described gravity as a universal force in his law of universal gravitation. He showed that the same force that causes an apple to fall also keeps the planets in orbit around the Sun.",
    ],
    grade: 10,
  );
  print("Response: $ragResponse");

  // Streaming generation
  print("\nGenerating with streaming...");
  String streamedResponse = "";
  await textGenService.generateRAGResponse(
    question: "Explain photosynthesis",
    context: [
      "Photosynthesis is the process by which plants use sunlight, water, and carbon dioxide to produce oxygen and energy in the form of sugar.",
    ],
    grade: 9,
    onToken: (token) {
      streamedResponse += token;
      print(token); // Print each token as it's generated
    },
  );

  // Get model info
  final info = textGenService.getModelInfo();
  print("\n=== Model Info ===");
  print(info);
}

// ============================================================================
// Example 9: Get Chat History
// ============================================================================

Future<void> getChatHistoryExample() async {
  final ragService = getRagService();

  // Get recent chat history
  final history = ragService.getChatHistory(
    "user-123",
    limit: 20,
  );

  print("=== Chat History ===");
  for (final message in history) {
    if (message.isUser) {
      print("\n👤 User: ${message.message}");
    } else {
      print("🤖 AI: ${message.response}");
      if (message.sourceTextbookIds.isNotEmpty) {
        print("   Sources: ${message.sourceTextbookIds.join(', ')}");
      }
    }
  }

  // Clear history
  // final cleared = ragService.clearChatHistory("user-123");
  // print("History cleared: $cleared");
}

// ============================================================================
// Example 10: Database Statistics
// ============================================================================

Future<void> getDatabaseStatsExample() async {
  final ragService = getRagService();

  final stats = ragService.getStatistics();

  print("=== Database Statistics ===");
  print("Subjects: ${stats['subjectCount']}");
  print("Textbooks: ${stats['textbookCount']}");
  print("Processed Textbooks: ${stats['processedTextbookCount']}");
  print("Total Chunks: ${stats['chunkCount']}");
  print("Total Chat Messages: ${stats['chatMessageCount']}");
}

// ============================================================================
// Helper: Get RAG Service (Replace with your actual DI)
// ============================================================================

RagService getRagService() {
  // Replace with your actual dependency injection
  // Example with get_it:
  // return getIt<RagService>();
  
  throw UnimplementedError("Implement your DI here");
}

// ============================================================================
// Helper: Extract Text from PDF (Stub)
// ============================================================================

Future<String> extractTextFromPdf(String path) async {
  // Use syncfusion_flutter_pdf or similar
  throw UnimplementedError("Implement PDF extraction");
}
