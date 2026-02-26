import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:async';

import '../../providers/auth_provider.dart';
import 'section_create_dialog.dart';
import 'section_edit_dialog.dart';

class CourseDetailScreen extends StatefulWidget {
  final String courseId;
  const CourseDetailScreen({super.key, required this.courseId});

  @override
  State<CourseDetailScreen> createState() => _CourseDetailScreenState();
}

class _CourseDetailScreenState extends State<CourseDetailScreen> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? _course;
  List<dynamic> _sections = [];
  List<dynamic> _modules = [];
  Map<String, bool> _completedModules = {};
  bool _isLoading = true;
  StreamSubscription? _moduleSubscription;

  @override
  void initState() {
    super.initState();
    _loadCourse();
    _setupRealTimeUpdates();
  }

  @override
  void dispose() {
    _moduleSubscription?.cancel();
    super.dispose();
  }

  void _setupRealTimeUpdates() {
    _moduleSubscription = supabase
        .from('module_completions')
        .stream(primaryKey: ['id']).listen((updates) {
      if (mounted) {
        _loadCourse();
      }
    });
  }

  Future<void> _loadCourse() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final auth = context.read<AuthProvider>();
      final userId = auth.user?.id;

      final courseRes = await supabase
          .from('courses')
          .select()
          .eq('id', widget.courseId)
          .single();

      final sectionsRes = await supabase
          .from('sections')
          .select()
          .eq('course_id', widget.courseId)
          .order('order_index', ascending: true);

      final modulesRes = await supabase
          .from('modules')
          .select()
          .eq('course_id', widget.courseId)
          .order('order_index', ascending: true);

      Map<String, bool> completedMap = {};
      if (userId != null) {
        final moduleIds =
            (modulesRes as List).map((m) => m['id'].toString()).toList();
        if (moduleIds.isNotEmpty) {
          final completionsRes = await supabase
              .from('module_completions')
              .select('module_id, completed')
              .filter('module_id', 'in', '(${moduleIds.join(',')})')
              .eq('user_id', userId);

          for (var completion in completionsRes as List) {
            completedMap[completion['module_id'].toString()] =
                completion['completed'] == true;
          }
        }
      }

      if (mounted) {
        setState(() {
          _course = courseRes;
          _sections = sectionsRes as List<dynamic>;
          _modules = modulesRes as List<dynamic>;
          _completedModules = completedMap;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  bool _isModuleAccessible(dynamic module, bool isAdmin) {
    if (isAdmin) return true;

    final moduleId = module['id'].toString();
    final sectionId = module['section_id']?.toString();

    if (sectionId == null) {
      final modulesWithoutSection = _modules
          .where((m) => m['section_id'] == null)
          .toList()
        ..sort((a, b) =>
            (a['order_index'] as int).compareTo(b['order_index'] as int));

      if (modulesWithoutSection.isEmpty) return true;

      final currentIndex = modulesWithoutSection
          .indexWhere((m) => m['id'].toString() == moduleId);

      if (currentIndex == 0) return true;

      for (int i = 0; i < currentIndex; i++) {
        final prevModuleId = modulesWithoutSection[i]['id'].toString();
        if (_completedModules[prevModuleId] != true) {
          return false;
        }
      }

      return true;
    }

    final sectionModules = _modules
        .where((m) => m['section_id'] == sectionId)
        .toList()
      ..sort((a, b) =>
          (a['order_index'] as int).compareTo(b['order_index'] as int));

    if (sectionModules.isEmpty) return true;

    if (moduleId == sectionModules.first['id'].toString()) {
      return _isPreviousSectionCompleted(sectionId, isAdmin);
    }

    int currentIndex =
        sectionModules.indexWhere((m) => m['id'].toString() == moduleId);
    if (currentIndex > 0) {
      final prevModuleId = sectionModules[currentIndex - 1]['id'].toString();
      if (_completedModules[prevModuleId] != true) {
        return false;
      }
    }

    return _isPreviousSectionCompleted(sectionId, isAdmin);
  }

  bool _isPreviousSectionCompleted(String sectionId, bool isAdmin) {
    if (isAdmin) return true;

    final sectionIndex =
        _sections.indexWhere((s) => s['id'].toString() == sectionId);

    if (sectionIndex <= 0) return true;

    final prevSectionId = _sections[sectionIndex - 1]['id'].toString();
    final prevSectionModules =
        _modules.where((m) => m['section_id'] == prevSectionId).toList();

    for (var module in prevSectionModules) {
      if (_completedModules[module['id'].toString()] != true) {
        return false;
      }
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.isAdmin;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_course == null)
      return Scaffold(
          appBar: AppBar(title: const Text('Курс не найден')),
          body: const Center(child: Text('Курс не найден')));

    final coverImageUrl = _course!['cover_image_url']?.toString() ??
        _course!['image_url']?.toString();

    return Scaffold(
      appBar: AppBar(
        title: Text(_course!['title'] ?? 'Курс'),
        actions: [
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => _showEditCourseDialog(context),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (coverImageUrl != null && coverImageUrl.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: coverImageUrl,
                    width: double.infinity,
                    fit: BoxFit.fitWidth,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: const Center(
                          child: Icon(Icons.broken_image,
                              size: 50, color: Colors.grey)),
                    ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_course!['description'] ?? '',
                      style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white : Colors.black)),
                  const SizedBox(height: 24),
                  if (isAdmin)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _showCreateSectionDialog(context),
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Добавить раздел'),
                        style: TextButton.styleFrom(
                          foregroundColor:
                              isDark ? Colors.blue[400] : Colors.blue,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  if (_sections.isEmpty) ...[
                    ..._buildModulesWithoutSections(isAdmin, isDark),
                  ] else ...[
                    ..._sections.map((section) =>
                        _buildSectionCard(section, isAdmin, isDark)),
                    ..._buildModulesWithoutSections(isAdmin, isDark),
                  ],
                  if (_sections.isEmpty && isAdmin) _buildAddModuleCard(isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildModulesWithoutSections(bool isAdmin, bool isDark) {
    final modulesWithoutSection = _modules
        .where((m) => m['section_id'] == null)
        .toList()
      ..sort((a, b) =>
          (a['order_index'] as int).compareTo(b['order_index'] as int));

    if (modulesWithoutSection.isEmpty) {
      return [];
    }

    int moduleCounter = 1;

    return [
      ...modulesWithoutSection.map((module) {
        final widget = _buildModuleCard(
          module,
          isAdmin,
          isDark,
          moduleNumber: moduleCounter,
        );
        moduleCounter++;
        return widget;
      }),
    ];
  }

  Widget _buildSectionCard(dynamic section, bool isAdmin, bool isDark) {
    final sectionId = section['id'].toString();
    final sectionTitle = section['title']?.toString() ?? 'Без названия';
    final sectionDescription = section['description']?.toString();
    final sectionModules = _modules
        .where((m) => m['section_id'] == sectionId)
        .toList()
      ..sort((a, b) =>
          (a['order_index'] as int).compareTo(b['order_index'] as int));

    bool isSectionCompleted = sectionModules.isNotEmpty &&
        sectionModules
            .every((m) => _completedModules[m['id'].toString()] == true);

    int moduleCounter = 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSectionCompleted
                      ? (isDark ? Colors.green[900] : Colors.green[100])
                      : (isDark ? Colors.blue[900] : Colors.blue[100]),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  sectionTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isSectionCompleted
                        ? (isDark ? Colors.green[400] : Colors.green[700])
                        : (isDark ? Colors.blue[400] : Colors.blue[700]),
                  ),
                ),
              ),
              const Spacer(),
              if (isAdmin)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit,
                          size: 20,
                          color: isDark ? Colors.grey[400] : Colors.grey),
                      onPressed: () => _showEditSectionDialog(context, section),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Редактировать раздел',
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          size: 20, color: Colors.red[400]),
                      onPressed: () => _deleteSection(context, section),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Удалить раздел',
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(Icons.add, size: 20, color: Colors.blue[400]),
                      onPressed: () =>
                          _showCreateModuleDialog(context, sectionId),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Добавить модуль',
                    ),
                  ],
                ),
            ],
          ),
          if (sectionDescription != null && sectionDescription.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              sectionDescription,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (sectionModules.isEmpty)
            Card(
              color: isDark ? Colors.grey[800] : Colors.grey[100],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.folder_outlined,
                        color: isDark ? Colors.grey[400] : Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'В этом разделе пока нет модулей',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                    const Spacer(),
                    if (isAdmin)
                      TextButton(
                        onPressed: () =>
                            _showCreateModuleDialog(context, sectionId),
                        child: const Text('Добавить модуль'),
                      ),
                  ],
                ),
              ),
            )
          else
            ...sectionModules.map((module) {
              final widget = _buildModuleCard(
                module,
                isAdmin,
                isDark,
                moduleNumber: moduleCounter,
              );
              moduleCounter++;
              return widget;
            }),
        ],
      ),
    );
  }

  Widget _buildModuleCard(dynamic module, bool isAdmin, bool isDark,
      {required int moduleNumber}) {
    final moduleId = module['id'].toString();
    final isCompleted = _completedModules[moduleId] == true;
    final isAccessible = _isModuleAccessible(module, isAdmin);
    final imageUrl = module['image_url']?.toString();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? Colors.grey[800] : Colors.white,
      child: InkWell(
        onTap: isAccessible || isAdmin
            ? () => context.push('/lesson-player/$moduleId')
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isAccessible
                      ? (isDark ? Colors.grey[700] : Colors.grey[800])
                      : (isDark ? Colors.grey[900] : Colors.grey[300]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    imageUrl != null && imageUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: CachedNetworkImage(
                              imageUrl: imageUrl,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Icon(
                                isAccessible ? Icons.folder : Icons.lock,
                                color: isAccessible
                                    ? Colors.white
                                    : (isDark
                                        ? Colors.grey[600]
                                        : Colors.grey[400]),
                                size: 28,
                              ),
                              errorWidget: (context, url, error) => Icon(
                                isAccessible ? Icons.folder : Icons.lock,
                                color: isAccessible
                                    ? Colors.white
                                    : (isDark
                                        ? Colors.grey[600]
                                        : Colors.grey[400]),
                                size: 28,
                              ),
                            ),
                          )
                        : Icon(
                            isAccessible ? Icons.folder : Icons.lock,
                            color: isAccessible
                                ? Colors.white
                                : (isDark
                                    ? Colors.grey[600]
                                    : Colors.grey[400]),
                            size: 28,
                          ),
                    if (isCompleted)
                      Container(
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 0, 0, 0)
                              .withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check,
                          color: Colors.green,
                          size: 32,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      module['title'] ?? '',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isAccessible
                            ? (isDark ? Colors.white : Colors.black)
                            : (isDark ? Colors.grey[600] : Colors.grey[400]),
                      ),
                    ),
                    Text(
                      'Модуль $moduleNumber',
                      style: TextStyle(
                        fontSize: 12,
                        color: isAccessible
                            ? (isDark ? Colors.grey[400] : Colors.grey[600])
                            : (isDark ? Colors.grey[700] : Colors.grey[400]),
                      ),
                    ),
                  ],
                ),
              ),
              if (isAdmin)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.edit,
                          size: 20,
                          color: isDark ? Colors.grey[400] : Colors.grey),
                      onPressed: () => _showEditModuleDialog(context, module),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          size: 20, color: Colors.red[400]),
                      onPressed: () => _deleteModule(context, module),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Удалить модуль',
                    ),
                  ],
                ),
              Icon(
                isAccessible ? Icons.chevron_right : Icons.lock,
                color: isAccessible
                    ? (isDark ? Colors.grey[400] : Colors.grey)
                    : (isDark ? Colors.grey[700] : Colors.grey[300]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteSection(BuildContext context, dynamic section) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        title: const Text('Удалить раздел?'),
        content: Text(
          'Вы уверены что хотите удалить раздел "${section['title']}"?\n\nМодули в этом разделе не будут удалены.',
        ),
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
      await supabase
          .from('modules')
          .update({'section_id': null}).eq('section_id', section['id']);

      await supabase.from('sections').delete().eq('id', section['id']);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Раздел удалён'),
          backgroundColor: Colors.green,
        ),
      );

      _loadCourse();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteModule(BuildContext context, dynamic module) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        title: const Text('Удалить модуль?'),
        content: Text(
          'Вы уверены что хотите удалить модуль "${module['title']}"?\n\nВсе уроки в этом модуле будут удалены.',
        ),
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
      await supabase.from('lessons').delete().eq('module_id', module['id']);

      await supabase.from('modules').delete().eq('id', module['id']);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Модуль удалён'),
          backgroundColor: Colors.green,
        ),
      );

      _loadCourse();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Widget _buildAddModuleCard(bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? Colors.grey[800] : Colors.white,
      child: InkWell(
        onTap: () => _showCreateModuleDialog(context, null),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.add,
                    color: isDark ? Colors.grey[400] : Colors.grey, size: 28),
              ),
              const SizedBox(width: 16),
              Text('Добавить модуль',
                  style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.grey[400] : Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateSectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => SectionCreateDialog(
        courseId: widget.courseId,
        onCreated: () {
          Navigator.pop(ctx);
          _loadCourse();
        },
      ),
    );
  }

  void _showEditSectionDialog(BuildContext context, dynamic section) {
    showDialog(
      context: context,
      builder: (ctx) => SectionEditDialog(
        section: section,
        onUpdated: () {
          Navigator.pop(ctx);
          _loadCourse();
        },
        onDeleted: () {
          Navigator.pop(ctx);
          _loadCourse();
        },
      ),
    );
  }

  void _showCreateModuleDialog(BuildContext context, String? sectionId) {
    showDialog(
      context: context,
      builder: (ctx) => _CreateModuleDialog(
        courseId: widget.courseId,
        sectionId: sectionId,
        onCreated: () {
          Navigator.pop(ctx);
          _loadCourse();
        },
      ),
    );
  }

  void _showEditModuleDialog(BuildContext context, dynamic module) {
    showDialog(
      context: context,
      builder: (ctx) => _EditModuleDialog(
        module: module,
        onUpdated: () {
          Navigator.pop(ctx);
          _loadCourse();
        },
        onDeleted: () {
          Navigator.pop(ctx);
          _loadCourse();
        },
      ),
    );
  }

  void _showEditCourseDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => _EditCourseDialog(
        course: _course!,
        onUpdated: () {
          Navigator.pop(ctx);
          _loadCourse();
        },
      ),
    );
  }
}

