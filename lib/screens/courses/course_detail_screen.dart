import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

import '../../providers/auth_provider.dart';

class CourseDetailScreen extends StatefulWidget {
  final String courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? _course;
  List<dynamic> _modules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCourse();
  }

  Future<void> _loadCourse() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final courseRes = await supabase
          .from('courses')
          .select()
          .eq('id', widget.courseId)
          .single();
      final modulesRes = await supabase
          .from('modules')
          .select()
          .eq('course_id', widget.courseId)
          .order('order_index', ascending: true);
      if (mounted)
        setState(() {
          _course = courseRes;
          _modules = modulesRes as List<dynamic>;
          _isLoading = false;
        });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.isAdmin;

    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_course == null)
      return Scaffold(
          appBar: AppBar(title: const Text('Курс не найден')),
          body: const Center(child: Text('Курс не найден')));

    return Scaffold(
      appBar: AppBar(title: Text(_course!['title'] ?? 'Курс')),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_course!['image_url'] != null &&
                _course!['image_url'].toString().isNotEmpty)
              CachedNetworkImage(
                imageUrl: _course!['image_url'],
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_course!['title'] ?? '',
                                style: const TextStyle(
                                    fontSize: 24, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(_course!['description'] ?? '',
                                style: TextStyle(
                                    fontSize: 14, color: Colors.grey[600])),
                          ],
                        ),
                      ),
                      if (isAdmin)
                        IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () => _showEditCourseDialog(context)),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text('Модули',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  if (_modules.isEmpty) ...[
                    Card(
                      child: InkWell(
                        onTap: isAdmin
                            ? () => _showCreateModuleDialog(context)
                            : null,
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Row(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(12)),
                                child: const Icon(Icons.add,
                                    color: Colors.grey, size: 28),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                  isAdmin
                                      ? 'Добавить первый модуль'
                                      : 'Модулей пока нет',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.grey[600])),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ] else ...[
                    ..._modules
                        .map((module) => _buildModuleCard(module, isAdmin)),
                    if (isAdmin) _buildAddModuleCard(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModuleCard(dynamic module, bool isAdmin) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/lesson-player/${module['id']}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                    color: Colors.grey[800],
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.folder, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(module['title'] ?? '',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text('Модуль ${module['order_index'] ?? 0}',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              if (isAdmin)
                IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () => _showEditModuleDialog(context, module),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddModuleCard() {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _showCreateModuleDialog(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.add, color: Colors.grey, size: 28),
              ),
              const SizedBox(width: 16),
              const Text('Добавить модуль',
                  style: TextStyle(fontSize: 16, color: Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateModuleDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (ctx) => _CreateModuleDialog(
            courseId: widget.courseId,
            onCreated: () {
              Navigator.pop(ctx);
              _loadCourse();
            }));
  }

  void _showEditModuleDialog(BuildContext context, dynamic module) {
    showDialog(
        context: context,
        builder: (ctx) => _EditModuleDialog(
            module: module,
            onUpdated: () {
              Navigator.pop(ctx);
              _loadCourse();
            }));
  }

  void _showEditCourseDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (ctx) => _EditCourseDialog(
            course: _course!,
            onUpdated: () {
              Navigator.pop(ctx);
              _loadCourse();
            }));
  }
}

class _CreateModuleDialog extends StatefulWidget {
  final String courseId;
  final VoidCallback onCreated;
  const _CreateModuleDialog({required this.courseId, required this.onCreated});

  @override
  State<_CreateModuleDialog> createState() => _CreateModuleDialogState();
}

class _CreateModuleDialogState extends State<_CreateModuleDialog> {
  final supabase = Supabase.instance.client;
  final _titleController = TextEditingController();
  bool _isUploading = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Введите название')));
      return;
    }
    setState(() => _isUploading = true);
    try {
      final res = await supabase
          .from('modules')
          .select('order_index')
          .eq('course_id', widget.courseId)
          .order('order_index', ascending: false)
          .limit(1);
      int nextOrder = 1;
      if (res.isNotEmpty && res[0]['order_index'] != null)
        nextOrder = (res[0]['order_index'] as int) + 1;

      await supabase.from('modules').insert({
        'course_id': widget.courseId,
        'title': _titleController.text,
        'order_index': nextOrder,
        'created_at': DateTime.now().toIso8601String()
      });
      if (mounted) {
        widget.onCreated();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Модуль создан')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
    }
    setState(() => _isUploading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Создать модуль'),
      content: TextField(
          controller: _titleController,
          decoration: const InputDecoration(
              labelText: 'Название модуля',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.folder)),
          maxLines: 2),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        ElevatedButton(
            onPressed: _isUploading ? null : _create,
            child: _isUploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Создать')),
      ],
    );
  }
}

