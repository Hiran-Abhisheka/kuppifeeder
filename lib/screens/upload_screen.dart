import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../widgets/custom_input.dart';

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  List<File> selectedFiles = [];
  bool isUploading = false;
  List<String> uploadedUrls = [];

  final supabase = Supabase.instance.client;

  // Get file type from extension
  String getFileTypeFromExtension(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) {
      return 'image';
    } else if (ext == 'pdf') {
      return 'pdf';
    } else if (['doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'].contains(ext)) {
      return 'document';
    }
    return 'file';
  }

  // Get appropriate icon for file type
  IconData getFileIcon(String ext) {
    ext = ext.toLowerCase();
    if (['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext)) return Icons.image;
    if (ext == 'pdf') return Icons.picture_as_pdf;
    if (['doc', 'docx'].contains(ext)) return Icons.description;
    if (['xls', 'xlsx'].contains(ext)) return Icons.table_chart;
    if (['ppt', 'pptx'].contains(ext)) return Icons.slideshow;
    return Icons.file_present;
  }

  Future<void> pickMultipleImages(ImageSource source) async {
    try {
      final picker = ImagePicker();
      if (source == ImageSource.gallery) {
        final pickedFiles = await picker.pickMultiImage();
        if (pickedFiles.isNotEmpty) {
          setState(() {
            selectedFiles.addAll(pickedFiles.map((f) => File(f.path)));
          });
        }
      } else {
        // For camera, just pick one image at a time
        final pickedFile = await picker.pickImage(source: source);
        if (pickedFile != null) {
          setState(() {
            selectedFiles.add(File(pickedFile.path));
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking images: $e')),
        );
      }
    }
  }

  void removeImage(int index) {
    setState(() {
      selectedFiles.removeAt(index);
    });
  }

  // Dialog for document selection guidance
  Future<void> pickDocument() async {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Select File Type'),
        content: const Text(
          'For PDF and document files (Word, Excel, PowerPoint), please:\n\n'
          '1. Convert to image/screenshot\n'
          '2. Or upload through the Gallery option\n\n'
          'This ensures compatibility with the app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              pickMultipleImages(ImageSource.gallery);
            },
            child: const Text('Select from Gallery'),
          ),
        ],
      ),
    );
  }

  Future<void> uploadRecipe() async {
    if (titleController.text.isEmpty ||
        descriptionController.text.isEmpty ||
        selectedFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Please fill all fields and select at least one image')),
      );
      return;
    }

    setState(() => isUploading = true);

    try {
      // Verify user is authenticated using SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId == null || userId.isEmpty) {
        throw Exception('User not authenticated. Please login first.');
      }

      uploadedUrls.clear();
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      // Upload all selected files
      for (int i = 0; i < selectedFiles.length; i++) {
        final file = selectedFiles[i];
        final fileName = file.path.split('/').last;
        final uploadFileName = '${timestamp}_${i}_$fileName';
        final filePath = 'recipes/$uploadFileName';

        await supabase.storage.from('content').upload(
              filePath,
              file,
              fileOptions:
                  const FileOptions(cacheControl: '3600', upsert: false),
            );

        // Get public URL
        final publicUrl =
            supabase.storage.from('content').getPublicUrl(filePath);
        uploadedUrls.add(publicUrl);
        print('Uploaded image $i: $publicUrl');
      }

      // Save recipe data to database with uploadedUrls list
      await supabase.from('posts').insert({
        'user_id': userId,
        'title': titleController.text,
        'description': descriptionController.text,
        'image_urls': uploadedUrls,
      });

      print('All images uploaded successfully! URLs: $uploadedUrls');
      print('Post saved to database!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('${selectedFiles.length} image(s) uploaded successfully!'),
          ),
        );

        // Reset form
        titleController.clear();
        descriptionController.clear();
        setState(() {
          selectedFiles.clear();
          uploadedUrls.clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isUploading = false);
      }
    }
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFE0E0E0),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Title',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                CustomInput(
                  hintText: 'Enter title',
                  controller: titleController,
                  enabled: !isUploading,
                ),
                const SizedBox(height: 16),
                const Text('Description',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                CustomInput(
                  hintText: 'Enter description',
                  maxLines: 4,
                  controller: descriptionController,
                  enabled: !isUploading,
                ),
                const SizedBox(height: 16),
                // Image grid preview
                if (selectedFiles.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: const Color(0xFFB2A4FF),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selected Images (${selectedFiles.length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                          ),
                          itemCount: selectedFiles.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.file(
                                    selectedFiles[index],
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () => removeImage(index),
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 16),
                // File picker buttons
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('Add Images:',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFB2A4FF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: isUploading
                                ? null
                                : () => pickMultipleImages(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library, size: 18),
                            label: const Text('Gallery',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFB2A4FF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: isUploading
                                ? null
                                : () => pickMultipleImages(ImageSource.camera),
                            icon: const Icon(Icons.camera_alt, size: 18),
                            label: const Text('Camera',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFB2A4FF),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                            ),
                            onPressed: isUploading
                                ? null
                                : () => pickMultipleImages(ImageSource.gallery),
                            icon:
                                const Icon(Icons.add_photo_alternate, size: 18),
                            label: const Text('Add More',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                Center(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF6C63FF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 50),
                    ),
                    onPressed: isUploading ? null : uploadRecipe,
                    child: isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Upload',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              fontSize: 16,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
