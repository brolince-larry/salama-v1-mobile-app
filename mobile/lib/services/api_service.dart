import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';
import 'api_exception.dart';

class ApiService {
  ApiService._();

  static late final Dio _dio;
  static const _storage  = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
static Future<bool> hasToken() async {
    final token = await _storage.read(key: _tokenKey);
    return token != null && token.isNotEmpty;
  }
  static Future<void> init() async {
    _dio = Dio(
      BaseOptions(
        baseUrl:        ApiConfig.baseUrl,
        connectTimeout: ApiConfig.connectTimeout,
        receiveTimeout: ApiConfig.receiveTimeout,
        headers: {
          'Accept': 'application/json',
          // Note: We remove global Content-Type here to let Dio 
          // set it automatically for Multipart vs JSON requests.
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await _storage.read(key: _tokenKey);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
        onError: (error, handler) {
          final apiEx = _handleError(error);
          return handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              error:          apiEx,
              message:        apiEx.message,
              type:           error.type,
              response:       error.response,
            ),
          );
        },
      ),
    );

    assert(() {
      _dio.interceptors.add(LogInterceptor(requestBody: true, responseBody: true));
      return true;
    }());
  }

  // ── Token helpers ─────────────────────────────────────────────────────────
  static Future<void> saveToken(String token) async => _storage.write(key: _tokenKey, value: token);
  static Future<void> clearToken() async => _storage.delete(key: _tokenKey);
  static Future<String?> getToken() => _storage.read(key: _tokenKey);

  // ── HTTP methods ──────────────────────────────────────────────────────────

  static Future<dynamic> get(String path, {Map<String, dynamic>? queryParams}) async {
    try {
      final res = await _dio.get(path, queryParameters: queryParams);
      return res.data;
    } on DioException catch (e) { throw _extractApiException(e); }
  }

  static Future<dynamic> post(String path, {Map<String, dynamic>? body}) async {
    try {
      final res = await _dio.post(path, data: body);
      return res.data;
    } on DioException catch (e) { throw _extractApiException(e); }
  }

  /// Specialized method for Image/File uploads
  static Future<dynamic> postMultipart(String path, FormData formData) async {
    try {
      final res = await _dio.post(
        path,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data', // Essential for file streams
        ),
      );
      return res.data;
    } on DioException catch (e) {
      throw _extractApiException(e);
    }
  }

  static Future<dynamic> put(String path, {Map<String, dynamic>? body}) async {
    try {
      final res = await _dio.put(path, data: body);
      return res.data;
    } on DioException catch (e) { throw _extractApiException(e); }
  }

  static Future<dynamic> delete(String path) async {
    try {
      final res = await _dio.delete(path);
      return res.data;
    } on DioException catch (e) { throw _extractApiException(e); }
  }

  // ── Error Handling Logic ──────────────────────────────────────────────────

  static ApiException _extractApiException(DioException e) {
    if (e.error is ApiException) return e.error as ApiException;
    return _handleError(e);
  }

  static ApiException _handleError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return const ApiException(message: 'Connection timed out.', statusCode: 408);
      case DioExceptionType.badResponse:
        return _handleHttpError(e.response);
      default:
        return ApiException(message: e.message ?? 'Unexpected error');
    }
  }

  static ApiException _handleHttpError(Response? response) {
    if (response == null) return const ApiException(message: 'No response.');
    final code = response.statusCode ?? 0;
    final data = response.data;
    String message = data is Map ? data['message'] ?? 'Error' : 'Error';
    
    return ApiException(
      message: message, 
      statusCode: code, 
      errors: data is Map ? data['errors'] : null
    );
  }
}