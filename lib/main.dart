import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

// Import services & config
import 'services/app_endpoints.dart';

// Import screens
import 'screens/home_page.dart';
import 'screens/login_page.dart';
import 'screens/register_page.dart';
import 'screens/forgot_password_page.dart';
import 'screens/camera_page.dart';
import 'screens/sell_seedling_page.dart';
import 'screens/settings_page.dart' as settings;
import 'screens/market_page.dart';
import 'screens/history_page.dart';
import 'screens/profile_page.dart';
import 'screens/splash_screen.dart';

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
      initialRoute: '/splash',
      routes: {
        '/splash': (context) => const SplashScreen(),
        '/': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/forgot-password': (context) => const ForgotPasswordPage(),
        '/home': (context) =>
            const HomeTabs(initialIndex: 2), // Default to Scanner
        '/sell_seedling': (context) => const SellSeedlingPage(),
      },
    );
  }
}

// --- 2. MAIN NAVIGATION & SERVER WAKE-UP ---
class HomeTabs extends StatefulWidget {
  final int initialIndex;
  const HomeTabs({super.key, this.initialIndex = 2});

  @override
  State<HomeTabs> createState() => _HomeTabsState();
}

class _HomeTabsState extends State<HomeTabs> {
  late int _selectedIndex;
  bool _isGuest = false;
  String _displayName = "";
  String? _profilePhotoUrl;
  int _cameraResetToken = 0;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;
    _checkUserStatus();

    // START SERVER WAKE-UP PROCESS
    _wakeUpBackend();
  }

  /// Pings the Render backend to start the 50s wake-up process
  /// so it's ready by the time the user tries to scan.
  Future<void> _wakeUpBackend() async {
    try {
      // We use a short timeout because we only want to trigger the server,
      // not wait for the whole model to load right now.
      await http
          .get(Uri.parse(AppEndpoints.healthCheckUrl))
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint("Backend Wake-up Triggered (Ignoring timeout)");
    }
  }

  Future<void> _checkUserStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _isGuest = prefs.getBool('is_guest') ?? false;
      if (_isGuest) {
        _displayName = "Guest User";
        _profilePhotoUrl = null;
      } else {
        _displayName =
            prefs.getString('seller_full_name') ?? "Coconut Detection";
        _profilePhotoUrl = prefs.getString('profile_photo_path');
      }
    });
  }

  void _onItemTapped(int index) {
    // Restricted tabs for guests
    if (_isGuest && (index == 1 || index == 3 || index == 4)) {
      _showLoginRequiredDialog();
    } else {
      setState(() {
        if (index == 2) {
          _cameraResetToken++; // Force refresh camera state
        }
        _selectedIndex = index;
      });
    }
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.lock_person, color: Color(0xFF2E7D32)),
            SizedBox(width: 10),
            Text("Login Required"),
          ],
        ),
        content: const Text("Please log in first to access more features."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                const Text("Maybe Later", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushReplacementNamed(context, '/');
            },
            child: const Text("Login Now"),
          ),
        ],
      ),
    );
  }

  Future<void> _openProfilePage() async {
    final prefs = await SharedPreferences.getInstance();
    final fullName = (prefs.getString('seller_full_name') ?? '').trim();
    final email = (prefs.getString('seller_email') ?? '').trim();
    final phone = (prefs.getString('seller_phone') ?? '').trim();
    final location = (prefs.getString('seller_location') ?? '').trim();

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProfilePage(
          fullName: fullName.isEmpty ? "Unknown Seller" : fullName,
          email: email.isEmpty ? "No email found" : email,
          phone: phone.isEmpty ? "No phone number found" : phone,
          location: location.isEmpty ? "No location found" : location,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(
          _displayName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF2E7D32),
        elevation: 2,
        automaticallyImplyLeading: false,
        leading: Padding(
          padding: const EdgeInsets.only(left: 6.0),
          child: IconButton(
            onPressed: _isGuest ? null : _openProfilePage,
            icon: (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty)
                ? CircleAvatar(
                    radius: 16,
                    backgroundImage: NetworkImage(_profilePhotoUrl!),
                    backgroundColor: Colors.white24,
                  )
                : Icon(
                    _isGuest ? Icons.account_circle_outlined : Icons.person,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          const HomePage(),
          const MarketPage(),
          KeyedSubtree(
            key: ValueKey('cam_$_cameraResetToken'),
            child: const CameraPage(),
          ),
          const HistoryPage(),
          const settings.SettingsPage(),
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
              items: [
                const BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home),
                    label: 'Home'),
                const BottomNavigationBarItem(
                    icon: Icon(Icons.storefront_outlined),
                    activeIcon: Icon(Icons.storefront),
                    label: 'Market'),
                const BottomNavigationBarItem(
                  icon: CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.white24,
                    child:
                        Icon(Icons.camera_alt, color: Colors.white, size: 20),
                  ),
                  label: 'Scanner',
                ),
                const BottomNavigationBarItem(
                    icon: Icon(Icons.history_outlined),
                    activeIcon: Icon(Icons.history),
                    label: 'History'),
                BottomNavigationBarItem(
                  icon: Icon(
                      _isGuest ? Icons.lock_outline : Icons.settings_outlined),
                  activeIcon: Icon(_isGuest ? Icons.lock : Icons.settings),
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
