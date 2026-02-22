import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  final supabase = Supabase.instance.client;

  Future<File?> pickImageFromGallery() async {
    return null;
  }

  Future<String?> uploadAvatar(File image) async {
    try {
      final fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bucket = supabase.storage.from('avatars');
      await bucket.upload(fileName, image);
      return bucket.getPublicUrl(fileName);
    } catch (e) {
      print('Error uploading avatar: $e');
      return null;
    }
  }

  Future<String?> uploadLessonImage(File image) async {
    try {
      final fileName = 'lesson_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bucket = supabase.storage.from('lesson_images');
      await bucket.upload(fileName, image);
      return bucket.getPublicUrl(fileName);
    } catch (e) {
      print('Error uploading lesson image: $e');
      return null;
    }
  }

  // ✅ ДОБАВЬТЕ ЭТОТ МЕТОД:
  Future<String?> uploadCourseThumbnail(File image) async {
    try {
      final fileName = 'course_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final bucket = supabase.storage.from('course_images');
      await bucket.upload(fileName, image);
      return bucket.getPublicUrl(fileName);
    } catch (e) {
      print('Error uploading course thumbnail: $e');
      return null;
    }
  }
}
