import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

/// Holds the currently logged-in user.
/// All screens and the router watch this to know who is logged in.
///
/// null isLoading=true  → app still checking saved token (splash)
/// null isLoading=false → not logged in → show LoginScreen
/// user != null         → logged in     → route by role
class AuthState {
  final UserModel? user;
  final bool isLoading;
  final String? errorMessage;

  const AuthState({
    this.user,
    this.isLoading = false,
    this.errorMessage,
  });

  bool get isLoggedIn => user != null;

  AuthState copyWith({
    UserModel? user,
    bool? isLoading,
    String? errorMessage,
    bool clearUser = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: clearUser ? null : user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState(isLoading: true)) {
    _init();
  }

  /// On app start: check saved token → verify with GET /auth/me
  Future<void> _init() async {
    try {
      final loggedIn = await AuthService.isLoggedIn();
      if (!loggedIn) {
        state = const AuthState();
        return;
      }
      final user = await AuthService.me();
      state = AuthState(user: user);
    } catch (_) {
      await AuthService.logout();
      state = const AuthState();
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final user = await AuthService.login(email, password);
      state = AuthState(user: user);
    } on Exception catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
        clearUser: true,
      );
    }
  }

  Future<void> logout() async {
    state = state.copyWith(isLoading: true);
    await AuthService.logout();
    state = const AuthState();
  }

  void clearError() => state = state.copyWith(clearError: true);
}

/// Watch this anywhere: final auth = ref.watch(authProvider);
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(),
);

/// Just the user object — null if not logged in
final currentUserProvider = Provider<UserModel?>((ref) {
  return ref.watch(authProvider).user;
});
