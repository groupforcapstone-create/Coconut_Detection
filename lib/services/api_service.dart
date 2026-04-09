import 'dart:convert';
import 'dart:io' show HttpClient, SocketException;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_endpoints.dart';

class ApiService {
  /// Helper to get client with SSL bypass
  /// Inayos para hindi mag-error sa Web (Chrome)
  static http.Client get _client {
    if (kIsWeb) {
      return http.Client(); // Standard client for Web
    }
    // SSL Bypass para sa Android/iOS local development
    final ioc = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30)
      ..badCertificateCallback = (cert, host, port) => true;
    return IOClient(ioc);
  }

  static Future<Map<String, String>> _getAuthHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString('auth_token');
    final headers = AppEndpoints.getHeaders(token: token);
    if (!kIsWeb) {
      headers['User-Agent'] = 'CoconutApp_Mobile';
    }
    return headers;
  }

  // --- 1. LIVE LOCATION SEARCH ---
  static Future<List<String>> searchLocations(String query) async {
    if (query.length < 3) return [];
    final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&addressdetails=1&limit=6&countrycodes=ph');

    try {
      final response = await _client.get(url, headers: {
        'User-Agent': 'CoconutApp_Mobile',
        'Accept': 'application/json',
      });

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((item) => item['display_name'].toString()).toList();
      }
    } catch (e) {
      debugPrint('🚨 Location API Error: $e');
    }
    return [];
  }

  // --- 2. LOGIN ---
  static Future<Map<String, dynamic>> login({
    required String loginInput,
    required String password,
  }) async {
    final url = Uri.parse(AppEndpoints.loginUrl);
    final body = jsonEncode({'login': loginInput.trim(), 'password': password});
    final headers = AppEndpoints.getHeaders();
    if (!kIsWeb) {
      headers['User-Agent'] = 'CoconutApp_Mobile';
    }

    try {
      final response = await _client.post(
        url,
        headers: headers,
        body: body,
      );
      return await _handleResponse(response);
    } catch (e) {
      _processError(e, "LOGIN");
      throw _friendlyError(e);
    }
  }

  // --- 3. REGISTER ---
  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    required String phoneNumber,
    required String otpCode,
    String? location,
  }) async {
    final url = Uri.parse(AppEndpoints.registerUrl);
    final body = jsonEncode({
      'full_name': name.trim(),
      'email': email.trim(),
      'password': password,
      'phone_number': phoneNumber.trim(),
      'otp_code': otpCode.trim(),
      'location': location ?? '',
    });
    final headers = AppEndpoints.getHeaders();
    if (!kIsWeb) {
      headers['User-Agent'] = 'CoconutApp_Mobile';
    }

    try {
      final response = await _client.post(
        url,
        headers: headers,
        body: body,
      );
      return await _handleResponse(response);
    } catch (e) {
      _processError(e, "REGISTER");
      throw _friendlyError(e);
    }
  }

  // --- 3A. REQUEST OTP ---
  static Future<Map<String, dynamic>> requestOtp({
    required String phoneNumber,
    required String purpose, // register | reset
  }) async {
    final url = Uri.parse(AppEndpoints.otpRequestUrl);
    final body = jsonEncode({
      'phone_number': phoneNumber.trim(),
      'purpose': purpose,
    });
    final headers = AppEndpoints.getHeaders();
    if (!kIsWeb) {
      headers['User-Agent'] = 'CoconutApp_Mobile';
    }

    try {
      final response = await _client.post(url, headers: headers, body: body);
      return await _handleResponse(response);
    } catch (e) {
      _processError(e, "OTP REQUEST");
      throw _friendlyError(e);
    }
  }

  // --- 3B. RESET PASSWORD WITH OTP ---
  static Future<Map<String, dynamic>> resetPasswordWithOtp({
    required String phoneNumber,
    required String otpCode,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final url = Uri.parse(AppEndpoints.forgotPasswordUrl);
    final body = jsonEncode({
      'phone_number': phoneNumber.trim(),
      'otp_code': otpCode.trim(),
      'new_password': newPassword,
      'new_password_confirmation': confirmPassword,
    });
    final headers = AppEndpoints.getHeaders();
    if (!kIsWeb) {
      headers['User-Agent'] = 'CoconutApp_Mobile';
    }

    try {
      final response = await _client.post(url, headers: headers, body: body);
      return await _handleResponse(response);
    } catch (e) {
      _processError(e, "RESET PASSWORD");
      throw _friendlyError(e);
    }
  }

  // --- 4. GET PROFILE ---
  static Future<Map<String, dynamic>> getProfile() async {
    final url = Uri.parse(AppEndpoints.profileUrl);
    final headers = await _getAuthHeaders();

    try {
      final response = await _client.get(url, headers: headers);
      return await _handleResponse(response);
    } catch (e) {
      _processError(e, "PROFILE");
      rethrow;
    }
  }

  // --- 5. UPDATE PROFILE ---
  static Future<Map<String, dynamic>> updateProfile({
    required String fullName,
    required String email,
    required String phoneNumber,
    String? location,
  }) async {
    final url = Uri.parse(AppEndpoints.updateProfileUrl);
    final headers = await _getAuthHeaders();
    final body = jsonEncode({
      'full_name': fullName.trim(),
      'email': email.trim(),
      'phone_number': phoneNumber.trim(),
      'location': location ?? '',
    });

    try {
      final response = await _client.put(url, headers: headers, body: body);
      final data = await _handleResponse(response);

      final prefs = await SharedPreferences.getInstance();
      final seller = data['seller'] ?? data['user'] ?? data['data'];
      if (seller != null) {
        await prefs.setString(
            'seller_full_name', seller['full_name'] ?? fullName);
        await prefs.setString('seller_location', seller['location'] ?? '');
        await prefs.setString('seller_phone', seller['phone_number'] ?? '');
        await prefs.setString('seller_email', seller['email'] ?? email);
      }

      final rawPhoto = data['photo_url'] ?? seller?['profile_photo_path'];
      final normalizedPhoto =
          AppEndpoints.normalizeUrl(rawPhoto?.toString());
      if (normalizedPhoto != null && normalizedPhoto.isNotEmpty) {
        await prefs.setString('profile_photo_path', normalizedPhoto);
      }

      return data;
    } catch (e) {
      _processError(e, "UPDATE PROFILE");
      rethrow;
    }
  }

  // --- 6. LOGOUT ---
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('seller_full_name');
    await prefs.remove('seller_location');
    await prefs.remove('seller_phone'); // Idinagdag para malinis pati phone
    debugPrint('🗑️ Session cleared.');
  }

  // --- HELPER: RESPONSE HANDLER (FIXED FOR PHONE NUMBER) ---
  static Future<Map<String, dynamic>> _handleResponse(
      http.Response response) async {
    final String rawBody = response.body.trim();
    final String contentType =
        (response.headers['content-type'] ?? '').toLowerCase();
    debugPrint('📡 API Response [${response.statusCode}]');

    if (rawBody.contains('<!DOCTYPE html>')) {
      throw 'Server error: Received HTML instead of JSON.';
    }

    try {
      final Map<String, dynamic> data = jsonDecode(rawBody);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['token'] != null) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('auth_token', data['token']);

          final seller = data['seller'] ?? data['user'];
          if (seller != null) {
            // --- DITO ANG FIX: Isave ang phone number ---
            await prefs.setString(
                'seller_full_name', seller['full_name'] ?? '');
            await prefs.setString('seller_location', seller['location'] ?? '');
            await prefs.setString('seller_phone', seller['phone_number'] ?? '');

            debugPrint('✅ Saved Phone: ${seller['phone_number']}');
          }

          // Save profile photo (if provided) so it can show on other devices
          final rawPhoto =
              data['photo_url'] ?? seller?['profile_photo_path'];
          final normalizedPhoto =
              AppEndpoints.normalizeUrl(rawPhoto?.toString());
          if (normalizedPhoto != null && normalizedPhoto.isNotEmpty) {
            await prefs.setString('profile_photo_path', normalizedPhoto);
          }
        }
        return data;
      } else {
        throw data['message'] ?? 'Error: ${response.statusCode}';
      }
    } catch (e) {
      if (e is FormatException) {
        final String snippet =
            rawBody.length > 300 ? '${rawBody.substring(0, 300)}...' : rawBody;
        debugPrint(
            '⚠️ JSON parse failed. Status ${response.statusCode}. CT=$contentType. Body: $snippet');
        throw 'Invalid JSON response from server (HTTP ${response.statusCode}).';
      }
      if (e is String) rethrow;
      throw 'Invalid JSON response from server.';
    }
  }

  static void _processError(dynamic e, String label) {
    debugPrint('🚨 API ERROR [$label]: $e');
  }

  static String _friendlyError(dynamic e) {
    if (e is SocketException) {
      return 'Check your internet.';
    }
    if (e is TimeoutException) {
      return 'Request timed out. Check your internet.';
    }
    final message = e.toString();
    if (message.contains('SocketException')) {
      return 'Check your internet.';
    }
    if (message.toLowerCase().contains('timed out')) {
      return 'Request timed out. Check your internet.';
    }
    return message.replaceAll('Exception: ', '').trim();
  }
}
