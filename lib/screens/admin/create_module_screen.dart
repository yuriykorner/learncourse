import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class CreateModuleScreen extends StatefulWidget {
  final String courseId;
  const CreateModuleScreen({super.key, required this.courseId});

  @override
  State<CreateModuleScreen> createState() => _CreateModuleScreenState();
}

class _CreateModuleScreenState extends State<CreateModuleScreen> {
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
      // ✅ ПОЛУЧАЕМ МАКСИМАЛЬНЫЙ order_index + 1
      final res = await supabase
          .from('modules')
          .select('order_index')
          .eq('course_id', widget.courseId)
          .order('order_index', ascending: false)
          .limit(1);

      int nextOrder = 1;
      if (res.isNotEmpty && res[0]['order_index'] != null) {
        nextOrder = (res[0]['order_index'] as int) + 1;
      }

      final response = await supabase.from('modules').insert({
        'course_id': widget.courseId,
        'title': _titleController.text,
        'order_index': nextOrder,
        'created_at': DateTime.now().toIso8601String(),
      }).select();

      if (response.isEmpty) {
        throw Exception('Не удалось создать модуль');
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Модуль создан')));
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
        title: const Text('Создать модуль'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isUploading ? null : _create,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Название модуля',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.folder),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isUploading ? null : _create,
              icon: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save),
              label: Text(_isUploading ? 'Сохранение...' : 'Создать модуль'),
            ),
          ],
        ),
      ),
    );
  }
}
