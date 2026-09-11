import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_super_app/core/services/api_service.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class ProtectPdfScreen extends StatefulWidget {
  final PlatformFile selectedFile;

  const ProtectPdfScreen({super.key, required this.selectedFile});

  @override
  State<ProtectPdfScreen> createState() => _ProtectPdfScreenState();
}

class _ProtectPdfScreenState extends State<ProtectPdfScreen> {
  final TextEditingController _passwordController = TextEditingController();

  final TextEditingController _confirmPasswordController =
      TextEditingController();

  final TextEditingController _existingPasswordController =
      TextEditingController();

  bool _isInitializing = true;
  bool _isProtectedPdf = false;
  bool _existingPasswordVerified = false;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _obscureExistingPassword = true;

  bool _isProtecting = false;
  bool _isCheckingPassword = false;

  String? _existingPasswordError;

  @override
  void initState() {
    super.initState();
    _inspectSelectedPdf();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _existingPasswordController.dispose();
    super.dispose();
  }

  // ============================================================
  // CHECK PDF ENCRYPTION
  // ============================================================

  bool _containsEncryptionMarker(Uint8List bytes) {
    const List<int> marker = <int>[
      0x2F,
      0x45,
      0x6E,
      0x63,
      0x72,
      0x79,
      0x70,
      0x74,
    ];

    if (bytes.length < marker.length) {
      return false;
    }

    for (int i = 0; i <= bytes.length - marker.length; i++) {
      bool found = true;

      for (int j = 0; j < marker.length; j++) {
        if (bytes[i + j] != marker[j]) {
          found = false;
          break;
        }
      }

      if (found) {
        return true;
      }
    }

    return false;
  }

  // ============================================================
  // INSPECT SELECTED PDF
  // ============================================================

