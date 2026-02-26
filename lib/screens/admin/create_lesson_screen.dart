import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/html_rich_editor.dart';

class CreateLessonScreen extends StatefulWidget {
  final String moduleId;
  const CreateLessonScreen({super.key, required this.moduleId});

  @override
  State<CreateLessonScreen> createState() => _CreateLessonScreenState();
}

class _CreateLessonScreenState extends State<CreateLessonScreen> {
  final supabase = Supabase.instance.client;
  final _titleController = TextEditingController();
  String _htmlContent = '';
  bool _isLoading = true;
  bool _isUploading = false;
  bool _isOwner = false;
  String _lessonType = 'info';
  List<QuizQuestion> _questions = [];

  @override
  void initState() {
    super.initState();
    _checkOwnership();
  }

  @override
  void dispose() {
    _titleController.dispose();
    for (var q in _questions) {
      q.textController.dispose();
      for (var a in q.answers) {
        a.textController.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _checkOwnership() async {
    try {
      final auth = context.read<AuthProvider>();
      final userId = auth.user?.id;

      final module = await supabase
          .from('modules')
          .select('admin_id, course_id, courses!inner(creator_id)')
          .eq('id', widget.moduleId)
          .single();

      final moduleAdminId = module['admin_id']?.toString();
      final courseCreatorId = module['courses']['creator_id']?.toString();

      if (!mounted) return;
      setState(() {
        _isOwner = userId == moduleAdminId || userId == courseCreatorId;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createLesson() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название')),
      );
      return;
    }

    if (_lessonType == 'quiz' && _questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте хотя бы один вопрос')),
      );
      return;
    }

    if (!_isOwner) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Ошибка: У вас нет прав на создание урока в этом модуле'),
          backgroundColor: Colors.red,
        ),
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
        'admin_id': userId,
        'title': _titleController.text,
        'content': _lessonType == 'info' ? _htmlContent : '',
        'lesson_type': _lessonType,
        'order_index': nextOrder,
        'created_at': DateTime.now().toIso8601String(),
      }).select();

      if (response.isEmpty) {
        throw Exception('Не удалось создать урок');
      }

      final lessonId = response.first['id'].toString();

      if (_lessonType == 'quiz') {
        await _saveQuizQuestions(lessonId);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Урок создан'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
    setState(() => _isUploading = false);
  }

  Future<void> _saveQuizQuestions(String lessonId) async {
    for (int i = 0; i < _questions.length; i++) {
      final question = _questions[i];
      final qRes = await supabase.from('quiz_questions').insert({
        'lesson_id': lessonId,
        'question_text': question.textController.text,
        'order_index': i,
      }).select();

      if (qRes.isNotEmpty) {
        final questionId = qRes.first['id'];

        for (int j = 0; j < question.answers.length; j++) {
          final answer = question.answers[j];
          await supabase.from('quiz_answers').insert({
            'question_id': questionId,
            'answer_text': answer.textController.text,
            'is_correct': answer.isCorrect,
            'order_index': j,
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          foregroundColor: isDark ? Colors.white : Colors.black,
          title: const Text('Загрузка...'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (!_isOwner) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          foregroundColor: isDark ? Colors.white : Colors.black,
          title: const Text('Доступ запрещён'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.red[400]),
              const SizedBox(height: 16),
              Text(
                'У вас нет прав на создание урока в этом модуле',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Назад'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        title: const Text('Создать урок'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isUploading ? null : _createLesson,
            tooltip: 'Сохранить',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      color: Colors.green[400],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Вы владелец этого модуля',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.green[400],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Тип урока',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(
                          value: 'info',
                          label: Text('Инфо'),
                          icon: Icon(Icons.description),
                        ),
                        ButtonSegment(
                          value: 'quiz',
                          label: Text('Тест'),
                          icon: Icon(Icons.quiz),
                        ),
                      ],
                      selected: {_lessonType},
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() => _lessonType = newSelection.first);
                        if (_lessonType == 'quiz' && _questions.isEmpty) {
                          final q = QuizQuestion(text: 'Вопрос 1', answers: [
                            QuizAnswer(text: 'Вариант 1', isCorrect: false),
                            QuizAnswer(text: 'Вариант 2', isCorrect: true),
                          ]);
                          q.textController =
                              TextEditingController(text: q.text);
                          for (var a in q.answers) {
                            a.textController =
                                TextEditingController(text: a.text);
                          }
                          _questions.add(q);
                        }
                      },
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
                    const Text(
                      'Название',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _titleController,
                      autofocus: true,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        hintText: 'Название урока',
                        hintStyle: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey),
                        border: const OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title,
                            color: isDark ? Colors.grey[400] : Colors.grey),
                        filled: true,
                        fillColor:
                            isDark ? const Color(0xFF2C2C2C) : Colors.grey[50],
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
                      const Text(
                        'Содержание',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
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
            if (_lessonType == 'quiz') ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Вопросы теста',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle,
                                color: Colors.blue),
                            onPressed: () {
                              setState(() {
                                final q = QuizQuestion(
                                    text: 'Новый вопрос',
                                    answers: [
                                      QuizAnswer(
                                          text: 'Вариант 1', isCorrect: false),
                                      QuizAnswer(
                                          text: 'Вариант 2', isCorrect: true),
                                    ]);
                                q.textController =
                                    TextEditingController(text: q.text);
                                for (var a in q.answers) {
                                  a.textController =
                                      TextEditingController(text: a.text);
                                }
                                _questions.add(q);
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ..._questions.asMap().entries.map((entry) {
                        final index = entry.key;
                        final question = entry.value;
                        return _buildQuestionEditor(index, question, isDark);
                      }).toList(),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _isUploading ? null : _createLesson,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.grey[300] : Colors.grey[800],
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: Text(_isUploading ? 'Создание...' : 'Создать урок'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionEditor(int index, QuizQuestion question, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Вопрос ${index + 1}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_upward, size: 20),
                    onPressed: index > 0
                        ? () {
                            setState(() {
                              final temp = _questions[index - 1];
                              _questions[index - 1] = _questions[index];
                              _questions[index] = temp;
                            });
                          }
                        : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.arrow_downward, size: 20),
                    onPressed: index < _questions.length - 1
                        ? () {
                            setState(() {
                              final temp = _questions[index + 1];
                              _questions[index + 1] = _questions[index];
                              _questions[index] = temp;
                            });
                          }
                        : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                    onPressed: _questions.length > 1
                        ? () {
                            setState(() {
                              question.textController.dispose();
                              for (var a in question.answers) {
                                a.textController.dispose();
                              }
                              _questions.removeAt(index);
                            });
                          }
                        : null,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            decoration: InputDecoration(
              labelText: 'Текст вопроса',
              labelStyle:
                  TextStyle(color: isDark ? Colors.grey[400] : Colors.grey),
              filled: true,
              fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
              border: const OutlineInputBorder(),
            ),
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            controller: question.textController,
            maxLines: 2,
          ),
          const SizedBox(height: 12),
          const Text(
            'Варианты ответов:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 8),
          ...question.answers.asMap().entries.map((entry) {
            final answerIndex = entry.key;
            final answer = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Radio<bool>(
                    value: true,
                    groupValue: answer.isCorrect,
                    onChanged: (value) {
                      setState(() {
                        for (var a in question.answers) {
                          a.isCorrect = false;
                        }
                        answer.isCorrect = value ?? false;
                      });
                    },
                  ),
                  Expanded(
                    child: TextField(
                      decoration: InputDecoration(
                        labelText: 'Вариант ${answerIndex + 1}',
                        labelStyle: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey),
                        filled: true,
                        fillColor:
                            isDark ? const Color(0xFF2C2C2C) : Colors.white,
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.delete, size: 18),
                          onPressed: question.answers.length > 2
                              ? () {
                                  setState(() {
                                    answer.textController.dispose();
                                    question.answers.removeAt(answerIndex);
                                  });
                                }
                              : null,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black),
                      controller: answer.textController,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          TextButton.icon(
            onPressed: () {
              setState(() {
                final a = QuizAnswer(text: 'Новый вариант', isCorrect: false);
                a.textController = TextEditingController(text: a.text);
                question.answers.add(a);
              });
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Добавить вариант'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 0),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

class QuizQuestion {
  String text;
  List<QuizAnswer> answers;
  late TextEditingController textController;

  QuizQuestion({required this.text, required this.answers});

  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    final answers = (map['quiz_answers'] as List?)
            ?.map((a) => QuizAnswer.fromMap(a))
            .toList() ??
        [];
    return QuizQuestion(
      text: map['question_text'] ?? '',
      answers: answers,
    );
  }
}

class QuizAnswer {
  String text;
  bool isCorrect;
  late TextEditingController textController;

  QuizAnswer({required this.text, required this.isCorrect});

  factory QuizAnswer.fromMap(Map<String, dynamic> map) {
    return QuizAnswer(
      text: map['answer_text'] ?? '',
      isCorrect: map['is_correct'] ?? false,
    );
  }
}
