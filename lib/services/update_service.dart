import 'dart:async';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as html;

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  String _currentVersion = '1.0.0';
  Timer? _checkTimer;
  bool _isChecking = false;

  String get version => _currentVersion;

  void startVersionCheck() {
    _checkTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      _checkForUpdates();
    });
  }

  void stopVersionCheck() {
    _checkTimer?.cancel();
  }

  Future<void> _checkForUpdates() async {
    if (_isChecking) return;
    _isChecking = true;

    try {
      final response = await Future.delayed(
        const Duration(milliseconds: 500),
        () => '{"version": "1.0.1"}',
      );
      _isChecking = false;
    } catch (e) {
      _isChecking = false;
    }
  }

  void showUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Доступна новая версия'),
        content: const Text(
            'Пожалуйста, обновите страницу для получения новых функций.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              html.window.location.reload();
            },
            child: const Text('Обновить'),
          ),
        ],
      ),
    );
  }

  void reloadPage() {
    html.window.location.reload();
  }

  void dispose() {
    stopVersionCheck();
  }
}
