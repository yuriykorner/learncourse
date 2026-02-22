import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/html_rich_editor.dart';

class EditLessonScreen extends StatefulWidget {
  final String lessonId;
  const EditLessonScreen({super.key, required this.lessonId});

  @override
  State<EditLessonScreen> createState() => _EditLessonScreenState();
}

class _EditLessonScreenState extends State<EditLessonScreen> {
  final supabase = Supabase.instance.client;
  final TextEditingController _titleController = TextEditingController();
  String _htmlContent = '';
  bool _isUploading = false;
  bool _isLoading = true;
  String _lessonType = 'info';
  List<QuizQuestion> _questions = [];

  @override
  void initState() {
    super.initState();
    _loadLesson();
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

  Future<void> _loadLesson() async {
    setState(() => _isLoading = true);
    try {
      final res = await supabase
          .from('lessons')
          .select()
          .eq('id', widget.lessonId)
          .single();
      if (!mounted) return;
      setState(() {
        _titleController.text = res['title'] ?? '';
        _htmlContent = res['content'] ?? '';
        _lessonType = res['lesson_type'] ?? 'info';
        _isLoading = false;
      });

      if (_lessonType == 'quiz') {
        await _loadQuizQuestions();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка загрузки: $e')));
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadQuizQuestions() async {
    try {
      final questions = await supabase
          .from('quiz_questions')
          .select('*, quiz_answers(*)')
          .eq('lesson_id', widget.lessonId)
          .order('order_index', ascending: true);

      if (!mounted) return;
      setState(() {
        _questions = (questions as List).map((q) {
          final question = QuizQuestion.fromMap(q);
          question.textController = TextEditingController(text: question.text);
          for (var answer in question.answers) {
            answer.textController = TextEditingController(text: answer.text);
          }
          return question;
        }).toList();

        if (_questions.isEmpty) {
          final q = QuizQuestion(text: 'Вопрос 1', answers: [
            QuizAnswer(text: 'Вариант 1', isCorrect: false),
            QuizAnswer(text: 'Вариант 2', isCorrect: true),
          ]);
          q.textController = TextEditingController(text: q.text);
          for (var a in q.answers) {
            a.textController = TextEditingController(text: a.text);
          }
          _questions.add(q);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final q = QuizQuestion(text: 'Вопрос 1', answers: [
          QuizAnswer(text: 'Вариант 1', isCorrect: false),
          QuizAnswer(text: 'Вариант 2', isCorrect: true),
        ]);
        q.textController = TextEditingController(text: q.text);
        for (var a in q.answers) {
          a.textController = TextEditingController(text: a.text);
        }
        _questions.add(q);
      });
    }
  }

  Future<void> _updateLesson() async {
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Введите название')));
      return;
    }

    if (_lessonType == 'quiz' && _questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Добавьте хотя бы один вопрос')));
      return;
    }

    setState(() => _isUploading = true);
    try {
      await supabase.from('lessons').update({
        'title': _titleController.text,
        'content': _lessonType == 'quiz' ? '' : _htmlContent,
        'lesson_type': _lessonType,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', widget.lessonId);

      if (_lessonType == 'quiz') {
        await _saveQuizQuestions();

        await supabase
            .from('quiz_results')
            .delete()
            .eq('lesson_id', widget.lessonId);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Урок обновлен. Результаты теста сброшены.'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
    }
    setState(() => _isUploading = false);
  }

  Future<void> _saveQuizQuestions() async {
    await supabase
        .from('quiz_questions')
        .delete()
        .eq('lesson_id', widget.lessonId);

    for (int i = 0; i < _questions.length; i++) {
      final question = _questions[i];
      final qRes = await supabase.from('quiz_questions').insert({
        'lesson_id': widget.lessonId,
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
    // ✅ ДОБАВЛЕНО: ОПРЕДЕЛЕНИЕ ТЕМЫ
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      // ✅ ИЗМЕНЕНО: ФОН АДАПТИРУЕТСЯ ПОД ТЕМУ
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        title: Text(
          'Редактировать урок',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.save, color: isDark ? Colors.white : Colors.black),
            onPressed: _isUploading ? null : _updateLesson,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Тип урока',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black)),
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
                      style: SegmentedButton.styleFrom(
                        selectedBackgroundColor:
                            isDark ? Colors.grey[300] : Colors.grey[800],
                        selectedForegroundColor:
                            isDark ? Colors.black : Colors.white,
                        foregroundColor: isDark ? Colors.white : Colors.black,
                      ),
                      onSelectionChanged: (Set<String> newSelection) {
                        setState(() {
                          _lessonType = newSelection.first;
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
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Название',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _titleController,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        hintText: 'Название урока',
                        hintStyle: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey),
                        filled: true,
                        fillColor:
                            isDark ? const Color(0xFF2C2C2C) : Colors.white,
                        border: const OutlineInputBorder(),
                        prefixIcon: Icon(Icons.title,
                            color: isDark ? Colors.grey[400] : Colors.black),
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
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Содержание',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black)),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        // ✅ HTML РЕДАКТОР ВСЕГДА СВЕТЛЫЙ (для toolbar)
                        child: HtmlRichEditor(
                          initialContent: _htmlContent,
                          onContentChanged: (html) {
                            setState(() => _htmlContent = html);
                          },
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
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Вопросы теста',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black)),
                          IconButton(
                            icon: Icon(Icons.add_circle,
                                color: isDark ? Colors.white : Colors.black),
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
              onPressed: _isUploading ? null : _updateLesson,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.grey[300] : Colors.grey[800],
                foregroundColor: isDark ? Colors.black : Colors.white,
              ),
              icon: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(Icons.save,
                      color: isDark ? Colors.black : Colors.white),
              label: Text(
                  _isUploading ? 'Сохранение...' : 'Сохранить изменения',
                  style:
                      TextStyle(color: isDark ? Colors.black : Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuestionEditor(int index, QuizQuestion question, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Вопрос ${index + 1}',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black)),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_upward,
                          color: isDark ? Colors.white : Colors.black),
                      onPressed: index > 0
                          ? () {
                              setState(() {
                                final temp = _questions[index - 1];
                                _questions[index - 1] = _questions[index];
                                _questions[index] = temp;
                              });
                            }
                          : null,
                    ),
                    IconButton(
                      icon: Icon(Icons.arrow_downward,
                          color: isDark ? Colors.white : Colors.black),
                      onPressed: index < _questions.length - 1
                          ? () {
                              setState(() {
                                final temp = _questions[index + 1];
                                _questions[index + 1] = _questions[index];
                                _questions[index] = temp;
                              });
                            }
                          : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
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
              onChanged: (value) {
                question.text = value;
              },
            ),
            const SizedBox(height: 16),
            Text('Варианты ответов:',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black)),
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
                      activeColor: isDark ? Colors.grey[300] : Colors.grey[800],
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
                            icon: const Icon(Icons.delete, size: 20),
                            onPressed: question.answers.length > 2
                                ? () {
                                    setState(() {
                                      answer.textController.dispose();
                                      question.answers.removeAt(answerIndex);
                                    });
                                  }
                                : null,
                          ),
                        ),
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black),
                        controller: answer.textController,
                        onChanged: (value) {
                          answer.text = value;
                        },
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
              icon:
                  Icon(Icons.add, color: isDark ? Colors.white : Colors.black),
              label: Text('Добавить вариант',
                  style:
                      TextStyle(color: isDark ? Colors.white : Colors.black)),
            ),
          ],
        ),
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
