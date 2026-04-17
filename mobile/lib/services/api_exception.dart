/// Unified error type thrown by ApiService.
/// Every screen catches this one type — no scattered DioException handling.
///
/// Usage:
///   try {
///     await ApiService.login(...);
///   } on ApiException catch (e) {
///     showSnackBar(e.message);
///   }
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors; // Laravel validation errors

  const ApiException({
    required this.message,
    this.statusCode,
    this.errors,
  });

  /// Returns the first Laravel validation error for a given field.
  /// e.g. firstError('email') → "The email field is required."
  String? firstError(String field) {
    final fieldErrors = errors?[field];
    if (fieldErrors is List && fieldErrors.isNotEmpty) {
      return fieldErrors.first as String;
    }
    return null;
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}