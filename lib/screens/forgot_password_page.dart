import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _otpController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _obscurePassword = true;
  bool _otpSending = false;
  bool _isSubmitting = false;
  bool _otpSent = false;

  bool _isValidPhone(String phone) {
    return RegExp(r'^09[0-9]{9}$').hasMatch(phone);
  }

  Future<void> _handleSendOtp() async {
    final phone = _phoneController.text.trim();
    if (!_isValidPhone(phone)) {
      _showStatusModal(
          title: 'Invalid Number',
          message: 'Please enter a valid 11-digit phone number starting with 09.',
          success: false);
      return;
    }

    setState(() => _otpSending = true);
    try {
      final response = await ApiService.requestOtp(
        phoneNumber: phone,
        purpose: 'reset',
      );

      if (!mounted) return;

      final debugOtp = response['debug_otp']?.toString();
      final message = debugOtp != null && debugOtp.isNotEmpty
          ? 'OTP sent. Debug OTP: $debugOtp'
          : 'OTP sent. Please check your phone.';

      _otpSent = true;
      _showStatusModal(title: 'OTP Sent', message: message, success: true);
    } catch (e) {
      if (!mounted) return;
      _showStatusModal(
          title: 'OTP Failed',
          message: e.toString().replaceAll('Exception:', '').trim(),
          success: false);
    } finally {
      if (mounted) setState(() => _otpSending = false);
    }
  }

  Future<void> _handleReset() async {
    final phone = _phoneController.text.trim();
    final otp = _otpController.text.trim();
    final newPassword = _newPasswordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (!_isValidPhone(phone)) {
      _showStatusModal(
          title: 'Invalid Number',
          message: 'Please enter a valid 11-digit phone number starting with 09.',
          success: false);
      return;
    }

    if (!_otpSent) {
      _showStatusModal(
          title: 'OTP Required',
          message: 'Please tap "Send OTP" first.',
          success: false);
      return;
    }

    if (otp.length != 6) {
      _showStatusModal(
          title: 'Invalid OTP',
          message: 'Please enter the 6-digit OTP sent to your phone.',
          success: false);
      return;
    }

    if (newPassword.length < 8) {
      _showStatusModal(
          title: 'Weak Password',
          message: 'Password must be at least 8 characters.',
          success: false);
      return;
    }

    if (newPassword != confirmPassword) {
      _showStatusModal(
          title: 'Password Mismatch',
          message: 'The passwords you entered do not match.',
          success: false);
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ApiService.resetPasswordWithOtp(
        phoneNumber: phone,
        otpCode: otp,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );

      if (!mounted) return;
      _showStatusModal(
          title: 'Success',
          message: 'Your password has been reset. You can now log in.',
          success: true);
    } catch (e) {
      if (!mounted) return;
      _showStatusModal(
          title: 'Reset Failed',
          message: e.toString().replaceAll('Exception:', '').trim(),
          success: false);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const themeColor = Color(0xFF2E7D32);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot Password'),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildTextField(
                _phoneController,
                'Phone Number',
                Icons.phone_android_outlined,
                themeColor,
                hint: '09XXXXXXXXX',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11)
                ],
              ),
              const SizedBox(height: 12),
              _buildOtpButton(themeColor),
              const SizedBox(height: 12),
              _buildTextField(
                _otpController,
                'OTP Code',
                Icons.sms_outlined,
                themeColor,
                hint: '6-digit OTP',
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6)
                ],
              ),
              const SizedBox(height: 16),
              _buildPasswordField(
                  _newPasswordController, 'New Password', themeColor),
              const SizedBox(height: 12),
              _buildPasswordField(_confirmPasswordController,
                  'Confirm Password', themeColor),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _handleReset,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('RESET PASSWORD',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpButton(Color color) => SizedBox(
      width: double.infinity,
      height: 46,
      child: OutlinedButton(
          onPressed: _otpSending ? null : _handleSendOtp,
          style: OutlinedButton.styleFrom(
              side: BorderSide(color: color, width: 1.5),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12))),
          child: _otpSending
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(_otpSent ? 'RESEND OTP' : 'SEND OTP',
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.bold))));

  Widget _buildTextField(
      TextEditingController controller, String label, IconData icon, Color color,
      {String? hint,
      TextInputType keyboardType = TextInputType.text,
      List<TextInputFormatter>? inputFormatters}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: color),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildPasswordField(
      TextEditingController controller, String label, Color color) {
    return TextField(
      controller: controller,
      obscureText: _obscurePassword,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(Icons.lock_outline_rounded, color: color),
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
              ],
            ));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
