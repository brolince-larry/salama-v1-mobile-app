// lib/main.dart
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'config/app_theme.dart';
import 'config/api_config.dart';
import 'config/memory_config.dart';
import 'services/api_service.dart';
import 'services/smart_poll.dart';
import 'providers/auth_provider.dart';
import 'features/messaging/messaging.dart';

import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/admin/admin_dashboard.dart';
import 'screens/driver/driver_dashboard.dart';
import 'screens/parent/parent_dashboard.dart';
import 'screens/superadmin/superadmin_dashboard.dart';

final themeModeProvider = StateProvider<ThemeMode>((_) => ThemeMode.system);

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage msg) async {
  await Firebase.initializeApp();
  debugPrint('BG msg: ${msg.messageId}');
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cap image cache before anything else loads
  MemoryConfig.apply();

  // Mapbox token — mobile only (flutter_map handles web)
  if (!kIsWeb) {
    MapboxOptions.setAccessToken(
      'pk.eyJ1IjoiYnJvbGluY2UiLCJhIjoiY21ucWJiMHRyMDU5cDJ3cXB4ZzA5ZmI1ayJ9'
      '.Guvi2WbAjg9hMpfCC6amwQ',
    );
  }

  await Future.wait([
    _initFirebase(),
    _initSystem(),
    ApiService.init(),
  ]);

  final repo = MessagingRepository.withoutPusher(
    datasource: const MessagingRemoteDatasource(),
  );

  runApp(ProviderScope(
    overrides: [messagingRepoProvider.overrideWithValue(repo)],
    child: const SchoolTrackApp(),
  ));
}

Future<void> _initFirebase() async {
  if (kIsWeb) return;
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_bgHandler);
  } catch (e) {
    debugPrint('Firebase: $e');
  }
}

Future<void> _initSystem() async {
  if (kIsWeb) return;
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: AppTheme.primary,
    statusBarIconBrightness: Brightness.light,
  ));
}

// ── App root ──────────────────────────────────────────────────────────────────

class SchoolTrackApp extends ConsumerWidget {
  const SchoolTrackApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
        title: 'SchoolTrack',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        themeMode: ref.watch(themeModeProvider),
        home: kIsWeb
            ? const _AppEntry()
            : const SalamaSplashScreen(nextScreen: _AppEntry()),
      );
}

// ── Role router ───────────────────────────────────────────────────────────────

class _AppEntry extends ConsumerStatefulWidget {
  const _AppEntry();
  @override
  ConsumerState<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends ConsumerState<_AppEntry> {
  int? _subscribedUserId;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) _setupFcm();
  }

  void _setupFcm() async {
    try {
      final m = FirebaseMessaging.instance;
      await m.requestPermission(alert: true, badge: true, sound: true);
      await m.setForegroundNotificationPresentationOptions(
          alert: true, badge: true, sound: true);
      FirebaseMessaging.onMessageOpenedApp
          .listen((msg) => debugPrint('FCM tap: ${msg.data}'));
      FirebaseMessaging.onMessage
          .listen((_) => ref.read(inboxProvider.notifier).fetch());
    } catch (e) {
      debugPrint('FCM: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    if (auth.isLoading) return const _Loading();

    if (!auth.isLoggedIn) {
      _onLogout();
      return const LoginScreen();
    }

    final user = auth.user!;
    if (_subscribedUserId != user.id) {
      _subscribedUserId = user.id;
      WidgetsBinding.instance.addPostFrameCallback((_) => _subscribe(user));
    }

    final role = (user.role as String? ?? '').toLowerCase();
    final Widget dashboard = switch (role) {
      'superadmin' || 'super_admin' => const SuperAdminDashboard(),
      'driver' => const DriverDashboard(),
      'parent' => const ParentDashboard(),
      _ => const AdminDashboard(),
    };

    return MessagingOverlay(child: dashboard);
  }

  Future<void> _subscribe(dynamic user) async {
    ref.read(messagingRepoProvider).userId = user.id as int;
    await ref.read(messagingRepoProvider).initWithReverb(
          wsUri: ApiConfig.reverbWsUri,
          authEndpoint: ApiConfig.reverbAuthEndpoint,
          getToken: () async => await ApiService.getToken() ?? '',
        );
  }

  void _onLogout() {
    if (_subscribedUserId == null) return;
    IntervalCleaner.instance.disposeAll();
    ref.read(messagingRepoProvider).dispose();
    _subscribedUserId = null;
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: dark ? AppTheme.black : AppTheme.lightBg,
      body: const Center(
          child: CircularProgressIndicator(color: AppTheme.primary)),
    );
  }
}
