import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:injectable/injectable.dart';
import '../../../core/database/objectbox/objectbox_service.dart';
import '../../../core/database/objectbox/models.dart';
import '../../../core/processing/pdf_processing_service.dart';
import '../../../core/ai/rag_service.dart';
import '../../../core/ai/embedding_service.dart';
import '../../../core/ai/text_generation_service.dart';

/// Textbook import screen with PDF processing
/// 
/// This screen allows users to:
/// 1. Import PDF textbooks
/// 2. Process PDF text extraction
/// 3. Chunk text for embedding
/// 4. Index chunks in ObjectBox with embeddings
/// 5. Manage imported textbooks
/// 
/// Architecture Decision:
/// - Completely offline processing
/// - Uses local PDF processing service
/// - Integrates with RAG service for indexing
/// - Shows processing progress to user
@injectable
class TextbookImportScreen extends ConsumerStatefulWidget {
  const TextbookImportScreen({super.key});

  @override
  ConsumerState<TextbookImportScreen> createState() => _TextbookImportScreenState();
}

class _TextbookImportScreenState extends ConsumerState<TextbookImportScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  
  final ObjectBoxService _objectBoxService = ObjectBoxService.instance;
  final PdfProcessingService _pdfProcessingService = PdfProcessingService();
  final EmbeddingService _embeddingService = EmbeddingService();
  final TextGenerationService _textGenerationService = TextGenerationService();
  late final RagService _ragService;

  String? _selectedSubjectCode;
  int? _selectedGrade;
  File? _selectedFile;
  bool _isUploading = false;
  bool _isProcessing = false;
  double _processingProgress = 0.0;
  String _processingStatus = '';
  List<Subject> _subjects = [];
  List<Textbook> _importedTextbooks = [];

  @override
  void initState() {
    super.initState();
    _ragService = RagService(
      _objectBoxService,
      _embeddingService,
      _textGenerationService,
    );
    _loadData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    await _loadSubjects();
    await _loadImportedTextbooks();
  }

  Future<void> _loadSubjects() async {
    try {
      final subjects = _objectBoxService.getAllSubjects();
      setState(() {
        _subjects = subjects;
      });
    } catch (e) {
      print('Failed to load subjects: $e');
    }
  }

  Future<void> _loadImportedTextbooks() async {
    try {
      final textbooks = _objectBoxService.getAllTextbooks();
      setState(() {
        _importedTextbooks = textbooks;
      });
    } catch (e) {
      print('Failed to load textbooks: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedFile = File(result.files.single.path!);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick file: $e')),
      );
    }
  }

  Future<void> _importTextbook() async {
    if (!_formKey.currentState!.validate() || _selectedFile == null) {
      return;
    }

    setState(() => _isUploading = true);

    try {
      // Validate PDF
      final isValid = await _pdfProcessingService.isValidPdf(_selectedFile!.path);
      if (!isValid) {
        throw Exception('Invalid PDF file');
      }

      // Get PDF metadata
      final metadata = await _pdfProcessingService.getPdfMetadata(_selectedFile!.path);

      // Create textbook entity
      final textbook = Textbook(
        title: _titleController.text.trim(),
        subjectCode: _selectedSubjectCode!,
        grade: _selectedGrade!,
        filePath: _selectedFile!.path,
        fileSize: metadata['fileSize'] as int,
        pageCount: metadata['pageCount'] as int,
        isProcessed: false,
      );

      // Save to ObjectBox
      final textbookId = _objectBoxService.insertTextbook(textbook);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Textbook imported successfully!')),
      );

      // Reset form
      _formKey.currentState!.reset();
      _titleController.clear();
      setState(() {
        _selectedFile = null;
        _selectedSubjectCode = null;
        _selectedGrade = null;
      });

      // Reload textbooks
      await _loadImportedTextbooks();

      // Ask if user wants to process the textbook
      _showProcessDialog(textbookId);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _showProcessDialog(int textbookId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Process Textbook'),
        content: const Text('Do you want to process this textbook now for AI search? This may take a few minutes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _processTextbook(textbookId);
            },
            child: const Text('Process Now'),
          ),
        ],
      ),
    );
  }

  Future<void> _processTextbook(int textbookId) async {
    setState(() {
      _isProcessing = true;
      _processingProgress = 0.0;
      _processingStatus = 'Starting...';
    });

    try {
      final textbook = _objectBoxService.getTextbook(textbookId);
      if (textbook == null) {
        throw Exception('Textbook not found');
      }

      // Step 1: Extract text
      setState(() {
        _processingStatus = 'Extracting text from PDF...';
        _processingProgress = 0.2;
      });

      final text = await _pdfProcessingService.extractTextFromPdf(textbook.filePath);

      // Step 2: Chunk text
      setState(() {
        _processingStatus = 'Chunking text...';
        _processingProgress = 0.4;
      });

      final chunks = _pdfProcessingService.chunkText(text: text);

      // Step 3: Index chunks (this will generate embeddings and store in ObjectBox)
      setState(() {
        _processingStatus = 'Generating embeddings and indexing...';
        _processingProgress = 0.6;
      });

      await _ragService.indexTextbook(
        textbookId: textbookId,
        chunks: chunks,
      );

      setState(() {
        _processingStatus = 'Complete!';
        _processingProgress = 1.0;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Textbook processed successfully!')),
      );

      await _loadImportedTextbooks();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Processing failed: $e')),
      );
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _deleteTextbook(int textbookId) async {
    try {
      _objectBoxService.deleteTextbook(textbookId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Textbook deleted successfully')),
      );
      await _loadImportedTextbooks();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Delete failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isProcessing) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Processing Textbook'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 24),
                Text(_processingStatus),
                const SizedBox(height: 16),
                LinearProgressIndicator(value: _processingProgress),
                const SizedBox(height: 8),
                Text('${(_processingProgress * 100).toInt()}%'),
              ],
            ),
          ),
        ),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Textbook Management'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Import'),
              Tab(text: 'My Textbooks'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildImportTab(),
            _buildTextbooksTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildImportTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Subject Dropdown
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'Subject',
                border: OutlineInputBorder(),
              ),
              value: _selectedSubjectCode,
              items: _subjects.map((subject) {
                return DropdownMenuItem(
                  value: subject.subjectCode,
                  child: Text(subject.name),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedSubjectCode = value);
              },
              validator: (value) {
                if (value == null) return 'Please select a subject';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Grade Dropdown
            DropdownButtonFormField<int>(
              decoration: const InputDecoration(
                labelText: 'Grade',
                border: OutlineInputBorder(),
              ),
              value: _selectedGrade,
              items: const [
                DropdownMenuItem(value: 9, child: Text('Grade 9')),
                DropdownMenuItem(value: 10, child: Text('Grade 10')),
                DropdownMenuItem(value: 11, child: Text('Grade 11')),
                DropdownMenuItem(value: 12, child: Text('Grade 12')),
              ],
              onChanged: (value) {
                setState(() => _selectedGrade = value);
              },
              validator: (value) {
                if (value == null) return 'Please select a grade';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Title Field
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Textbook Title',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // File Picker
            InkWell(
              onTap: _pickFile,
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Icon(
                      _selectedFile != null
                          ? Icons.check_circle
                          : Icons.upload_file,
                      size: 48,
                      color: _selectedFile != null ? Colors.green : Colors.grey,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _selectedFile != null
                          ? _selectedFile!.path.split('/').last
                          : 'Tap to select PDF file',
                      style: TextStyle(
                        color: _selectedFile != null
                            ? Colors.green
                            : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Import Button
            ElevatedButton(
              onPressed: _isUploading ? null : _importTextbook,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isUploading
                  ? const CircularProgressIndicator()
                  : const Text('Import Textbook'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextbooksTab() {
    if (_importedTextbooks.isEmpty) {
      return const Center(
        child: Text('No textbooks imported yet'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _importedTextbooks.length,
      itemBuilder: (context, index) {
        final textbook = _importedTextbooks[index];
        final subject = _subjects.firstWhere(
          (s) => s.subjectCode == textbook.subjectCode,
          orElse: () => Subject(name: 'Unknown', subjectCode: ''),
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(textbook.title),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Grade ${textbook.grade} • ${subject.name}'),
                Text(
                  '${textbook.pageCount} pages • ${textbook.isProcessed ? "Processed" : "Not processed"}',
                  style: TextStyle(
                    fontSize: 12,
                    color: textbook.isProcessed ? Colors.green : Colors.orange,
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!textbook.isProcessed)
                  IconButton(
                    icon: const Icon(Icons.play_arrow, color: Colors.blue),
                    onPressed: () => _processTextbook(textbook.id),
                    tooltip: 'Process for AI',
                  ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _deleteTextbook(textbook.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
