import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class TestResultsScreen extends StatefulWidget {
  const TestResultsScreen({super.key});

  @override
  State<TestResultsScreen> createState() => _TestResultsScreenState();
}

class _TestResultsScreenState extends State<TestResultsScreen> {
  final supabase = Supabase.instance.client;
  List<dynamic> _courses = [];
  Map<String, int> _studentCounts = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCourses();
  }

  Future<void> _loadCourses() async {
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

      final res = await supabase
          .from('courses')
          .select('*, profiles:creator_id(full_name, avatar_url)')
          .eq('creator_id', userId)
          .order('created_at', ascending: false);

      final coursesList = res as List<dynamic>;

      Map<String, int> studentCounts = {};
      for (var course in coursesList) {
        final courseId = course['id'].toString();

        final modulesRes = await supabase
            .from('modules')
            .select('id')
            .eq('course_id', courseId);

        final moduleIds =
            (modulesRes as List).map((m) => m['id'].toString()).toList();

        if (moduleIds.isNotEmpty) {
          final lessonsRes = await supabase
              .from('lessons')
              .select('id, module_id')
              .filter('module_id', 'in', '(${moduleIds.join(',')})');

          final lessonIds =
              (lessonsRes as List).map((l) => l['id'].toString()).toList();

          if (lessonIds.isNotEmpty) {
            final resultsRes = await supabase
                .from('quiz_results')
                .select('user_id')
                .filter('lesson_id', 'in', '(${lessonIds.join(',')})');

            final uniqueStudents = (resultsRes as List)
                .map((r) => r['user_id'].toString())
                .toSet()
                .length;

            studentCounts[courseId] = uniqueStudents;
          } else {
            studentCounts[courseId] = 0;
          }
        } else {
          studentCounts[courseId] = 0;
        }
      }

      if (mounted) {
        setState(() {
          _courses = coursesList;
          _studentCounts = studentCounts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка загрузки курсов: $e')),
        );
      }
    }
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
        title: const Text('Результаты'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCourses,
            tooltip: 'Обновить',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _courses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.analytics_outlined,
                          size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'У вас ещё нет курсов',
                        style: TextStyle(
                          fontSize: 16,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () => context.push('/admin/create-course'),
                        icon: const Icon(Icons.add),
                        label: const Text('Создать курс'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadCourses,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(
                        top: 16, bottom: 80, left: 16, right: 16),
                    itemCount: _courses.length,
                    itemBuilder: (context, index) {
                      final course = _courses[index];
                      return _buildCourseCard(course, isDark);
                    },
                  ),
                ),
    );
  }

  Widget _buildCourseCard(dynamic course, bool isDark) {
    final courseId = course['id'].toString();
    final title = course['title']?.toString() ?? 'Без названия';
    final description = course['description']?.toString() ?? '';
    final imageUrl = course['image_url']?.toString();
    final studentCount = _studentCounts[courseId] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black54 : Colors.black26,
            blurRadius: 8,
            offset: const Offset(0, 4),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        shadowColor: Colors.transparent,
        color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () => context.push('/admin/course-results/$courseId'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: imageUrl != null && imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              width: 100,
                              height: 100,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: 100,
                                height: 100,
                                color: isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[300],
                                child: const Center(
                                    child: CircularProgressIndicator()),
                              ),
                              errorWidget: (context, url, error) => Container(
                                width: 100,
                                height: 100,
                                color: isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[300],
                                child: const Icon(Icons.broken_image,
                                    size: 30, color: Colors.grey),
                              ),
                            )
                          : Container(
                              width: 100,
                              height: 100,
                              color:
                                  isDark ? Colors.grey[800] : Colors.grey[300],
                              child: const Icon(Icons.school,
                                  size: 30, color: Colors.grey),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          if (description.isNotEmpty)
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                                height: 1.3,
                              ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Divider(
                    color: isDark ? Colors.grey[800] : Colors.grey[300],
                    height: 1),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 16,
                      color: Colors.blue[400],
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$studentCount',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue[400],
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Результаты',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue[400],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: Colors.blue[400],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