class _CreateModuleDialog extends StatefulWidget {
  final String courseId;
  final String? sectionId;
  final VoidCallback onCreated;
  const _CreateModuleDialog({
    required this.courseId,
    this.sectionId,
    required this.onCreated,
  });

  @override
  State<_CreateModuleDialog> createState() => _CreateModuleDialogState();
}

class _CreateModuleDialogState extends State<_CreateModuleDialog> {
  final supabase = Supabase.instance.client;
  final _titleController = TextEditingController();
  String? _imageUrl;
  Uint8List? _imageBytes;
  bool _isUploading = false;
  bool _isProcessing = false;

  @override
  void dispose() {
    _titleController.dispose();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<void> _uploadImage() async {
    if (_imageBytes == null || !mounted) return;
    setState(() => _isProcessing = true);
    try {
      final fileName = 'module_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage
          .from('lesson_images')
          .uploadBinary(fileName, _imageBytes!);
      final publicUrl =
          supabase.storage.from('lesson_images').getPublicUrl(fileName);
      if (mounted) {
        setState(() {
          _imageUrl = publicUrl;
          _imageBytes = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
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
        'section_id': widget.sectionId,
        'title': _titleController.text,
        'image_url': _imageUrl,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: isDark ? Colors.grey[800] : Colors.white,
      title: Text(
        widget.sectionId != null
            ? 'Добавить модуль в раздел'
            : 'Добавить модуль',
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
      ),
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
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: _imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (c, u) => Container(
                              color: Colors.grey[300],
                              child: const Center(
                                  child: CircularProgressIndicator()),
                            ),
                            errorWidget: (c, u, e) => Container(
                              color: Colors.grey[300],
                              child:
                                  const Center(child: Icon(Icons.broken_image)),
                            ),
                          )
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
                autofocus: true,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'Название модуля',
                  labelStyle:
                      TextStyle(color: isDark ? Colors.grey[400] : Colors.grey),
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.folder,
                      color: isDark ? Colors.grey[400] : Colors.grey),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена',
                style:
                    TextStyle(color: isDark ? Colors.grey[400] : Colors.grey))),
        ElevatedButton(
          onPressed: (_isUploading || _isProcessing) ? null : _create,
          child: _isUploading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Создать'),
        ),
      ],
    );
  }
}

