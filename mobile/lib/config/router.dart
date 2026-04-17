// lib/config/router.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/login_screen.dart';
import '../screens/admin/admin_dashboard.dart';
import '../screens/driver/driver_dashboard.dart';
import '../screens/parent/parent_dashboard.dart'; // ← ParentDashboard lives here
import '../screens/superadmin/superadmin_dashboard.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: _RouterRefreshStream(ref),
    redirect: (context, state) {
      if (authState.isLoading) return null;
      final loggedIn = authState.user != null;
      final authRoute = state.matchedLocation == '/login';
      if (!loggedIn) return authRoute ? null : '/login';
      if (loggedIn && authRoute) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) {
          final user = authState.user;
          if (user == null) return const LoginScreen();
          final role = (user.role as String? ?? '').toLowerCase();
          return switch (role) {
            'superadmin' || 'super_admin' => const SuperAdminDashboard(),
            'driver' => const DriverDashboard(),
            'parent' => const ParentDashboard(),
            _ => const AdminDashboard(),
          };
        },
      ),
    ],
  );
});

class _RouterRefreshStream extends ChangeNotifier {
  _RouterRefreshStream(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}
