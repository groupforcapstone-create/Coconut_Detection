import 'package:flutter/material.dart';

class LoginInstructionPage extends StatefulWidget {
  const LoginInstructionPage({super.key});

  @override
  State<LoginInstructionPage> createState() => _LoginInstructionPageState();
}

class _LoginInstructionPageState extends State<LoginInstructionPage> {
  bool _useEnglish = true;

  @override
  Widget build(BuildContext context) {
    final title = _useEnglish ? 'Quick Guide' : 'Mabilis na Gabay';
    final message = _useEnglish
        ? 'You can use Guest Mode for scanning. Log in to sell seedlings and manage your posts.'
        : 'Pwede kang mag-Guest Mode para mag-scan. Mag-login para makapagbenta at ma-manage ang posts.';

    return Scaffold(
      backgroundColor: const Color(0xFFF7FAF7),
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline,
                  size: 40, color: Color(0xFF2E7D32)),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2E2E2E),
                ),
              ),
              const SizedBox(height: 20),
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
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(_useEnglish ? 'Got it' : 'Okay'),
              ),
            ],
          ),
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
