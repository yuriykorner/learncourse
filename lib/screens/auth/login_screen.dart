import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _isLogin = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните все поля')),
      );
      return;
    }

    if (!_isLogin && _nameController.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите ФИО')),
      );
      return;
    }

    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final auth = context.read<AuthProvider>();
      if (_isLogin) {
        await auth.signIn(_emailController.text, _passwordController.text);
      } else {
        await auth.signUp(
          email: _emailController.text,
          password: _passwordController.text,
          fullName: _nameController.text,
        );
      }
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
      );
    }
    if (!mounted) return;
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: AppBar(
        backgroundColor:
            isDark ? const Color.fromARGB(255, 18, 18, 18) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black,
        title: Text(
          _isLogin ? '' : '',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 48),
            Image.asset(
              isDark
                  ? 'assets/icon/logogifdark.gif'
                  : 'assets/icon/logogiflight.gif',
              width: 160,
              height: 160,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Icons.school,
                  size: 80,
                  color: isDark ? Colors.white : const Color(0xFF1976D2),
                );
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Learn Course',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1976D2),
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 48),
            if (!_isLogin) ...[
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'ФИО',
                  labelStyle: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  prefixIcon: Icon(Icons.person,
                      color: isDark ? Colors.grey[400] : Colors.grey[600]),
                  filled: true,
                  fillColor:
                      isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600]),
                prefixIcon: Icon(Icons.email,
                    color: isDark ? Colors.grey[400] : Colors.grey[600]),
                filled: true,
                fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Пароль',
                labelStyle: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600]),
                prefixIcon: Icon(Icons.lock,
                    color: isDark ? Colors.grey[400] : Colors.grey[600]),
                filled: true,
                fillColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[100],
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDark ? const Color(0xFF3C3C3C) : const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(_isLogin ? 'Войти' : 'Зарегистрироваться'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => setState(() => _isLogin = !_isLogin),
              child: Text(
                _isLogin
                    ? 'Нет аккаунта? Зарегистрироваться'
                    : 'Есть аккаунт? Войти',
                style: TextStyle(
                    color: isDark ? Colors.grey[400] : Colors.grey[600]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
