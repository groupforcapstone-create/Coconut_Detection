import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import '../services/api_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _otpController = TextEditingController();

  // State Variables
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _isSearchingLocation = false;
  bool _otpSending = false;
  bool _otpSent = false;
  int _resendCountdown = 0;
  Timer? _debounce;
  Timer? _countdownTimer;

  // Constants
  static const themeColor = Color(0xFF2E7D32);

  @override
  void dispose() {
    _debounce?.cancel();
    _countdownTimer?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _locationController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  // --- Logic Methods ---

  bool _isValidGmail(String email) =>
      RegExp(r'^[A-Za-z0-9._%+-]+@gmail\.com$').hasMatch(email);
  bool _isValidPhone(String phone) => RegExp(r'^09[0-9]{9}$').hasMatch(phone);
  bool _isValidFullName(String value) {
    final parts =
        value.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    return parts.length >= 2;
  }

  void _startOtpCountdown() {
    setState(() => _resendCountdown = 60);
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCountdown == 0) {
        timer.cancel();
      } else {
        setState(() => _resendCountdown--);
      }
    });
  }

  Future<void> _handleSendOtp() async {
    final phone = _phoneController.text.trim();

    if (!_isValidPhone(phone)) {
      _showStatusModal(
          title: 'Invalid Number',
          message: 'Please enter a valid 11-digit phone number (09XXXXXXXXX).',
          success: false);
      return;
    }

    setState(() => _otpSending = true);

    try {
      final response =
          await ApiService.requestOtp(phoneNumber: phone, purpose: 'register');

      if (!mounted) return;

      final debugOtp = response['debug_otp']?.toString();
      final message = (debugOtp != null && debugOtp.isNotEmpty)
          ? 'OTP sent. For testing use: $debugOtp'
          : 'OTP sent successfully. Please check your messages.';

      setState(() => _otpSent = true);
      _startOtpCountdown();
      _showStatusModal(title: 'Success', message: message, success: true);
    } catch (e) {
      if (!mounted) return;
      _showStatusModal(
          title: 'Request Failed',
          message: e.toString().replaceAll('Exception:', '').trim(),
          success: false);
    } finally {
      if (mounted) setState(() => _otpSending = false);
    }
  }

  Future<void> _handleRegister() async {
    final fields = {
      'Full Name': _nameController.text.trim(),
      'Email': _emailController.text.trim(),
      'Phone': _phoneController.text.trim(),
      'Location': _locationController.text.trim(),
      'Password': _passwordController.text.trim(),
      'OTP': _otpController.text.trim(),
    };

    if (fields.values.any((v) => v.isEmpty)) {
      _showStatusModal(
          title: 'Missing Info',
          message: 'Please fill out all fields.',
          success: false);
      return;
    }

    if (!_isValidFullName(fields['Full Name']!)) {
      _showStatusModal(
          title: 'Invalid Name',
          message: 'Please enter your full name (first and last).',
          success: false);
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showStatusModal(
          title: 'Error', message: 'Passwords do not match.', success: false);
      return;
    }

    if (!_isValidGmail(fields['Email']!)) {
      _showStatusModal(
          title: 'Invalid Email',
          message: 'Only @gmail.com addresses are allowed.',
          success: false);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.register(
        name: fields['Full Name']!,
        email: fields['Email']!,
        password: fields['Password']!,
        phoneNumber: fields['Phone']!,
        otpCode: fields['OTP']!,
        location: fields['Location']!,
      );

      if (!mounted) return;

      if (response['token'] != null || response['status'] == 'success') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('is_guest', false);
        _storeSellerProfile(prefs, response);

        await _showSuccessModal();
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/home', (route) => false);
      }
    } catch (e) {
      if (!mounted) return;
      _showStatusModal(
          title: 'Registration Failed',
          message: e.toString().replaceAll('Exception:', '').trim(),
          success: false);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _onFullNameChanged(String value) {
    final formatted = _capitalizeFullName(value);
    if (formatted == value) return;
    final currentSelection = _nameController.selection;
    final baseOffset =
        currentSelection.baseOffset.clamp(0, formatted.length).toInt();
    final extentOffset =
        currentSelection.extentOffset.clamp(0, formatted.length).toInt();
    _nameController.value = TextEditingValue(
        text: formatted,
        selection: currentSelection.copyWith(
            baseOffset: baseOffset, extentOffset: extentOffset));
  }

  String _capitalizeFullName(String value) {
    if (value.isEmpty) return value;
    final buffer = StringBuffer();
    bool startOfWord = true;

    for (var i = 0; i < value.length; i++) {
      final char = value[i];
      final isBoundary = _isNameBoundaryChar(char);

      if (startOfWord && !isBoundary) {
        buffer.write(char.toUpperCase());
        startOfWord = false;
      } else {
        buffer.write(char);
        startOfWord = isBoundary;
      }
    }

    return buffer.toString();
  }

  bool _isNameBoundaryChar(String char) =>
      char.trim().isEmpty || char == '-' || char == '\'' || char == '.';

  // --- UI Components ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: const [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 20,
                          offset: Offset(0, 10))
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 30),
                      _buildTextField(
                          _nameController, 'Full Name', Icons.person_outline,
                          textCapitalization: TextCapitalization.words,
                          onChanged: _onFullNameChanged),
                      const SizedBox(height: 16),
                      _buildTextField(
                          _emailController, 'Email', Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 16),
                      _buildTextField(_phoneController, 'Phone Number',
                          Icons.phone_android_outlined,
                          hint: '09XXXXXXXXX',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(11)
                          ]),
                      const SizedBox(height: 10),
                      _buildOtpButton(),
                      const SizedBox(height: 12),
                      _buildTextField(
                          _otpController, 'OTP Code', Icons.sms_outlined,
                          hint: '6-digit code',
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6)
                          ]),
                      const SizedBox(height: 16),
                      _buildLocationAutocomplete(),
                      const SizedBox(height: 16),
                      _buildPasswordField(_passwordController, 'Password'),
                      const SizedBox(height: 16),
                      _buildPasswordField(
                          _confirmPasswordController, 'Confirm Password'),
                      const SizedBox(height: 24),
                      _buildRegisterButton(),
                      const SizedBox(height: 20),
                      _buildLoginLink(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationAutocomplete() {
    return LayoutBuilder(
      builder: (context, constraints) => Autocomplete<String>(
        optionsBuilder: (TextEditingValue textEditingValue) async {
          if (_debounce?.isActive ?? false) _debounce!.cancel();
          final completer = Completer<Iterable<String>>();

          _debounce = Timer(const Duration(milliseconds: 600), () async {
            if (!mounted) return;
            setState(() => _isSearchingLocation = true);
            try {
              final results =
                  await ApiService.searchLocations(textEditingValue.text);
              completer.complete(results);
            } catch (e) {
              completer.complete(const Iterable<String>.empty());
            } finally {
              if (mounted) setState(() => _isSearchingLocation = false);
            }
          });
          return completer.future;
        },
        onSelected: (String selection) {
          _locationController.text = selection;
          FocusScope.of(context).unfocus();
        },
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          // Sync internal autocomplete controller with our main controller
          if (_locationController.text.isNotEmpty && controller.text.isEmpty) {
            controller.text = _locationController.text;
          }
          controller
              .addListener(() => _locationController.text = controller.text);

          return TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              labelText: 'Location',
              hintText: 'Barangay, City, or Province',
              prefixIcon:
                  const Icon(Icons.location_on_rounded, color: themeColor),
              suffixIcon: _isSearchingLocation
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(strokeWidth: 2)))
                  : const Icon(Icons.search, size: 20),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.white,
            ),
          );
        },
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildBackground() => Container(
      decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [themeColor.withValues(alpha: 0.8), Colors.white])));

  Widget _buildHeader() => Column(children: [
        const CircleAvatar(
            radius: 35,
            backgroundColor: themeColor,
            child:
                Icon(Icons.person_add_rounded, size: 35, color: Colors.white)),
        const SizedBox(height: 16),
        const Text('Create Account',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        const Text('Join us to start selling seedlings',
            style: TextStyle(color: Colors.grey))
      ]);

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon,
      {String? hint,
      TextInputType keyboardType = TextInputType.text,
      List<TextInputFormatter>? inputFormatters,
      TextCapitalization textCapitalization = TextCapitalization.none,
      ValueChanged<String>? onChanged}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: themeColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildPasswordField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline_rounded, color: themeColor),
        suffixIcon: IconButton(
            icon: Icon(
                _obscurePassword ? Icons.visibility_off : Icons.visibility),
            onPressed: () =>
                setState(() => _obscurePassword = !_obscurePassword)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildOtpButton() {
    String buttonText = _otpSent ? 'RESEND OTP' : 'SEND OTP';
    if (_resendCountdown > 0) buttonText = 'RESEND IN ${_resendCountdown}s';

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: OutlinedButton(
          onPressed:
              (_otpSending || _resendCountdown > 0) ? null : _handleSendOtp,
          style: OutlinedButton.styleFrom(
              side: const BorderSide(color: themeColor, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          child: _otpSending
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(buttonText,
                  style: const TextStyle(
                      color: themeColor, fontWeight: FontWeight.bold))),
    );
  }

  Widget _buildRegisterButton() => SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
          onPressed: _isLoading ? null : _handleRegister,
          style: ElevatedButton.styleFrom(
              backgroundColor: themeColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          child: _isLoading
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('REGISTER',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold))));

  Widget _buildLoginLink() =>
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const Text("Already have an account? "),
        GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Text("Login",
                style:
                    TextStyle(color: themeColor, fontWeight: FontWeight.bold)))
      ]);

  void _showStatusModal(
      {required String title, required String message, required bool success}) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)),
                title: Text(title,
                    style: TextStyle(
                        color: success ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold)),
                content: Text(message),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('OK'))
                ]));
  }

  Future<void> _showSuccessModal() async {
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Center(
            child: Card(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20)),
                child: const Padding(
                    padding: EdgeInsets.all(30),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.check_circle_rounded,
                          color: Colors.green, size: 80),
                      SizedBox(height: 15),
                      Text('Success!',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 18))
                    ])))));
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) Navigator.pop(context);
  }

  void _storeSellerProfile(
      SharedPreferences prefs, Map<String, dynamic> response) {
    final seller = response['seller'] ?? response['user'];
    if (seller != null) {
      prefs.setString(
          'seller_full_name', (seller['full_name'] ?? '').toString());
      prefs.setString('seller_location', (seller['location'] ?? '').toString());
    }
  }
}
