

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/subjects_provider.dart';

class SubjectScreen extends ConsumerStatefulWidget {
  const SubjectScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SubjectScreen> createState() => _SubjectScreenState();
}

class _SubjectScreenState extends ConsumerState<SubjectScreen> {
  final TextEditingController subjectController = TextEditingController();
  int selectedGrade = 9;

  Uint8List? pdfFile;
  Uint8List? videoFile;

  @override
  Widget build(BuildContext context) {
    final provider = ref.watch(subjectProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Subject Upload')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// Subject Input
            TextField(
              controller: subjectController,
              decoration: const InputDecoration(
                labelText: 'Subject Name (e.g. Math)',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            /// Grade Dropdown
            DropdownButton<int>(
              value: selectedGrade,
              items: const [9, 10, 11, 12]
                  .map((g) => DropdownMenuItem(
                        value: g,
                        child: Text('Grade $g'),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedGrade = value!;
                });
              },
            ),

            const SizedBox(height: 16),

            /// Upload Buttons (Mock for now)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      FilePickerResult? result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf'],
                      );
                      if (result != null && result.files.single.bytes != null) {
                        setState(() {
                          pdfFile = result.files.single.bytes;
                        });
                      }
                    },
                    child: const Text('Select PDF'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      FilePickerResult? result = await FilePicker.platform.pickFiles(
                        type: FileType.video,
                      );
                      if (result != null && result.files.single.bytes != null) {
                        setState(() {
                          videoFile = result.files.single.bytes;
                        });
                      }
                    },
                    child: const Text('Select Video'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            /// Upload Button
            ElevatedButton(
              onPressed: provider.isLoading
                  ? null
                  : () async {
                      final subjectName = subjectController.text.trim();

                      if (subjectName.isEmpty ||
                          pdfFile == null ||
                          videoFile == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('select subject, pdf, and video')),
                        );
                        return;
                      }

                      final subjectId = subjectName.toLowerCase();

                      await ref.read(subjectProvider).uploadPdfAndVideo(
                            subjectId: subjectId,
                            subjectName: subjectName,
                            grade: selectedGrade,
                            pdfFile: pdfFile!,
                            videoFile: videoFile!,
                          );
                    },
              child: provider.isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Upload'),
            ),

            const SizedBox(height: 20),

            /// Error
            if (provider.error != null)
              Text(
                provider.error!,
                style: const TextStyle(color: Colors.red),
              ),

            const SizedBox(height: 20),

            /// GRID DISPLAY (Grades Side by Side)
            Expanded(
              child: provider.subject == null
                  ? const Center(child: Text('No Data for now.'))
                  : Column(
                      children: [
                        /// Row 1: Grade 9 & 10
                        Row(
                          children: [
                            Expanded(child: _buildGradeCard(provider, 9)),
                            const SizedBox(width: 10),
                            Expanded(child: _buildGradeCard(provider, 10)),
                          ],
                        ),
                        const SizedBox(height: 10),

                        /// Row 2: Grade 11 & 12
                        Row(
                          children: [
                            Expanded(child: _buildGradeCard(provider, 11)),
                            const SizedBox(width: 10),
                            Expanded(child: _buildGradeCard(provider, 12)),
                          ],
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🎯 Beautiful Grade Card
  Widget _buildGradeCard(SubjectProvider provider, int grade) {
    final courses = provider.getCourses(grade);
    final videos = provider.getVideos(grade);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// Grade Title
          Text(
            'Grade $grade',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),

          const Divider(),

          /// Courses
          const Text('PDFs:', style: TextStyle(fontWeight: FontWeight.w600)),
          ...courses.map((e) => Text(
                '• PDF',
                style: const TextStyle(fontSize: 12),
              )),

          const SizedBox(height: 6),

          /// Videos
          const Text('Videos:', style: TextStyle(fontWeight: FontWeight.w600)),
          ...videos.map((e) => Text(
                '• Video',
                style: const TextStyle(fontSize: 12),
              )),
        ],
      ),
    );
  }
}
