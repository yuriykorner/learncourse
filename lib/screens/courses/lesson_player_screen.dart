import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:video_player/video_player.dart';
import 'dart:async';

import '../../providers/auth_provider.dart';

class LessonPlayerScreen extends StatefulWidget {
  final String moduleId;
  final String? startLessonId;
  const LessonPlayerScreen(
      {super.key, required this.moduleId, this.startLessonId});

  @override
  State<LessonPlayerScreen> createState() => _LessonPlayerScreenState();
}

class _LessonPlayerScreenState extends State<LessonPlayerScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> _lessons = [];
  int _currentIndex = 0;
  bool _isLoading = true;
  bool _isCompleted = false;
  final ScrollController _scrollController = ScrollController();
  final ScrollController _lessonsScrollController = ScrollController();

  static final customCacheManager = CacheManager(
    Config(
      'lesson_images_cache',
      stalePeriod: const Duration(days: 7),
      maxNrOfCacheObjects: 100,
      repo: JsonCacheInfoRepository(databaseName: 'lesson_images_cache'),
      fileService: HttpFileService(),
    ),
  );

  Map<int, int?> _userAnswers = {};
  bool _quizSubmitted = false;
  int _correctAnswers = 0;
  bool _quizPassed = false;
  bool _quizLoading = false;
  List<QuizQuestion> _quizQuestions = [];
  int _totalQuestions = 0;
  String? _loadedLessonId;

  @override
  void initState() {
    super.initState();
    _loadLessons();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _lessonsScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadLessons() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final res = await supabase
          .from('lessons')
          .select()
          .eq('module_id', widget.moduleId)
          .order('order_index', ascending: true);
      if (!mounted) return;
      setState(() {
        _lessons = res as List<dynamic>;
        if (widget.startLessonId != null) {
          _currentIndex =
              _lessons.indexWhere((l) => l['id'] == widget.startLessonId);
          if (_currentIndex == -1) _currentIndex = 0;
        }
        _isLoading = false;
        _scrollToCurrentLesson();
        _scheduleQuizLoad();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  void _scheduleQuizLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          _lessons.isNotEmpty &&
          !_quizLoading &&
          _quizQuestions.isEmpty) {
        _loadQuizQuestionsData();
      }
    });
  }

  void _scrollToCurrentLesson() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final scrollPosition = _currentIndex * 48.0;
      _lessonsScrollController.animateTo(
        scrollPosition,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  void _nextLesson() {
    if (_currentIndex < _lessons.length - 1) {
      if (!mounted) return;
      setState(() {
        _currentIndex++;
        _isCompleted = false;
        _resetQuizState();
        _scrollController.animateTo(0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut);
        _scrollToCurrentLesson();
        _scheduleQuizLoad();
      });
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Поздравляем!'),
          content: const Text('Вы завершили этот модуль.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
          ],
        ),
      );
    }
  }

  void _resetQuizState() {
    _userAnswers.clear();
    _quizSubmitted = false;
    _quizPassed = false;
    _quizLoading = false;
    _quizQuestions.clear();
    _totalQuestions = 0;
    _loadedLessonId = null;
  }

  Future<void> _deleteLesson() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить урок?'),
        content: const Text('Это действие нельзя отменить.'),
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
      final lessonId = _lessons[_currentIndex]['id'];
      await supabase.from('lessons').delete().eq('id', lessonId);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Урок удалён'), backgroundColor: Colors.green),
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
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.isAdmin;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading)
      return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        title: Text(
          _lessons.isNotEmpty
              ? (_lessons[_currentIndex]['title'] ?? 'Урок')
              : 'Модуль',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        actions: [
          if (isAdmin && _lessons.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: _deleteLesson,
              tooltip: 'Удалить урок',
            ),
          if (isAdmin && _lessons.isNotEmpty)
            IconButton(
              icon:
                  Icon(Icons.edit, color: isDark ? Colors.white : Colors.black),
              onPressed: () {
                if (!mounted) return;
                context.push(
                    '/admin/edit-lesson/${_lessons[_currentIndex]['id']}');
              },
            ),
          if (isAdmin)
            IconButton(
              icon:
                  Icon(Icons.add, color: isDark ? Colors.white : Colors.black),
              onPressed: () {
                if (!mounted) return;
                context.push('/admin/create-lesson/${widget.moduleId}');
              },
            ),
        ],
      ),
      body: _lessons.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.book_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    isAdmin ? 'Нет уроков в этом модуле' : 'Уроков пока нет',
                    style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontSize: 16),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        if (!mounted) return;
                        context.push('/admin/create-lesson/${widget.moduleId}');
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить первый урок'),
                    ),
                  ],
                ],
              ),
            )
          : Column(
              children: [
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: ListView.builder(
                    controller: _lessonsScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _lessons.length + (isAdmin ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (isAdmin && index == _lessons.length) {
                        return GestureDetector(
                          onTap: () {
                            if (!mounted) return;
                            context.push(
                                '/admin/create-lesson/${widget.moduleId}');
                          },
                          child: Container(
                            width: 40,
                            margin: const EdgeInsets.only(right: 8, left: 8),
                            decoration: BoxDecoration(
                              color:
                                  isDark ? Colors.grey[800] : Colors.grey[300],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.add,
                                color: isDark ? Colors.grey[400] : Colors.grey,
                                size: 20),
                          ),
                        );
                      }
                      final isActive = index == _currentIndex;
                      return GestureDetector(
                        onTap: () {
                          if (!mounted) return;
                          setState(() {
                            _currentIndex = index;
                            _resetQuizState();
                            _scheduleQuizLoad();
                          });
                        },
                        child: Container(
                          width: 40,
                          margin: const EdgeInsets.only(right: 8, left: 8),
                          decoration: BoxDecoration(
                            color: isActive
                                ? (isDark ? Colors.grey[300] : Colors.grey[800])
                                : (isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[300]),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text('${index + 1}',
                                style: TextStyle(
                                    color: isActive
                                        ? (isDark ? Colors.black : Colors.white)
                                        : (isDark
                                            ? Colors.white
                                            : Colors.grey[700]),
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Divider(
                    height: 1,
                    color: isDark ? Colors.grey[800] : Colors.grey[300]),
                Expanded(
                  child: Listener(
                    onPointerSignal: (event) {
                      if (event is PointerScrollEvent &&
                          _scrollController.hasClients) {
                        final offset =
                            _scrollController.offset + event.scrollDelta.dy;
                        _scrollController.animateTo(
                          offset.clamp(
                              0.0, _scrollController.position.maxScrollExtent),
                          duration: const Duration(milliseconds: 100),
                          curve: Curves.easeOut,
                        );
                      }
                    },
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_lessons[_currentIndex]['lesson_type'] ==
                                    'quiz')
                                  _buildQuizContent(isDark)
                                else
                                  _buildInfoContent(isDark),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF121212) : Colors.white,
                  ),
                  child: SafeArea(
                    child: ElevatedButton(
                      onPressed: (_isCompleted ||
                              _lessons[_currentIndex]['lesson_type'] != 'quiz')
                          ? _nextLesson
                          : null,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        backgroundColor: (_isCompleted ||
                                _lessons[_currentIndex]['lesson_type'] !=
                                    'quiz')
                            ? (isDark ? Colors.grey[300] : Colors.grey[800])
                            : Colors.grey[400],
                        foregroundColor: isDark ? Colors.black : Colors.white,
                      ),
                      child: Text(_currentIndex < _lessons.length - 1
                          ? 'Дальше'
                          : 'Завершить'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildInfoContent(bool isDark) {
    final content = _lessons[_currentIndex]['content'] ?? '';

    if (content.isEmpty || content.trim().isEmpty) {
      return Text('Содержимое урока пустое',
          style: TextStyle(color: isDark ? Colors.grey[400] : Colors.grey));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border:
            Border.all(color: isDark ? Colors.grey[800]! : Colors.grey[300]!),
      ),
      child: HtmlWidget(
        content,
        textStyle: TextStyle(
          fontSize: 16,
          height: 1.6,
          color: isDark ? Colors.white : Colors.black87,
        ),
        customStylesBuilder: (element) {
          final tagName = element.localName;
          final style = element.attributes['style'] ?? '';

          if (tagName == 'h1') {
            return {
              'font-size': '32px',
              'font-weight': 'bold',
              'margin': '24px 0 16px 0'
            };
          }
          if (tagName == 'h2') {
            return {
              'font-size': '24px',
              'font-weight': 'bold',
              'margin': '20px 0 12px 0'
            };
          }
          if (tagName == 'h3') {
            return {
              'font-size': '20px',
              'font-weight': 'bold',
              'margin': '16px 0 8px 0'
            };
          }

          if (tagName == 'p' || tagName == 'div') {
            final textAlign = _getTextAlign(style);
            return {
              'margin': '12px 0',
              'line-height': '1.6',
              'text-align': textAlign,
            };
          }

          if (tagName == 'ul' || tagName == 'ol') {
            return {'margin': '16px 0', 'padding-left': '30px'};
          }
          if (tagName == 'li') {
            return {'margin': '8px 0'};
          }

          if (tagName == 'img') {
            final src = element.attributes['src'];
            if (src == null || src.isEmpty) {
              return {'display': 'none'};
            }

            final styles = <String, String>{
              'height': 'auto',
              'border-radius': '8px',
              'margin': '10px 0',
              'max-width': '100%',
            };

            if (style.contains('float: left') || style.contains('float:left')) {
              styles['float'] = 'left';
              styles['margin'] = '10px 16px 10px 0';
            } else if (style.contains('float: right') ||
                style.contains('float:right')) {
              styles['float'] = 'right';
              styles['margin'] = '10px 0 10px 16px';
            }

            final widthMatch = RegExp(r'width:\s*(\d+)px').firstMatch(style);
            if (widthMatch != null) {
              final width = widthMatch.group(1);
              if (width != null) {
                styles['width'] = '${width}px';
              }
            }

            return styles;
          }

          if (tagName == 'video') {
            return {
              'max-width': '100%',
              'height': 'auto',
              'margin': '16px 0',
              'border-radius': '8px',
            };
          }

          return null;
        },
        customWidgetBuilder: (element) {
          if (element.localName == 'img') {
            final src = element.attributes['src'];
            if (src == null || src.isEmpty) return null;

            final style = element.attributes['style'] ?? '';
            final isFloatLeft =
                style.contains('float: left') || style.contains('float:left');
            final isFloatRight =
                style.contains('float: right') || style.contains('float:right');

            double? imageWidth;
            final widthMatch = RegExp(r'width:\s*(\d+)px').firstMatch(style);
            if (widthMatch != null) {
              imageWidth = double.tryParse(widthMatch.group(1) ?? '');
            }

            return Padding(
              padding: EdgeInsets.only(
                left: isFloatLeft ? 0 : (isFloatRight ? 16 : 8),
                right: isFloatRight ? 0 : (isFloatLeft ? 16 : 8),
                bottom: 16,
                top: 8,
              ),
              child: Align(
                alignment: isFloatLeft
                    ? Alignment.centerLeft
                    : (isFloatRight ? Alignment.centerRight : Alignment.center),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: imageWidth ?? double.infinity,
                      maxHeight: 600,
                    ),
                    child: CachedNetworkImage(
                      imageUrl: src,
                      fit: BoxFit.contain,
                      cacheManager: customCacheManager,
                      fadeInDuration: const Duration(milliseconds: 300),
                      fadeOutDuration: const Duration(milliseconds: 300),
                      placeholder: (context, url) => Container(
                        width: imageWidth ?? 300,
                        height: 200,
                        color: isDark ? Colors.grey[800] : Colors.grey[300],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: imageWidth ?? 300,
                        height: 200,
                        color: isDark ? Colors.grey[800] : Colors.grey[300],
                        child: const Icon(Icons.broken_image,
                            size: 64, color: Colors.grey),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }

          if (element.localName == 'video') {
            final src = element.attributes['src'];
            if (src == null || src.isEmpty) return null;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  color: Colors.black,
                  child: VideoPlayerWithControls(videoUrl: src),
                ),
              ),
            );
          }

          return null;
        },
      ),
    );
  }

  String _getTextAlign(String style) {
    if (style.contains('text-align: center') ||
        style.contains('text-align:center')) {
      return 'center';
    } else if (style.contains('text-align: right') ||
        style.contains('text-align:right')) {
      return 'right';
    } else if (style.contains('text-align: justify') ||
        style.contains('text-align:justify')) {
      return 'justify';
    }
    return 'left';
  }

  Widget _buildQuizContent(bool isDark) {
    if (_quizLoading) {
      return Center(
          child: CircularProgressIndicator(
              color: isDark ? Colors.white : Colors.black));
    }

    if (_quizPassed) {
      return _buildQuizPassedWidget(isDark);
    }

    if (_quizSubmitted && !_quizPassed) {
      return _buildQuizResultsWidget(isDark);
    }

    if (_quizQuestions.isEmpty) {
      return Center(
          child: CircularProgressIndicator(
              color: isDark ? Colors.white : Colors.black));
    }

    return _buildQuizQuestionsWidget(isDark);
  }

  Widget _buildQuizQuestionsWidget(bool isDark) {
    if (_quizQuestions.isEmpty) {
      return Text('Вопросы не найдены',
          style: TextStyle(color: isDark ? Colors.white : Colors.black));
    }

    return Card(
      margin: EdgeInsets.zero,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Тест',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black)),
            const SizedBox(height: 16),
            ..._quizQuestions.asMap().entries.map((entry) {
              final qIndex = entry.key;
              final question = entry.value;
              return _buildQuestionWidget(qIndex, question, isDark);
            }).toList(),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _userAnswers.length == _quizQuestions.length
                  ? _submitQuiz
                  : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: isDark ? Colors.grey[300] : Colors.grey[800],
                foregroundColor: isDark ? Colors.black : Colors.white,
              ),
              child: Text('Завершить тест',
                  style:
                      TextStyle(color: isDark ? Colors.black : Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadQuizQuestionsData() async {
    final currentLessonId = _lessons[_currentIndex]['id'].toString();

    if (_loadedLessonId == currentLessonId &&
        _quizQuestions.isNotEmpty &&
        !_quizSubmitted) {
      return;
    }

    if (_quizLoading) {
      return;
    }

    setState(() {
      _quizLoading = true;
    });

    try {
      if (!_quizSubmitted) {
        final result = await supabase
            .from('quiz_results')
            .select()
            .eq('lesson_id', currentLessonId)
            .eq('user_id', supabase.auth.currentUser!.id)
            .maybeSingle();

        if (result != null && result['passed'] == true) {
          if (!mounted) return;
          setState(() {
            _quizPassed = true;
            _quizSubmitted = true;
            _correctAnswers = result['correct_answers'] ?? 0;
            _totalQuestions = result['total_questions'] ?? 0;
            _quizLoading = false;
            _loadedLessonId = currentLessonId;
          });
          return;
        }
      }

      final questions = await supabase
          .from('quiz_questions')
          .select('*, quiz_answers(*)')
          .eq('lesson_id', currentLessonId)
          .order('order_index', ascending: true);

      if (!mounted) return;
      setState(() {
        _quizQuestions =
            (questions as List).map((q) => QuizQuestion.fromMap(q)).toList();
        _totalQuestions = _quizQuestions.length;
        _quizLoading = false;
        _loadedLessonId = currentLessonId;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _quizLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки теста: $e')),
      );
    }
  }

  Widget _buildQuestionWidget(int qIndex, QuizQuestion question, bool isDark) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Вопрос ${qIndex + 1}: ${question.text}',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 12),
            ...question.answers.asMap().entries.map((entry) {
              final aIndex = entry.key;
              final answer = entry.value;
              return RadioListTile<int>(
                title: Text(answer.text,
                    style:
                        TextStyle(color: isDark ? Colors.white : Colors.black)),
                value: aIndex,
                groupValue: _userAnswers[qIndex],
                onChanged: (value) {
                  setState(() {
                    _userAnswers[qIndex] = value;
                  });
                },
                activeColor: isDark ? Colors.grey[300] : Colors.grey[800],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Future<void> _submitQuiz() async {
    if (_quizQuestions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Вопросы не загружены')),
      );
      return;
    }

    final lessonId = _lessons[_currentIndex]['id'].toString();

    final questions = await supabase
        .from('quiz_questions')
        .select('*, quiz_answers(*)')
        .eq('lesson_id', lessonId)
        .order('order_index', ascending: true);

    int correct = 0;
    for (var q in questions) {
      final qObj = QuizQuestion.fromMap(q);
      final userAnswerIndex = _userAnswers[questions.indexOf(q)];
      if (userAnswerIndex != null && userAnswerIndex < qObj.answers.length) {
        if (qObj.answers[userAnswerIndex].isCorrect) {
          correct++;
        }
      }
    }

    final total = questions.length;
    final passed = correct >= total * 0.7;

    await supabase
        .from('quiz_results')
        .delete()
        .eq('lesson_id', lessonId)
        .eq('user_id', supabase.auth.currentUser!.id);

    await supabase.from('quiz_results').insert({
      'lesson_id': lessonId,
      'user_id': supabase.auth.currentUser!.id,
      'correct_answers': correct,
      'total_questions': total,
      'passed': passed,
      'completed_at': DateTime.now().toIso8601String(),
    });

    setState(() {
      _quizSubmitted = true;
      _correctAnswers = correct;
      _totalQuestions = total;
      _quizPassed = passed;
    });
  }

  Widget _buildQuizPassedWidget(bool isDark) {
    return Card(
      margin: EdgeInsets.zero,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green, width: 2),
        ),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Тест пройден',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Правильных ответов: $_correctAnswers из $_totalQuestions',
              style: TextStyle(
                  fontSize: 16, color: isDark ? Colors.white : Colors.green),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuizResultsWidget(bool isDark) {
    return Card(
      margin: EdgeInsets.zero,
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.cancel, color: Colors.red, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Тест не пройден',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Правильных ответов: $_correctAnswers из $_totalQuestions',
              style: TextStyle(
                  fontSize: 16, color: isDark ? Colors.white : Colors.black),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _retryQuiz,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? Colors.grey[300] : Colors.grey[800],
                foregroundColor: isDark ? Colors.black : Colors.white,
              ),
              child: Text('Пройти заново',
                  style:
                      TextStyle(color: isDark ? Colors.black : Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _retryQuiz() async {
    final lessonId = _lessons[_currentIndex]['id'].toString();

    await supabase
        .from('quiz_results')
        .delete()
        .eq('lesson_id', lessonId)
        .eq('user_id', supabase.auth.currentUser!.id);

    setState(() {
      _userAnswers.clear();
      _quizSubmitted = false;
      _quizPassed = false;
      _quizQuestions.clear();
      _totalQuestions = 0;
      _loadedLessonId = null;
      _quizLoading = false;
    });

    if (mounted) {
      _loadQuizQuestionsData();
    }
  }
}

class VideoPlayerWithControls extends StatefulWidget {
  final String videoUrl;
  const VideoPlayerWithControls({super.key, required this.videoUrl});

  @override
  State<VideoPlayerWithControls> createState() =>
      _VideoPlayerWithControlsState();
}

class _VideoPlayerWithControlsState extends State<VideoPlayerWithControls> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  @override
  void didUpdateWidget(VideoPlayerWithControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoUrl != widget.videoUrl) {
      _disposeVideo();
      _initVideo();
    }
  }

  Future<void> _initVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
        videoPlayerOptions: VideoPlayerOptions(
          mixWithOthers: true,
          webOptions: const VideoPlayerWebOptions(
            controls: VideoPlayerWebOptionsControls.enabled(),
          ),
        ),
      );

      await _controller!.initialize();
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    }
  }

  void _disposeVideo() {
    _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }

  @override
  void dispose() {
    _disposeVideo();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized ||
        _controller == null ||
        !_controller!.value.isInitialized) {
      return const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return AspectRatio(
      aspectRatio: _controller!.value.aspectRatio,
      child: VideoPlayer(_controller!),
    );
  }
}

class QuizQuestion {
  String text;
  List<QuizAnswer> answers;

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

  QuizAnswer({required this.text, required this.isCorrect});

  factory QuizAnswer.fromMap(Map<String, dynamic> map) {
    return QuizAnswer(
      text: map['answer_text'] ?? '',
      isCorrect: map['is_correct'] ?? false,
    );
  }
}
