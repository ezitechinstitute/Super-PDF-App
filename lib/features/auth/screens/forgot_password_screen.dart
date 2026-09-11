import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:pdf_super_app/core/services/api_service.dart';
import 'package:pdf_super_app/features/auth/screens/reset_password_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    final email = _emailController.text.trim();

    if (email.isEmpty) {
      _showMessage('Please enter your email address.');
      return;
    }

    if (!_isValidEmail(email)) {
      _showMessage('Please enter a valid email address.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await ApiService.instance.forgotPassword(email: email);

      if (!mounted) return;

      final data = response.data;

      final message = data is Map && data['message'] is String
          ? data['message'] as String
          : 'Password reset OTP generated successfully.';

      _showMessage(message);

      await Future.delayed(const Duration(milliseconds: 400));

      if (!mounted) return;

      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ResetPasswordScreen(email: email)),
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

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    return emailRegex.hasMatch(email);
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
              const _ForgotPasswordBackground(),

              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: size.height - 50),
                  child: Column(
                    children: [
                      _buildBackButton(),
                      const SizedBox(height: 8),
                      _buildHero(),
                      const SizedBox(height: 24),
                      _buildForm(),
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
            'assets/images/forgot_password.png',
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Forgot Password?',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF10255C),
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          "Enter your email address and we'll send you a verification code to reset your password.",
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF68798F), fontSize: 14, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildForm() {
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
              const Text(
                'Email Address',
                style: TextStyle(
                  color: Color(0xFF243653),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _emailController,
                enabled: !_isLoading,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _sendResetLink(),
                style: const TextStyle(
                  color: Color(0xFF16233A),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter your email',
                  hintStyle: const TextStyle(
                    color: Color(0xFF8190A5),
                    fontSize: 14,
                  ),
                  prefixIcon: const Icon(
                    Icons.email_outlined,
                    color: Color(0xFF1769FF),
                    size: 21,
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.54),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 17,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(17),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(17),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(17)),
                    borderSide: BorderSide(
                      color: Color(0xFF1769FF),
                      width: 1.4,
                    ),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(17),
                    borderSide: BorderSide(
                      color: Colors.white.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              _PrimaryButton(
                text: _isLoading ? 'Sending...' : 'Send Reset Link',
                icon: Icons.arrow_forward_rounded,
                onTap: _sendResetLink,
                isLoading: _isLoading,
              ),
            ],
          ),
        ),
      ),
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
                  Icons.shield_outlined,
                  color: Color(0xFF1769FF),
                  size: 23,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'We will only use your email to help you recover your account securely.',
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

class _ForgotPasswordBackground extends StatelessWidget {
  const _ForgotPasswordBackground();

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
            top: 330,
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
