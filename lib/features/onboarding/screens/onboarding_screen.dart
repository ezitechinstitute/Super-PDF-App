import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pdf_super_app/features/auth/screens/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();

  int _currentPage = 0;

  final List<OnboardingData> _pages = const [
    OnboardingData(
      title: 'All-in-One',
      highlightedTitle: 'PDF Tools',
      description: 'Everything you need to work with PDF in one powerful app.',
      image: 'assets/images/onboarding1.png',
    ),
    OnboardingData(
      title: 'Scan. Convert.',
      highlightedTitle: 'Edit. Save.',
      description:
          'Scan documents, convert images, edit and protect your PDFs.',
      image: 'assets/images/onboarding2.png',
    ),
    OnboardingData(
      title: 'AI-Powered',
      highlightedTitle: 'Productivity',
      description:
          'Summarize, extract and understand your documents with AI technology.',
      image: 'assets/images/onboarding3.png',
    ),
  ];

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _openHome();
    }
  }

  void _skip() {
    _openHome();
  }

  void _openHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7FBFF), Color(0xFFEAF4FF), Color(0xFFDCEBFF)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              const _BackgroundDecoration(),

              Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: _pages.length,
                      onPageChanged: (index) {
                        setState(() {
                          _currentPage = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        return _buildPage(_pages[index]);
                      },
                    ),
                  ),
                  _buildBottomSection(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          _GlassButton(
            onTap: _skip,
            child: const Text(
              'Skip',
              style: TextStyle(
                color: Color(0xFF1246A0),
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(OnboardingData data) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 12),

          _buildTitle(data),

          const SizedBox(height: 12),

          Text(
            data.description,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF50627A),
              fontSize: 16,
              height: 1.55,
              fontWeight: FontWeight.w400,
            ),
          ),

          const SizedBox(height: 12),

          Expanded(
            child: Center(
              child: Hero(
                tag: data.image,
                child: Image.asset(
                  data.image,
                  fit: BoxFit.contain,
                  width: double.infinity,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle(OnboardingData data) {
    return Column(
      children: [
        Text(
          data.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF10255C),
            fontSize: 34,
            fontWeight: FontWeight.w800,
            height: 1.1,
            letterSpacing: -0.8,
          ),
        ),
        Text(
          data.highlightedTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF1769FF),
            fontSize: 34,
            fontWeight: FontWeight.w800,
            height: 1.1,
            letterSpacing: -0.8,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSection() {
    final bool isLastPage = _currentPage == _pages.length - 1;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Row(
        children: [
          Row(
            children: List.generate(
              _pages.length,
              (index) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(right: 7),
                width: index == _currentPage ? 28 : 9,
                height: 9,
                decoration: BoxDecoration(
                  color: index == _currentPage
                      ? const Color(0xFF1769FF)
                      : Colors.white.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: index == _currentPage
                      ? [
                          BoxShadow(
                            color: const Color(
                              0xFF1769FF,
                            ).withValues(alpha: 0.28),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
              ),
            ),
          ),

          const Spacer(),

          _NextButton(
            text: isLastPage ? 'Get Started' : 'Next',
            onTap: _nextPage,
            showArrow: !isLastPage,
          ),
        ],
      ),
    );
  }
}

class OnboardingData {
  final String title;
  final String highlightedTitle;
  final String description;
  final String image;

  const OnboardingData({
    required this.title,
    required this.highlightedTitle,
    required this.description,
    required this.image,
  });
}

class _GlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _GlassButton({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.white.withValues(alpha: 0.28),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.75),
                  width: 1.2,
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _NextButton extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final bool showArrow;

  const _NextButton({
    required this.text,
    required this.onTap,
    required this.showArrow,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
              colors: [Color(0xFF2878FF), Color(0xFF0755E8)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1769FF).withValues(alpha: 0.30),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (showArrow) ...[
                const SizedBox(width: 12),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BackgroundDecoration extends StatelessWidget {
  const _BackgroundDecoration();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -80,
            child: _BlurCircle(
              size: 280,
              color: const Color(0xFF7DB2FF).withValues(alpha: 0.30),
            ),
          ),
          Positioned(
            top: 260,
            left: -120,
            child: _BlurCircle(
              size: 240,
              color: const Color(0xFF4E8DFF).withValues(alpha: 0.16),
            ),
          ),
          Positioned(
            bottom: 40,
            right: -100,
            child: _BlurCircle(
              size: 230,
              color: const Color(0xFF9BC6FF).withValues(alpha: 0.24),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlurCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _BlurCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
