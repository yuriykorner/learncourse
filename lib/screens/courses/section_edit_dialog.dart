import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class SectionEditDialog extends StatefulWidget {
  final dynamic section;
  final VoidCallback onUpdated;
  final VoidCallback onDeleted;

  const SectionEditDialog({
    super.key,
    required this.section,
    required this.onUpdated,
    required this.onDeleted,
  });

  @override
  State<SectionEditDialog> createState() => _SectionEditDialogState();
}

class _SectionEditDialogState extends State<SectionEditDialog> {
  final supabase = Supabase.instance.client;
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  bool _isUploading = false;
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.section['title'] ?? '');
    _descriptionController = TextEditingController(
      text: widget.section['description'] ?? '',
    );
    _checkOwnership();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _checkOwnership() async {
    try {
      final auth = context.read<AuthProvider>();
      final userId = auth.user?.id;
      final creatorId = widget.section['creator_id']?.toString();

      setState(() {
        _isOwner = userId == creatorId;
      });
    } catch (e) {
      setState(() => _isOwner = false);
    }
  }

  Future<void> _update() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название раздела')),
      );
      return;
    }

    if (!_isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка: У вас нет прав на редактирование'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      await supabase.from('sections').update({
        'title': _titleController.text,
        'description': _descriptionController.text.isEmpty
            ? null
            : _descriptionController.text,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.section['id']);

      if (!mounted) return;

      widget.onUpdated();
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Раздел обновлён'),
          backgroundColor: Colors.green,
        ),
      );
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

  Future<void> _delete() async {
    if (!_isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ошибка: У вас нет прав на удаление'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        title: const Text('Удалить раздел?'),
        content: Text(
          'Вы уверены что хотите удалить раздел "${widget.section['title']}"?\n\nМодули в этом разделе не будут удалены.',
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

    setState(() => _isUploading = true);

    try {
      await supabase
          .from('modules')
          .update({'section_id': null}).eq('section_id', widget.section['id']);

      await supabase.from('sections').delete().eq('id', widget.section['id']);

      if (!mounted) return;

      widget.onDeleted();
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Раздел удалён'),
          backgroundColor: Colors.green,
        ),
      );
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

    if (!_isOwner) {
      return AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(
          'Доступ запрещён',
          style: TextStyle(
            color: Colors.red[400],
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.lock_outline, size: 64, color: Colors.red[400]),
            const SizedBox(height: 16),
            Text(
              'У вас нет прав на редактирование этого раздела',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      );
    }

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      title: Text(
        'Редактировать раздел',
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
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isUploading ? null : _delete,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Удалить раздел'),
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
          onPressed: _isUploading ? null : () => Navigator.pop(context),
          child: Text('Отмена',
              style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isUploading ? null : _update,
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
              : const Text('Сохранить'),
        ),
      ],
    );
  }
}
