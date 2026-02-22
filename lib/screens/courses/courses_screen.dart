import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';

import '../../providers/auth_provider.dart';

class CoursesScreen extends StatefulWidget {
  const CoursesScreen({super.key});

  @override
  State<CoursesScreen> createState() => _CoursesScreenState();
}

class _CoursesScreenState extends State<CoursesScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> _courses = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  // ✅ ЗАГРУЗКА КУРСОВ С JOIN PROFILES
  Future<void> _loadCourses() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final res = await supabase
          .from('courses')
          .select('*, profiles:creator_id(full_name, avatar_url)')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _courses = res as List<dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        try {
          final res = await supabase
              .from('courses')
              .select()
              .order('created_at', ascending: false);

          setState(() {
            _courses = res as List<dynamic>;
            _isLoading = false;
          });
        } catch (e2) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Ошибка: $e2')));
          setState(() => _isLoading = false);
        }
      }
    }
  }

  // ✅ УДАЛЕНИЕ КУРСА
  Future<void> _deleteCourse(BuildContext context, dynamic course) async {
    final courseId = course['id'];
    final courseTitle = course['title'] ?? 'этот курс';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить курс?'),
        content: Text('Вы уверены, что хотите удалить "$courseTitle"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    try {
      await supabase.from('courses').delete().eq('id', courseId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Курс удалён'), backgroundColor: Colors.green),
      );
      _loadCourses();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.isAdmin;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Курсы'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () => _showCreateCourseDialog(context),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _courses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.menu_book_outlined,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text('Курсов пока нет',
                          style: TextStyle(color: Colors.grey[600])),
                      if (isAdmin) ...[
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _showCreateCourseDialog(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Создать первый курс'),
                        ),
                      ],
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadCourses,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(
                        top: 16, bottom: 80, left: 16, right: 16),
                    itemCount: _courses.length,
                    itemBuilder: (context, index) {
                      final course = _courses[index];
                      return _buildCourseCard(course, isAdmin, isDark);
                    },
                  ),
                ),
    );
  }

  // ✅ КАРТОЧКА КУРСА С ТЕНЬЮ ВОКРУГ
  Widget _buildCourseCard(dynamic course, bool isAdmin, bool isDark) {
    final title = course['title']?.toString() ?? 'Без названия';
    final description = course['description']?.toString() ?? '';

    // ✅ ЧТЕНИЕ image_url
    final imageUrl =
        course['image_url'] != null ? course['image_url'].toString() : null;

    // ✅ ЧТЕНИЕ ДАННЫХ АВТОРА ИЗ profiles
    String creatorName = 'Автор курса';
    String? creatorAvatar;

    final profiles = course['profiles'];
    if (profiles != null &&
        profiles is Map<String, dynamic> &&
        profiles.isNotEmpty) {
      creatorName = profiles['full_name']?.toString() ?? 'Автор курса';
      creatorAvatar = profiles['avatar_url']?.toString();
    }

    final courseId = course['id']?.toString() ?? '';

    // ✅ КОНТЕЙНЕР С ТЕНЬЮ ВОКРУГ КАРТОЧКИ
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black54 : Colors.black26,
            blurRadius: 8,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shadowColor: Colors.transparent,
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () => context.push('/course/$courseId'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ КАРТИНКА КУРСА 100x100
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 100,
                                height: 100,
                                color: isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[300],
                                child: const Center(
                                    child: CircularProgressIndicator()),
                              ),
                              errorWidget: (context, url, error) => Container(
                                width: 100,
                                height: 100,
                                color: isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[300],
                                child: const Icon(Icons.broken_image,
                                    size: 30, color: Colors.grey),
                              ),
                            )
                          : Container(
                              width: 100,
                              height: 100,
                              color:
                                  isDark ? Colors.grey[800] : Colors.grey[300],
                              child: const Icon(Icons.school,
                                  size: 30, color: Colors.grey),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ✅ ROW С НАЗВАНИЕМ И ИКОНКАМИ - ВСЁ ПО ВЕРХУ
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        isDark ? Colors.white : Colors.black87,
                                    height: 1.3,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // ✅ ИКОНКИ АДМИНА - ВЫРОВНЕНЫ ПО ВЕРХУ
                              if (isAdmin)
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit,
                                          size: 20, color: Colors.grey),
                                      onPressed: () => _showEditCourseDialog(
                                          context, course),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete,
                                          size: 20, color: Colors.red),
                                      onPressed: () =>
                                          _deleteCourse(context, course),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      visualDensity: VisualDensity.compact,
                                      tooltip: 'Удалить курс',
                                    ),
                                  ],
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          if (description.isNotEmpty)
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                                height: 1.3,
                              ),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(
                    color: isDark ? Colors.grey[800] : Colors.grey[300],
                    height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor:
                          isDark ? Colors.grey[700] : Colors.grey[300],
                      child: creatorAvatar != null && creatorAvatar.isNotEmpty
                          ? ClipOval(
                              child: CachedNetworkImage(
                                imageUrl: creatorAvatar,
                                width: 24,
                                height: 24,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Icon(
                                    Icons.person,
                                    size: 14,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600]),
                                errorWidget: (context, url, error) => Icon(
                                    Icons.person,
                                    size: 14,
                                    color: isDark
                                        ? Colors.grey[400]
                                        : Colors.grey[600]),
                              ),
                            )
                          : Icon(Icons.person,
                              size: 14,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      creatorName,
                      style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCreateCourseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _CreateCourseDialog(onCreated: () {
        Navigator.pop(ctx);
        _loadCourses();
      }),
    );
  }

  void _showEditCourseDialog(BuildContext context, dynamic course) {
    showDialog(
      context: context,
      builder: (ctx) => _EditCourseDialog(
        course: course,
        onUpdated: () {
          Navigator.pop(ctx);
          _loadCourses();
        },
      ),
    );
  }
}

