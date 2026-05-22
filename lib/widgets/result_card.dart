import 'dart:io';

import 'package:flutter/material.dart';

class ResultCard extends StatelessWidget {
  final File? capturedImage;
  final String label;
  final String lifespan;
  final List<dynamic> topPredictions;
  final void Function()? onScanAgain;
  final VoidCallback onShowFullImage;

  const ResultCard({
    super.key,
    required this.capturedImage,
    required this.label,
    required this.lifespan,
    required this.topPredictions,
    required this.onShowFullImage,
    this.onScanAgain,
  });

  Color _getRankColor(int index) {
    if (index == 0) return const Color(0xFF16A34A);
    if (index == 1) return const Color(0xFFF59E0B);
    return const Color(0xFFDC2626);
  }

  @override
  Widget build(BuildContext context) {
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
                if (capturedImage != null)
                  GestureDetector(
                    onTap: onShowFullImage,
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
                          child: Image.file(capturedImage!, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 15),
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2E7D32),
                  ),
                ),
                Text(
                  'Lifespan: $lifespan',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(),
                ...topPredictions.asMap().entries.map((entry) {
                  int idx = entry.key;
                  final p = entry.value;

                  final double conf =
                      double.tryParse(p['confidence'].toString()) ?? 0.0;
                  final Color rankColor = _getRankColor(idx);

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
                            '${conf.toStringAsFixed(1)}%',
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
                  onPressed: onScanAgain,
                  child: const Text(
                    'SCAN AGAIN',
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
