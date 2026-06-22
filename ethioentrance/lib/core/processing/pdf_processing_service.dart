import 'dart:io';
import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:injectable/injectable.dart';

/// PDF text extraction and chunking service
/// 
/// This service handles:
/// 1. Extracting text from PDF files
/// 2. Chunking text into smaller segments for embedding
/// 3. Preparing chunks for vector database storage
/// 
/// Architecture Decision:
/// - Uses Syncfusion PDF for text extraction
/// - Implements intelligent chunking with overlap
/// - Preserves paragraph structure where possible
/// - Handles Ethiopian text (Amharic, English)
/// 
/// Chunking Strategy:
/// - Chunk size: 500-1000 characters (configurable)
/// - Overlap: 100-200 characters (configurable)
/// - Respects paragraph boundaries
/// - Maintains context for better retrieval
@injectable
class PdfProcessingService {
  // Chunking parameters
  static const int _defaultChunkSize = 800;
  static const int _defaultChunkOverlap = 150;
  static const int _minChunkSize = 200;

  /// Extract text from a PDF file
  /// 
  /// Parameters:
  /// - filePath: Path to the PDF file
  /// 
  /// Returns: Extracted text as a string
  Future<String> extractTextFromPdf(String filePath) async {
    try {
      // Load the PDF document
      final File file = File(filePath);
      final List<int> bytes = await file.readAsBytes();
      
      // Load PDF using Syncfusion
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      
      // Extract text from all pages
      final String extractedText = PdfTextExtractor(document).extractText();
      
      // Dispose the document
      document.dispose();
      
      return extractedText;
    } catch (e) {
      throw Exception('Failed to extract text from PDF: $e');
    }
  }

  /// Extract text from PDF bytes
  /// 
  /// Parameters:
  /// - bytes: PDF file as bytes
  /// 
  /// Returns: Extracted text as a string
  Future<String> extractTextFromPdfBytes(Uint8List bytes) async {
    try {
      // Load PDF using Syncfusion
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      
      // Extract text from all pages
      final String extractedText = PdfTextExtractor(document).extractText();
      
      // Dispose the document
      document.dispose();
      
      return extractedText;
    } catch (e) {
      throw Exception('Failed to extract text from PDF: $e');
    }
  }

