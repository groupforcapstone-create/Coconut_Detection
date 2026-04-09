import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/seedling_post_service.dart';
import 'profile_page.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _notificationsEnabled = true;
  String _language = 'English';

  String _fullName = 'Loading...';
  String _email = 'Loading...';
  String _phone = 'No number found';
  String _location = 'No location found';
  String? _profilePhotoUrl; // Dagdag para sa photo
  bool _loadingProfile = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();

    // Kunin ang lahat ng data pati ang photo path
    final fullName = (prefs.getString('seller_full_name') ?? '').trim();
    final email = (prefs.getString('seller_email') ?? '').trim();
    final phone = (prefs.getString('seller_phone') ?? '').trim();
    final location = (prefs.getString('seller_location') ?? '').trim();
    String? photoUrl = prefs.getString('profile_photo_path');
    try {
      final serverUrl =
          await SeedlingPostService.instance.fetchProfilePhotoUrl();
      if (serverUrl != null && serverUrl.isNotEmpty) {
        final sanitizedUrl =
            serverUrl.replaceAll('/storage/storage/', '/storage/');
        await prefs.setString('profile_photo_path', sanitizedUrl);
        photoUrl = sanitizedUrl;
      }
    } catch (_) {
      // ignore errors; we keep cached photo (if any)
    }

    if (!mounted) return;
    setState(() {
      _fullName = fullName.isEmpty ? "Unknown Seller" : fullName;
      _email = email.isEmpty ? "No email found" : email;
      _phone = phone.isEmpty ? "No phone number found" : phone;
      _location = location.isEmpty ? "No location found" : location;

      // Cache buster: Nagdadagdag ng timestamp para laging fresh ang load ng image
      _profilePhotoUrl = photoUrl != null && photoUrl.isNotEmpty
          ? "$photoUrl?t=${DateTime.now().millisecondsSinceEpoch}"
          : null;

      _loadingProfile = false;
    });
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
            const SizedBox(height: 20),
            _buildAccountCard(),
            const SizedBox(height: 32),
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

  Widget _buildAccountCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E20).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: _loadingProfile
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // --- PROFILE PHOTO LOGIC ---
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 2),
                      ),
                      child: CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white24,
                        backgroundImage: _profilePhotoUrl != null
                            ? NetworkImage(_profilePhotoUrl!)
                            : null,
                        child: _profilePhotoUrl == null
                            ? const Icon(Icons.person_rounded,
                                color: Colors.white, size: 35)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_fullName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis),
                          const Text('Verified Merchant',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.arrow_forward_ios_rounded,
                          color: Colors.white, size: 18),
                      onPressed: _openProfilePage,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(color: Colors.white10, thickness: 1),
                const SizedBox(height: 16),
                _detailRow(Icons.alternate_email_rounded, _email),
                const SizedBox(height: 12),
                _detailRow(Icons.phone_android_rounded, _phone),
                const SizedBox(height: 12),
                _detailRow(Icons.location_on_outlined, _location),
              ],
            ),
    );
  }

  void _openProfilePage() async {
    // Mahalaga ito: Hinihintay natin bumalik ang user galing ProfilePage
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfilePage(
          fullName: _fullName,
          email: _email,
          phone: _phone,
          location: _location,
        ),
      ),
    );
    // Kapag bumalik ang user, ire-load natin ang profile para update pati ang photo
    _loadProfile();
  }

  Widget _sectionHeader(String title) {
    return Text(title,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w900,
            color: Colors.grey[500],
            letterSpacing: 1.2));
  }

  Widget _detailRow(IconData icon, String text) {
    return Row(children: [
      Icon(icon, color: Colors.white60, size: 18),
      const SizedBox(width: 12),
      Expanded(
          child: Text(text,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              overflow: TextOverflow.ellipsis))
    ]);
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
