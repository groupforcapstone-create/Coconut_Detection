import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;

// Services
import '../services/app_endpoints.dart';
import '../services/seedling_post_service.dart';
import 'instructions/camerainstruction_page.dart';

class CameraPage extends StatefulWidget {
  final bool isGuest;
  const CameraPage({super.key, this.isGuest = false});

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

  bool _isCameraReady = false;
  bool _isAnalyzing = false;
  bool _hasResult = false;
  File? _capturedImage;

  String _label = "";
  List<dynamic> _topPredictions = [];
  String _lifespan = "";
  String _statusLabel = "READY TO SCAN";
  String _exactAddress = "Fetching location...";

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

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _showInstructionOnce());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _pulseController.dispose();
    super.dispose();
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
      await _controller!.setFlashMode(_currentFlashMode);

      if (mounted) {
        setState(() {
          _isCameraReady = true;
          _hasResult = false;
          _statusLabel = "READY TO SCAN";
        });
      }
    } catch (e) {
      debugPrint("Camera Error: $e");
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    FlashMode nextMode =
        (_currentFlashMode == FlashMode.off) ? FlashMode.torch : FlashMode.off;
    try {
      await _controller!.setFlashMode(nextMode);
      setState(() => _currentFlashMode = nextMode);
    } catch (e) {
      debugPrint("Flash Toggle Error: $e");
    }
  }

  Future<void> _showInstructionOnce() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('has_seen_quick_guide') ?? false;
    if (!mounted || hasSeen) return;

    await showDialog<void>(
      context: context,
      builder: (_) => const CameraInstructionPage(),
    );
    await prefs.setBool('has_seen_quick_guide', true);
  }

  Future<String> _getAddress() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      Position pos = await Geolocator.getCurrentPosition(
          locationSettings:
              const LocationSettings(accuracy: LocationAccuracy.high));

      List<Placemark> marks =
          await placemarkFromCoordinates(pos.latitude, pos.longitude);
      if (marks.isNotEmpty) {
        Placemark p = marks[0];
        return "${p.subLocality ?? ''}, ${p.locality}, ${p.administrativeArea}";
      }
      return "${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}";
    } catch (e) {
      return "Location Unavailable";
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
    final croppedFile =
        File('${directory.path}/cropped_${DateTime.now().millisecond}.jpg')
          ..writeAsBytesSync(img.encodeJpg(croppedImage, quality: 90));

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
      String fullAddress = await _getAddress();
      File fileToUpload;

      if (manualFile != null) {
        fileToUpload = manualFile;
      } else {
        if (_controller == null || !_controller!.value.isInitialized) {
          throw Exception("Camera not ready");
        }
        XFile rawPhoto = await _controller!.takePicture();
        fileToUpload =
            await _cropToScannerArea(File(rawPhoto.path), screenSize);
      }

      if (!mounted) return;

      final token = await AppEndpoints.getStoredToken();
      var request =
          http.MultipartRequest('POST', Uri.parse(AppEndpoints.predictUrl));
      request.headers.addAll(AppEndpoints.getMultipartHeaders(token: token));
      request.files
          .add(await http.MultipartFile.fromPath('file', fileToUpload.path));
      request.fields['address'] = fullAddress;

      final streamedRes =
          await request.send().timeout(const Duration(seconds: 45));
      final response = await http.Response.fromStream(streamedRes);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _exactAddress = fullAddress;
          _capturedImage = fileToUpload;
        });
        await _processResults(data, fileToUpload);
      } else {
        throw Exception("Server connection failed");
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

  Future<void> _processResults(Map<String, dynamic> data, File file) async {
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

    if (!isNotCoconut && !widget.isGuest) {
      await _saveLocal(file);
      await _uploadToServer(file);
    }
  }

  Future<void> _saveLocal(File file) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('scan_history') ?? [];
    list.add(json.encode({
      'timestamp': DateTime.now().toIso8601String(),
      'label': _label,
      'address': _exactAddress,
      'imagePath': file.path,
    }));
    await prefs.setStringList('scan_history', list);
  }

  Future<void> _uploadToServer(File file) async {
    try {
      await SeedlingPostService.instance.uploadScanHistory(
        imageFile: file,
        label: _label,
        topPrediction: _label,
        predictions: _topPredictions,
        address: _exactAddress,
      );
    } catch (e) {
      debugPrint("Upload failed: $e");
    }
  }

  void _showFullImage() {
    if (_capturedImage == null) return;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          // Replacement 1: withValues instead of withOpacity
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
            Positioned.fill(
              child: CameraPreview(_controller!),
            ),
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
                        color: _isAnalyzing ? Colors.green : Colors.white70),
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
                  top: MediaQuery.of(context).padding.top + 10, bottom: 15),
              // Replacement 2: withValues instead of withOpacity
              color: const Color(0xFF2E7D32).withValues(alpha: 0.9),
              child: const Center(
                  child: Icon(Icons.eco, color: Colors.white, size: 30)),
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
                color: Colors.black45, borderRadius: BorderRadius.circular(20)),
            child: Text(_statusLabel,
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildCircularIconButton(
                icon: Icons.photo_library,
                onTap: () async {
                  final XFile? imgFile =
                      await _picker.pickImage(source: ImageSource.gallery);
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
                      border: Border.all(color: Colors.white, width: 3)),
                  child: CircleAvatar(
                    radius: 38,
                    backgroundColor: Colors.white,
                    child: _isAnalyzing
                        ? const CircularProgressIndicator(color: Colors.green)
                        : const Icon(Icons.camera_alt,
                            size: 40, color: Colors.black),
                  ),
                ),
              ),
              _buildCircularIconButton(
                icon: _currentFlashMode == FlashMode.torch
                    ? Icons.flash_on
                    : Icons.flash_off,
                iconColor: _currentFlashMode == FlashMode.torch
                    ? Colors.yellow
                    : Colors.white,
                onTap: _toggleFlash,
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCircularIconButton(
      {required IconData icon,
      required VoidCallback onTap,
      Color iconColor = Colors.white}) {
    return Container(
      decoration:
          const BoxDecoration(color: Colors.black38, shape: BoxShape.circle),
      child: IconButton(
          icon: Icon(icon, color: iconColor, size: 30), onPressed: onTap),
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
                  BoxShadow(color: Colors.black26, blurRadius: 10)
                ]),
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
                          child: Image.file(
                            _capturedImage!,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 15),
                Text(_label.toUpperCase(),
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2E7D32))),
                Text("Lifespan: $_lifespan",
                    style: const TextStyle(
                        color: Colors.orange, fontWeight: FontWeight.bold)),
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
                          Text(p['label'],
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500)),
                          Text("${conf.toStringAsFixed(1)}%",
                              style: TextStyle(
                                  color: rankColor,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                          value: conf / 100,
                          color: rankColor,
                          backgroundColor: Colors.grey[200]),
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
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() => _hasResult = false),
                  child: const Text("SCAN AGAIN",
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold)),
                )
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
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width - l, size.height), p);
    canvas.drawLine(Offset(size.width, size.height),
        Offset(size.width, size.height - l), p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => true;
}
