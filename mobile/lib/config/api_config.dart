import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

class ApiConfig {
  ApiConfig._();

  // ── LAN IP / HTTP base ────────────────────────────────────────────────
  static const String _lanIp = '192.168.0.109';
  static const int _reverbPort = 8080;
  static const String _reverbKey = 'ewe4blzwmkn5lxrn6cg1';
  static const String _reverbScheme = 'http';

  static String get _httpBase {
    if (kIsWeb) return 'http://$_lanIp:8000';
    try {
      if (Platform.isAndroid) return 'http://$_lanIp:8000';
      if (Platform.isIOS) return 'http://$_lanIp:8000';
    } catch (_) {}
    return 'http://$_lanIp:8000';
  }

  static String get baseUrl => '$_httpBase/api';
  static String get storageBase => _httpBase;

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 15);

  // ── Auth ──────────────────────────────────────────────────────────────
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String me = '/auth/me';
  static const String fcmToken = '/auth/fcm-token';

  // ── Driver ────────────────────────────────────────────────────────────
  static const String gpsPing = '/gps/ping';
  static const String boardings = '/boardings';
  static const String driverHome = '/driver/home';
  static const String driverProfile = '/driver/profile';
  static const String driverNotifications = '/driver/notifications';
  static const String driverRoute = '/driver/route'; // ← added
  static const String tripHistory = '/driver/trip-history';
  static const String notifyParent = '/driver/notify-parent';
  static const String stopStudents = '/driver/stop-students';
  static const String startTrip = '/driver/trip/start';

  static String tripEnd(int id) => '/trips/$id/end';
  static String tripStudents(int id) => '/trips/$id/students';
  static String tripStudentStatus(int t, int s) =>
      '/trips/$t/students/$s/status';
  static String pauseTrip(int id) => '/trips/$id/pause';
  static String resumeTrip(int id) => '/trips/$id/resume';
  static String tripSos(int id) => '/driver/trip/$id/sos';
  static String sosResolve(int id) => '/sos/$id/resolve';

  // ── Messaging ─────────────────────────────────────────────────────────
  static const String messagesInbox = '/messages/inbox';
  static const String messagesDirect = '/messages/direct';
  static const String messagesGroup = '/messages/group';
  static const String broadcastingAuth = '/broadcasting/auth';
  static String messagesThread(String threadKey) =>
      '/messages/thread/$threadKey';

  // ── School Admin ──────────────────────────────────────────────────────
  static const String buses = '/buses';
  static const String routes = '/routes';
  static const String adminFleet = '/admin/fleets';
  static String busById(int id) => '/buses/$id';
  static String busLive(int id) => '/buses/$id/live';

  // ── Subscription ──────────────────────────────────────────────────────
  static const String initiatePayment = '/subscription/pay';
  static String checkPayment(String ref) => '/subscription/check/$ref';
  static String subStatus(int schoolId) => '/subscription/status/$schoolId';

  // ── Super Admin ───────────────────────────────────────────────────────
  static const String superSchools = '/super/schools';
  static const String superFleet = '/super/fleets';
  static String schoolById(int id) => '/schools/$id';

  // ── Parent ────────────────────────────────────────────────────────────
  static const String parentChildren = '/parent/children';
  static String parentBusLocation(int id) => '/parent/bus-location/$id';
  static String parentTripStatus(int id) => '/parent/trip-status/$id';

  // ── WebSocket — Laravel Reverb ────────────────────────────────────────
  static String get reverbHost => _lanIp;

  static Uri get reverbWsUri {
    const wsScheme = _reverbScheme == 'https' ? 'wss' : 'ws';
    return Uri.parse(
      '$wsScheme://$reverbHost:$_reverbPort/app/$_reverbKey'
      '?protocol=7&client=dart&version=1.0&flash=false',
    );
  }

  static String get reverbAuthEndpoint => '$_httpBase/broadcasting/auth';
}
