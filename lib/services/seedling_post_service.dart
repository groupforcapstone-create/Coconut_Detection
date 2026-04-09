import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_endpoints.dart';

// =========================================================
// MODEL CLASS
// =========================================================
class SeedlingPost {
  final int? id;
  final int? sellerId;
  final String sellerName;
  final String sellerEmail;
  final String? sellerPhotoUrl;
  final String coconutVariety;
  final String lifespan;
  final String definition;
  final String price;
  final String quantity;
  final String location;
  final String contact;
  final String? imageUrl;
  final bool isActive;
  final DateTime? createdAt;

  SeedlingPost({
    this.id,
    this.sellerId,
    required this.sellerName,
    required this.sellerEmail,
    this.sellerPhotoUrl,
    required this.coconutVariety,
    required this.lifespan,
    required this.definition,
    required this.price,
    required this.quantity,
    required this.location,
    required this.contact,
    this.imageUrl,
    this.isActive = true,
    this.createdAt,
  });

  factory SeedlingPost.fromJson(Map<String, dynamic> json) {
    final seller = json['seller'] is Map<String, dynamic>
        ? json['seller'] as Map<String, dynamic>
        : <String, dynamic>{};

    return SeedlingPost(
      id: _parseId(json['id']),
      sellerId: _parseId(json['seller_id'] ?? seller['id']),
      sellerName: (seller['full_name'] ?? 'Unknown Seller').toString(),
      sellerEmail: (seller['email'] ?? '').toString(),
      contact: (seller['phone_number'] ?? '-').toString(),
      sellerPhotoUrl: AppEndpoints.normalizeUrl(
          seller['photo_url'] ?? seller['profile_photo_path']),
      coconutVariety:
          (json['coconut_variety'] ?? 'Coconut Seedling').toString(),
      lifespan: (json['lifespan'] ?? '-').toString(),
      definition: (json['definition'] ?? '-').toString(),
      price: (json['price'] ?? '0').toString(),
      quantity: (json['quantity'] ?? '0').toString(),
      // FULL FIX: Ensure location is captured correctly from the new DB column
      location: (json['location'] ?? '-').toString(),
      imageUrl:
          AppEndpoints.normalizeUrl(json['image_url'] ?? json['image_path']),
      isActive:
          json['is_active'] == true || json['is_active'].toString() == '1',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  static int? _parseId(dynamic value) => int.tryParse(value?.toString() ?? '');
}

// =========================================================
// SERVICE CLASS
// =========================================================
class SeedlingPostService {
  SeedlingPostService._();
  static final SeedlingPostService instance = SeedlingPostService._();

  final ValueNotifier<List<SeedlingPost>> posts = ValueNotifier([]);
  final ValueNotifier<bool> hasNewPostNotice = ValueNotifier(false);
  final ValueNotifier<bool> loading = ValueNotifier(false);

  // --- INTERNAL HANDSHAKE BYPASS (Mobile SSL Fix) ---
  http.Client get _client {
    if (kIsWeb) {
      return http.Client();
    }
    final ioc = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
    return IOClient(ioc);
  }

  Future<String> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('auth_token') ?? prefs.getString('token');
    return (token ?? '').trim();
  }

  // --- 1. AI PREDICTION ---
  Future<String?> predictVariety(XFile image) async {
    try {
      final uri = Uri.parse(AppEndpoints.predictUrl);
      var request = http.MultipartRequest('POST', uri);

      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes('file', bytes,
            filename: 'analysis.jpg'));
      } else {
        request.files
            .add(await http.MultipartFile.fromPath('file', image.path));
      }

      final streamedRes =
          await _client.send(request).timeout(const Duration(seconds: 25));
      final response = await http.Response.fromStream(streamedRes);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['variety']?.toString();
      }
    } catch (e) {
      debugPrint('AI Prediction Error: $e');
    }
    return null;
  }

  // --- 2. FETCH ALL POSTS ---
  Future<void> fetchPosts() async {
    loading.value = true;
    try {
      final response = await _client.get(
        Uri.parse(AppEndpoints.productsUrl),
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        posts.value = _parsePostList(response.body);
      }
    } catch (e) {
      debugPrint('Fetch All Posts Error: $e');
    } finally {
      loading.value = false;
    }
  }

  // --- 3. CREATE POST ---
  Future<void> createPost({
    required XFile image,
    required String coconutVariety,
    required String price,
    required String quantity,
    required String location,
  }) async {
    final token = await _getToken();
    if (token.isEmpty) {
      throw Exception('Session expired. Please re-login.');
    }

    try {
      final uri = Uri.parse(AppEndpoints.sellerProductsUrl);
      final request = http.MultipartRequest('POST', uri);

      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      request.fields['coconut_variety'] = coconutVariety;
      request.fields['price'] = price;
      request.fields['quantity'] = quantity;
      request.fields['location'] = location;

      if (kIsWeb) {
        final bytes = await image.readAsBytes();
        request.files.add(http.MultipartFile.fromBytes('image', bytes,
            filename: 'upload.jpg'));
      } else {
        request.files
            .add(await http.MultipartFile.fromPath('image', image.path));
      }

      final streamedResponse =
          await _client.send(request).timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        hasNewPostNotice.value = true;
        await fetchPosts();
      } else {
        final errorMsg = _extractMessage(response.body) ??
            'Server Error ${response.statusCode}';
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('Create Post Error: $e');
      rethrow;
    }
  }

  // --- 4. UPDATE POST ---
  Future<void> updatePost({
    required int id,
    XFile? image,
    required String coconutVariety,
    required String price,
    required String quantity,
    required String location,
  }) async {
    final token = await _getToken();
    if (token.isEmpty) {
      throw Exception('Session expired. Please re-login.');
    }

    try {
      final uri = Uri.parse('${AppEndpoints.sellerProductsUrl}/$id');
      final request = http.MultipartRequest('POST', uri);

      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      request.fields['coconut_variety'] = coconutVariety;
      request.fields['price'] = price;
      request.fields['quantity'] = quantity;
      request.fields['location'] = location;

      if (image != null) {
        if (kIsWeb) {
          final bytes = await image.readAsBytes();
          request.files.add(http.MultipartFile.fromBytes('image', bytes,
              filename: 'upload.jpg'));
        } else {
          request.files
              .add(await http.MultipartFile.fromPath('image', image.path));
        }
      }

      final streamedResponse =
          await _client.send(request).timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        await fetchPosts();
      } else {
        final errorMsg = _extractMessage(response.body) ??
            'Server Error ${response.statusCode}';
        throw Exception(errorMsg);
      }
    } catch (e) {
      debugPrint('Update Post Error: $e');
      rethrow;
    }
  }

  // --- 5. FETCH MY POSTS ---
  Future<List<SeedlingPost>> fetchMyPosts() async {
    final token = await _getToken();
    if (token.isEmpty) {
      throw Exception('Authentication required.');
    }

    try {
      final response = await _client.get(
        Uri.parse(AppEndpoints.sellerProductsUrl),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        return _parsePostList(response.body);
      } else {
        throw Exception(
            _extractMessage(response.body) ?? 'Failed to fetch listings.');
      }
    } catch (e) {
      if (e is SocketException || e is HandshakeException) {
        throw Exception('Connection error. Please check your internet.');
      }
      rethrow;
    }
  }

  // --- 6. DELETE POST ---
  Future<void> deletePost(int id) async {
    final token = await _getToken();
    try {
      final response = await _client.delete(
        Uri.parse('${AppEndpoints.sellerProductsUrl}/$id'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200 && response.statusCode != 204) {
        throw Exception(_extractMessage(response.body) ?? 'Delete failed');
      }
      await fetchPosts();
    } catch (e) {
      rethrow;
    }
  }

  // --- 7. UPDATE PROFILE PICTURE (Mobile Optimized) ---
  Future<String> updateProfilePicture(XFile pickedFile) async {
    final token = await _getToken();
    if (token.isEmpty) {
      throw Exception('Session expired.');
    }

    try {
      final uri = Uri.parse(AppEndpoints.updatePhotoUrl);
      final request = http.MultipartRequest('POST', uri);

      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      // Pinapasa natin ang file path mula sa XFile
      request.files.add(
          await http.MultipartFile.fromPath('profile_photo', pickedFile.path));

      final streamedRes =
          await _client.send(request).timeout(const Duration(seconds: 20));
      final response = await http.Response.fromStream(streamedRes);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // I-normalize ang URL na galing sa server para mabasa ng network image
        String rawUrl = data['photo_url'] ?? data['image_url'] ?? '';
        return AppEndpoints.normalizeUrl(rawUrl) ?? '';
      } else {
        throw Exception(_extractMessage(response.body) ?? 'Upload failed');
      }
    } catch (e) {
      debugPrint('Profile Upload Error: $e');
      rethrow;
    }
  }

  // --- 8. SAVE SCAN HISTORY TO SERVER ---
  Future<bool> uploadScanHistory({
    required File imageFile,
    required String label,
    required String topPrediction,
    required List<dynamic> predictions,
    required String address,
  }) async {
    final token = await _getToken();
    if (token.isEmpty) {
      return false;
    }

    try {
      final uri = Uri.parse(AppEndpoints.scanHistoryUrl);
      final request = http.MultipartRequest('POST', uri);

      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });

      request.fields['label'] = label;
      request.fields['top_prediction'] = topPrediction;
      request.fields['confidence_json'] = jsonEncode(predictions);
      request.fields['address'] = address;

      request.files
          .add(await http.MultipartFile.fromPath('scan_image', imageFile.path));

      final streamedRes =
          await _client.send(request).timeout(const Duration(seconds: 20));
      final response = await http.Response.fromStream(streamedRes);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return true;
      }
      debugPrint('Scan history upload failed: ${response.statusCode}');
      return false;
    } catch (e) {
      debugPrint('Scan history upload error: $e');
      return false;
    }
  }

  /// Fetches the currently saved profile photo URL from the backend.
  ///
  /// This is useful to keep the app in sync across multiple devices using the
  /// same account, since local SharedPreferences is device-specific.
  Future<String?> fetchProfilePhotoUrl() async {
    final token = await _getToken();
    if (token.isEmpty) {
      return null;
    }

    try {
      final response = await _client.get(
        Uri.parse(AppEndpoints.profileUrl),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final profile = (data is Map<String, dynamic>)
            ? (data['data'] ?? data) as Map<String, dynamic>
            : {};

        // Server may return different field names for photo
        final rawUrl = profile['photo_url'] ??
            profile['profile_photo_path'] ??
            profile['photo'] ??
            profile['avatar'];
        return AppEndpoints.normalizeUrl(rawUrl?.toString());
      }
    } catch (e) {
      debugPrint('Fetch profile photo error: $e');
    }
    return null;
  }

  // --- HELPERS ---
  List<SeedlingPost> _parsePostList(String body) {
    try {
      final decoded = jsonDecode(body);
      final List<dynamic> data =
          (decoded is List) ? decoded : (decoded['data'] ?? []);
      return data
          .map((e) => SeedlingPost.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  String? _extractMessage(String body) {
    try {
      return jsonDecode(body)['message']?.toString();
    } catch (_) {
      return null;
    }
  }

  void clearNewPostNotice() => hasNewPostNotice.value = false;
}
