import 'dart:ui';

import 'package:flutter/material.dart';

class ResultScreen extends StatelessWidget {
  final String fileName;
  final String operation;

  const ResultScreen({
    super.key,
    this.fileName = 'Annual_Report_2024.pdf',
    this.operation = 'File saved successfully',
  });

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      body: SafeArea(
        child: Stack(
          children: [
            const _ResultBackground(),

            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
              child: Column(
                children: [
                  _buildTopBar(context),
                  const SizedBox(height: 20),
                  _buildSuccessIcon(),
                  const SizedBox(height: 18),
                  _buildHeading(),
                  const SizedBox(height: 22),
                  _buildFileCard(),
                  const SizedBox(height: 16),
                  _buildActionButtons(context),
                  const SizedBox(height: 16),
                  _buildDetailsCard(),
                  const SizedBox(height: 18),
                  _buildDoneButton(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      children: [
        _GlassIconButton(
          icon: Icons.close_rounded,
          onTap: () => Navigator.pop(context),
        ),
        const Spacer(),
        _GlassIconButton(
          icon: Icons.more_vert_rounded,
          onTap: () {
            _showMessage(context, 'More options will be added next.');
          },
        ),
      ],
    );
  }

  Widget _buildSuccessIcon() {
    return Container(
      width: 132,
      height: 132,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF62A4FF), Color(0xFF1769FF), Color(0xFF0755E8)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1769FF).withValues(alpha: 0.28),
            blurRadius: 36,
            spreadRadius: 3,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
          ),
          const Icon(Icons.check_rounded, color: Colors.white, size: 64),
        ],
      ),
    );
  }

  Widget _buildHeading() {
    return const Column(
      children: [
        Text(
          'Your PDF is Ready!',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFF10255C),
            fontSize: 28,
            fontWeight: FontWeight.w800,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'File saved successfully',
          textAlign: TextAlign.center,
          style: TextStyle(color: Color(0xFF7184A4), fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildFileCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6D91C8).withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 62,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F1FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCFDDF0)),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Color(0xFFF45151),
                      size: 29,
                    ),
                    SizedBox(height: 5),
                    Text(
                      'PDF',
                      style: TextStyle(
                        color: Color(0xFFF45151),
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fileName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF10255C),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      '2.4 MB  •  24 pages',
                      style: TextStyle(
                        color: Color(0xFF7B8DA7),
                        fontSize: 10.5,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 15,
                          color: Color(0xFF12A86B),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          operation,
                          style: const TextStyle(
                            color: Color(0xFF12A86B),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionCard(
            icon: Icons.open_in_new_rounded,
            title: 'Open',
            onTap: () {
              _showMessage(context, 'PDF viewer will open next.');
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionCard(
            icon: Icons.share_outlined,
            title: 'Share',
            onTap: () {
              _showMessage(context, 'Share option will be connected next.');
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.80)),
          ),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'File Details',
                  style: TextStyle(
                    color: Color(0xFF10255C),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.insert_drive_file_outlined,
                title: 'File Type',
                value: 'PDF Document',
              ),
              _DetailRow(
                icon: Icons.layers_outlined,
                title: 'Pages',
                value: '24 pages',
              ),
              _DetailRow(
                icon: Icons.data_usage_rounded,
                title: 'File Size',
                value: '2.4 MB',
              ),
              _DetailRow(
                icon: Icons.access_time_rounded,
                title: 'Created',
                value: 'Just now',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDoneButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.pop(context);
          },
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFF2D7BFF), Color(0xFF0958EA)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1769FF).withValues(alpha: 0.25),
                  blurRadius: 20,
                  offset: const Offset(0, 9),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Done',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          height: 55,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFD7E4F4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFF1769FF), size: 20),
              const SizedBox(width: 7),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1769FF),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF3FF),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: const Color(0xFF1769FF), size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF687B96),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF243653),
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
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
          color: Colors.white.withValues(alpha: 0.42),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
              ),
              child: Icon(icon, color: const Color(0xFF17345F), size: 19),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultBackground extends StatelessWidget {
  const _ResultBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -90,
            child: _BlurCircle(
              size: 300,
              color: const Color(0xFF7EB3FF).withValues(alpha: 0.28),
            ),
          ),
          Positioned(
            top: 390,
            left: -120,
            child: _BlurCircle(
              size: 250,
              color: const Color(0xFF4C8EFF).withValues(alpha: 0.13),
            ),
          ),
          Positioned(
            bottom: -90,
            right: -80,
            child: _BlurCircle(
              size: 270,
              color: const Color(0xFF94C5FF).withValues(alpha: 0.18),
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
      imageFilter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
