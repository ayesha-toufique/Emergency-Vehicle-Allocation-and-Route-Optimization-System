import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../mock/demo_data.dart';
import '../mock/mock_repository.dart';
import 'api_service.dart';

class SessionService extends ChangeNotifier {
  static const String _prefRoleKey = 'resq_demo_role';
  static const String _prefLoggedInKey = 'resq_is_logged_in';
  static const String _prefUserNameKey = 'resq_user_name';
  static const String _prefUserEmailKey = 'resq_user_email';
  static const String _prefTokenKey = 'resq_auth_token';

  String? _role;
  String? _userName;
  String? _userEmail;
  String? _authToken;
  bool _isLoggedIn = false;
  final bool _isDemoMode = true; // Prototype frontend demo mode

  String? get role => _role;
  String get userName => _userName ?? 'User';
  String get userEmail => _userEmail ?? '';
  String? get authToken => _authToken;
  bool get isLoggedIn => _isLoggedIn;
  bool get isDemoMode => _isDemoMode;

  Future<void> restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isLoggedIn = prefs.getBool(_prefLoggedInKey) ?? false;
      if (_isLoggedIn) {
        _role = prefs.getString(_prefRoleKey) ?? 'citizen';
        _userName = prefs.getString(_prefUserNameKey) ?? 'Demo ${_role![0].toUpperCase()}${_role!.substring(1)}';
        _userEmail = prefs.getString(_prefUserEmailKey) ?? '';
        _authToken = prefs.getString(_prefTokenKey);
      } else {
        _role = null;
        _userName = null;
        _userEmail = null;
        _authToken = null;
      }
      notifyListeners();
    } catch (_) {
      _isLoggedIn = false;
      _role = null;
      _authToken = null;
    }
  }

  Future<void> _syncToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefLoggedInKey, _isLoggedIn);
      if (_isLoggedIn) {
        if (_role != null) await prefs.setString(_prefRoleKey, _role!);
        if (_userName != null) await prefs.setString(_prefUserNameKey, _userName!);
        if (_userEmail != null) await prefs.setString(_prefUserEmailKey, _userEmail!);
        if (_authToken != null) {
          await prefs.setString(_prefTokenKey, _authToken!);
        } else {
          await prefs.remove(_prefTokenKey);
        }
      } else {
        await prefs.remove(_prefRoleKey);
        await prefs.remove(_prefUserNameKey);
        await prefs.remove(_prefUserEmailKey);
        await prefs.remove(_prefTokenKey);
      }
    } catch (_) {}
  }

  /// Authenticates using ApiService against Django backend with automatic
  /// fallback to centralized MockRepository predefined/stored accounts.
  Future<DemoUserAccount?> loginWithCredentials(
    String email,
    String password,
    MockRepository repo, {
    ApiService? apiService,
  }) async {
    final api = apiService ?? ApiService();
    final apiResponse = await api.login(email, password, mockRepo: repo);
    final account = apiResponse.data;
    if (account == null) {
      return null;
    }

    _role = account.role.toLowerCase();
    _userName = account.name;
    _userEmail = account.email;
    _authToken = api.authToken;
    _isLoggedIn = true;
    notifyListeners();
    await _syncToPrefs();

    return account;
  }

  /// Automatically activates session for newly registered citizen
  Future<void> loginAsRegisteredCitizen(DemoUserAccount account) async {
    _role = 'citizen';
    _userName = account.name;
    _userEmail = account.email;
    _authToken = null;
    _isLoggedIn = true;
    notifyListeners();
    await _syncToPrefs();
  }

  /// Quick Demo Role Switcher (clearly labeled DEMO MODE)
  Future<void> demoLogin(String targetRole) async {
    _role = targetRole.toLowerCase();
    _isLoggedIn = true;
    _userName = 'Demo ${_role![0].toUpperCase()}${_role!.substring(1)}';
    _userEmail = '$_role@resq.com';
    _authToken = null;
    notifyListeners();
    await _syncToPrefs();
  }

  Future<void> logout() async {
    _isLoggedIn = false;
    _role = null;
    _userName = null;
    _userEmail = null;
    _authToken = null;
    notifyListeners();
    await _syncToPrefs();
  }
}
