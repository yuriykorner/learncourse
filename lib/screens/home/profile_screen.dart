import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';

import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final user = auth.user;
    final profile = auth.profile;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final iconColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final selectedColor = isDark ? Colors.white : Colors.black;
    final selectedBackgroundColor =
        isDark ? Colors.grey[800]! : Colors.grey[200]!;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        title: const Text('Профиль'),
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor:
                  isDark ? Colors.grey[800] : const Color(0xFF1976D2),
              backgroundImage: profile?['avatar_url'] != null &&
                      profile!['avatar_url'].toString().isNotEmpty
                  ? CachedNetworkImageProvider(profile!['avatar_url'])
                  : null,
              child: profile?['avatar_url'] == null ||
                      profile!['avatar_url'].toString().isEmpty
                  ? Text(
                      (profile?['full_name'] ?? user?.email ?? '?')[0]
                          .toUpperCase(),
                      style: const TextStyle(
                        fontSize: 32,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 16),
            Text(
              profile?['full_name'] ?? 'Пользователь',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1976D2),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              user?.email ?? '',
              style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: (profile?['role'] == 'admin')
                    ? const Color(0xFF1976D2)
                    : (isDark ? Colors.grey[800] : Colors.grey[300]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                (profile?['role'] == 'admin') ? 'Администратор' : 'Студент',
                style: TextStyle(
                  fontSize: 12,
                  color: (profile?['role'] == 'admin')
                      ? Colors.white
                      : (isDark ? Colors.grey[400] : Colors.grey[700]),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Card(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.brightness_6,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF1976D2)),
                            const SizedBox(width: 12),
                            Text(
                              'Тема оформления',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? Colors.white : Colors.black),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SegmentedButton<ThemeMode>(
                          segments: [
                            ButtonSegment(
                              value: ThemeMode.light,
                              icon: Icon(
                                Icons.light_mode,
                                color: iconColor,
                                size: 16,
                              ),
                              tooltip: 'Светлая',
                            ),
                            ButtonSegment(
                              value: ThemeMode.system,
                              icon: Icon(
                                Icons.brightness_auto,
                                color: iconColor,
                                size: 16,
                              ),
                              tooltip: 'Системная',
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              icon: Icon(
                                Icons.dark_mode,
                                color: iconColor,
                                size: 16,
                              ),
                              tooltip: 'Тёмная',
                            ),
                          ],
                          selected: {themeProvider.themeMode},
                          style: SegmentedButton.styleFrom(
                            selectedBackgroundColor: selectedBackgroundColor,
                            selectedForegroundColor: selectedColor,
                            foregroundColor: iconColor,
                            backgroundColor: Colors.transparent,
                          ),
                          onSelectionChanged: (Set<ThemeMode> newSelection) {
                            themeProvider.setThemeMode(newSelection.first);
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1, color: Colors.grey),
                  ListTile(
                    leading: Icon(Icons.edit,
                        color: isDark ? Colors.white : const Color(0xFF1976D2)),
                    title: Text('Редактировать профиль',
                        style: TextStyle(
                            color: isDark ? Colors.white : Colors.black)),
                    trailing: Icon(Icons.chevron_right,
                        color: isDark ? Colors.grey[400] : Colors.grey[600]),
                    onTap: () => _showEditDialog(auth),
                  ),
                  const Divider(height: 1, color: Colors.grey),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.red),
                    title: const Text('Выйти',
                        style: TextStyle(color: Colors.red)),
                    trailing:
                        const Icon(Icons.chevron_right, color: Colors.red),
                    onTap: () async {
                      await auth.signOut();
                      if (mounted) {
                        context.go('/login');
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditDialog(AuthProvider auth) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final fullNameController = TextEditingController(
      text: auth.profile?['full_name'] ?? '',
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text('Редактировать профиль',
            style: TextStyle(color: isDark ? Colors.white : Colors.black)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[800],
                    backgroundImage: auth.profile?['avatar_url'] != null &&
                            auth.profile!['avatar_url'].toString().isNotEmpty
                        ? CachedNetworkImageProvider(
                            auth.profile!['avatar_url'])
                        : null,
                    child: auth.profile?['avatar_url'] == null ||
                            auth.profile!['avatar_url'].toString().isEmpty
                        ? Text(
                            (auth.profile?['full_name'] ??
                                    auth.user?.email ??
                                    '?')[0]
                                .toUpperCase(),
                            style: const TextStyle(
                                fontSize: 32,
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () async {
                    final avatarUrl = await _pickAndUploadAvatar();
                    if (avatarUrl != null && mounted) {
                      await auth.updateProfile(avatarUrl: avatarUrl);
                    }
                  },
                  icon: const Icon(Icons.upload),
                  label: const Text('Загрузить аватарку'),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: fullNameController,
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    labelText: 'ФИО',
                    labelStyle: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey),
                    border: const OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person,
                        color: isDark ? Colors.grey[400] : Colors.grey),
                    filled: true,
                    fillColor:
                        isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Отмена',
                style:
                    TextStyle(color: isDark ? Colors.grey[400] : Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx, {
                'full_name': fullNameController.text,
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? Colors.grey[300] : Colors.grey[800],
              foregroundColor: isDark ? Colors.black : Colors.white,
            ),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    if (result != null && mounted) {
      await auth.updateProfile(fullName: result['full_name']);
    }
  }

  Future<String?> _pickAndUploadAvatar() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null || !mounted) return null;

      final bytes = await pickedFile.readAsBytes();
      final userId = supabase.auth.currentUser?.id;
      final fileName =
          'avatar_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await supabase.storage
          .from('lesson_images')
          .uploadBinary(fileName, bytes);
      final publicUrl =
          supabase.storage.from('lesson_images').getPublicUrl(fileName);

      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Аватарка загружена'), backgroundColor: Colors.green),
      );

      return publicUrl;
    } catch (e) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка загрузки фото: $e')),
      );
      return null;
    }
  }
}
