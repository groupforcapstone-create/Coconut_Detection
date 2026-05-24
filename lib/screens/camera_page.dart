import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../services/detection_history_store.dart';
import 'instructions/camerainstruction_page.dart';

class CameraPage extends StatefulWidget {
  const CameraPage({super.key});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  CameraController? _controller;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final ImagePicker _picker = ImagePicker();

  FlashMode _currentFlashMode = FlashMode.off;
  bool _isFlashSupported = true;

  bool _isLocalModelReady = false;
  final bool _useLocalModel = !kIsWeb;

  bool _isCameraReady = false;
  bool _isAnalyzing = false;
  bool _hasResult = false;

  File? _capturedImage;

  String _label = "";
  List<dynamic> _topPredictions = [];
  String _lifespan = "";
  String _statusLabel = "READY TO SCAN";

  final double _scannerBoxSizeUI = 260.0;
  final double _topPercentUI = 0.20;
  final int _maxImageSide = 1024;
  final Duration _minimumScanDuration = const Duration(milliseconds: 1800);

  Interpreter? _interpreter;
  List<String> _labels = [];
  String? _lastModelError;

  bool _didShowGuide = false;

  bool _isNotCoconutLabel(String label) {
    final l = label.toLowerCase().trim();
    return l.contains('not a coconut') ||
        l.contains('not coconut') ||
        l.contains('notcoconut') ||
        l.contains('invalid') ||
        l.contains('unknown') ||
        l.contains('not ') ||
        l == 'not';
  }

  String _displayLabel(String label) {
    final normalized = label.toLowerCase();
    if (normalized.contains('baybay')) return 'Baybay Tall Coconut';
    if (normalized.contains('catigan')) return 'Catigan Dwarf Coconut';
    if (normalized.contains('tacunan')) return 'Tacunan Dwarf Coconut';
    return 'Invalid Image';
  }

