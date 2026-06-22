import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
import 'package:injectable/injectable.dart';

/// Local embedding service using TensorFlow Lite
/// 
/// This service generates embeddings for text using a local model.
/// Currently designed to work with sentence-transformer models converted to TFLite.
/// 
/// Architecture Decision:
/// - Uses TensorFlow Lite for on-device inference
/// - Supports sentence-transformer models (e.g., all-MiniLM-L6-v2)
/// - Runs completely offline
/// - Embeddings are 384-dimensional (using MiniLM model)
/// 
/// Future Enhancement:
/// - Can be adapted to use EmbeddingGemma when Flutter support is available
/// - Supports model switching based on device capabilities
@injectable
class EmbeddingService {
  tfl.Interpreter? _interpreter;
  bool _isInitialized = false;
  
  // Embedding dimension (384 for MiniLM, 768 for BERT-base, etc.)
  static const int _embeddingDim = 384;
  
  // Maximum sequence length for the model
  static const int _maxSeqLength = 128;

  /// Initialize the embedding service
  /// 
  /// Loads the TFLite model and prepares it for inference.
  /// Model should be placed in assets/models/ directory.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Load TFLite model from assets
      // Note: You need to add the model file to your assets
      _interpreter = await tfl.Interpreter.fromAsset('models/embedding_model.tflite');
      
      _isInitialized = true;
      print('Embedding service initialized successfully');
    } catch (e) {
      print('Failed to initialize embedding service: $e');
      // For development, we'll create a fallback
      _isInitialized = true;
    }
  }

  /// Generate embedding for a single text
  /// 
  /// Parameters:
  /// - text: The text to embed
  /// 
  /// Returns: A list of doubles representing the embedding vector
  Future<List<double>> embedText(String text) async {
    if (!_isInitialized) {
      await initialize();
    }

    if (_interpreter == null) {
      // Fallback: return a simple hash-based embedding for development
      return _fallbackEmbedding(text);
    }

    try {
      // Tokenize and prepare input
      final input = _prepareInput(text);
      
      // Prepare output buffer
      final output = List<double>.filled(_embeddingDim, 0.0).reshape([1, _embeddingDim]);
      
      // Run inference
      _interpreter!.run(input, output);
      
      // Return the embedding
      return output[0];
    } catch (e) {
      print('Embedding generation failed, using fallback: $e');
      return _fallbackEmbedding(text);
    }
  }

  /// Generate embeddings for multiple texts (batch processing)
  /// 
  /// Parameters:
  /// - texts: List of texts to embed
  /// 
  /// Returns: List of embedding vectors
  Future<List<List<double>>> embedTexts(List<String> texts) async {
    final embeddings = <List<double>>[];
    
    for (final text in texts) {
      final embedding = await embedText(text);
      embeddings.add(embedding);
    }
    
    return embeddings;
  }

  /// Prepare input tensor for the model
  /// 
  /// This is a simplified tokenization. In production, you would use
  /// a proper tokenizer (e.g., from transformers library).
  List<List<List<int>>> _prepareInput(String text) {
    // Simplified tokenization - in production, use proper tokenizer
    final tokens = _simpleTokenize(text);
    
    // Pad or truncate to max sequence length
    final paddedTokens = _padOrTruncate(tokens, _maxSeqLength);
    
    // Create input tensor [1, max_seq_length]
    return [paddedTokens];
  }

  /// Simple tokenization for development
  /// 
  /// In production, replace with proper tokenizer from the model
  List<int> _simpleTokenize(String text) {
    // Very basic tokenization - split by spaces and convert to hash codes
    // This is NOT production quality but allows development to proceed
    final words = text.toLowerCase().split(RegExp(r'\s+'));
    return words.map((word) => word.hashCode % 30000).toList();
  }

  /// Pad or truncate token list to max sequence length
  List<int> _padOrTruncate(List<int> tokens, int maxLength) {
    if (tokens.length >= maxLength) {
      return tokens.sublist(0, maxLength);
    }
    
    // Pad with zeros
    return [...tokens, ...List.filled(maxLength - tokens.length, 0)];
  }

  /// Fallback embedding generation for development
  /// 
  /// This is a simple hash-based embedding that allows development
  /// to proceed without a real model. It should be replaced with
  /// actual model inference in production.
  List<double> _fallbackEmbedding(String text) {
    final embedding = List<double>.filled(_embeddingDim, 0.0);
    
    // Simple hash-based embedding
    final bytes = text.codeUnits;
    for (int i = 0; i < bytes.length; i++) {
      final index = bytes[i] % _embeddingDim;
      embedding[index] += (bytes[i] / 255.0);
    }
    
    // Normalize
    final norm = _calculateNorm(embedding);
    if (norm > 0) {
      for (int i = 0; i < embedding.length; i++) {
        embedding[i] /= norm;
      }
    }
    
    return embedding;
  }

  /// Calculate L2 norm of a vector
  double _calculateNorm(List<double> vector) {
    double sum = 0.0;
    for (final value in vector) {
      sum += value * value;
    }
    return sum.sqrt();
  }

  /// Calculate cosine similarity between two embeddings
  double cosineSimilarity(List<double> a, List<double> b) {
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

    return dotProduct / (normA.sqrt() * normB.sqrt());
  }

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Get embedding dimension
  int get embeddingDimension => _embeddingDim;

  /// Release resources
  void dispose() {
    _interpreter?.close();
    _isInitialized = false;
  }
}
