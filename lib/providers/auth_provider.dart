import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthProvider extends ChangeNotifier {
  final supabase = Supabase.instance.client;
  User? _user;
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  User? get user => _user;
  Map<String, dynamic>? get profile => _profile;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _initAuth();
  }

  Future<void> _initAuth() async {
    _user = supabase.auth.currentUser;
    if (_user != null) {
      await _loadProfile();
    }
    _isLoading = false;
    notifyListeners();

    supabase.auth.onAuthStateChange.listen((data) async {
      _user = data.session?.user;
      if (_user != null) {
        await _loadProfile();
      } else {
        _profile = null;
      }
      _isLoading = false;
      notifyListeners();
    });
  }

  Future<void> loadProfile() async {
    if (_user == null) return;
    try {
      final res = await supabase
          .from('profiles')
          .select()
          .eq('id', _user!.id)
          .maybeSingle();
      _profile = res as Map<String, dynamic>?;
      notifyListeners();
    } catch (e) {
      // ignore: avoid_print
      print('Error loading profile: $e');
    }
  }

  Future<void> _loadProfile() async {
    if (_user == null) return;
    try {
      final res = await supabase
          .from('profiles')
          .select()
          .eq('id', _user!.id)
          .maybeSingle();
      _profile = res as Map<String, dynamic>?;
      notifyListeners();
    } catch (e) {
      // ignore: avoid_print
      print('Error loading profile: $e');
    }
  }

  Future<void> signIn(String email, String password) async {
    final response = await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
    _user = response.user;
    if (_user != null) {
      await _loadProfile();
    }
    notifyListeners();
  }

  Future<void> signUp(
      {required String email,
      required String password,
      required String fullName}) async {
    final response = await supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );

    if (response.user != null) {
      await supabase.from('profiles').insert({
        'id': response.user!.id,
        'email': email,
        'full_name': fullName,
        'role': 'user',
      });
      _user = response.user;
      await _loadProfile();
    }
    notifyListeners();
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
    _user = null;
    _profile = null;
    notifyListeners();
  }

  Future<void> updateProfile({String? fullName, String? avatarUrl}) async {
    if (_user == null) return;

    await supabase.from('profiles').update({
      if (fullName != null) 'full_name': fullName,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
    }).eq('id', _user!.id);

    await _loadProfile();
  }

  bool get isAdmin {
    return _profile?['role'] == 'admin';
  }

  Future<bool> checkAdmin() async {
    if (_user == null) return false;
    await _loadProfile();
    return isAdmin;
  }
}