  Color _getRankColor(int index) {
    if (index == 0) return const Color(0xFF16A34A);
    if (index == 1) return const Color(0xFFF59E0B);
    return const Color(0xFFDC2626);
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _initCamera();
    _loadLocalModel();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _controller?.dispose();
    _pulseController.dispose();
    _interpreter?.close();

    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Show guide once when camera page becomes active.
    if (!_didShowGuide && _isCameraReady) {
      _didShowGuide = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _hasResult) return;
        showDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (context) => const CameraInstructionPage(),
        );
      });
    }
  }

  Future<void> _loadLocalModel() async {
    if (!_useLocalModel) return;

    try {
      if (mounted) {
        setState(() {
          _statusLabel = "LOADING MODEL...";
        });
      }

      final options = InterpreterOptions()..threads = 2;
      final interpreter = await Interpreter.fromAsset(
        'assets/models/coconut_model2.tflite',
        options: options,
      );
      final labelsText = await rootBundle.loadString(
        'assets/models/coconut_labels.txt',
      );

      _interpreter = interpreter;
      _labels = labelsText
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      if (_labels.isEmpty) {
        _labels = const [
          'Baybay Tall Coconut',
          'Catigan Dwarf Coconut',
          'Tacunan Dwarf Coconut',
          'Not a Coconut',
        ];
      }

      if (mounted) {
        setState(() {
          _isLocalModelReady = true;
          _lastModelError = null;
          _statusLabel = _isCameraReady ? "READY TO SCAN" : "OPENING CAMERA...";
        });
      }
    } catch (e) {
      debugPrint('Local TFLite load failed: $e');
      if (mounted) {
        setState(() {
          _isLocalModelReady = false;
          _lastModelError = e.toString();
          _statusLabel = "MODEL LOAD FAILED";
        });
      }
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) return;

      _controller = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();

      try {
        await _controller!.setFlashMode(_currentFlashMode);
        _isFlashSupported = true;
      } catch (_) {
        _isFlashSupported = false;
      }

      if (mounted) {
        setState(() {
          _isCameraReady = true;
          _hasResult = false;
          _statusLabel = _isLocalModelReady
              ? (_isFlashSupported
                  ? "READY TO SCAN"
                  : "READY TO SCAN (NO FLASH)")
              : "LOADING MODEL...";
        });
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (!_isFlashSupported) return;

    final FlashMode nextMode =
        (_currentFlashMode == FlashMode.off) ? FlashMode.torch : FlashMode.off;

    try {
      await _controller!.setFlashMode(nextMode);
      setState(() => _currentFlashMode = nextMode);
    } catch (e) {
      debugPrint("Flash Toggle Error: $e");
      setState(() {
        _isFlashSupported = false;
        _currentFlashMode = FlashMode.off;
        _statusLabel = "FLASH NOT SUPPORTED";
      });
    }
  }

  Future<void> _handleScan({File? manualFile}) async {
    // Ensures a clean camera state before capturing.
    // (Helps with devices where takePicture() sporadically fails.)
    if (manualFile == null &&
        _controller != null &&
        _controller!.value.isInitialized) {
      try {
        await _controller!.stopImageStream();
      } catch (_) {
        // no-op: not all camera states support this
      }
    }

    if (_isAnalyzing) return;
    if (!_isLocalModelReady || _interpreter == null || _labels.isEmpty) {
      setState(() {
        _statusLabel = _lastModelError == null
            ? "MODEL STILL LOADING"
            : "MODEL NOT CONNECTED";
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _statusLabel = "ANALYZING...";
    });

    try {
      final scanStartedAt = DateTime.now();
      late final File fileToUpload;

      if (manualFile != null) {
        fileToUpload = manualFile;
      } else {
        final controller = _controller;
        if (controller == null || !controller.value.isInitialized) {
          throw Exception("Camera not ready");
        }

        // Some Android devices throw NPE inside the camera plugin when
        // ImageReader isn't fully ready. A short delay greatly reduces this.
        await Future<void>.delayed(const Duration(milliseconds: 150));

        try {
          final XFile rawPhoto = await controller.takePicture();
          fileToUpload = File(rawPhoto.path);
        } catch (e) {
          // Retry once: this is common for transient plugin state.
          await Future<void>.delayed(const Duration(milliseconds: 250));
          final XFile rawPhoto = await controller.takePicture();
          fileToUpload = File(rawPhoto.path);
        }
      }

      if (_useLocalModel) {
        final localResult = await _predictWithLocalModel(fileToUpload.path)
            .timeout(const Duration(seconds: 12));

        if (localResult != null) {
          await _waitForScanMoment(scanStartedAt);

          if (!mounted) return;
          setState(() => _capturedImage = fileToUpload);
          await _processResults(localResult);
          return;
        }
      }

      throw Exception('Local model failed to return a result');
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _statusLabel = "SCAN TIMED OUT";
      });
    } catch (e) {
      debugPrint('Scan failed: $e');
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _lastModelError = e.toString();
        _statusLabel = "MODEL SCAN FAILED";
      });
    }
  }

  Future<void> _waitForScanMoment(DateTime scanStartedAt) async {
    final elapsed = DateTime.now().difference(scanStartedAt);
    final remaining = _minimumScanDuration - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
  }

  String _shortError(String error) {
    return error
        .replaceAll('Exception: ', '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<Map<String, dynamic>?> _predictWithLocalModel(String imagePath) async {
    final interpreter = _interpreter;
    if (interpreter == null || _labels.isEmpty) return null;

    try {
      final inputTensor = interpreter.getInputTensor(0);

      final outputTensor = interpreter.getOutputTensor(0);
      final inputShape = inputTensor.shape;
      final outputShape = outputTensor.shape;

      if (inputShape.length != 4) {
        throw Exception('Unsupported input shape: $inputShape');
      }
      if (outputShape.isEmpty) {
        throw Exception('Unsupported output shape: $outputShape');
      }

      final imageBytes = await File(imagePath).readAsBytes();
      final decodedImage = img.decodeImage(imageBytes);
      if (decodedImage == null) {
        throw Exception('Image could not be decoded');
      }

      final preparedImage = _resizeForFastDecode(decodedImage);
      final inputLayout = _resolveInputLayout(inputShape);

      final inputType = inputTensor.type.toString().toLowerCase();
      final outputType = outputTensor.type.toString().toLowerCase();

      final resizedImage = img.copyResize(
        preparedImage,
        width: inputLayout.width,
        height: inputLayout.height,
      );

      final input = _buildModelInput(
        image: resizedImage,
        layout: inputLayout,
        inputType: inputType,
      );

      final output = _buildModelOutput(
        outputShape: outputShape,
        outputType: outputType,
      );

      interpreter.run(input, output);

      final scores = _scoresFromOutput(
        output,
        outputType: outputType,
        scale: outputTensor.params.scale,
        zeroPoint: outputTensor.params.zeroPoint,
      );
      if (scores.isEmpty) {
        throw Exception('Model returned empty output');
      }

      final classCount = math.min(scores.length, _labels.length);
      final rankedPredictions = List.generate(classCount, (index) {
        final label = index < _labels.length ? _labels[index] : 'Class $index';
        return {'label': label, 'confidence': scores[index]};
      })
        ..sort((a, b) =>
            (b['confidence'] as double).compareTo(a['confidence'] as double));

      // We must show top 3 coconut varieties excluding "Not a Coconut".
      final coconutOnly = rankedPredictions.where((p) {
        final label = (p['label']?.toString() ?? '');
        return !_isNotCoconutLabel(label);
      }).toList();

      // If fewer than 3 coconut labels exist, pad with 0% for display.
      final top3 = <Map<String, dynamic>>[];
      for (final item in coconutOnly.take(3)) {
        top3.add(Map<String, dynamic>.from(item));
      }

      while (top3.length < 3) {
        // Find the first known coconut label and use 0%.
        final fallbackLabel = _labels.firstWhere(
          (l) => !_isNotCoconutLabel(l),
          orElse: () => 'Unknown Coconut',
        );
        top3.add({'label': fallbackLabel, 'confidence': 0.0});
      }

      // Main label selection stays with existing heuristic.
      final label = _resolvePredictionLabel(rankedPredictions.take(4).toList());

      return {
        'variety_name': label,
        'lifespan': _getLifespanFromLabel(label),
        'top_predictions': top3,
      };
    } catch (e) {
      debugPrint('Local TFLite inference failed: $e');
      rethrow;
    }
  }

  img.Image _resizeForFastDecode(img.Image image) {
    final longestSide = image.width > image.height ? image.width : image.height;
    if (longestSide <= _maxImageSide) return image;

    if (image.width >= image.height) {
      return img.copyResize(image, width: _maxImageSide);
    }
    return img.copyResize(image, height: _maxImageSide);
  }

  _ModelInputLayout _resolveInputLayout(List<int> inputShape) {
    if (inputShape[3] == 3) {
      return _ModelInputLayout(
          height: inputShape[1], width: inputShape[2], channelsFirst: false);
    }

    if (inputShape[1] == 3) {
      return _ModelInputLayout(
          height: inputShape[2], width: inputShape[3], channelsFirst: true);
    }

    throw Exception('Model input must have 3 color channels: $inputShape');
  }

  Object _buildModelInput({
    required img.Image image,
    required _ModelInputLayout layout,
    required String inputType,
  }) {
    final isFloat = inputType.contains('float');
    final isInt8 = inputType.contains('int8') && !inputType.contains('uint8');

    List<num> pixelValues(img.Pixel pixel) {
      if (isFloat) {
        return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
      }
      if (isInt8) {
        return [
          (pixel.r.toInt() - 128).clamp(-128, 127),
          (pixel.g.toInt() - 128).clamp(-128, 127),
          (pixel.b.toInt() - 128).clamp(-128, 127),
        ];
      }

      return [
        pixel.r.toInt().clamp(0, 255),
        pixel.g.toInt().clamp(0, 255),
        pixel.b.toInt().clamp(0, 255),
      ];
    }

    if (layout.channelsFirst) {
      final channels = List.generate(
        3,
        (channel) => List.generate(
          image.height,
          (y) => List.generate(image.width, (x) {
            return pixelValues(image.getPixel(x, y))[channel];
          }),
        ),
      );
      return [channels];
    }

    final imageMatrix = List.generate(
      image.height,
      (y) =>
          List.generate(image.width, (x) => pixelValues(image.getPixel(x, y))),
    );

    return [imageMatrix];
  }

  Object _buildModelOutput({
    required List<int> outputShape,
    required String outputType,
  }) {
    final isFloat = outputType.contains('float');

    Object buildDimension(int index) {
      final length = outputShape[index];
      if (index == outputShape.length - 1) {
        return isFloat
            ? List<double>.filled(length, 0)
            : List<int>.filled(length, 0);
      }
      return List.generate(length, (_) => buildDimension(index + 1));
    }

    return buildDimension(0);
  }

  List<double> _scoresFromOutput(
    Object output, {
    required String outputType,
    required double scale,
    required int zeroPoint,
  }) {
    final rawScores = <double>[];

    void collect(Object? value) {
      if (value is num) {
        final score = value.toDouble();
        rawScores.add(
          outputType.contains('float') || scale == 0
              ? score
              : scale * (score - zeroPoint),
        );
        return;
      }
      if (value is List) {
        for (final item in value) {
          collect(item);
        }
      }
    }

    collect(output);

    if (rawScores.isEmpty) return rawScores;

    final maxScore = rawScores.reduce((a, b) => a > b ? a : b);
    final minScore = rawScores.reduce((a, b) => a < b ? a : b);

    if (minScore >= 0 && maxScore <= 1.0) {
      return rawScores.map((score) => score * 100.0).toList();
    }

    final positiveTotal = rawScores.fold<double>(0, (sum, score) {
      return score > 0 ? sum + score : sum;
    });

    if (minScore >= 0 && positiveTotal > 0) {
      return rawScores.map((score) => (score / positiveTotal) * 100.0).toList();
    }

    final expScores = rawScores.map((score) => math.exp(score - maxScore));
    final expTotal = expScores.fold<double>(0, (sum, score) => sum + score);

    if (expTotal == 0) return rawScores;
    return expScores.map((score) => (score / expTotal) * 100.0).toList();
  }

  String _resolvePredictionLabel(List<dynamic> predictions) {
    if (predictions.isEmpty) return 'Invalid Image';

    final Map top = predictions[0];
    final Map? second = predictions.length > 1 ? predictions[1] : null;

    final topLabel = top['label']?.toString() ?? 'Unknown';
    final topConfidence =
        double.tryParse(top['confidence']?.toString() ?? '') ?? 0;

    final notCoconutConfidence = predictions.whereType<Map>().map((prediction) {
      final label = prediction['label']?.toString() ?? '';
      if (!_isNotCoconutLabel(label)) return 0.0;
      return double.tryParse(prediction['confidence']?.toString() ?? '') ?? 0.0;
    }).fold<double>(0, (best, score) => score > best ? score : best);

    final secondConfidence = second == null
        ? 0.0
        : double.tryParse(second['confidence']?.toString() ?? '') ?? 0;

    final margin = topConfidence - secondConfidence;

    if (_isNotCoconutLabel(topLabel)) return topLabel;
    // Loosen thresholds slightly for real-time camera frames.
    // (Live camera images are often blurrier/darker than saved/manual photos.)
    if (notCoconutConfidence >= 25 || topConfidence < 65 || margin < 10) {
      return 'Invalid Image';
    }

    return topLabel;
  }

  String _getLifespanFromLabel(String label) {
    final normalized = label.toLowerCase();
    if (normalized.contains('baybay')) return '60-80 years';
    if (normalized.contains('catigan')) return '50-70 years';
    if (normalized.contains('tacunan')) return '55-75 years';
    if (normalized.contains('not')) return 'N/A';
    return '60-80 years';
  }

  Future<void> _processResults(Map<String, dynamic> data) async {
    final String resLabel = data['variety_name'] ?? "Unknown";
    final bool isNotCoconut = _isNotCoconutLabel(resLabel);

    final resultLabel =
        isNotCoconut ? "Invalid Image" : _displayLabel(resLabel);
    final resultLifespan =
        isNotCoconut ? "N/A" : (data['lifespan']?.toString() ?? "60-80 years");

    // We already return top3 coconut-only predictions from inference.
    final List<dynamic> resultPredictions = data['top_predictions'] != null
        ? (data['top_predictions'] as List).take(3).toList()
        : <dynamic>[];

    if (!mounted) return;

    setState(() {
      _label = resultLabel;
      _lifespan = resultLifespan;
      _topPredictions = isNotCoconut ? <dynamic>[] : resultPredictions;

      // Ensure labels are mapped (consistency with display label)
      _topPredictions = _topPredictions.map((p) {
        if (p is Map) {
          final mapped = Map<String, dynamic>.from(p);

          mapped['label'] = _displayLabel(mapped['label']?.toString() ?? '');
          return mapped;
        }
        return p;
      }).toList();

      _hasResult = true;
      _isAnalyzing = false;
    });

    final imageFile = _capturedImage;
    if (imageFile != null && !isNotCoconut) {
      await DetectionHistoryStore.instance.saveDetection(
        imageFile: imageFile,
        label: resultLabel,
        lifespan: resultLifespan,
        topPredictions: resultPredictions,
      );
    }
  }

  void _showFullImageZoomable() {
    if (_capturedImage == null) return;

    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(12),
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0x99000000),
                borderRadius: BorderRadius.all(Radius.circular(16)),
              ),
              padding: const EdgeInsets.all(12),
              child: InteractiveViewer(
                panEnabled: true,
                minScale: 0.6,
                maxScale: 4.0,
                child: Image.file(_capturedImage!, fit: BoxFit.contain),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (_isCameraReady && _controller != null && !_hasResult)
            Positioned.fill(child: CameraPreview(_controller!)),
          if (!_hasResult)
            Positioned(
              top: MediaQuery.of(context).size.height * _topPercentUI,
              left: 0,
              right: 0,
              child: Center(
                child: ScaleTransition(
                  scale: _pulseAnimation,
                  child: CustomPaint(
                    size: Size(_scannerBoxSizeUI, _scannerBoxSizeUI),
                    painter: ScannerPainter(
                      color: _isAnalyzing ? Colors.green : Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _hasResult ? _buildResultCard() : _buildControlUI(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlUI() {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _statusLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_statusLabel.contains('FAILED') && _lastModelError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _shortError(_lastModelError!),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCircularIconButton(
                icon: Icons.photo_library,
                onTap: () async {
                  final XFile? imgFile = await _picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (imgFile != null) {
                    _handleScan(manualFile: File(imgFile.path));
                  }
                },
              ),
              GestureDetector(
                onTap: () => _handleScan(),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: CircleAvatar(
                    radius: 38,
                    backgroundColor: Colors.white,
                    child: _isAnalyzing
                        ? const CircularProgressIndicator(color: Colors.green)
                        : const Icon(
                            Icons.camera_alt,
                            size: 40,
                            color: Colors.black,
                          ),
                  ),
                ),
              ),
              _buildCircularIconButton(
                icon: _currentFlashMode == FlashMode.torch
                    ? Icons.flash_on
                    : Icons.flash_off,
                iconColor: !_isFlashSupported
                    ? Colors.grey
                    : _currentFlashMode == FlashMode.torch
                        ? Colors.yellow
                        : Colors.white,
                onTap: _isFlashSupported ? _toggleFlash : null,
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCircularIconButton({
    required IconData icon,
    VoidCallback? onTap,
    Color iconColor = Colors.white,
  }) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.black38,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor, size: 30),
        onPressed: onTap,
      ),
    );
  }

  Widget _buildResultCard() {
    final isInvalidResult = _isNotCoconutLabel(_label);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 10),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_capturedImage != null)
                  GestureDetector(
                    onTap: _showFullImageZoomable,
                    child: Container(
                      width: double.infinity,
                      height: 180,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        color: Colors.grey[50],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(15),
                        child: Image.file(_capturedImage!, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                const SizedBox(height: 15),
                Text(
                  _label.toUpperCase(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isInvalidResult
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF2E7D32),
                  ),
                ),
                if (isInvalidResult)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text(
                      'Please scan a clear coconut seedling image.',
                      style: TextStyle(
                        color: Color(0xFF991B1B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else ...[
                  Text(
                    "Lifespan: $_lifespan",
                    style: const TextStyle(
                      color: Colors.orange,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Divider(),
                  ..._topPredictions.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final p = entry.value;
                    final conf =
                        double.tryParse(p['confidence'].toString()) ?? 0.0;
                    final rankColor = _getRankColor(idx);

                    return Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              p['label'].toString(),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            Text(
                              "${conf.toStringAsFixed(1)}%",
                              style: TextStyle(
                                color: rankColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: conf / 100,
                          color: rankColor,
                          backgroundColor: Colors.grey[200],
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
                  }),
                ],
                const SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => setState(() => _hasResult = false),
                  child: const Text(
                    "SCAN AGAIN",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }
}

class ScannerPainter extends CustomPainter {
  final Color color;

  ScannerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;

    const double l = 40;

    canvas.drawLine(Offset.zero, const Offset(0, l), p);
    canvas.drawLine(Offset.zero, const Offset(l, 0), p);

    canvas.drawLine(Offset(size.width, 0), Offset(size.width - l, 0), p);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, l), p);

    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - l), p);
    canvas.drawLine(Offset(0, size.height), Offset(l, size.height), p);

    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width - l, size.height), p);
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width, size.height - l), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}

class _ModelInputLayout {
  const _ModelInputLayout({
    required this.height,
    required this.width,
    required this.channelsFirst,
  });

  final int height;
  final int width;
  final bool channelsFirst;
}
