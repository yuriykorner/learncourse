import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class SectionCreateDialog extends StatefulWidget {
  final String courseId;
  final VoidCallback onCreated;

  const SectionCreateDialog({
    super.key,
    required this.courseId,
    required this.onCreated,
  });

  @override
  State<SectionCreateDialog> createState() => _SectionCreateDialogState();
}

class _SectionCreateDialogState extends State<SectionCreateDialog> {
  final supabase = Supabase.instance.client;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isUploading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название раздела')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final auth = context.read<AuthProvider>();
      final userId = auth.user?.id;

      if (userId == null) {
        throw Exception('Пользователь не авторизован');
      }

      final maxOrderRes = await supabase
          .from('sections')
          .select('order_index')
          .eq('course_id', widget.courseId)
          .order('order_index', ascending: false)
          .limit(1);

      int nextOrder = 1;
      if (maxOrderRes.isNotEmpty && maxOrderRes[0]['order_index'] != null) {
        nextOrder = (maxOrderRes[0]['order_index'] as int) + 1;
      }

      await supabase.from('sections').insert({
        'course_id': widget.courseId,
        'creator_id': userId,
        'title': _titleController.text,
        'description': _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        'order_index': nextOrder,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Раздел создан'),
          backgroundColor: Colors.green,
        ),
      );

      widget.onCreated();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ошибка: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isUploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      title: Text(
        'Создать раздел',
        style: TextStyle(color: isDark ? Colors.white : Colors.black),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                autofocus: true,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'Название раздела *',
                  labelStyle: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: Icon(
                    Icons.folder,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  labelText: 'Описание (необязательно)',
                  labelStyle: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: Icon(
                    Icons.description,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
                ),
                maxLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isUploading ? null : () => Navigator.pop(context),
          child: Text('Отмена',
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isUploading ? null : _create,
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ? Colors.grey[300] : Colors.grey[800],
            foregroundColor: isDark ? Colors.black : Colors.white,
          ),
          child: _isUploading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Создать'),
        ),
      ],
    );
  }
}
