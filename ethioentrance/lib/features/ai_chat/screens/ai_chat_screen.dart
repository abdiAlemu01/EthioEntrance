

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../providers/chat_provider.dart';
import '../../../core/database/objectbox/objectbox_service.dart';
import '../../../core/ai/rag_service.dart';
import '../../../core/ai/embedding_service.dart';
import '../../../core/ai/text_generation_service.dart';

class AiResponsePage extends StatefulWidget {
  const AiResponsePage({super.key});

  @override
  State<AiResponsePage> createState() => _AiResponsePageState();
}

class _AiResponsePageState extends State<AiResponsePage> {
  final TextEditingController _promptController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _messages = []; // {role: 'user/ai', text: '...', sources: []}
  bool _isLoading = false;
  String? _errorMessage;
  
  // Simple ChatProvider instance (in production, use dependency injection)
  late final ChatProvider _chatProvider;

  @override
  void initState() {
    super.initState();
    _chatProvider = ChatProvider(
      RagService(
        ObjectBoxService.instance,
        EmbeddingService(),
        TextGenerationService(),
      ),
    );
    _initializeChat();
  }

  Future<void> _initializeChat() async {
    final userId = Supabase.instance.client.auth.currentSession?.user.id;
    if (userId != null) {
      _chatProvider.setUserContext(userId: userId);
      await _chatProvider.initialize();
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendPrompt() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty) {
      setState(() => _errorMessage = 'Please enter a question.');
      return;
    }

    setState(() {
      _errorMessage = null;
      _isLoading = true;
      _messages.add({'role': 'user', 'text': prompt});
      _promptController.clear();
    });

    // Scroll to bottom when user sends a question
    _scrollToBottom();

    try {
      final response = await _chatProvider.askQuestion(question: prompt);

      setState(() {
        _messages.add({
          'role': 'ai',
          'text': response.answer,
          'sources': response.sources.map((s) => s.toJson()).toList(),
        });
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add({'role': 'ai', 'text': 'Failed to get AI response.', 'sources': []});
      });
      print('AI Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Chat messages
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                color: Colors.grey.shade100,
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isUser = msg['role'] == 'user';
                    final sources = msg['sources'] as List<dynamic>? ?? [];
                    
                    return Column(
                      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            padding: const EdgeInsets.all(12),
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                            decoration: BoxDecoration(
                              color: isUser ? Colors.blue.shade600 : Colors.grey.shade200,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(12),
                                topRight: const Radius.circular(12),
                                bottomLeft: Radius.circular(isUser ? 12 : 0),
                                bottomRight: Radius.circular(isUser ? 0 : 12),
                              ),
                            ),
                            child: Text(
                              msg['text']!,
                              style: TextStyle(
                                color: isUser ? Colors.white : Colors.black87,
                                fontSize: 16,
                              ),
                            ),
                          ),
                        ),
                        // Display sources for AI responses
                        if (!isUser && sources.isNotEmpty)
                          Container(
                            margin: const EdgeInsets.only(left: 8, bottom: 8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.source, size: 16, color: Colors.green.shade700),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Sources',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.green.shade700,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ...sources.map((source) {
                                  final sourceMap = source as Map<String, dynamic>;
                                  return Padding(
                                    padding: const EdgeInsets.only(left: 8, top: 2),
                                    child: Text(
                                      '• ${sourceMap['textbook'] ?? 'Unknown'} (Grade ${sourceMap['grade'] ?? '?'})',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // Error message
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),

            // Input field & send button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _promptController,
                      minLines: 1,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Ask me anything...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: IconButton(
                            icon: const Icon(Icons.send, color: Colors.white),
                            onPressed: _sendPrompt,
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
