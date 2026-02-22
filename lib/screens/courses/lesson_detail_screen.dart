import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class LessonDetailScreen extends StatefulWidget {
  final String lessonId;
  const LessonDetailScreen({super.key, required this.lessonId});

  @override
  State<LessonDetailScreen> createState() => _LessonDetailScreenState();
}

class _LessonDetailScreenState extends State<LessonDetailScreen> {
  final supabase = Supabase.instance.client;
  Map<String, dynamic>? _lesson;
  bool _isLoading = true;
  String _htmlContent = '';

  @override
  void initState() {
    super.initState();
    _loadLesson();
  }

  Future<void> _loadLesson() async {
    setState(() => _isLoading = true);
    try {
      final res = await supabase
          .from('lessons')
          .select('*, modules(course_id, courses(title))')
          .eq('id', widget.lessonId)
          .single();

      setState(() {
        _lesson = res;
        _htmlContent = res['content'] ?? '';
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ошибка загрузки: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_lesson == null) {
      return Scaffold(
        appBar: AppBar(
            title: const Text('Урок не найден'),
            backgroundColor: const Color(0xFF1976D2),
            foregroundColor: Colors.white),
        body: const Center(child: Text('Урок не существует или был удален.')),
      );
    }

    final lessonType = _lesson!['lesson_type'] ?? 'info';

    // ✅ ЕСЛИ ТЕСТ - ПЕРЕНАПРАВЛЯЕМ НА ЭКРАН ТЕСТА
    if (lessonType == 'quiz') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.push('/quiz/${widget.lessonId}');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final courseTitle =
        (_lesson!['modules'] as Map?)?['courses']?['title'] ?? 'Курс';
    final title = _lesson!['title'] ?? 'Без названия';
    final imageUrl = _lesson!['image_url'];

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(courseTitle,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: Colors.white70)),
            Text(title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white)),
          ],
        ),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (imageUrl != null && imageUrl.isNotEmpty)
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.grey[800]),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  placeholder: (context, url) =>
                      const Center(child: CircularProgressIndicator()),
                  errorWidget: (context, url, error) => const Center(
                      child: Icon(Icons.broken_image,
                          size: 64, color: Colors.grey)),
                ),
              ),
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          height: 1.2)),
                  const Divider(height: 40, thickness: 1, color: Colors.grey),
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.5,
                    child: InAppWebView(
                      initialData: InAppWebViewInitialData(
                        data: '''
                          <!DOCTYPE html>
                          <html>
                          <head>
                            <meta name="viewport" content="width=device-width, initial-scale=1.0">
                            <meta charset="UTF-8">
                            <style>
                              body { 
                                font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif; 
                                line-height: 1.8; 
                                padding: 20px;
                                font-size: 16px;
                                color: #fff;
                                background-color: #1a1a1a;
                                max-width: 100%;
                                overflow-wrap: break-word;
                              }
                              img { 
                                max-width: 100%; 
                                height: auto; 
                                border-radius: 8px;
                                margin: 10px 0;
                              }
                              p { margin: 15px 0; }
                              h1, h2, h3 { color: #64B5F6; margin: 20px 0 10px 0; }
                              video { max-width: 100%; border-radius: 8px; margin: 10px 0; }
                              hr { border: 0; height: 1px; background: #333; margin: 20px 0; }
                            </style>
                          </head>
                          <body>
                            ${_htmlContent}
                          </body>
                          </html>
                        ''',
                        encoding: 'utf-8',
                      ),
                      initialSettings: InAppWebViewSettings(
                        verticalScrollBarEnabled: true,
                        horizontalScrollBarEnabled: false,
                        transparentBackground: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        // ✅ ПЕРЕЙТИ К СЛЕДУЮЩЕМУ УРОКУ
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child:
                          const Text('Дальше', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
