import 'package:flutter/material.dart';

class CameraInstructionPage extends StatefulWidget {
  const CameraInstructionPage({super.key});

  @override
  State<CameraInstructionPage> createState() => _CameraInstructionPageState();
}

class _CameraInstructionPageState extends State<CameraInstructionPage> {
  bool _useEnglish = true;

  @override
  Widget build(BuildContext context) {
    final title = _useEnglish ? 'Scan Guide' : 'Gabay sa Pag-scan';
    final message = _useEnglish
        ? 'Point the camera at the seedling, keep it inside the frame, and tap the scan button.'
        : 'Itutok ang camera sa punla, siguraduhing nasa loob ng frame, at pindutin ang scan button.';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              size: 42,
              color: Color(0xFF2E7D32),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2E2E2E),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _langButton('English', _useEnglish, () {
                  setState(() => _useEnglish = true);
                }),
                const SizedBox(width: 10),
                _langButton('Tagalog', !_useEnglish, () {
                  setState(() => _useEnglish = false);
                }),
              ],
            ),
            const SizedBox(height: 14),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 26,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(_useEnglish ? 'Got it' : 'Okay'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _langButton(String label, bool active, VoidCallback onTap) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        backgroundColor: active ? const Color(0xFF2E7D32) : Colors.white,
        foregroundColor: active ? Colors.white : const Color(0xFF2E7D32),
        side: const BorderSide(color: Color(0xFF2E7D32)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}
