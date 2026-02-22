import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseService {
  final supabase = Supabase.instance.client;

  // ========== КУРСЫ ==========
  Future<List<Map<String, dynamic>>> getCourses() async {
    try {
      final response = await supabase
          .from('courses')
          .select('*, profiles(full_name, avatar_url)')
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getCourseById(String courseId) async {
    try {
      final response = await supabase
          .from('courses')
          .select('*, profiles(full_name, avatar_url)')
          .eq('id', courseId)
          .single();
      return response as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  Future<bool> createCourse({
    required String title,
    required String description,
    String? thumbnailUrl,
  }) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return false;

      await supabase.from('courses').insert({
        'title': title,
        'description': description,
        'thumbnail_url': thumbnailUrl,
        'created_by': user.id,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteCourse(String courseId) async {
    try {
      await supabase.from('courses').delete().eq('id', courseId);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ========== МОДУЛИ ==========
  Future<List<Map<String, dynamic>>> getModules(String courseId) async {
    try {
      final response = await supabase
          .from('modules')
          .select('*')
          .eq('course_id', courseId)
          .order('order_index', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<bool> createModule({
    required String courseId,
    required String title,
    int orderIndex = 0,
  }) async {
    try {
      await supabase.from('modules').insert({
        'course_id': courseId,
        'title': title,
        'order_index': orderIndex,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // ========== УРОКИ ==========
  Future<List<Map<String, dynamic>>> getLessons(String moduleId) async {
    try {
      final response = await supabase
          .from('lessons')
          .select('*')
          .eq('module_id', moduleId)
          .order('order_index', ascending: true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>?> getLessonById(String lessonId) async {
    try {
      final response =
          await supabase.from('lessons').select().eq('id', lessonId).single();
      return response as Map<String, dynamic>?;
    } catch (e) {
      return null;
    }
  }

  Future<bool> createLesson({
    required String moduleId,
    required String title,
    String? content,
    String? contentType = 'text',
    String? videoUrl,
    int orderIndex = 0,
  }) async {
    try {
      await supabase.from('lessons').insert({
        'module_id': moduleId,
        'title': title,
        'content': content,
        'content_type': contentType,
        'video_url': videoUrl,
        'order_index': orderIndex,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  // ========== ПРОГРЕСС ==========
  Future<bool> markLessonComplete(String lessonId) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return false;

      await supabase.from('progress').upsert({
        'user_id': user.id,
        'lesson_id': lessonId,
        'completed': true,
        'completed_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,lesson_id');
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> isLessonComplete(String lessonId) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return false;

      final response = await supabase
          .from('progress')
          .select('completed')
          .eq('user_id', user.id)
          .eq('lesson_id', lessonId)
          .single();
      return response['completed'] == true;
    } catch (e) {
      return false;
    }
  }

  // ========== АДМИН ПРОВЕРКА ==========
  Future<bool> checkIfAdmin() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return false;

      final response = await supabase
          .from('profiles')
          .select('is_admin')
          .eq('id', user.id)
          .single();
      return response['is_admin'] == true;
    } catch (e) {
      return false;
    }
  }

  // ========== ИЗБРАННОЕ ==========
  Future<bool> addToFavorites(String courseId) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return false;

      await supabase.from('favorites').insert({
        'user_id': user.id,
        'course_id': courseId,
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> removeFromFavorites(String courseId) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return false;

      await supabase
          .from('favorites')
          .delete()
          .eq('user_id', user.id)
          .eq('course_id', courseId);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<List<String>> getFavoriteCourseIds() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return [];

      final response = await supabase
          .from('favorites')
          .select('course_id')
          .eq('user_id', user.id);

      final List<Map<String, dynamic>> dataList =
          List<Map<String, dynamic>>.from(response);
      return dataList.map((e) => e['course_id'] as String).toList();
    } catch (e) {
      return [];
    }
  }
}
