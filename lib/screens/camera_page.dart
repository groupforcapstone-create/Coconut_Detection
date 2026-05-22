import 'dart:async';

import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

// Services

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

  bool _isNotCoconutLabel(String label) {
    final l = label.toLowerCase().trim();
    return l.contains('not a coconut') ||
        l.contains('not coconut') ||
        l.contains('not ') ||
        l == 'not';
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
    Tflite.close();

    super.dispose();
  }

  Future<void> _loadLocalModel() async {
    if (!_useLocalModel) return;

    try {
      final result = await Tflite.loadModel(
        model: 'assets/models/coconut_variety_model.tflite',
        labels: 'assets/models/coconut_labels.txt',
        numThreads: 2,
        isAsset: true,
      );

      debugPrint('TFLite model loaded: $result');

      if (mounted) {
        setState(() {
          _isLocalModelReady = true;
        });
      }
    } catch (e) {
      debugPrint('Local TFLite load failed: $e');
      if (mounted) {
        setState(() {
          _isLocalModelReady = false;
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
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();

      try {
        await _controller!.setFlashMode(_currentFlashMode);
        _isFlashSupported = true;
      } catch (e) {
        debugPrint("Flash mode unsupported: $e");
        _isFlashSupported = false;
      }

      if (mounted) {
        setState(() {
          _isCameraReady = true;
          _hasResult = false;
          _statusLabel = _isFlashSupported
              ? "READY TO SCAN"
              : "READY TO SCAN (NO FLASH)";
        });
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null ||
        !_controller!.value.isInitialized ||
        !_isFlashSupported) {
      return;
    }

    final FlashMode nextMode = (_currentFlashMode == FlashMode.off)
        ? FlashMode.torch
        : FlashMode.off;

    try {
      await _controller!.setFlashMode(nextMode);
      setState(() {
        _currentFlashMode = nextMode;
      });
    } catch (e) {
      debugPrint("Flash Toggle Error: $e");
      setState(() {
        _isFlashSupported = false;
        _currentFlashMode = FlashMode.off;
        _statusLabel = "FLASH NOT SUPPORTED";
      });
    }
  }

  Future<File> _cropToScannerArea(File imageFile, Size screenSize) async {
    final bytes = await imageFile.readAsBytes();

    img.Image? originalImage = img.decodeImage(bytes);

    if (originalImage == null) return imageFile;

    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;

    double topOffsetUI = screenHeight * _topPercentUI;

    double leftOffsetUI = (screenWidth - _scannerBoxSizeUI) / 2;

    double widthRatio = originalImage.width / screenWidth;

    double heightRatio = originalImage.height / screenHeight;

    int cropX = (leftOffsetUI * widthRatio).toInt();
    int cropY = (topOffsetUI * heightRatio).toInt();

    int cropW = (_scannerBoxSizeUI * widthRatio).toInt();

    int cropH = (_scannerBoxSizeUI * heightRatio).toInt();

    img.Image croppedImage = img.copyCrop(
      originalImage,
      x: cropX,
      y: cropY,
      width: cropW,
      height: cropH,
    );

    final directory = await Directory.systemTemp.createTemp();

    final croppedFile = File(
      '${directory.path}/cropped_${DateTime.now().millisecond}.jpg',
    )..writeAsBytesSync(img.encodeJpg(croppedImage, quality: 90));

    return croppedFile;
  }

  Future<void> _handleScan({File? manualFile}) async {
    if (_isAnalyzing) return;

    final Size screenSize = MediaQuery.of(context).size;

    setState(() {
      _isAnalyzing = true;
      _statusLabel = "ANALYZING...";
    });

    try {
      File fileToUpload;

      if (manualFile != null) {
        fileToUpload = manualFile;
      } else {
        if (_controller == null || !_controller!.value.isInitialized) {
          throw Exception("Camera not ready");
        }

        XFile rawPhoto = await _controller!.takePicture();

        fileToUpload = await _cropToScannerArea(
          File(rawPhoto.path),
          screenSize,
        );
      }

      if (!mounted) return;

      if (_useLocalModel && _isLocalModelReady) {
        final localResult = await _predictWithLocalModel(fileToUpload.path);
        if (localResult != null) {
          if (!mounted) return;
          setState(() {
            _capturedImage = fileToUpload;
          });
          await _processResults(localResult);
          return;
        }
      }

      // Camera-only mode: use local TFLite results.
      // If local model isn't ready yet, treat scan as failed.
      if (!_useLocalModel || !_isLocalModelReady) {
        throw Exception('Local model not ready');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _statusLabel = "SCAN FAILED";
        });
      }
    }
  }

  Future<Map<String, dynamic>?> _predictWithLocalModel(String imagePath) async {
    try {
      final results = await Tflite.runModelOnImage(
        path: imagePath,
        numResults: 4,
        threshold: 0.05,
        imageMean: 0.0,
        imageStd: 255.0,
      );

      if (results == null || results.isEmpty) return null;

      final topPredictions = results.map((result) {
        final label = result['label']?.toString() ?? 'Unknown';
        final confidenceValue =
            (result['confidence'] as num?)?.toDouble() ?? 0.0;
        return {'label': label, 'confidence': confidenceValue * 100.0};
      }).toList();

      final primary = topPredictions.first;
      final String label = primary['label']?.toString() ?? 'Unknown';

      return {
        'variety_name': label,
        'lifespan': _getLifespanFromLabel(label),
        'top_predictions': topPredictions,
      };
    } catch (e) {
      debugPrint('Local TFLite inference failed: $e');
      return null;
    }
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

    if (!mounted) return;

    setState(() {
      _label = isNotCoconut ? "Invalid Image" : resLabel;

      _lifespan = isNotCoconut
          ? "N/A"
          : (data['lifespan']?.toString() ?? "60-80 years");

      if (data['top_predictions'] != null) {
        _topPredictions = (data['top_predictions'] as List).take(3).toList();
      }

      _hasResult = true;
      _isAnalyzing = false;
    });
  }

  void _showFullImage() {
    if (_capturedImage == null) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          color: Colors.black.withValues(alpha: 0.9),
          child: Center(
            child: Hero(
              tag: 'scanned_image',
              child: Image.file(_capturedImage!, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
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
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10,
                bottom: 15,
              ),
              color: const Color(0xFF2E7D32).withValues(alpha: 0.9),
              child: const Center(
                child: Icon(Icons.eco, color: Colors.white, size: 30),
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
            child: Text(
              _statusLabel,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
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
                    onTap: _showFullImage,
                    child: Hero(
                      tag: 'scanned_image',
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
                  ),
                const SizedBox(height: 15),
                Text(
                  _label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                Text(
                  "Lifespan: $_lifespan",
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(),
                ..._topPredictions.asMap().entries.map((entry) {
                  int idx = entry.key;

                  var p = entry.value;

                  double conf =
                      double.tryParse(p['confidence'].toString()) ?? 0.0;

                  Color rankColor = _getRankColor(idx);

                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            p['label'],
                            style: const TextStyle(fontWeight: FontWeight.w500),
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
                const SizedBox(height: 10),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => setState(() {
                    _hasResult = false;
                  }),
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

    double l = 40;

    canvas.drawLine(Offset.zero, Offset(0, l), p);

    canvas.drawLine(Offset.zero, Offset(l, 0), p);

    canvas.drawLine(Offset(size.width, 0), Offset(size.width - l, 0), p);

    canvas.drawLine(Offset(size.width, 0), Offset(size.width, l), p);

    canvas.drawLine(Offset(0, size.height), Offset(0, size.height - l), p);

    canvas.drawLine(Offset(0, size.height), Offset(l, size.height), p);

    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width - l, size.height),
      p,
    );

    canvas.drawLine(
      Offset(size.width, size.height),
      Offset(size.width, size.height - l),
      p,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
