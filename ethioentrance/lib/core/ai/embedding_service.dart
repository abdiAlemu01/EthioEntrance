// embedding_service.dart


import 'dart:math';
import 'dart:io';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Local embedding service using FlutterGemma (EmbeddingGemma)
/// 
/// This service generates embeddings for text using EmbeddingGemma model.
/// 
/// Architecture Decision:
/// - Uses FlutterGemmaEmbedder for on-device inference
/// - Uses EmbeddingGemma-300M model from HuggingFace
/// - Runs completely offline after model download
/// - Embeddings are 768-dimensional (EmbeddingGemma-300M)
/// - Singleton pattern for efficient resource management
/// 
/// Model:
/// - Model: embeddinggemma-300M_seq256_mixed-precision.tflite
/// - Sequence length: 256
/// - Precision: Mixed-precision for better performance
/// - Backend: GPU preferred, falls back to CPU

class EmbeddingService {
  static final EmbeddingService _instance = EmbeddingService._internal();
  factory EmbeddingService() => _instance;
  EmbeddingService._internal();

  bool _isInitialized = false;
  bool _isModelInstalled = false;
  
  // Embedding dimension for EmbeddingGemma-300M
  static const int _embeddingDim = 768;

  /// Initialize the embedding service
  /// 
  /// Checks if the model is installed, and if not, downloads it.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check if embedder is already installed
      _isModelInstalled = await FlutterGemma.hasActiveEmbedder();
      
      if (!_isModelInstalled) {
        print("EmbeddingGemma model not installed. Downloading...");
        await _downloadModel();
      } else {
        print("EmbeddingGemma model already installed.");
      }
      
      _isInitialized = true;
      print('Embedding service initialized successfully');
    } catch (e) {
      print('Failed to initialize embedding service: $e');
      _isInitialized = true; // Allow fallback to hash-based embedding
    }
  }

  /// Download EmbeddingGemma model from HuggingFace
  Future<void> _downloadModel() async {
    try {
      print("Installing EmbeddingGemma onto local device storage...");
      
      // Use FlutterGemma's built-in installer
      await FlutterGemma.installEmbedder()
        .modelFromNetwork(
          'https://huggingface.co/litert-community/embeddinggemma-300m/resolve/main/embeddinggemma-300M_seq256_mixed-precision.tflite'
        )
        .tokenizerFromNetwork(
          'https://huggingface.co/litert-community/embeddinggemma-300m/resolve/main/sentencepiece.model'
        )
        .install();

      print("EmbeddingGemma successfully downloaded and ready for offline use.");
      _isModelInstalled = true;
    } catch (e) {
      print("Failed to download or initialize the embedding files: $e");
      rethrow;
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

    if (!_isModelInstalled) {
      // Fallback: return a simple hash-based embedding
      return _fallbackEmbedding(text);
    }

    try {
      // Use FlutterGemma to generate embedding
      final embedder = await FlutterGemma.getActiveEmbedder();
      final embedding = await embedder.encode(text);
      return embedding;
    } catch (e) {
      print("Embedding generation failed, using fallback: $e");
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
    if (!_isInitialized) {
      await initialize();
    }

    if (!_isModelInstalled) {
      final embeddings = <List<double>>[];
      for (final text in texts) {
        final embedding = await embedText(text);
        embeddings.add(embedding);
      }
      return embeddings;
    }

    try {
      // Use FlutterGemma batch embedding
      final embedder = await FlutterGemma.getActiveEmbedder();
      final embeddings = await embedder.batchEncode(texts);
      return embeddings;
    } catch (e) {
      print("Batch embedding failed, using sequential fallback: $e");
      final embeddings = <List<double>>[];
      for (final text in texts) {
        final embedding = await embedText(text);
        embeddings.add(embedding);
      }
      return embeddings;
    }
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
    return sqrt(sum);
  }

  /// Calculate cosine similarity between two embeddings
  double cosineSimilarity(List<double> a, List<double> b) {
    if (_isModelInstalled) {
      try {
        // Use FlutterGemma's built-in cosine similarity
        final aNorm = _normalize(a);
        final bNorm = _normalize(b);
        double dotProduct = 0.0;
        for (int i = 0; i < aNorm.length; i++) {
          dotProduct += aNorm[i] * bNorm[i];
        }
        return dotProduct;
      } catch (e) {
        print("Model cosine similarity failed, using manual calculation: $e");
      }
    }
    
    // Manual calculation as fallback
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

    return dotProduct / (sqrt(normA) * sqrt(normB));
  }

  /// Normalize a vector
  List<double> _normalize(List<double> vector) {
    double norm = 0.0;
    for (final v in vector) {
      norm += v * v;
    }
    norm = sqrt(norm);
    if (norm == 0) return List.from(vector);
    return vector.map((v) => v / norm).toList();
  }

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Check if model is installed
  bool get isModelInstalled => _isModelInstalled;

  /// Get embedding dimension
  int get embeddingDimension => _embeddingDim;

  /// Release resources
  void dispose() {
    _isInitialized = false;
  }
}