// ✅ СОЗДАНИЕ КУРСА - ИСПРАВЛЕНА ЗАГРУЗКА КАРТИНКИ
class _CreateCourseDialog extends StatefulWidget {
  final VoidCallback onCreated;
  const _CreateCourseDialog({required this.onCreated});

  @override
  State<_CreateCourseDialog> createState() => _CreateCourseDialogState();
}

class _CreateCourseDialogState extends State<_CreateCourseDialog> {
  final supabase = Supabase.instance.client;
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String? _imageUrl;
  Uint8List? _imageBytes;
  bool _isUploading = false;
  bool _isProcessing = false;

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
      print('✅ Image uploaded: $publicUrl');
      if (mounted)
        setState(() {
          _imageUrl = publicUrl;
          _imageBytes = null;
        });
    } catch (e) {
      print('❌ Upload error: $e');
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
    if (mounted) setState(() => _isProcessing = false);
  }

  Future<void> _create() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Введите название')));
      return;
    }

    if (_imageBytes != null && _imageUrl == null) {
      await _uploadImage();
    }

    if (!mounted) return;
    setState(() => _isUploading = true);

    final user = supabase.auth.currentUser;

    try {
      print('✅ Creating course with image_url: $_imageUrl');

      await supabase.from('courses').insert({
        'title': _titleController.text,
        'description': _descController.text,
        'image_url': _imageUrl,
        'creator_id': user?.id,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        widget.onCreated();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Курс создан')));
      }
    } catch (e) {
      print('❌ Create error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
      }
    }
    setState(() => _isUploading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Создать курс'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.add_photo_alternate),
                label: Text(_imageUrl != null
                    ? 'Изменить фото'
                    : _imageBytes != null
                        ? 'Фото выбрано'
                        : 'Добавить фото'),
              ),
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
            onPressed: (_isUploading || _isProcessing) ? null : _create,
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

// ✅ РЕДАКТИРОВАНИЕ КУРСА
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
        TextEditingController(text: widget.course['title']?.toString() ?? '');
    _descController = TextEditingController(
        text: widget.course['description']?.toString() ?? '');
    _imageUrl = widget.course['image_url'] != null
        ? widget.course['image_url'].toString()
        : null;
    print('Edit dialog image_url: $_imageUrl');
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
      print('✅ Image uploaded: $publicUrl');
      if (mounted)
        setState(() {
          _imageUrl = publicUrl;
          _imageBytes = null;
        });
    } catch (e) {
      print('❌ Upload error: $e');
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

    if (_imageBytes != null && _imageUrl == null) {
      await _uploadImage();
    }

    if (!mounted) return;
    setState(() => _isUploading = true);
    try {
      print('✅ Updating course with image_url: $_imageUrl');

      await supabase.from('courses').update({
        'title': _titleController.text,
        'description': _descController.text,
        'image_url': _imageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.course['id']);

      if (mounted) {
        widget.onUpdated();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Курс обновлён')));
      }
    } catch (e) {
      print('❌ Update error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
      }
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
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: const Icon(Icons.add_photo_alternate),
                label: Text(_imageUrl != null
                    ? 'Изменить фото'
                    : _imageBytes != null
                        ? 'Фото выбрано'
                        : 'Добавить фото'),
              ),
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