  /// Chunk text into smaller segments for embedding
  /// 
  /// Parameters:
  /// - text: The text to chunk
  /// - chunkSize: Maximum characters per chunk (default: 800)
  /// - chunkOverlap: Overlap between chunks (default: 150)
  /// 
  /// Returns: List of text chunks
  List<String> chunkText({
    required String text,
    int chunkSize = _defaultChunkSize,
    int chunkOverlap = _defaultChunkOverlap,
  }) {
    if (text.isEmpty) return [];

    // Clean the text
    final cleanedText = _cleanText(text);
    
    // Split into paragraphs
    final paragraphs = _splitIntoParagraphs(cleanedText);
    
    // Chunk paragraphs
    final chunks = <String>[];
    final currentChunk = StringBuffer();
    int currentSize = 0;

    for (int i = 0; i < paragraphs.length; i++) {
      final paragraph = paragraphs[i];
      final paragraphSize = paragraph.length;

      // If adding this paragraph exceeds chunk size
      if (currentSize + paragraphSize > chunkSize && currentChunk.isNotEmpty) {
        // Save current chunk
        chunks.add(currentChunk.toString().trim());
        
        // Start new chunk with overlap
        currentChunk.clear();
        currentSize = 0;
        
        // Add overlap from previous paragraphs
        final overlapText = _getOverlapText(paragraphs, i, chunkOverlap);
        if (overlapText.isNotEmpty) {
          currentChunk.write(overlapText);
          currentSize += overlapText.length;
        }
      }

      // Add paragraph to current chunk
      if (currentSize > 0) {
        currentChunk.write('\n\n');
        currentSize += 2;
      }
      currentChunk.write(paragraph);
      currentSize += paragraphSize;
    }

    // Add the last chunk if it has content
    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk.toString().trim());
    }

    // Filter out chunks that are too small
    return chunks.where((chunk) => chunk.length >= _minChunkSize).toList();
  }

  /// Clean extracted text
  /// 
  /// Removes extra whitespace, normalizes line breaks, etc.
  String _cleanText(String text) {
    // Remove extra whitespace
    String cleaned = text.replaceAll(RegExp(r'\s+'), ' ');
    
    // Normalize line breaks
    cleaned = cleaned.replaceAll(RegExp(r'\n\s*\n'), '\n\n');
    
    // Trim
    cleaned = cleaned.trim();
    
    return cleaned;
  }

  /// Split text into paragraphs
  /// 
  /// Respects paragraph boundaries for better chunking
  List<String> _splitIntoParagraphs(String text) {
    // Split by double newlines (paragraph breaks)
    final paragraphs = text.split(RegExp(r'\n\n'));
    
    // Filter out empty paragraphs
    return paragraphs.where((p) => p.trim().isNotEmpty).toList();
  }

  /// Get overlap text from previous paragraphs
  /// 
  /// This helps maintain context between chunks
  String _getOverlapText(List<String> paragraphs, int currentIndex, int overlapSize) {
    final overlapParts = <String>[];
    int currentSize = 0;
    
    // Go back through paragraphs to build overlap
    for (int i = currentIndex - 1; i >= 0 && currentSize < overlapSize; i--) {
      final paragraph = paragraphs[i];
      final paragraphSize = paragraph.length;
      
      if (currentSize + paragraphSize > overlapSize) {
        // Take only part of this paragraph
        final remainingSpace = overlapSize - currentSize;
        overlapParts.insert(0, paragraph.substring(paragraph.length - remainingSpace));
        currentSize = overlapSize;
      } else {
        // Add entire paragraph
        overlapParts.insert(0, paragraph);
        if (overlapParts.isNotEmpty) {
          overlapParts.insert(0, '\n\n');
        }
        currentSize += paragraphSize + 2;
      }
      
      if (currentSize >= overlapSize) break;
    }
    
    return overlapParts.join().trim();
  }

  /// Process a PDF file completely
  /// 
  /// This is a convenience method that:
  /// 1. Extracts text from PDF
  /// 2. Chunks the text
  /// 3. Returns the chunks ready for embedding
  /// 
  /// Parameters:
  /// - filePath: Path to the PDF file
  /// - chunkSize: Maximum characters per chunk
  /// - chunkOverlap: Overlap between chunks
  /// 
  /// Returns: List of text chunks
  Future<List<String>> processPdf({
    required String filePath,
    int chunkSize = _defaultChunkSize,
    int chunkOverlap = _defaultChunkOverlap,
  }) async {
    // Extract text
    final text = await extractTextFromPdf(filePath);
    
    // Chunk text
    final chunks = chunkText(
      text: text,
      chunkSize: chunkSize,
      chunkOverlap: chunkOverlap,
    );
    
    return chunks;
  }

  /// Process PDF bytes completely
  /// 
  /// Same as processPdf but works with bytes instead of file path
  Future<List<String>> processPdfBytes({
    required Uint8List bytes,
    int chunkSize = _defaultChunkSize,
    int chunkOverlap = _defaultChunkOverlap,
  }) async {
    // Extract text
    final text = await extractTextFromPdfBytes(bytes);
    
    // Chunk text
    final chunks = chunkText(
      text: text,
      chunkSize: chunkSize,
      chunkOverlap: chunkOverlap,
    );
    
    return chunks;
  }

  /// Get PDF metadata
  /// 
  /// Parameters:
  /// - filePath: Path to the PDF file
  /// 
  /// Returns: Map containing page count, title, etc.
  Future<Map<String, dynamic>> getPdfMetadata(String filePath) async {
    try {
      final File file = File(filePath);
      final List<int> bytes = await file.readAsBytes();
      
      final PdfDocument document = PdfDocument(inputBytes: bytes);
      
      final metadata = <String, dynamic>{
        'pageCount': document.pages.count,
        'fileSize': file.lengthSync(),
        'title': document.documentInformation.title ?? '',
        'author': document.documentInformation.author ?? '',
        'subject': document.documentInformation.subject ?? '',
      };
      
      document.dispose();
      
      return metadata;
    } catch (e) {
      throw Exception('Failed to get PDF metadata: $e');
    }
  }

  /// Estimate reading time for text
  /// 
  /// Parameters:
  /// - text: The text to analyze
  /// - wordsPerMinute: Average reading speed (default: 200)
  /// 
  /// Returns: Estimated reading time in minutes
  double estimateReadingTime(String text, {int wordsPerMinute = 200}) {
    final wordCount = text.split(RegExp(r'\s+')).length;
    return wordCount / wordsPerMinute;
  }

  /// Validate PDF file
  /// 
  /// Parameters:
  /// - filePath: Path to the PDF file
  /// 
  /// Returns: True if valid, false otherwise
  Future<bool> isValidPdf(String filePath) async {
    try {
      final File file = File(filePath);
      if (!await file.exists()) return false;
      
      final bytes = await file.readAsBytes();
      if (bytes.length < 4) return false;
      
      // Check PDF signature
      final signature = String.fromCharCodes(bytes.sublist(0, 4));
      return signature == '%PDF';
    } catch (e) {
      return false;
    }
  }
}
