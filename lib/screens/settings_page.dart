import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  String _language = 'English';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            const Text(
              'Settings',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1B5E20),
              ),
            ),
            const SizedBox(height: 40),
            _sectionHeader('PREFERENCES'),
            const SizedBox(height: 12),
            _buildPreferenceTile(
              icon: Icons.notifications_none_rounded,
              title: 'Push Notifications',
              trailing: Switch(
                value: _notificationsEnabled,
                activeTrackColor: const Color(0xFF1B5E20),
                activeThumbColor: Colors.white,
                onChanged: (val) => setState(() => _notificationsEnabled = val),
              ),
            ),
            _buildPreferenceTile(
              icon: Icons.translate_rounded,
              title: 'Language',
              subtitle: _language,
              onTap: _selectLanguage,
            ),
            const SizedBox(height: 24),
            _sectionHeader('SYSTEM'),
            const SizedBox(height: 12),
            _buildPreferenceTile(
              icon: Icons.info_outline_rounded,
              title: 'About Coconut Detection',
              subtitle: 'Version 1.0.0',
              onTap: _showAbout,
            ),
            const SizedBox(height: 40),
            _buildLogoutButton(),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(title,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: Colors.grey[500],
            letterSpacing: 1.2));
  }

  Widget _buildPreferenceTile(
      {required IconData icon,
      required String title,
      String? subtitle,
      Widget? trailing,
      VoidCallback? onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: const Color(0xFF1B5E20)),
        title: Text(title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: trailing ??
            const Icon(Icons.chevron_right_rounded,
                color: Colors.grey, size: 20),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton(
        onPressed: _logout,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.red.withValues(alpha: 0.05),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: const Text('Logout',
            style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _selectLanguage() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Language'),
        children: ['English', 'Tagalog']
            .map((l) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, l), child: Text(l)))
            .toList(),
      ),
    );
    if (selected != null) setState(() => _language = selected);
  }

  void _showAbout() => showAboutDialog(
      context: context,
      applicationName: 'Coconut Detection',
      applicationVersion: '1.0.0');

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }
}