class _EditModuleDialog extends StatefulWidget {
  final dynamic module;
  final VoidCallback onUpdated;
  final VoidCallback onDeleted;
  const _EditModuleDialog({
    required this.module,
    required this.onUpdated,
    required this.onDeleted,
  });

  @override
  State<_EditModuleDialog> createState() => _EditModuleDialogState();
}

class _EditModuleDialogState extends State<_EditModuleDialog> {
  final supabase = Supabase.instance.client;
  late TextEditingController _titleController;
  String? _imageUrl;
  Uint8List? _imageBytes;
  bool _isUploading = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.module['title'] ?? '');
    _imageUrl = widget.module['image_url']?.toString();
  }

  @override
  void dispose() {
    _titleController.dispose();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
    }
  }

  Future<void> _uploadImage() async {
    if (_imageBytes == null || !mounted) return;
    setState(() => _isProcessing = true);
    try {
      final fileName = 'module_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage
          .from('lesson_images')
          .uploadBinary(fileName, _imageBytes!);
      final publicUrl =
          supabase.storage.from('lesson_images').getPublicUrl(fileName);
      if (mounted) {
        setState(() {
          _imageUrl = publicUrl;
          _imageBytes = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e')),
        );
      }
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

    setState(() => _isUploading = true);
    try {
      await supabase.from('modules').update({
        'title': _titleController.text,
        'image_url': _imageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.module['id']);
      if (mounted) {
        widget.onUpdated();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Модуль обновлён')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
    }
    setState(() => _isUploading = false);
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        title: const Text('Удалить модуль?'),
        content: Text(
            'Вы уверены что хотите удалить модуль "${widget.module['title']}"?'),
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
      await supabase
          .from('lessons')
          .delete()
          .eq('module_id', widget.module['id']);
      await supabase.from('modules').delete().eq('id', widget.module['id']);

      if (!mounted) return;
      widget.onDeleted();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Модуль удалён'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: isDark ? Colors.grey[800] : Colors.white,
      title: Text('Редактировать модуль',
          style: TextStyle(color: isDark ? Colors.white : Colors.black)),
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
                  aspectRatio: 1,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: _imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (c, u) => Container(
                              color: Colors.grey[300],
                              child: const Center(
                                  child: CircularProgressIndicator()),
                            ),
                            errorWidget: (c, u, e) => Container(
                              color: Colors.grey[300],
                              child:
                                  const Center(child: Icon(Icons.broken_image)),
                            ),
                          )
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
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'Название модуля',
                  labelStyle:
                      TextStyle(color: isDark ? Colors.grey[400] : Colors.grey),
                  border: const OutlineInputBorder(),
                  prefixIcon: Icon(Icons.folder,
                      color: isDark ? Colors.grey[400] : Colors.grey),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Удалить модуль'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена',
                style:
                    TextStyle(color: isDark ? Colors.grey[400] : Colors.grey))),
        ElevatedButton(
          onPressed: (_isUploading || _isProcessing) ? null : _update,
          child: _isUploading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const Text('Сохранить'),
        ),
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
  String? _coverImageUrl;
  Uint8List? _imageBytes;
  Uint8List? _coverImageBytes;
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
    _coverImageUrl = widget.course['cover_image_url'];
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

  Future<void> _pickCoverImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null && mounted) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          _coverImageBytes = bytes;
          _coverImageUrl = null;
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
      if (mounted) {
        setState(() {
          _imageUrl = publicUrl;
          _imageBytes = null;
        });
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
    if (mounted) setState(() => _isProcessing = false);
  }

  Future<void> _uploadCoverImage() async {
    if (_coverImageBytes == null || !mounted) return;
    setState(() => _isProcessing = true);
    try {
      final fileName =
          'course_cover_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage
          .from('lesson_images')
          .uploadBinary(fileName, _coverImageBytes!);
      final publicUrl =
          supabase.storage.from('lesson_images').getPublicUrl(fileName);
      if (mounted) {
        setState(() {
          _coverImageUrl = publicUrl;
          _coverImageBytes = null;
        });
      }
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
      if (_imageBytes != null && _imageUrl == null) {
        await _uploadImage();
      }
      if (_coverImageBytes != null && _coverImageUrl == null) {
        await _uploadCoverImage();
      }

      await supabase.from('courses').update({
        'title': _titleController.text,
        'description': _descController.text,
        'image_url': _imageUrl,
        'cover_image_url': _coverImageUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.course['id']);
      if (mounted) {
        widget.onUpdated();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Курс обновлён')));
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      backgroundColor: isDark ? Colors.grey[800] : Colors.white,
      title: Text('Редактировать курс',
          style: TextStyle(color: isDark ? Colors.white : Colors.black)),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Фото для карточки',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _pickImage,
                icon: Icon(Icons.add_photo_alternate,
                    color: isDark ? Colors.white : Colors.black),
                label: Text(_imageUrl != null
                    ? 'Изменить фото'
                    : _imageBytes != null
                        ? 'Фото выбрано'
                        : 'Добавить фото'),
              ),
              if (_imageUrl != null || _imageBytes != null) ...[
                const SizedBox(height: 12),
                AspectRatio(
                  aspectRatio: 1,
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
              const SizedBox(height: 24),
              Text('Обложка для шапки курса',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _pickCoverImage,
                icon: Icon(Icons.image,
                    color: isDark ? Colors.white : Colors.black),
                label: Text(_coverImageUrl != null
                    ? 'Изменить обложку'
                    : _coverImageBytes != null
                        ? 'Обложка выбрана'
                        : 'Добавить обложку'),
              ),
              if (_coverImageUrl != null || _coverImageBytes != null) ...[
                const SizedBox(height: 12),
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _coverImageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: _coverImageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (c, u) => Container(
                                color: Colors.grey[300],
                                child: const Center(
                                    child: CircularProgressIndicator())),
                            errorWidget: (c, u, e) => Container(
                                color: Colors.grey[300],
                                child: const Center(
                                    child: Icon(Icons.broken_image))))
                        : Image.memory(_coverImageBytes!, fit: BoxFit.cover),
                  ),
                ),
                if (_coverImageBytes != null && _coverImageUrl == null) ...[
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _isProcessing ? null : _uploadCoverImage,
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
              const SizedBox(height: 24),
              TextField(
                  controller: _titleController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                      labelText: 'Название',
                      labelStyle: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey),
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(Icons.title,
                          color: isDark ? Colors.grey[400] : Colors.grey))),
              const SizedBox(height: 16),
              TextField(
                  controller: _descController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                      labelText: 'Описание',
                      labelStyle: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey),
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(Icons.description,
                          color: isDark ? Colors.grey[400] : Colors.grey)),
                  maxLines: 3),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Отмена',
                style:
                    TextStyle(color: isDark ? Colors.grey[400] : Colors.grey))),
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
