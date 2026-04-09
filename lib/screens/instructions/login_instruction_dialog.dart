import 'package:flutter/material.dart';

Future<void> showLoginInstructionDialog(BuildContext context) {
  bool useEnglish = true;

  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black54,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (context, setLocalState) {
          final title = useEnglish ? 'Quick Guide' : 'Mabilis na Gabay';
          final message = useEnglish
              ? 'You can use Guest Mode for scanning. Log in to sell seedlings and manage your posts.'
              : 'Pwede kang mag-Guest Mode para mag-scan. Mag-login para makapagbenta at ma-manage ang posts.';

          return Dialog(
            backgroundColor: Colors.white.withValues(alpha: 0.92),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline,
                      size: 40, color: Color(0xFF2E7D32)),
                  const SizedBox(height: 10),
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 10),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13.5, height: 1.35),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _langButton('English', useEnglish, () {
                        setLocalState(() => useEnglish = true);
                      }),
                      const SizedBox(width: 8),
                      _langButton('Tagalog', !useEnglish, () {
                        setLocalState(() => useEnglish = false);
                      }),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(useEnglish ? 'Got it' : 'Okay'),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
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
