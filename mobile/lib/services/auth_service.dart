import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/user.dart';
import 'api_service.dart';

class AuthService {
  AuthService._();

  static const _userIdKey    = 'user_id';
  static const _userNameKey  = 'user_name';
  static const _userEmailKey = 'user_email';
  static const _userRoleKey  = 'user_role';
  static const _schoolIdKey  = 'school_id';

  // ── Login ─────────────────────────────────────────────────────────────────

  static Future<UserModel> login(String email, String password) async {
    final raw = await ApiService.post(
      ApiConfig.login,
      body: {'email': email, 'password': password},
    );

    final data  = _toMap(raw);
    final token = data['token'] as String?
               ?? data['access_token'] as String?
               ?? '';
    if (token.isEmpty) throw Exception('Login failed: no token in response');

    final user = UserModel.fromJson(_toMap(data['user']));
    await ApiService.saveToken(token);
    await _saveUser(user);
    return user;
  }

  // ── Logout ────────────────────────────────────────────────────────────────

  static Future<void> logout() async {
    try {
      await ApiService.post(ApiConfig.logout);
    } catch (_) {}
    finally {
      await ApiService.clearToken();
      await _clearUser();
    }
  }

  // ── Get current user ──────────────────────────────────────────────────────
  // Falls back to saved local user if the API returns 500.
  // The 500 on /auth/me is usually caused by a missing eager-load in the
  // Laravel controller — fix: add ->load('school') to the me() endpoint.

  static Future<UserModel> me() async {
    try {
      final raw  = await ApiService.get(ApiConfig.me);
      final data = _toMap(raw);
      if (data.isEmpty) throw Exception('Empty response from /auth/me');
      final user = UserModel.fromJson(data);
      await _saveUser(user);
      return user;
    } catch (e) {
      // If /auth/me fails (e.g. 500), fall back to locally saved user
      // so the app doesn't log out the user on a transient server error.
      final saved = await getSavedUser();
      if (saved != null) return saved;
      rethrow;
    }
  }

  // ── Save FCM token ────────────────────────────────────────────────────────

  static Future<void> saveFcmToken(String fcmToken) async {
    await ApiService.post(ApiConfig.fcmToken, body: {'fcm_token': fcmToken});
  }

  // ── Read saved user ───────────────────────────────────────────────────────

  static Future<UserModel?> getSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final id    = prefs.getInt(_userIdKey);
    if (id == null) return null;
    return UserModel(
      id:       id,
      name:     prefs.getString(_userNameKey)  ?? '',
      email:    prefs.getString(_userEmailKey) ?? '',
      role:     prefs.getString(_userRoleKey)  ?? '',
      schoolId: prefs.getInt(_schoolIdKey),
    );
  }

  static Future<bool> isLoggedIn() async => ApiService.hasToken();

  // ── Helpers ───────────────────────────────────────────────────────────────

  static Map<String, dynamic> _toMap(dynamic v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return {};
  }

  static Future<void> _saveUser(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_userIdKey,        user.id);
    await prefs.setString(_userNameKey,   user.name);
    await prefs.setString(_userEmailKey,  user.email);
    await prefs.setString(_userRoleKey,   user.role);
    if (user.schoolId != null) {
      await prefs.setInt(_schoolIdKey, user.schoolId!);
    }
  }

  static Future<void> _clearUser() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_userRoleKey);
    await prefs.remove(_schoolIdKey);
  }
}