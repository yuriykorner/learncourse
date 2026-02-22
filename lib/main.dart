import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'routes/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
      url: SupabaseConfig.url, anonKey: SupabaseConfig.anonKey);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp.router(
            title: 'LearnCourse',
            debugShowCheckedModeBanner: false,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('ru', 'RU'), Locale('en', 'US')],

            // ✅ ТЕМА ЗАВИСИТ ОТ PROVIDER
            themeMode: themeProvider.themeMode,

            // ✅ СВЕТЛАЯ ТЕМА
            theme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.grey[800]!,
                brightness: Brightness.light,
                primary: Colors.grey[800],
                secondary: Colors.grey[600],
                surface: Colors.white,
                background: Colors.white,
              ),
              scaffoldBackgroundColor: Colors.white,
              appBarTheme: const AppBarTheme(
                centerTitle: false,
                elevation: 0,
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                titleTextStyle: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              cardTheme: CardThemeData(
                elevation: 2, // ✅ ТЕНЬ ДЛЯ КАРТОЧЕК
                shadowColor: Colors.black26, // ✅ ЦВЕТ ТЕНИ
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                color: Colors.white,
                surfaceTintColor: Colors.transparent,
              ),
              inputDecorationTheme: InputDecorationTheme(
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                backgroundColor: Colors.white,
                selectedItemColor: Colors.black,
                unselectedItemColor: Colors.grey,
                type: BottomNavigationBarType.fixed,
                elevation: 8, // ✅ ТЕНЬ ДЛЯ NAV BAR
              ),
              iconTheme: const IconThemeData(
                color: Colors.black87,
              ),
            ),

            // ✅ ТЁМНАЯ ТЕМА
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.grey[900]!,
                brightness: Brightness.dark,
                primary: Colors.grey[300],
                secondary: Colors.grey[500],
                surface: const Color(0xFF1E1E1E),
                background: const Color(0xFF121212),
              ),
              scaffoldBackgroundColor: const Color(0xFF121212),
              appBarTheme: const AppBarTheme(
                centerTitle: false,
                elevation: 0,
                backgroundColor: Color(0xFF1E1E1E),
                foregroundColor: Colors.white,
                titleTextStyle: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold),
              ),
              cardTheme: CardThemeData(
                elevation: 2, // ✅ ТЕНЬ ДЛЯ КАРТОЧЕК
                shadowColor: Colors.black54, // ✅ ЦВЕТ ТЕНИ
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                color: const Color(0xFF1E1E1E),
                surfaceTintColor: Colors.transparent,
              ),
              inputDecorationTheme: InputDecorationTheme(
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: const Color(0xFF2C2C2C),
              ),
              elevatedButtonTheme: ElevatedButtonThemeData(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3C3C3C),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              bottomNavigationBarTheme: const BottomNavigationBarThemeData(
                backgroundColor: Color(0xFF1E1E1E),
                selectedItemColor: Colors.white,
                unselectedItemColor: Colors.grey,
                type: BottomNavigationBarType.fixed,
                elevation: 8, // ✅ ТЕНЬ ДЛЯ NAV BAR
              ),
              textTheme: const TextTheme(
                bodyLarge: TextStyle(color: Colors.white),
                bodyMedium: TextStyle(color: Colors.white),
                titleLarge: TextStyle(color: Colors.white),
                titleMedium: TextStyle(color: Colors.white),
              ),
              dividerTheme: const DividerThemeData(
                color: Color(0xFF3C3C3C),
              ),
              iconTheme: const IconThemeData(
                color: Colors.white,
              ),
            ),

            routerConfig: AppRouter.router,
          );
        },
      ),
    );
  }
}
