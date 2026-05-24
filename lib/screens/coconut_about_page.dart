import 'package:flutter/material.dart';

class CoconutAboutPage extends StatelessWidget {
  const CoconutAboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About Coconut Detection'),
        backgroundColor: const Color(0xFF2E7D32),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          children: [
            const Text(
              'How to use the app',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(height: 12),
            const _AboutSection(
              icon: Icons.camera_alt_outlined,
              title: '1) Scan the seedling',
              text:
                  'Point the camera at the seedling. Place it inside the frame and make sure the image is bright and clear before pressing the scan button.',
            ),
            const _AboutSection(
              icon: Icons.photo_library_outlined,
              title: '2) Or upload from the gallery',
              text:
                  'If you already have a clear photo, you can select it from the gallery and scan it using the same process.',
            ),
            const _AboutSection(
              icon: Icons.filter_alt_outlined,
              title: '3) Result (Top 3 varieties)',
              text:
                  'The app will show the top 3 possible coconut varieties based on your photo. If the image is unclear or not a coconut seedling, it may display “Invalid Image”.',
            ),
            const _AboutSection(
              icon: Icons.history_rounded,
              title: '4) Scan history',
              text:
                  'When the result is valid, the app saves the image and information to History so you can easily review it later.',
            ),
            const SizedBox(height: 18),
            const Text(
              'Tip',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'For better accuracy: use bright lighting, keep the camera steady, and make sure the seedling is inside the frame.',
              style:
                  TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Back'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _AboutSection({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32).withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF2E7D32)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
