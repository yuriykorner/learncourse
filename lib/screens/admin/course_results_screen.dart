import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class CourseResultsScreen extends StatefulWidget {
  final String courseId;
  const CourseResultsScreen({super.key, required this.courseId});

  @override
  State<CourseResultsScreen> createState() => _CourseResultsScreenState();
}

class _CourseResultsScreenState extends State<CourseResultsScreen> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? _course;
  List<dynamic> _students = [];
  List<dynamic> _modules = [];
  int _totalQuizLessons = 0;
  bool _isLoading = true;
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final auth = context.read<AuthProvider>();
      final userId = auth.user?.id;

      if (userId == null) {
        if (mounted) {
          setState(() => _isLoading = false);
        }
        return;
      }

      final courseRes = await supabase
          .from('courses')
          .select()
          .eq('id', widget.courseId)
          .single();

      final modulesRes = await supabase
          .from('modules')
          .select()
          .eq('course_id', widget.courseId)
          .order('order_index', ascending: true);

      final moduleIds =
          (modulesRes as List).map((m) => m['id'].toString()).toList();

      List<String> lessonIds = [];
      if (moduleIds.isNotEmpty) {
        final lessonIdsRes = await supabase
            .from('lessons')
            .select('id, module_id, lesson_type')
            .filter('module_id', 'in', '(${moduleIds.join(',')})')
            .order('order_index', ascending: true);

        lessonIds =
            (lessonIdsRes as List).map((l) => l['id'].toString()).toList();
      }

      int totalQuizLessons = 0;
      if (moduleIds.isNotEmpty) {
        final allQuizLessonsRes = await supabase
            .from('lessons')
            .select('id, lesson_type')
            .filter('module_id', 'in', '(${moduleIds.join(',')})')
            .eq('lesson_type', 'quiz');

        totalQuizLessons = (allQuizLessonsRes as List).length;
      }

      List<dynamic> students = [];
      if (lessonIds.isNotEmpty && moduleIds.isNotEmpty) {
        final quizResultsRes = await supabase
            .from('quiz_results')
            .select(
                'lesson_id, user_id, correct_answers, total_questions, passed, completed_at')
            .filter('lesson_id', 'in', '(${lessonIds.join(',')})')
            .order('completed_at', ascending: false);

        final moduleCompletionsRes = await supabase
            .from('module_completions')
            .select('module_id, user_id, completed, completed_at')
            .filter('module_id', 'in', '(${moduleIds.join(',')})')
            .order('completed_at', ascending: false);

        final userIds = [
          ...quizResultsRes.map((r) => r['user_id'].toString()),
          ...moduleCompletionsRes.map((r) => r['user_id'].toString())
        ].toSet().toList();

        if (userIds.isNotEmpty) {
          final profilesRes = await supabase
              .from('profiles')
              .select('id, full_name, email, avatar_url')
              .filter('id', 'in', '(${userIds.join(',')})')
              .order('created_at', ascending: false);

          for (var profile in profilesRes as List) {
            final studentId = profile['id'].toString();

            final studentQuizResults = quizResultsRes
                .where((r) => r['user_id'].toString() == studentId)
                .toList();

            final studentModuleCompletions = moduleCompletionsRes
                .where((r) => r['user_id'].toString() == studentId)
                .toList();

            final totalTests = totalQuizLessons;
            final passedTests =
                studentQuizResults.where((r) => r['passed'] == true).length;
            final completedModules = studentModuleCompletions
                .where((r) => r['completed'] == true)
                .length;

            students.add({
              'id': studentId,
              'full_name': profile['full_name'] ?? 'Без имени',
              'email': profile['email'] ?? '',
              'avatar_url': profile['avatar_url'],
              'total_tests': totalTests,
              'passed_tests': passedTests,
              'completed_modules': completedModules,
              'total_modules': modulesRes.length,
              'last_activity': studentQuizResults.isNotEmpty
                  ? studentQuizResults
                      .map((r) => r['completed_at'])
                      .where((d) => d != null)
                      .reduce((a, b) => DateTime.parse(a.toString())
                              .isAfter(DateTime.parse(b.toString()))
                          ? a
                          : b)
                  : null,
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _course = courseRes;
          _modules = modulesRes as List<dynamic>;
          _students = students;
          _totalQuizLessons = totalQuizLessons;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки: $e')),
        );
      }
    }
  }

  Future<void> _deleteStudentResults(
      String studentId, String studentName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1E1E1E)
            : Colors.white,
        title: const Text('Удалить результаты?'),
        content: Text(
          'Вы уверены что хотите удалить все результаты студента "$studentName"?\n\nЭто действие нельзя отменить.',
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
      await supabase.from('quiz_results').delete().eq('user_id', studentId);

      await supabase
          .from('module_completions')
          .delete()
          .eq('user_id', studentId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Результаты удалены'),
          backgroundColor: Colors.green,
        ),
      );

      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
  }

  List<dynamic> get _filteredStudents {
    if (_searchQuery.isEmpty) {
      return _students;
    }
    return _students.where((student) {
      final fullName = (student['full_name'] ?? '').toString().toLowerCase();
      final email = (student['email'] ?? '').toString().toLowerCase();
      return fullName.contains(_searchQuery.toLowerCase()) ||
          email.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.isAdmin;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Доступ запрещён'),
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          foregroundColor: isDark ? Colors.white : Colors.black,
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Colors.red[400]),
              const SizedBox(height: 16),
              Text(
                'Только для администраторов',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_course?['title']?.toString() ?? 'Результаты курса'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _students.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.analytics_outlined,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Нет результатов',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Студенты ещё не проходили этот курс',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[500] : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Поиск по ФИО или email...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          filled: true,
                          fillColor:
                              isDark ? Colors.grey[800] : Colors.grey[100],
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredStudents.length,
                        itemBuilder: (context, index) {
                          final student = _filteredStudents[index];
                          return _buildStudentCard(student, isDark);
                        },
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildStudentCard(dynamic student, bool isDark) {
    final studentId = student['id'].toString();
    final fullName = student['full_name']?.toString() ?? 'Без имени';
    final email = student['email']?.toString() ?? '';
    final avatarUrl = student['avatar_url']?.toString();
    final totalTests = student['total_tests'] as int? ?? 0;
    final passedTests = student['passed_tests'] as int? ?? 0;
    final lastActivity = student['last_activity'];

    final testProgress = totalTests > 0 ? passedTests / totalTests : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Аватар
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
                  child: avatarUrl != null && avatarUrl.isNotEmpty
                      ? ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: avatarUrl,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Icon(
                              Icons.person,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                            errorWidget: (context, url, error) => Icon(
                              Icons.person,
                              color:
                                  isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        )
                      : Icon(
                          Icons.person,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                ),
                const SizedBox(width: 12),
                // Имя и Email
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fullName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      if (email.isNotEmpty)
                        Text(
                          email,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.red[400]),
                  onPressed: () => _deleteStudentResults(studentId, fullName),
                  tooltip: 'Удалить результаты',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.quiz,
                    size: 16,
                    color: isDark ? Colors.grey[400] : Colors.grey[600]),
                const SizedBox(width: 8),
                Text(
                  'Тесты: $passedTests/$totalTests',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
                const Spacer(),
                Text(
                  '${(testProgress * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: testProgress >= 0.7
                        ? Colors.green
                        : testProgress >= 0.4
                            ? Colors.orange
                            : Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: testProgress,
              backgroundColor: isDark ? Colors.grey[700] : Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(
                testProgress >= 0.7
                    ? Colors.green
                    : testProgress >= 0.4
                        ? Colors.orange
                        : Colors.red,
              ),
            ),
            if (lastActivity != null) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Icons.access_time,
                      size: 14,
                      color: isDark ? Colors.grey[500] : Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    'Последняя активность: ${_formatDate(lastActivity)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey[500] : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(dynamic date) {
    try {
      if (date == null) return '—';
      final dateTime = DateTime.parse(date.toString());
      return '${dateTime.day}.${dateTime.month}.${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return date.toString();
    }
  }
}
