// NOTE: This file was added to satisfy imports during development.
// The app now runs in "camera settings only" mode and does not contact the backend.

class AppEndpoints {
  // Legacy fields kept for compatibility with existing code.
  // They should not be used.
  static const String healthCheckUrl = '';
  static const String predictUrl = '';

  static Future<String> getStoredToken() async => '';

  static Map<String, String> getMultipartHeaders({required String token}) {
    return const {
      'Content-Type': 'multipart/form-data',
      // No auth header (token is unused in camera-only mode)
    };
  }
}