class _EditModuleDialog extends StatefulWidget {
  final dynamic module;
  final VoidCallback onUpdated;
  const _EditModuleDialog({required this.module, required this.onUpdated});

  @override
  State<_EditModuleDialog> createState() => _EditModuleDialogState();
}

class _EditModuleDialogState extends State<_EditModuleDialog> {
  final supabase = Supabase.instance.client;
  late TextEditingController _titleController;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.module['title'] ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _update() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Введите название')));
      return;
    }
    setState(() => _isUploading = true);
    try {
      await supabase.from('modules').update(
          {'title': _titleController.text}).eq('id', widget.module['id']);
      if (mounted) {
        widget.onUpdated();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Модуль обновлен')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
    }
    setState(() => _isUploading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Редактировать модуль'),
      content: TextField(
          controller: _titleController,
          decoration: const InputDecoration(
              labelText: 'Название модуля',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.folder)),
          maxLines: 2),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        ElevatedButton(
            onPressed: _isUploading ? null : _update,
            child: _isUploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Сохранить')),
      ],
    );
  }
}

class _EditCourseDialog extends StatefulWidget {
  final dynamic course;
  final VoidCallback onUpdated;
  const _EditCourseDialog({required this.course, required this.onUpdated});

  @override
  State<_EditCourseDialog> createState() => _EditCourseDialogState();
}

class _EditCourseDialogState extends State<_EditCourseDialog> {
  final supabase = Supabase.instance.client;
  late TextEditingController _titleController;
  late TextEditingController _descController;
  String? _imageUrl;
  Uint8List? _imageBytes;
  bool _isUploading = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.course['title'] ?? '');
    _descController =
        TextEditingController(text: widget.course['description'] ?? '');
    _imageUrl = widget.course['image_url'];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null && mounted) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _imageBytes = bytes;
          _imageUrl = null;
        });
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _uploadImage() async {
    if (_imageBytes == null || !mounted) return;
    setState(() => _isProcessing = true);
    try {
      final fileName = 'course_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage
          .from('lesson_images')
          .uploadBinary(fileName, _imageBytes!);
      final publicUrl =
          supabase.storage.from('lesson_images').getPublicUrl(fileName);
      if (mounted)
        setState(() {
          _imageUrl = publicUrl;
          _imageBytes = null;
        });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
    if (mounted) setState(() => _isProcessing = false);
  }

  Future<void> _update() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Введите название')));
      return;
    }
    if (!mounted) return;
    setState(() => _isUploading = true);
    try {
      await supabase.from('courses').update({
        'title': _titleController.text,
        'description': _descController.text,
        'image_url': _imageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.course['id']);
      if (mounted) {
        widget.onUpdated();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Курс обновлен')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
    }
    setState(() => _isUploading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Редактировать курс'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ✅ КНОПКА ВЫБОРА ФОТО
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.add_photo_alternate),
                label: Text(_imageUrl != null
                    ? 'Изменить фото'
                    : _imageBytes != null
                        ? 'Фото выбрано'
                        : 'Добавить фото'),
              ),
              // ✅ ПРЕВЬЮ
              if (_imageUrl != null || _imageBytes != null) ...[
                const SizedBox(height: 12),
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: _imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (c, u) => Container(
                                color: Colors.grey[300],
                                child: const Center(
                                    child: CircularProgressIndicator())),
                            errorWidget: (c, u, e) => Container(
                                color: Colors.grey[300],
                                child: const Center(
                                    child: Icon(Icons.broken_image))))
                        : Image.memory(_imageBytes!, fit: BoxFit.cover),
                  ),
                ),
                // ✅ КНОПКА ЗАГРУЗКИ
                if (_imageBytes != null && _imageUrl == null) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _uploadImage,
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.cloud_upload),
                    label: Text(_isProcessing ? 'Загрузка...' : 'Загрузить'),
                  ),
                ],
              ],
              const SizedBox(height: 16),
              TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                      labelText: 'Название',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.title))),
              const SizedBox(height: 16),
              TextField(
                  controller: _descController,
                  decoration: const InputDecoration(
                      labelText: 'Описание',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description)),
                  maxLines: 3),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        ElevatedButton(
            onPressed: (_isUploading || _isProcessing) ? null : _update,
            child: _isUploading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Text('Сохранить')),
      ],
    );
  }
}
