import 'dart:io';
import 'package:flutter/material.dart';

// Import screens
import 'screens/camera_page.dart';
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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = MyHttpOverrides();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Coconut Detection',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F7F6),
      ),
      home: const HomeTabs(),
    );
  }
}

// --- 2. MAIN NAVIGATION & SERVER WAKE-UP ---
class HomeTabs extends StatefulWidget {
  final int initialIndex;
  const HomeTabs({super.key, this.initialIndex = 0});

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
        title: Text(
          'Coconut Detection',
          style: const TextStyle(
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
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Container(
          height: 72,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2E7D32), Color(0xFF43A047)],
            ),
            borderRadius: BorderRadius.circular(35),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(35),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: _onItemTapped,
              backgroundColor: Colors.transparent,
              elevation: 0,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Colors.white,
              unselectedItemColor: Colors.white.withValues(alpha: 0.5),
              showSelectedLabels: false,
              showUnselectedLabels: false,
              iconSize: 22,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.camera_alt_outlined),
                  activeIcon: Icon(Icons.camera_alt),
                  label: 'Scanner',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.settings_outlined),
                  activeIcon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
