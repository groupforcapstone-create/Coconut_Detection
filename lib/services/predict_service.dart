import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'app_endpoints.dart';

class PredictService {
  /// MAIN FUNCTION: Nagpapadala ng image sa LOCAL AI Server (Python Flask)
  Future<Map<String, dynamic>?> predictCoconut(
      File imageFile, String token, String currentAddress) async {
    debugPrint('--- 🥥 COCONUT AI DEBUG START (LOCAL) ---');

    final stopwatch = Stopwatch()..start();

    try {
      // 1. I-prepare ang request para sa Local Flask Server
      var request =
          http.MultipartRequest('POST', Uri.parse(AppEndpoints.predictUrl));

      // I-add ang image file
      request.files
          .add(await http.MultipartFile.fromPath('file', imageFile.path));

      // I-add ang address field
      request.fields['address'] = currentAddress;

      debugPrint('⏳ Sending to Local AI @ ${AppEndpoints.predictUrl}...');

      // Mogamit sa timeout gikan sa AppEndpoints (60s)
      var streamedResponse =
          await request.send().timeout(AppEndpoints.connectionTimeout);

      var response = await http.Response.fromStream(streamedResponse);

      stopwatch.stop();

      if (response.statusCode == 200) {
        final Map<String, dynamic> aiResult = json.decode(response.body);
        debugPrint(
            '✅ AI SUCCESS: ${aiResult['variety_name']} (${stopwatch.elapsed.inSeconds}s)');

        // 2. AUTOMATIC SAVING TO LARAVEL HISTORY (Hostinger)
        // Bisan local ang AI, i-save gihapon nato ang result sa imong online database
        await _saveToScanHistory(imageFile, aiResult, token, currentAddress);

        return aiResult;
      } else {
        debugPrint(
            '❌ AI SERVER ERROR: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint(
          '🚨 CONNECTION ERROR: Siguraduha nga naka-ON ang Flask ug pareho og WiFi ang PC ug Phone.');
      debugPrint('Error Detail: $e');
      return null;
    } finally {
      debugPrint('--- 🥥 COCONUT AI DEBUG END ---');
    }
  }

  /// PRIVATE FUNCTION: I-save ang resulta sa Laravel (Hostinger)
  Future<void> _saveToScanHistory(File image, Map<String, dynamic> aiResult,
      String token, String address) async {
    debugPrint('💾 Syncing result to Hostinger Database...');

    try {
      var historyRequest =
          http.MultipartRequest('POST', Uri.parse(AppEndpoints.scanHistoryUrl));

      // Gamiton ang Multipart Headers nga naay Bearer Token
      historyRequest.headers
          .addAll(AppEndpoints.getMultipartHeaders(token: token));

      // Mapping: I-convert ang variety name gikan sa AI ngadto sa Database ID
      int detectionId = _getDetectionId(aiResult['variety_name']);

      historyRequest.fields['detection_id'] = detectionId.toString();
      historyRequest.fields['address'] = address;

      // I-save ang confidence (i-handle kung double o string ang balik sa AI)
      var conf = aiResult['confidence'];
      historyRequest.fields['confidence_json'] =
          json.encode({"label": aiResult['variety_name'], "confidence": conf});

      // I-upload ang actual image sa Hostinger/Laravel storage
      historyRequest.files
          .add(await http.MultipartFile.fromPath('scan_image', image.path));

      var response = await historyRequest.send();
      var responseData = await http.Response.fromStream(response);

      if (response.statusCode == 201 || response.statusCode == 200) {
        debugPrint('✅ Scan history synced to cloud!');
      } else {
        debugPrint('⚠️ Cloud Sync Failed: ${responseData.body}');
      }
    } catch (e) {
      debugPrint('🚨 History Saving Error: $e');
    }
  }

  /// Helper para makuha ang ID base sa pangalan gikan sa AI
  /// Siguraduhon nga ang ID na-setup na sa imong 'detections' table sa MySQL
  int _getDetectionId(String? varietyName) {
    switch (varietyName) {
      case 'Baybay Tall Coconut':
        return 1;
      case 'Catigan Dwarf Coconut':
        return 2;
      case 'Tacunan Dwarf Coconut':
        return 3;
      default:
        return 4; // ID para sa 'Not a Coconut' o 'Unknown'
    }
  }
}
