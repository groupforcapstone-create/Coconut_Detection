import 'package:shared_preferences/shared_preferences.dart';

/// AppEndpoints: Central configuration for all API connections.
/// Updated for Production: Render (AI) & Hostinger (Laravel Web).
class AppEndpoints {
  // --- BASE URLS ---

  // Laravel Web/API (Hostinger)
  static const String _liveWebsite = 'https://coconutweb.online';

  // Python/Flask AI (Render)
  static const String _aiBackend = 'https://coconut-ai-backend.onrender.com';

  // --- TIMEOUT CONFIG ---
  // Render Free Tier needs a long timeout (up to 120s) due to "Cold Starts"
  static const Duration connectionTimeout = Duration(seconds: 120);

  // --- AI ENDPOINTS (Flask/TensorFlow Lite) ---
  static const String predictUrl = '$_aiBackend/predict';
  static const String healthCheckUrl = '$_aiBackend/';

  // --- LARAVEL API ENDPOINTS ---
  static const String apiBase = '$_liveWebsite/api';

  // Authentication & Profile
  static const String loginUrl = '$apiBase/seller/login';
  static const String registerUrl = '$apiBase/seller/register';
  static const String otpRequestUrl = '$apiBase/seller/otp/request';
  static const String forgotPasswordUrl = '$apiBase/seller/forgot-password';
  static const String logoutUrl = '$apiBase/seller/logout';
  static const String profileUrl = '$apiBase/seller/profile';
  static const String updateProfileUrl = '$apiBase/seller/profile/update';
  static const String updatePhotoUrl = '$apiBase/seller/profile/update-photo';

  // Scanning & History
  // Note: Your AI backend saves to DB directly, but Laravel might fetch it.
  static const String scanHistoryUrl = '$apiBase/seller/scan-history';
  static const String detectionsUrl = '$apiBase/detections';

  // Products & Varieties
  static const String varietiesUrl = '$apiBase/varieties';
  static const String coconutVarietiesUrl = '$apiBase/coconut-varieties';
  static const String productsUrl = '$apiBase/products';
  static const String sellerProductsUrl = '$apiBase/seller/products';

  // --- HEADERS CONFIG ---

  /// Standard Headers for JSON-based requests (POST/GET)
  static Map<String, String> getHeaders({String? token}) {
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  /// Specialized Headers for Image Uploads (Multipart)
  /// Note: DO NOT set 'Content-Type' manually here;
  /// http.MultipartRequest will automatically generate it with the correct boundary.
  static Map<String, String> getMultipartHeaders({String? token}) {
    return {
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // --- STORAGE & HELPERS ---

  /// Retrieves the Bearer token from local storage
  static Future<String?> getStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    // Use the same key across your login/logout logic
    return prefs.getString('auth_token');
  }

  /// Laravel Image URL Normalizer
  /// Converts DB paths (e.g., 'products/img.jpg') to full accessible URLs.
  static String? normalizeUrl(String? path) {
    if (path == null || path.trim().isEmpty) return null;

    // 1. If it's already a full URL, return it as is
    if (path.startsWith('http')) return path;

    String cleanPath = path.trim();

    // 2. Remove 'public/' if present (Laravel filesystem quirk)
    if (cleanPath.startsWith('public/')) {
      cleanPath = cleanPath.substring(7);
    }

    // 3. Strip any leading slashes to prevent "double slash" errors
    cleanPath = cleanPath.replaceFirst(RegExp(r'^/+'), '');

    // 4. Ensure it points to the 'storage' link
    if (!cleanPath.startsWith('storage/')) {
      cleanPath = 'storage/$cleanPath';
    }

    return "$_liveWebsite/$cleanPath";
  }
}
