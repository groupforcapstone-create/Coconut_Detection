import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'register_page.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _loginController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _showLoginForm = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _loginController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // --- LOGIC: LOGIN ---
  Future<void> _handleLogin() async {
    final loginInput = _loginController.text.trim();
    final password = _passwordController.text.trim();

    if (loginInput.isEmpty || password.isEmpty) {
      _showStatusModal(
          title: 'Missing Fields',
          message: 'Please enter your email/phone and password.',
          success: false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Call API - Inayos ang response assignment para mawala ang VS Code warning
      final response = await ApiService.login(
        loginInput: loginInput,
        password: password,
      );

      if (!mounted) return;

      // 2. Gamitin ang response para mawala ang 'unused_local_variable' error
      debugPrint(
          "✅ LOGIN SUCCESSFUL: ${response['message'] ?? 'User Authenticated'}");

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_guest', false);
      _storeSellerProfile(prefs, response);

      if (!mounted) return;
      FocusScope.of(context).unfocus();

      _showSuccessModal();

      await Future.delayed(const Duration(milliseconds: 1500));

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } catch (e) {
      if (!mounted) return;

      debugPrint("❌ LOGIN FAILED: $e");

      String errorMessage = e.toString().replaceAll("Exception: ", "").trim();

      // Handle Firewall/Security blocks
      if (errorMessage.contains("403") || errorMessage.contains("HTML")) {
        errorMessage =
            "Server Security blocked the request. Try using Mobile Data.";
      } else if (errorMessage.toLowerCase().contains("invalid credentials") ||
          errorMessage.toLowerCase().contains("incorrect user")) {
        errorMessage = "Incorrect user or password.";
      }

      _showStatusModal(
          title: 'Access Denied', message: errorMessage, success: false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LOGIC: GUEST ---
  Future<void> _handleGuestLogin() async {
    setState(() => _isLoading = true);
    try {
      await ApiService.clearSession();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('is_guest', true);

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
    } catch (e) {
      if (!mounted) return;
      _showStatusModal(
          title: 'Error', message: 'Could not enter as guest.', success: false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFF2E7D32);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [themeColor, Colors.white],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(230),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 20,
                        offset: Offset(0, 10))
                  ],
                ),
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeader(themeColor),
                      const SizedBox(height: 30),
                      _buildMainButton(
                          text: "CONTINUE AS GUEST",
                          onPressed: _isLoading ? null : _handleGuestLogin,
                          color: themeColor,
                          isSolid: true),
                      const SizedBox(height: 12),
                      if (!_showLoginForm)
                        _buildMainButton(
                            text: "LOGIN",
                            onPressed: () =>
                                setState(() => _showLoginForm = true),
                            color: themeColor,
                            isSolid: false)
                      else ...[
                        const Divider(height: 40, thickness: 1),
                        _buildLoginField(themeColor),
                        const SizedBox(height: 16),
                        _buildPasswordField(themeColor),
                        const SizedBox(height: 24),
                        _buildMainButton(
                            text: "LOG IN",
                            onPressed: _isLoading ? null : _handleLogin,
                            color: themeColor,
                            isSolid: true,
                            loading: _isLoading),
                        const SizedBox(height: 16),
                        _buildRegisterLink(themeColor),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ForgotPasswordPage())),
                          child: const Text("Forgot password?"),
                        ),
                        TextButton(
                          onPressed: () =>
                              setState(() => _showLoginForm = false),
                          child: const Text("Go Back",
                              style: TextStyle(color: Colors.grey)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // --- UI COMPONENTS ---
  Widget _buildHeader(Color color) => Column(children: [
        Icon(Icons.eco_rounded, size: 70, color: color),
        const SizedBox(height: 16),
        const Text('Coconut Detection',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
        const Text('Seller Portal',
            style: TextStyle(color: Colors.grey, fontSize: 16)),
      ]);

  Widget _buildLoginField(Color color) => TextField(
        controller: _loginController,
        keyboardType: TextInputType.emailAddress,
        decoration: InputDecoration(
          labelText: 'Email or Phone',
          prefixIcon: Icon(Icons.person_outline, color: color),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
      );

  Widget _buildPasswordField(Color color) => TextField(
        controller: _passwordController,
        obscureText: _obscurePassword,
        decoration: InputDecoration(
          labelText: 'Password',
          prefixIcon: Icon(Icons.lock_outline, color: color),
          suffixIcon: IconButton(
              icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility),
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword)),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
      );

  Widget _buildMainButton({
    required String text,
    required VoidCallback? onPressed,
    required Color color,
    required bool isSolid,
    bool loading = false,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: isSolid
          ? ElevatedButton(
              onPressed: onPressed,
              style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15))),
              child: loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(text,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.white)),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                  side: BorderSide(color: color, width: 2),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15))),
              child: Text(text,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            ),
    );
  }

  Widget _buildRegisterLink(Color color) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("Don't have an account? "),
          GestureDetector(
            onTap: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const RegisterPage())),
            child: Text("Register",
                style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          )
        ],
      );

  void _showStatusModal(
      {required String title, required String message, required bool success}) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text(title,
                  style: TextStyle(color: success ? Colors.green : Colors.red)),
              content: Text(message),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('OK'))
              ],
            ));
  }

  void _showSuccessModal() {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
            child: Card(
                child: Padding(
                    padding: EdgeInsets.all(30),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 60),
                        SizedBox(height: 10),
                        Text('Login Successful!',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 18)),
                      ],
                    )))));
  }

  void _storeSellerProfile(
      SharedPreferences prefs, Map<String, dynamic> response) {
    Map<String, dynamic>? seller;
    final directSeller = response['seller'];
    if (directSeller is Map<String, dynamic>) {
      seller = Map<String, dynamic>.from(directSeller);
    } else if (response['data'] is Map) {
      final data = Map<String, dynamic>.from(response['data']);
      if (data['seller'] is Map) {
        seller = Map<String, dynamic>.from(data['seller']);
      } else if (data['user'] is Map) {
        seller = Map<String, dynamic>.from(data['user']);
      }
    } else if (response['user'] is Map) {
      seller = Map<String, dynamic>.from(response['user']);
    }

    if (seller == null) return;

    final fullName = (seller['full_name'] ?? seller['name'] ?? '').toString();
    final email = (seller['email'] ?? '').toString();
    final phone = (seller['phone_number'] ?? seller['phone'] ?? '').toString();
    final location = (seller['location'] ?? '').toString();

    if (fullName.isNotEmpty) prefs.setString('seller_full_name', fullName);
    if (email.isNotEmpty) prefs.setString('seller_email', email);
    if (phone.isNotEmpty) prefs.setString('seller_phone', phone);
    if (location.isNotEmpty) prefs.setString('seller_location', location);
  }
}
