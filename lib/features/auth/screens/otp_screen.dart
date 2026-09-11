import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:pdf_super_app/core/services/api_service.dart';
import 'package:pdf_super_app/features/home/screens/home_screen.dart';

class OtpScreen extends StatefulWidget {
  final String email;

  const OtpScreen({super.key, required this.email});

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );

  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  int _secondsRemaining = 45;
  bool _isVerifying = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }

    for (final node in _focusNodes) {
      node.dispose();
    }

    super.dispose();
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));

      if (!mounted) {
        return false;
      }

      if (_secondsRemaining <= 0) {
        return false;
      }

      setState(() {
        _secondsRemaining--;
      });

      return _secondsRemaining > 0;
    });
  }

  void _resendCode() {
    if (_secondsRemaining > 0 || _isVerifying) {
      return;
    }

    _showMessage(
      'Resend OTP is not available yet. Please use the current code.',
    );
  }

  Future<void> _verifyCode() async {
    if (_isVerifying) {
      return;
    }

    FocusScope.of(context).unfocus();

    final code = _controllers.map((controller) {
      return controller.text.trim();
    }).join();

    if (code.length != 6) {
      _showMessage('Please enter the complete 6-digit code.');
      return;
    }

    setState(() {
      _isVerifying = true;
    });

    try {
      final response = await ApiService.instance.verifyOtp(
        email: widget.email,
        otp: code,
      );

      if (!mounted) {
        return;
      }

      final data = response.data;

      final message = data is Map && data['message'] is String
          ? data['message'] as String
          : 'OTP verified successfully.';

      _showMessage(message);

      await Future.delayed(const Duration(milliseconds: 400));

      if (!mounted) {
        return;
      }

      /*
       * ApiService.verifyOtp() already saves the Sanctum token
       * into SharedPreferences.
       *
       * After successful verification, the user can enter the app.
       */
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
        (route) => false,
      );
    } on DioException catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage(_extractDioError(e));
    } catch (_) {
      if (!mounted) {
        return;
      }

      _showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
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
    if (!mounted) {
      return;
    }

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

  void _handleOtpInput(int index, String value) {
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');

      for (int i = 0; i < digits.length && index + i < 6; i++) {
        _controllers[index + i].text = digits[i];
      }

      final nextIndex = (index + digits.length).clamp(0, 5);

      _focusNodes[nextIndex].requestFocus();

      setState(() {});
      return;
    }

    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }

    setState(() {});
  }

  void _handleBackspace(int index) {
    if (_controllers[index].text.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();

      _controllers[index - 1].clear();
    }
  }

  String get _timerText {
    final seconds = _secondsRemaining.toString().padLeft(2, '0');

    return '00:$seconds';
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
              const _OtpBackground(),

              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: size.height - 50),
                  child: Column(
                    children: [
                      _buildTopBar(),

                      const SizedBox(height: 8),

                      _buildHero(),

                      const SizedBox(height: 20),

                      _buildVerificationCard(),

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

  Widget _buildTopBar() {
    return Align(
      alignment: Alignment.centerLeft,
      child: _GlassIconButton(
        icon: Icons.arrow_back_ios_new_rounded,
        onTap: _isVerifying ? () {} : () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildHero() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 190,
          child: Image.asset('assets/images/otp.png', fit: BoxFit.contain),
        ),

        const SizedBox(height: 6),

        const Text(
          'Verify Your Email',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF10255C),
            fontSize: 30,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          "We've sent a 6-digit verification code to",
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF68798F), fontSize: 14, height: 1.4),
        ),

        const SizedBox(height: 4),

        Text(
          widget.email,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF1769FF),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }

  Widget _buildVerificationCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
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
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Enter Verification Code',
                  style: TextStyle(
                    color: Color(0xFF243653),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              _buildOtpFields(),

              const SizedBox(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Didn't receive the code? ",
                    style: TextStyle(color: Color(0xFF718198), fontSize: 12),
                  ),
                  GestureDetector(
                    onTap: _resendCode,
                    child: Text(
                      'Resend',
                      style: TextStyle(
                        color: _secondsRemaining == 0 && !_isVerifying
                            ? const Color(0xFF1769FF)
                            : const Color(0xFF7D8CA0),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_secondsRemaining > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '($_timerText)',
                      style: const TextStyle(
                        color: Color(0xFF1769FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),

              const SizedBox(height: 20),

              _PrimaryButton(
                text: _isVerifying ? 'Verifying...' : 'Verify',
                icon: Icons.verified_rounded,
                onTap: _verifyCode,
                isLoading: _isVerifying,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpFields() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(
        6,
        (index) => Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 3,
              right: index == 5 ? 0 : 3,
            ),
            child: _buildOtpField(index),
          ),
        ),
      ),
    );
  }

  Widget _buildOtpField(int index) {
    return SizedBox(
      height: 56,
      child: TextField(
        controller: _controllers[index],
        focusNode: _focusNodes[index],
        enabled: !_isVerifying,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        onChanged: (value) {
          _handleOtpInput(index, value);
        },
        onSubmitted: (_) {
          if (index == 5) {
            _verifyCode();
          }
        },
        style: const TextStyle(
          color: Color(0xFF10255C),
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: Colors.white.withValues(alpha: 0.58),
          contentPadding: EdgeInsets.zero,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.75)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.75)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Color(0xFF1769FF), width: 1.5),
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.55)),
          ),
        ),
        onTapOutside: (_) {
          FocusScope.of(context).unfocus();
        },
        onEditingComplete: () {
          _handleBackspace(index);
        },
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
                  'Your verification code is private and secure. Never share it with anyone.',
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
                if (isLoading) ...[
                  const SizedBox(width: 10),
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ] else ...[
                  const SizedBox(width: 10),
                  Icon(icon, color: Colors.white, size: 21),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OtpBackground extends StatelessWidget {
  const _OtpBackground();

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
            top: 350,
            left: -110,
            child: _GlowCircle(
              size: 230,
              color: const Color(0xFF4C8EFF).withValues(alpha: 0.14),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -60,
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
