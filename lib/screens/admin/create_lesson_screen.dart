import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/html_rich_editor.dart';

class CreateLessonScreen extends StatefulWidget {
  final String moduleId;
  const CreateLessonScreen({super.key, required this.moduleId});

  @override
  State<CreateLessonScreen> createState() => _CreateLessonScreenState();
}

class _CreateLessonScreenState extends State<CreateLessonScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _titleController = TextEditingController();
  String _htmlContent = '';
  bool _isUploading = false;
  String _lessonType = 'info';

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _createLesson() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Введите название')));
      return;
    }
    setState(() => _isUploading = true);
    try {
      // ✅ ПОЛУЧАЕМ МАКСИМАЛЬНЫЙ order_index + 1
      final res = await supabase
          .from('lessons')
          .select('order_index')
          .eq('module_id', widget.moduleId)
          .order('order_index', ascending: false)
          .limit(1);

      int nextOrder = 1;
      if (res.isNotEmpty && res[0]['order_index'] != null) {
        nextOrder = (res[0]['order_index'] as int) + 1;
      }

      final response = await supabase.from('lessons').insert({
        'module_id': widget.moduleId,
        'title': _titleController.text,
        'content': _lessonType == 'info' ? _htmlContent : '',
        'lesson_type': _lessonType,
        'order_index': nextOrder,
        'max_score': _lessonType == 'quiz' ? 10 : null,
        'created_at': DateTime.now().toIso8601String(),
      }).select();

      if (response.isEmpty) {
        throw Exception('Не удалось создать урок');
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Урок создан')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Ошибка: ${e.toString()}'),
          backgroundColor: Colors.red,
        ));
      }
    }
    setState(() => _isUploading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Создать урок'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isUploading ? null : _createLesson,
          ),
        ],
      ),
      body: SingleChildScrollView(
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
                    const Text('Тип урока',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                            value: 'info',
                            label: Text('Инфо'),
                            icon: Icon(Icons.description)),
                        ButtonSegment(
                            value: 'quiz',
                            label: Text('Тест'),
                            icon: Icon(Icons.quiz)),
                      ],
                      selected: {_lessonType},
                      onSelectionChanged: (Set<String> newSelection) =>
                          setState(() => _lessonType = newSelection.first),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Название',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                        hintText: 'Название урока',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title),
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            if (_lessonType == 'info') ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Содержание',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: HtmlRichEditor(
                          initialContent: '',
                          onContentChanged: (html) =>
                              setState(() => _htmlContent = html),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isUploading ? null : _createLesson,
              icon: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: Text(_isUploading ? 'Сохранение...' : 'Создать урок'),
            ),
          ],
        ),
      ),
    );
  }
}
