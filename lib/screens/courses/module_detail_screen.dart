import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

class ModuleDetailScreen extends StatefulWidget {
  final String moduleId;
  const ModuleDetailScreen({super.key, required this.moduleId});

  @override
  State<ModuleDetailScreen> createState() => _ModuleDetailScreenState();
}

class _ModuleDetailScreenState extends State<ModuleDetailScreen> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? _module;
  List<dynamic> _lessons = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadModule();
  }

  Future<void> _loadModule() async {
    setState(() => _isLoading = true);
    try {
      final moduleRes = await supabase
          .from('modules')
          .select()
          .eq('id', widget.moduleId)
          .single();
      final lessonsRes = await supabase
          .from('lessons')
          .select()
          .eq('module_id', widget.moduleId)
          .order('order_index');
      setState(() {
        _module = moduleRes;
        _lessons = lessonsRes as List<dynamic>;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_module == null)
      return Scaffold(
          appBar: AppBar(title: const Text('Модуль не найден')),
          body: const Center(child: Text('Модуль не найден')));

    return Scaffold(
      appBar: AppBar(title: Text(_module!['title'] ?? 'Модуль')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_module!['title'] ?? '',
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ..._lessons.map((lesson) => _buildLessonCard(lesson)),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonCard(dynamic lesson) {
    final isQuiz = lesson['lesson_type'] == 'quiz';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/lesson/${lesson['id']}'),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: isQuiz ? Colors.grey[800] : Colors.black,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(isQuiz ? Icons.quiz : Icons.description,
                    color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lesson['title'] ?? '',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    Text(isQuiz ? 'Тест' : 'Урок',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
