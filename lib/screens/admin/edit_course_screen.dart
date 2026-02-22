import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

class EditCourseScreen extends StatefulWidget {
  final String courseId;
  const EditCourseScreen({super.key, required this.courseId});

  @override
  State<EditCourseScreen> createState() => _EditCourseScreenState();
}

class _EditCourseScreenState extends State<EditCourseScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  Uint8List? _imageBytes;
  String? _imageUrl;
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadCourse();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadCourse() async {
    try {
      final response = await supabase
          .from('courses')
          .select()
          .eq('id', widget.courseId)
          .single();

      setState(() {
        _titleController.text = response['title'] ?? '';
        _descriptionController.text = response['description'] ?? '';
        _imageUrl = response['image_url'];
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      setState(() => _imageBytes = bytes);
    }
  }

  Future<void> _uploadImage() async {
    if (_imageBytes == null) return;

    setState(() => _isUploading = true);

    try {
      final fileName = 'course_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bucket = supabase.storage.from('course_images');
      await bucket.uploadBinary(fileName, _imageBytes!);
      final url = bucket.getPublicUrl(fileName);

      setState(() {
        _imageUrl = url;
        _imageBytes = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Фото загружено')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }

    setState(() => _isUploading = false);
  }

  Future<void> _updateCourse() async {
    setState(() => _isUploading = true);

    try {
      await supabase.from('courses').update({
        'title': _titleController.text,
        'description': _descriptionController.text,
        'image_url': _imageUrl,
      }).eq('id', widget.courseId);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Курс обновлён')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }

    setState(() => _isUploading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Редактировать курс'),
        backgroundColor: const Color(0xFF1976D2),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Изображение курса',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),
                          if (_imageBytes != null || _imageUrl != null)
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: _imageBytes != null
                                      ? Image.memory(_imageBytes!,
                                          height: 200,
                                          width: double.infinity,
                                          fit: BoxFit.cover)
                                      : Image.network(_imageUrl!,
                                          height: 200,
                                          width: double.infinity,
                                          fit: BoxFit.cover),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: IconButton(
                                    icon: const Icon(Icons.close,
                                        color: Colors.white),
                                    style: IconButton.styleFrom(
                                        backgroundColor: Colors.black54),
                                    onPressed: () {
                                      setState(() {
                                        _imageBytes = null;
                                        _imageUrl = null;
                                      });
                                    },
                                  ),
                                ),
                              ],
                            )
                          else
                            Container(
                              height: 200,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: InkWell(
                                onTap: _pickImage,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_photo_alternate,
                                        size: 64, color: Colors.grey[400]),
                                    const SizedBox(height: 8),
                                    Text('Нажмите для добавления фото',
                                        style:
                                            TextStyle(color: Colors.grey[600])),
                                  ],
                                ),
                              ),
                            ),
                          if (_imageBytes != null) ...[
                            const SizedBox(height: 12),
                            ElevatedButton.icon(
                              onPressed: _isUploading ? null : _uploadImage,
                              icon: _isUploading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.cloud_upload),
                              label: Text(_isUploading
                                  ? 'Загрузка...'
                                  : 'Загрузить фото'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                        labelText: 'Название курса',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.title)),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                        labelText: 'Описание',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.description)),
                    maxLines: 5,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isUploading ? null : _updateCourse,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isUploading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Сохранить изменения'),
                  ),
                ],
              ),
            ),
    );
  }
}
