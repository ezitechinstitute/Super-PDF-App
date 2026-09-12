import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:pdf_super_app/core/services/api_service.dart';
import 'package:pdf_super_app/features/auth/screens/login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;

  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    final otp = _otpController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (otp.isEmpty) {
      _showMessage('Please enter the verification code.');
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      _showMessage('Please enter a valid 6-digit OTP.');
      return;
    }

    if (password.isEmpty || confirmPassword.isEmpty) {
      _showMessage('Please fill both password fields.');
      return;
    }

    if (password.length < 8) {
      _showMessage('Password must be at least 8 characters.');
      return;
    }

    if (password != confirmPassword) {
      _showMessage('Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.instance.resetPassword(
        email: widget.email,
        otp: otp,
        password: password,
        passwordConfirmation: confirmPassword,
      );

      if (!mounted) return;

      final data = response.data;

      final message = data is Map && data['message'] is String
          ? data['message'] as String
          : 'Password reset successfully.';

      _showMessage(message);

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } on DioException catch (e) {
      if (!mounted) return;

      _showMessage(_extractDioError(e));
    } catch (_) {
      if (!mounted) return;

      _showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _extractDioError(DioException error) {
    final responseData = error.response?.data;

    if (responseData is Map) {
      final errors = responseData['errors'];

      if (errors is Map && errors.isNotEmpty) {
        final firstError = errors.values.first;

        if (firstError is List && firstError.isNotEmpty) {
          final validationMessage = firstError.first;

          if (validationMessage is String &&
              validationMessage.trim().isNotEmpty) {
            return validationMessage;
          }
        }
      }

      final message = responseData['message'];

      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Please try again.';

      case DioExceptionType.connectionError:
        return 'Unable to connect to the server.';

      default:
        return 'Something went wrong. Please try again.';
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  bool get _hasPassword => _passwordController.text.isNotEmpty;

  bool get _hasMinimumLength => _passwordController.text.length >= 8;

  bool get _hasUppercase => RegExp(r'[A-Z]').hasMatch(_passwordController.text);

  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(_passwordController.text);

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF8FBFF), Color(0xFFEAF4FF), Color(0xFFDDEBFF)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              const _ResetPasswordBackground(),

              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: size.height - 50),
                  child: Column(
                    children: [
                      _buildBackButton(),
                      const SizedBox(height: 8),
                      _buildHero(),
                      const SizedBox(height: 22),
                      _buildPasswordCard(),
                      const SizedBox(height: 20),
                      _buildSecurityCard(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: _GlassIconButton(
        icon: Icons.arrow_back_ios_new_rounded,
        onTap: _isLoading ? () {} : () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildHero() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 205,
          child: Image.asset(
            'assets/images/reset_password.webp',
            fit: BoxFit.contain,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'Reset Password',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF10255C),
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          'Enter your verification code and create a new password.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF68798F), fontSize: 14, height: 1.5),
        ),

        const SizedBox(height: 6),

        Text(
          widget.email,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF1769FF),
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.40),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.76),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6D9EEB).withValues(alpha: 0.10),
                blurRadius: 30,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildLabel('Verification Code'),

              const SizedBox(height: 8),

              _buildOtpField(),

              const SizedBox(height: 16),

              _buildLabel('New Password'),

              const SizedBox(height: 8),

              _buildPasswordField(
                controller: _passwordController,
                hint: 'Enter new password',
                obscureText: _obscurePassword,
                onToggle: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
              ),

              const SizedBox(height: 16),

              _buildLabel('Confirm Password'),

              const SizedBox(height: 8),

              _buildPasswordField(
                controller: _confirmPasswordController,
                hint: 'Confirm new password',
                obscureText: _obscureConfirmPassword,
                onToggle: () {
                  setState(() {
                    _obscureConfirmPassword = !_obscureConfirmPassword;
                  });
                },
              ),

              const SizedBox(height: 18),

              _buildPasswordStrength(),

              const SizedBox(height: 20),

              _PrimaryButton(
                text: _isLoading ? 'Resetting...' : 'Reset Password',
                icon: Icons.lock_reset_rounded,
                onTap: _resetPassword,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpField() {
    return TextField(
      controller: _otpController,
      enabled: !_isLoading,
      keyboardType: TextInputType.number,
      textInputAction: TextInputAction.next,
      maxLength: 6,
      style: const TextStyle(
        color: Color(0xFF16233A),
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 6,
      ),
      decoration: InputDecoration(
        hintText: 'Enter 6-digit OTP',
        hintStyle: const TextStyle(
          color: Color(0xFF8190A5),
          fontSize: 14,
          letterSpacing: 0,
        ),
        prefixIcon: const Icon(
          Icons.verified_outlined,
          color: Color(0xFF1769FF),
          size: 21,
        ),
        counterText: '',
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.54),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.72)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.72)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(17)),
          borderSide: BorderSide(color: Color(0xFF1769FF), width: 1.4),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.55)),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Color(0xFF243653),
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      enabled: !_isLoading,
      obscureText: obscureText,
      onChanged: (_) {
        setState(() {});
      },
      textInputAction: TextInputAction.next,
      style: const TextStyle(
        color: Color(0xFF16233A),
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF8190A5), fontSize: 14),
        prefixIcon: const Icon(
          Icons.lock_outline_rounded,
          color: Color(0xFF1769FF),
          size: 21,
        ),
        suffixIcon: IconButton(
          onPressed: _isLoading ? null : onToggle,
          icon: Icon(
            obscureText
                ? Icons.visibility_off_outlined
                : Icons.visibility_outlined,
            color: const Color(0xFF60708A),
          ),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.54),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.72)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.72)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(17)),
          borderSide: BorderSide(color: Color(0xFF1769FF), width: 1.4),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(17),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.55)),
        ),
      ),
    );
  }

  Widget _buildPasswordStrength() {
    int score = 0;

    if (_hasMinimumLength) score++;
    if (_hasUppercase) score++;
    if (_hasNumber) score++;

    if (_passwordController.text.contains(RegExp(r'[!@#$%^&*()]'))) {
      score++;
    }

    String label = 'Create a strong password';

    if (_hasPassword && score == 1) {
      label = 'Weak password';
    } else if (score == 2) {
      label = 'Medium password';
    } else if (score == 3) {
      label = 'Good password';
    } else if (score >= 4) {
      label = 'Strong password';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Password strength',
              style: TextStyle(
                color: Color(0xFF53647B),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            Text(
              label,
              style: TextStyle(
                color: score >= 3
                    ? const Color(0xFF159447)
                    : const Color(0xFF6B7C92),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),

        const SizedBox(height: 9),

        Row(
          children: List.generate(4, (index) {
            final active = index < score;

            return Expanded(
              child: Container(
                height: 5,
                margin: EdgeInsets.only(right: index == 3 ? 0 : 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: active
                      ? const Color(0xFF1769FF)
                      : const Color(0xFFD5DFEC),
                ),
              ),
            );
          }),
        ),

        const SizedBox(height: 10),

        const Text(
          'Use at least 8 characters with an uppercase letter and a number.',
          style: TextStyle(color: Color(0xFF7A899C), fontSize: 11, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildSecurityCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.32),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
          ),
          child: const Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: Color(0xFFEAF3FF),
                child: Icon(
                  Icons.verified_user_outlined,
                  color: Color(0xFF1769FF),
                  size: 23,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Your new password will be securely protected.',
                  style: TextStyle(
                    color: Color(0xFF68798F),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.white.withValues(alpha: 0.32),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.76)),
              ),
              child: Icon(icon, size: 18, color: const Color(0xFF17345F)),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onTap;
  final bool isLoading;

  const _PrimaryButton({
    required this.text,
    required this.icon,
    required this.onTap,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isLoading ? null : onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFF2D7BFF), Color(0xFF0958EA)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1769FF).withValues(alpha: 0.28),
                  blurRadius: 20,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(width: 10),
                if (isLoading)
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  Icon(icon, color: Colors.white, size: 21),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResetPasswordBackground extends StatelessWidget {
  const _ResetPasswordBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -70,
            child: _GlowCircle(
              size: 280,
              color: const Color(0xFF7EB3FF).withValues(alpha: 0.30),
            ),
          ),
          Positioned(
            top: 340,
            left: -110,
            child: _GlowCircle(
              size: 230,
              color: const Color(0xFF4C8EFF).withValues(alpha: 0.14),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -70,
            child: _GlowCircle(
              size: 250,
              color: const Color(0xFF94C5FF).withValues(alpha: 0.18),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