  Future<void> _inspectSelectedPdf() async {
    final String? sourcePath = widget.selectedFile.path;

    if (sourcePath == null || sourcePath.isEmpty) {
      if (!mounted) return;

      setState(() {
        _isInitializing = false;
      });

      _showMessage('Unable to access the selected PDF.');

      return;
    }

    try {
      final File file = File(sourcePath);

      if (!await file.exists()) {
        throw Exception('PDF file not found.');
      }

      final Uint8List bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        throw Exception('PDF file is empty.');
      }

      final bool encrypted = _containsEncryptionMarker(bytes);

      debugPrint('==========================================');
      debugPrint('🔎 PDF SECURITY CHECK');
      debugPrint('📄 File: ${widget.selectedFile.name}');
      debugPrint('🔐 /Encrypt marker found: $encrypted');
      debugPrint('==========================================');

      if (!encrypted) {
        try {
          final PdfDocument document = PdfDocument(inputBytes: bytes);

          final int pages = document.pages.count;

          document.dispose();

          if (pages <= 0) {
            throw Exception('PDF contains no pages.');
          }
        } catch (e) {
          debugPrint('❌ Normal PDF validation failed: $e');

          throw Exception('Unable to read the selected PDF.');
        }
      }

      if (!mounted) return;

      setState(() {
        _isProtectedPdf = encrypted;
        _isInitializing = false;
      });
    } catch (e) {
      debugPrint('❌ PDF inspection failed: $e');

      if (!mounted) return;

      setState(() {
        _isInitializing = false;
      });

      _showMessage('Unable to read this PDF.');
    }
  }

  // ============================================================
  // VERIFY EXISTING PASSWORD
  // ============================================================

  Future<void> _verifyExistingPassword() async {
    final String password = _existingPasswordController.text;

    if (password.isEmpty) {
      setState(() {
        _existingPasswordError = 'Please enter the existing password.';
      });

      return;
    }

    if (_isCheckingPassword) return;

    final String? sourcePath = widget.selectedFile.path;

    if (sourcePath == null || sourcePath.isEmpty) {
      _showMessage('Unable to access the PDF.');
      return;
    }

    if (!mounted) return;

    setState(() {
      _isCheckingPassword = true;
      _existingPasswordError = null;
    });

    try {
      final File file = File(sourcePath);

      final Uint8List bytes = await file.readAsBytes();

      PdfDocument? document;

      try {
        document = PdfDocument(inputBytes: bytes, password: password);

        final int pages = document.pages.count;

        if (pages <= 0) {
          throw Exception('PDF contains no pages.');
        }
      } finally {
        document?.dispose();
      }

      if (!mounted) return;

      setState(() {
        _existingPasswordVerified = true;
        _isCheckingPassword = false;
        _existingPasswordError = null;
      });

      _showMessage('Password verified successfully.');

      debugPrint('✅ Existing PDF password verified.');
    } catch (e) {
      debugPrint('❌ Existing password verification failed: $e');

      if (!mounted) return;

      setState(() {
        _isCheckingPassword = false;
        _existingPasswordError = 'Incorrect password. Please try again.';
      });
    }
  }

  // ============================================================
  // PROTECT PDF
  // ============================================================

  Future<void> _protectPdf() async {
    if (_isProtectedPdf && !_existingPasswordVerified) {
      _showMessage('Please verify the existing PDF password first.');
      return;
    }

    final String password = _passwordController.text.trim();

    final String confirmPassword = _confirmPasswordController.text.trim();

    if (password.isEmpty) {
      _showMessage('Please enter a new password.');
      return;
    }

    if (password.length < 4) {
      _showMessage('Password must be at least 4 characters.');
      return;
    }

    if (confirmPassword.isEmpty) {
      _showMessage('Please confirm your password.');
      return;
    }

    if (password != confirmPassword) {
      _showMessage('Passwords do not match.');
      return;
    }

    final String? sourcePath = widget.selectedFile.path;

    if (sourcePath == null || sourcePath.isEmpty) {
      _showMessage('Unable to access the selected PDF.');
      return;
    }

    if (_isProtecting) return;

    if (!mounted) return;

    setState(() {
      _isProtecting = true;
    });

    PdfDocument? document;

    try {
      final File sourceFile = File(sourcePath);

      if (!await sourceFile.exists()) {
        throw Exception('Selected PDF file was not found.');
      }

      final Uint8List sourceBytes = await sourceFile.readAsBytes();

      if (sourceBytes.isEmpty) {
        throw Exception('Selected PDF is empty.');
      }

      debugPrint('==========================================');
      debugPrint('🔐 PROTECT PDF');
      debugPrint('📄 File: ${widget.selectedFile.name}');
      debugPrint('🔐 Existing protected: $_isProtectedPdf');
      debugPrint(
        '✅ Existing password verified: '
        '$_existingPasswordVerified',
      );
      debugPrint('🔑 New encryption: AES-256');
      debugPrint('==========================================');

      // ==========================================================
      // OPEN SOURCE PDF
      // ==========================================================

      if (_isProtectedPdf) {
        final String oldPassword = _existingPasswordController.text;

        document = PdfDocument(inputBytes: sourceBytes, password: oldPassword);
      } else {
        document = PdfDocument(inputBytes: sourceBytes);
      }

      // ==========================================================
      // ADD AES-256 SECURITY
      // ==========================================================

      final PdfSecurity security = document.security;

      security.algorithm = PdfEncryptionAlgorithm.aesx256Bit;

      security.userPassword = password;

      security.ownerPassword = _generateOwnerPassword(password);

      security.encryptionOptions = PdfEncryptionOptions.encryptAllContents;

      // ==========================================================
      // SAVE PROTECTED PDF
      // ==========================================================

      final List<int> protectedBytes = await document.save();

      document.dispose();
      document = null;

      if (protectedBytes.isEmpty) {
        throw Exception('Protected PDF is empty.');
      }

      // ==========================================================
      // OUTPUT FILE
      // ==========================================================

      final Directory directory = await getApplicationDocumentsDirectory();

      final String fileName =
          'Protected_Document_'
          '${DateTime.now().millisecondsSinceEpoch}.pdf';

      final String outputPath = '${directory.path}/$fileName';

      final File outputFile = File(outputPath);

      await outputFile.writeAsBytes(protectedBytes, flush: true);

      final int outputFileSize = await outputFile.length();

      if (outputFileSize <= 0) {
        throw Exception('Protected PDF is empty.');
      }

      // ==========================================================
      // VERIFY OUTPUT ENCRYPTION
      // ==========================================================

      final Uint8List savedBytes = await outputFile.readAsBytes();

      final bool outputEncrypted = _containsEncryptionMarker(savedBytes);

      if (!outputEncrypted) {
        throw Exception('Encryption marker was not found in output PDF.');
      }

      debugPrint('✅ Output PDF contains /Encrypt marker.');

      // ==========================================================
      // VERIFY OUTPUT WITH NEW PASSWORD
      // ==========================================================

      PdfDocument? validationDocument;

      try {
        validationDocument = PdfDocument(
          inputBytes: savedBytes,
          password: password,
        );

        final int pages = validationDocument.pages.count;

        if (pages <= 0) {
          throw Exception('Protected PDF has no pages.');
        }

        debugPrint('✅ Output password validation passed.');

        debugPrint('📑 Pages: $pages');
      } finally {
        validationDocument?.dispose();
      }

      // ==========================================================
      // SAVE HISTORY
      // ==========================================================

      try {
        final response = await ApiService.instance.createHistory(
          toolName: 'Protect PDF',
          fileName: widget.selectedFile.name,
          outputFileName: fileName,
          status: 'completed',
          fileSize: outputFileSize,
          notes: 'Protected PDF using AES-256 encryption.',
        );

        debugPrint(
          '✅ Protect history API response: '
          '${response.data}',
        );
      } catch (historyError) {
        // The actual PDF operation succeeded.
        // History failure must not break the PDF flow.
        debugPrint(
          '⚠️ PDF protected successfully, '
          'but history could not be saved: '
          '$historyError',
        );
      }

      if (!mounted) return;

      setState(() {
        _isProtecting = false;
      });

      // ==========================================================
      // OPEN PROTECTED VIEWER
      // ==========================================================

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProtectedPdfViewerScreen(
            filePath: outputPath,
            fileName: fileName,
            password: password,
          ),
        ),
      );
    } catch (e) {
      debugPrint('==========================================');
      debugPrint('❌ PROTECT PDF FAILED');
      debugPrint('❌ Error: $e');
      debugPrint('==========================================');

      document?.dispose();

      if (!mounted) return;

      setState(() {
        _isProtecting = false;
      });

      _showMessage('Unable to protect PDF. Please try another PDF.');
    }
  }

  // ============================================================
  // OWNER PASSWORD
  // ============================================================

  String _generateOwnerPassword(String userPassword) {
    final int timestamp = DateTime.now().microsecondsSinceEpoch;

    return '${userPassword}_owner_$timestamp';
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: const Color(0xFF1769FF),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 18),
        elevation: 8,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // ============================================================
  // INPUT DECORATION
  // ============================================================

  InputDecoration _inputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF1769FF)),
      suffixIcon: IconButton(
        onPressed: _isProtecting ? null : onToggle,
        icon: Icon(
          obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded,
          color: const Color(0xFF6D83A5),
        ),
      ),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.72),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.85)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.85)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: Color(0xFF1769FF), width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(17),
        borderSide: const BorderSide(color: Color(0xFFE85D75)),
      ),
      labelStyle: const TextStyle(color: Color(0xFF5F7393)),
      hintStyle: const TextStyle(color: Color(0xFF98A9BF)),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      body: SafeArea(
        child: Stack(
          children: [
            const _ProtectBackground(),
            if (_isInitializing)
              _buildInitializing()
            else if (_isProtectedPdf && !_existingPasswordVerified)
              _buildExistingPasswordScreen()
            else
              _buildProtectScreen(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // INITIALIZING
  // ============================================================

  Widget _buildInitializing() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.60),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(19),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xFF1769FF),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Checking PDF security...',
                  style: TextStyle(
                    color: Color(0xFF10255C),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EXISTING PASSWORD SCREEN
  // ============================================================

  Widget _buildExistingPasswordScreen() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
            child: Column(
              children: [
                _buildFileCard(),
                const SizedBox(height: 18),
                _GlassPanel(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      Container(
                        width: 78,
                        height: 78,
                        decoration: BoxDecoration(
                          color: const Color(
                            0xFF1769FF,
                          ).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: const Icon(
                          Icons.lock_outline_rounded,
                          color: Color(0xFF1769FF),
                          size: 39,
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Password Required',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF10255C),
                          fontSize: 23,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'This PDF is already password protected. '
                        'Enter its current password to continue.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF7588A5),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 22),
                      TextField(
                        controller: _existingPasswordController,
                        obscureText: _obscureExistingPassword,
                        enabled: !_isCheckingPassword,
                        style: const TextStyle(color: Color(0xFF10255C)),
                        decoration: _inputDecoration(
                          label: 'Current Password',
                          hint: 'Enter current password',
                          icon: Icons.lock_rounded,
                          obscure: _obscureExistingPassword,
                          onToggle: () {
                            setState(() {
                              _obscureExistingPassword =
                                  !_obscureExistingPassword;
                            });
                          },
                        ),
                      ),
                      if (_existingPasswordError != null) ...[
                        const SizedBox(height: 9),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _existingPasswordError!,
                            style: const TextStyle(
                              color: Color(0xFFD84D68),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      _PrimaryButton(
                        icon: _isCheckingPassword
                            ? null
                            : Icons.lock_open_rounded,
                        label: _isCheckingPassword
                            ? 'Checking Password...'
                            : 'Unlock PDF',
                        loading: _isCheckingPassword,
                        onTap: _isCheckingPassword
                            ? () {}
                            : _verifyExistingPassword,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PROTECT SCREEN
  // ============================================================

  Widget _buildProtectScreen() {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
            child: Column(
              children: [
                _buildHeroCard(),
                const SizedBox(height: 16),
                _buildFileCard(),
                const SizedBox(height: 16),
                _buildPasswordPanel(),
                const SizedBox(height: 16),
                _buildSecurityInfo(),
                const SizedBox(height: 22),
                _PrimaryButton(
                  icon: _isProtecting ? null : Icons.lock_rounded,
                  label: _isProtecting ? 'Protecting PDF...' : 'Protect PDF',
                  loading: _isProtecting,
                  onTap: _isProtecting ? () {} : _protectPdf,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      child: Row(
        children: [
          _GlassIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: _isProtecting ? () {} : () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Protect PDF',
              style: TextStyle(
                color: Color(0xFF10255C),
                fontSize: 23,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _GlassIconButton(
            icon: Icons.info_outline_rounded,
            onTap: () {
              _showMessage(
                'Your PDF will be protected with AES-256 encryption.',
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HERO
  // ============================================================

  Widget _buildHeroCard() {
    return _GlassPanel(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: const Color(0xFF1769FF).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(23),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: Color(0xFF1769FF),
              size: 39,
            ),
          ),
          const SizedBox(height: 17),
          const Text(
            'Secure Your PDF',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF10255C),
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add a password to protect this PDF '
            'from unauthorized access.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF7588A5),
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FILE CARD
  // ============================================================

  Widget _buildFileCard() {
    return _GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFFFF5C72).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.picture_as_pdf_rounded,
              color: Color(0xFFFF5C72),
              size: 28,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.selectedFile.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF10255C),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isProtectedPdf
                      ? 'Password protected PDF'
                      : 'Ready to protect',
                  style: const TextStyle(
                    color: Color(0xFF7B8DA7),
                    fontSize: 10.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F1FF),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Text(
              'PDF',
              style: TextStyle(
                color: Color(0xFF1769FF),
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PASSWORD PANEL
  // ============================================================

  Widget _buildPasswordPanel() {
    return _GlassPanel(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Set New Password',
            style: TextStyle(
              color: Color(0xFF10255C),
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Create a password for the protected PDF.',
            style: TextStyle(color: Color(0xFF7A8CA6), fontSize: 11),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            enabled: !_isProtecting,
            style: const TextStyle(color: Color(0xFF10255C)),
            decoration: _inputDecoration(
              label: 'New Password',
              hint: 'Enter new password',
              icon: Icons.lock_outline_rounded,
              obscure: _obscurePassword,
              onToggle: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            enabled: !_isProtecting,
            style: const TextStyle(color: Color(0xFF10255C)),
            decoration: _inputDecoration(
              label: 'Confirm Password',
              hint: 'Re-enter new password',
              icon: Icons.lock_reset_rounded,
              obscure: _obscureConfirmPassword,
              onToggle: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECURITY INFO
  // ============================================================

  Widget _buildSecurityInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCFE0FF)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_user_rounded, color: Color(0xFF1769FF)),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AES-256 Protection',
                  style: TextStyle(
                    color: Color(0xFF10255C),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Your PDF will be encrypted with '
                  'AES-256 password protection.',
                  style: TextStyle(
                    color: Color(0xFF667B9B),
                    fontSize: 10.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// GLASS PANEL
// ============================================================================

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.58),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.86)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1769FF).withValues(alpha: 0.05),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ============================================================================
// PRIMARY BUTTON
// ============================================================================

class _PrimaryButton extends StatelessWidget {
  final IconData? icon;
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                colors: [Color(0xFF2D7BFF), Color(0xFF0958EA)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1769FF).withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.3,
                      color: Colors.white,
                    ),
                  )
                else
                  Icon(icon, color: Colors.white, size: 21),
                const SizedBox(width: 9),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// GLASS ICON BUTTON
// ============================================================================

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
          color: Colors.white.withValues(alpha: 0.46),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
              ),
              child: Icon(icon, size: 19, color: const Color(0xFF17345F)),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// BACKGROUND
// ============================================================================

class _ProtectBackground extends StatelessWidget {
  const _ProtectBackground();

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
              color: const Color(0xFF7EB3FF).withValues(alpha: 0.26),
            ),
          ),
          Positioned(
            top: 300,
            left: -130,
            child: _BlurCircle(
              size: 270,
              color: const Color(0xFF4C8EFF).withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -80,
            child: _BlurCircle(
              size: 290,
              color: const Color(0xFF94C5FF).withValues(alpha: 0.18),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// BLUR CIRCLE
// ============================================================================

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

// ============================================================================
// PROTECTED PDF VIEWER
// ============================================================================

class ProtectedPdfViewerScreen extends StatefulWidget {
  final String filePath;
  final String fileName;
  final String password;

  const ProtectedPdfViewerScreen({
    super.key,
    required this.filePath,
    required this.fileName,
    required this.password,
  });

  @override
  State<ProtectedPdfViewerScreen> createState() =>
      _ProtectedPdfViewerScreenState();
}

class _ProtectedPdfViewerScreenState extends State<ProtectedPdfViewerScreen> {
  late final PdfViewerController _pdfViewerController;

  bool _documentLoaded = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _pdfViewerController = PdfViewerController();

    _validateFile();
  }

  @override
  void dispose() {
    _pdfViewerController.dispose();
    super.dispose();
  }

  // ============================================================
  // VALIDATE PROTECTED FILE
  // ============================================================

  Future<void> _validateFile() async {
    try {
      final File file = File(widget.filePath);

      if (!await file.exists()) {
        throw Exception('Protected PDF file was not found.');
      }

      final Uint8List bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        throw Exception('Protected PDF is empty.');
      }

      final bool encrypted = _containsEncryptionMarkerStatic(bytes);

      if (!encrypted) {
        throw Exception('PDF is not encrypted.');
      }

      PdfDocument? document;

      try {
        document = PdfDocument(inputBytes: bytes, password: widget.password);

        if (document.pages.count <= 0) {
          throw Exception('PDF contains no pages.');
        }
      } finally {
        document?.dispose();
      }

      if (!mounted) return;

      setState(() {
        _documentLoaded = true;
        _errorMessage = null;
      });

      debugPrint('✅ Protected PDF viewer ready');
    } catch (e) {
      debugPrint('❌ Protected viewer validation failed: $e');

      if (!mounted) return;

      setState(() {
        _documentLoaded = false;
        _errorMessage = 'Unable to open the protected PDF.';
      });
    }
  }

  static bool _containsEncryptionMarkerStatic(Uint8List bytes) {
    const List<int> marker = <int>[
      0x2F,
      0x45,
      0x6E,
      0x63,
      0x72,
      0x79,
      0x70,
      0x74,
    ];

    if (bytes.length < marker.length) {
      return false;
    }

    for (int i = 0; i <= bytes.length - marker.length; i++) {
      bool found = true;

      for (int j = 0; j < marker.length; j++) {
        if (bytes[i + j] != marker[j]) {
          found = false;
          break;
        }
      }

      if (found) {
        return true;
      }
    }

    return false;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.82),
        foregroundColor: const Color(0xFF10255C),
        elevation: 0,
        title: Text(
          widget.fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      body: !_documentLoaded
          ? _buildLoadingOrError()
          : SfPdfViewer.file(
              File(widget.filePath),
              password: widget.password,
              controller: _pdfViewerController,
              canShowPasswordDialog: false,
              canShowScrollHead: true,
              canShowScrollStatus: true,
              onDocumentLoaded: (PdfDocumentLoadedDetails details) {
                debugPrint('✅ Protected PDF loaded.');
              },
              onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                debugPrint(
                  '❌ Viewer load failed: '
                  '${details.description}',
                );

                if (!mounted) return;

                setState(() {
                  _documentLoaded = false;
                  _errorMessage = details.description;
                });
              },
            ),
    );
  }

  // ============================================================
  // LOADING / ERROR
  // ============================================================

  Widget _buildLoadingOrError() {
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.70),
                  borderRadius: BorderRadius.circular(21),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFE05B71),
                  size: 38,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF10255C),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _errorMessage = null;
                  });

                  _validateFile();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    return const Center(
      child: CircularProgressIndicator(color: Color(0xFF1769FF)),
    );
  }
}
