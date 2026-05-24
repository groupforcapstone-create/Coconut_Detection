import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

class DetectionHistoryStore {
  DetectionHistoryStore._();

  static final DetectionHistoryStore instance = DetectionHistoryStore._();

  static const String _historyFileName = 'detection_history.json';

  Future<List<Map<String, dynamic>>> getDetections() async {
    final file = await _historyFile();

    if (!await file.exists()) {
      return [];
    }

    final contents = await file.readAsString();
    if (contents.trim().isEmpty) {
      return [];
    }

    final decoded = jsonDecode(contents);
    if (decoded is! List) {
      return [];
    }

    return decoded
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Future<void> saveDetection({
    required File imageFile,
    required String label,
    required String lifespan,
    required List<dynamic> topPredictions,
  }) async {
    final savedImage = await _copyImageToLocalStorage(imageFile);
    final detections = await getDetections();
    final confidence = _readConfidence(topPredictions);

    detections.insert(0, {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'label': label,
      'lifespan': lifespan,
      'confidence': confidence,
      'image_path': savedImage.path,
      'created_at': DateTime.now().toIso8601String(),
      'top_predictions': topPredictions,
    });

    final file = await _historyFile();
    await file.writeAsString(jsonEncode(detections), flush: true);
  }

  Future<void> clearDetections() async {
    final detections = await getDetections();
    await _deleteSavedImages(detections);

    final file = await _historyFile();
    if (await file.exists()) {
      await file.writeAsString('[]', flush: true);
    }
  }

  Future<void> deleteDetectionsByIds(Set<String> ids) async {
    if (ids.isEmpty) return;

    final detections = await getDetections();
    final toDelete = detections.where((detection) {
      return ids.contains(detection['id']?.toString());
    }).toList();
    final remaining = detections.where((detection) {
      return !ids.contains(detection['id']?.toString());
    }).toList();

    await _deleteSavedImages(toDelete);

    final file = await _historyFile();
    await file.writeAsString(jsonEncode(remaining), flush: true);
  }

  Future<File> _historyFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_historyFileName');
  }

  Future<File> _copyImageToLocalStorage(File imageFile) async {
    final directory = await getApplicationDocumentsDirectory();
    final imageDirectory = Directory('${directory.path}/detection_images');

    if (!await imageDirectory.exists()) {
      await imageDirectory.create(recursive: true);
    }

    final extension = imageFile.path.split('.').last;
    final fileName = '${DateTime.now().microsecondsSinceEpoch}.$extension';
    return imageFile.copy('${imageDirectory.path}/$fileName');
  }

  double _readConfidence(List<dynamic> topPredictions) {
    if (topPredictions.isEmpty) return 0;

    final first = topPredictions.first;
    if (first is Map && first['confidence'] is num) {
      return (first['confidence'] as num).toDouble();
    }

    return 0;
  }

  Future<void> _deleteSavedImages(List<Map<String, dynamic>> detections) async {
    for (final detection in detections) {
      final imagePath = detection['image_path']?.toString() ?? '';
      if (imagePath.isEmpty) continue;

      final imageFile = File(imagePath);
      if (await imageFile.exists()) {
        try {
          await imageFile.delete();
        } catch (_) {
          // History deletion should not fail only because an image is locked.
        }
      }
    }
  }
}
