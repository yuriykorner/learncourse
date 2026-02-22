import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/courses/course_detail_screen.dart';
import '../screens/courses/lesson_player_screen.dart';
import '../screens/admin/create_lesson_screen.dart';
import '../screens/admin/edit_lesson_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/login',
    refreshListenable: GoRouterRefreshStream(),
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
      GoRoute(
        path: '/course/:courseId',
        builder: (context, state) {
          final courseId = state.pathParameters['courseId']!;
          return CourseDetailScreen(courseId: courseId);
        },
      ),
      GoRoute(
        path: '/lesson-player/:moduleId',
        builder: (context, state) {
          final moduleId = state.pathParameters['moduleId']!;
          final lessonId = state.uri.queryParameters['lessonId'];
          return LessonPlayerScreen(
              moduleId: moduleId, startLessonId: lessonId);
        },
      ),
      GoRoute(
          path: '/admin/create-lesson/:moduleId',
          builder: (context, state) {
            final moduleId = state.pathParameters['moduleId']!;
            return CreateLessonScreen(moduleId: moduleId);
          }),
      GoRoute(
          path: '/admin/edit-lesson/:lessonId',
          builder: (context, state) {
            final lessonId = state.pathParameters['lessonId']!;
            return EditLessonScreen(lessonId: lessonId);
          }),
    ],
    redirect: (context, state) {
      final auth = context.read<AuthProvider>();
      final isLoggedIn = auth.isAuthenticated;
      final isLoggingIn = state.matchedLocation == '/login';
      if (!isLoggedIn && !isLoggingIn) return '/login';
      if (isLoggedIn && isLoggingIn) return '/home';
      return null;
    },
  );
}

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream() {
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      notifyListeners();
    });
  }
}
