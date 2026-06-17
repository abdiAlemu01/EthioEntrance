



// ======================= exam_screen.dart =======================
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ethioentrance/features/exam/providers/exam_providers.dart';

class ExamScreen extends ConsumerStatefulWidget {
  const ExamScreen({super.key});

  @override
  ConsumerState<ExamScreen> createState() => _ExamScreenState();
}

class _ExamScreenState extends ConsumerState<ExamScreen> {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController examController = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(examProvider.notifier).fetchExams());
  }

  @override
  void dispose() {
    titleController.dispose();
    examController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exams = ref.watch(examProvider);
    final examNotifier = ref.read(examProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text("")),
      body: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 3,
          bottom: MediaQuery.of(context).viewInsets.bottom + 8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // // Exam title
            // TextField(
            //   controller: titleController,
            //   decoration: const InputDecoration(
            //     labelText: 'Exam Title',
            //     border: OutlineInputBorder(),
            //   ),
            // ),
            // const SizedBox(height: 10),

            // // Exam content
            // TextField(
            //   controller: examController,
            //   maxLines: 6,
            //   decoration: const InputDecoration(
            //     labelText: 'Exam Questions / Content',
            //     border: OutlineInputBorder(),
            //   ),
            // ),
            // const SizedBox(height: 10),

            // // Add exam button
            // ElevatedButton(
            //   onPressed: () async {
            //     final title = titleController.text.trim();
            //     final content = examController.text.trim();

            //     if (title.isEmpty || content.isEmpty) {
            //       ScaffoldMessenger.of(context).showSnackBar(
            //         const SnackBar(
            //           content: Text('Please fill all fields'),
            //         ),
            //       );
            //       return;
            //     }

            //     await examNotifier.addExam(title, content);

            //     if (examNotifier.error != null) {
            //       ScaffoldMessenger.of(context).showSnackBar(
            //         SnackBar(
            //           content: Text('Error: ${examNotifier.error}'),
            //         ),
            //       );
            //     } else {
            //       titleController.clear();
            //       examController.clear();
            //     }
            //   },
            //   child: const Text('Add Exam'),

            // ),






            const SizedBox(height: 20),
            // Show error if exists
            if (examNotifier.error != null)
              Text(
                'Error: ${examNotifier.error}',
                style: const TextStyle(color: Colors.red),
              ),

            const SizedBox(height: 20),




            // Exams list
            Expanded(
              child: exams.isEmpty
                  ? const Center(child: Text('No exams yet'))
                  : ListView.builder(
                      itemCount: exams.length,
                      itemBuilder: (context, index) {
                        final exam = exams[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            title: Text(exam.title),
                            subtitle: Text(exam.exam),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
