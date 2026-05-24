import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme/app_theme.dart';

// Import screens
import 'screens/camera_page.dart';
import 'screens/history_page.dart';
import 'screens/settings_page.dart' as settings;

// --- 1. SSL HANDSHAKE FIX (Essential for local/private servers) ---
class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isDarkMode = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDarkMode = prefs.getBool('app_dark_mode') ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coconut Detection',
      debugShowCheckedModeBanner: false,
      theme: _isDarkMode ? AppTheme.dark() : AppTheme.light(),
      home: const HomeTabs(),
    );
  }
}

class HomeTabs extends StatefulWidget {
  final int initialIndex;
  const HomeTabs({super.key, this.initialIndex = 1});

  @override
  State<HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends State<HomeTabs> {
  late int _selectedIndex;
  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
  }

  void _onItemTapped(int index) {
    // If user taps the camera tab while it's already selected,
    // force a refresh of that tab by rebuilding it.
    if (_selectedIndex == index) {
      setState(() {
        // A different key causes IndexedStack child to rebuild.
        _selectedIndex = index;
      });
      return;
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text(
          'Coconut Detection',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 2,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: const [
          HistoryPage(),
          CameraPage(),
          settings.SettingsPage(),
        ],
      ),
      bottomNavigationBar: _buildFloatingNavbar(),
    );
  }

  Widget _buildFloatingNavbar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: SizedBox(
          height: 86,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.bottomCenter,
            children: [
              Container(
                height: 68,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
                  ),
                  borderRadius: BorderRadius.circular(34),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.22),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _navItem(
                        index: 0,
                        icon: Icons.history_rounded,
                        label: 'History',
                      ),
                    ),
                    const SizedBox(width: 82),
                    Expanded(
                      child: _navItem(
                        index: 2,
                        icon: Icons.settings_rounded,
                        label: 'Settings',
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 0,
                child: _cameraNavIcon(_selectedIndex == 1),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final selected = _selectedIndex == index;

    return InkWell(
      borderRadius: BorderRadius.circular(34),
      onTap: () => _onItemTapped(index),
      child: SizedBox(
        height: 68,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color:
                  selected ? Colors.white : Colors.white.withValues(alpha: 0.6),
              size: 25,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.6),
                fontSize: 11,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cameraNavIcon(bool selected) {
    return InkWell(
      borderRadius: BorderRadius.circular(38),
      onTap: () => _onItemTapped(1),
      child: SizedBox(
        width: 78,
        height: 78,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: selected ? Colors.white : const Color(0xFFE8F5E9),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF2E7D32),
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 14,
                    offset: const Offset(0, 7),
                  ),
                ],
              ),
              child: Icon(
                selected ? Icons.camera_alt : Icons.camera_alt_outlined,
                color: const Color(0xFF2E7D32),
                size: 32,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              'Camera',
              maxLines: 1,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
