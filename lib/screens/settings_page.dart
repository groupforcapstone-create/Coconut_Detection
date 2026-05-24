import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'coconut_about_page.dart';
import 'about_settings_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _isDarkMode = false;
  String _language = 'English';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('app_dark_mode') ?? false;
      _language = prefs.getString('app_language') ?? 'English';
    });
  }

  Future<void> _setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('app_dark_mode', value);

    setState(() => _isDarkMode = value);

    // Theme is applied by MyApp using persisted preference.
    // Note: if immediate update is needed, we can refactor to use a theme provider/state manager.
  }

  Future<void> _selectLanguage() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Language'),
        children: ['English', 'Tagalog']
            .map(
              (l) => SimpleDialogOption(
                onPressed: () => Navigator.pop(context, l),
                child: Text(l),
              ),
            )
            .toList(),
      ),
    );

    if (selected == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', selected);

    setState(() => _language = selected);
  }

  void _openAbout() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CoconutAboutPage()),
    );
  }

  void _openAboutSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AboutSettingsPage()),
    );
  }

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
              icon: Icons.dark_mode_rounded,
              title: 'Light / Dark Mode',
              subtitle: _isDarkMode ? 'Dark' : 'Light',
              trailing: Switch(
                value: _isDarkMode,
                activeTrackColor: const Color(0xFF1B5E20),
                activeThumbColor: Colors.white,
                onChanged: _setDarkMode,
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
              icon: Icons.settings_rounded,
              title: 'Settings Overview',
              subtitle: 'How to use the options',
              onTap: _openAboutSettings,
            ),
            _buildPreferenceTile(
              icon: Icons.info_outline_rounded,
              title: 'About Coconut Detection',
              subtitle: 'Version 1.0.0',
              onTap: _openAbout,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w900,
        color: Colors.grey[500],
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildPreferenceTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
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
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: trailing ??
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.grey,
              size: 20,
            ),
      ),
    );
  }
}
