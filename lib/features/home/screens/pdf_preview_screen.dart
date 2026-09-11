import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pdf_super_app/core/services/file_service.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfPreviewScreen extends StatefulWidget {
  final String fileName;
  final String? filePath;

  const PdfPreviewScreen({
    super.key,
    this.fileName = 'Project Proposal.pdf',
    this.filePath,
  });

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();

  bool _isLoadingPdf = true;
  bool _isSaving = false;
  bool _isSharing = false;
  String? _pdfError;

  @override
  void initState() {
    super.initState();

    if (widget.filePath == null || widget.filePath!.isEmpty) {
      _isLoadingPdf = false;
    }
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
  // PDF LOADED
  // ============================================================

  void _handlePdfLoaded(PdfDocumentLoadedDetails details) {
    if (!mounted) return;

    setState(() {
      _isLoadingPdf = false;
      _pdfError = null;
    });
  }

  // ============================================================
  // PDF ERROR
  // ============================================================

  void _handlePdfError(Object error) {
    if (!mounted) return;

    setState(() {
      _isLoadingPdf = false;
      _pdfError = 'Unable to open this PDF.';
    });

    debugPrint('❌ PDF preview error: $error');
  }

  // ============================================================
  // SAVE PDF
  // ============================================================

  Future<void> _savePdf() async {
    if (_isSaving || _isSharing) return;

    final String? path = widget.filePath;

    if (path == null || path.isEmpty) {
      _showMessage('There is no PDF file available to save.');
      return;
    }

    try {
      final File sourceFile = File(path);

      if (!await sourceFile.exists()) {
        _showMessage('The PDF file could not be found.');
        return;
      }

      if (mounted) {
        setState(() {
          _isSaving = true;
        });
      }

      final Uri? savedUri = await FileService.savePdf(
        filePath: path,
        fileName: widget.fileName,
      );

      if (!mounted) return;

      if (savedUri == null) {
        _showMessage('Save cancelled.');
        return;
      }

      _showMessage('PDF saved successfully.');
    } catch (e) {
      debugPrint('❌ PDF save error: $e');

      if (mounted) {
        _showMessage('Unable to save this PDF.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // SHARE PDF
  // ============================================================

  Future<void> _sharePdf() async {
    if (_isSaving || _isSharing) return;

    final String? path = widget.filePath;

    if (path == null || path.isEmpty) {
      _showMessage('There is no PDF file available to share.');
      return;
    }

    try {
      final File file = File(path);

      if (!await file.exists()) {
        _showMessage('The PDF file could not be found.');
        return;
      }

      if (mounted) {
        setState(() {
          _isSharing = true;
        });
      }

      await FileService.sharePdf(filePath: path, fileName: widget.fileName);
    } catch (e) {
      debugPrint('❌ PDF share error: $e');

      if (mounted) {
        _showMessage('Unable to share this PDF.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
        });
      }
    }
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
            const _PreviewBackground(),

            Column(
              children: [
                _buildTopBar(),
                _buildFileInfo(),
                Expanded(child: _buildPreviewArea()),
                _buildBottomActions(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      child: Row(
        children: [
          _GlassIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
          ),

          const SizedBox(width: 12),

          const Expanded(
            child: Text(
              'PDF Preview',
              style: TextStyle(
                color: Color(0xFF10255C),
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FILE INFO
  // ============================================================

  Widget _buildFileInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xFFBCD4FF).withValues(alpha: 0.72),
                width: 1.0,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEEEE),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Color(0xFFF45151),
                    size: 25,
                  ),
                ),

                const SizedBox(width: 11),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF10255C),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Selected PDF',
                        style: TextStyle(
                          color: Color(0xFF788BA8),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),

                const _SmallInfoChip(
                  icon: Icons.picture_as_pdf_rounded,
                  text: 'PDF',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PREVIEW AREA
  // ============================================================

  Widget _buildPreviewArea() {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 18),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.34),
              borderRadius: BorderRadius.circular(25),
              border: Border.all(
                color: const Color(0xFF8FB8FF).withValues(alpha: 0.68),
                width: 1.35,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1769FF).withValues(alpha: 0.06),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Stack(
              children: [
                if (widget.filePath != null && widget.filePath!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SfPdfViewer.file(
                      File(widget.filePath!),
                      key: _pdfViewerKey,
                      canShowScrollHead: true,
                      canShowScrollStatus: true,
                      enableDoubleTapZooming: true,
                      onDocumentLoaded: _handlePdfLoaded,
                      onDocumentLoadFailed: (details) {
                        _handlePdfError(details.description);
                      },
                    ),
                  )
                else
                  _buildDemoState(),

                if (_isLoadingPdf)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 34,
                            height: 34,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: Color(0xFF1769FF),
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Opening PDF...',
                            style: TextStyle(
                              color: Color(0xFF10255C),
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                if (_pdfError != null) Positioned.fill(child: _buildPdfError()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DEMO STATE
  // ============================================================

  Widget _buildDemoState() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF3FF),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_rounded,
                  color: Color(0xFF1769FF),
                  size: 38,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'No PDF file loaded',
                style: TextStyle(
                  color: Color(0xFF10255C),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select a real PDF from the File Picker to preview it.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF74859F),
                  fontSize: 11.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PDF ERROR
  // ============================================================

  Widget _buildPdfError() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEEEE),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Color(0xFFE25563),
                  size: 36,
                ),
              ),

              const SizedBox(height: 14),

              const Text(
                'Couldn’t open PDF',
                style: TextStyle(
                  color: Color(0xFF10255C),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 7),

              const Text(
                'The selected file could not be loaded as a PDF.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF74859F), fontSize: 11.5),
              ),

              const SizedBox(height: 15),

              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1769FF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM ACTIONS
  // ============================================================

  Widget _buildBottomActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ======================================================
          // SHARE
          // ======================================================
          Expanded(
            flex: 2,
            child: _BottomAction(
              icon: Icons.share_outlined,
              label: _isSharing ? 'Sharing...' : 'Share',
              loading: _isSharing,
              onTap: _sharePdf,
            ),
          ),

          // ======================================================
          // EDIT
          // ======================================================

          // ======================================================
          // DELETE
          // ======================================================
          Expanded(
            flex: 2,
            child: _BottomAction(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              onTap: () {
                _showMessage('Delete action will be added next.');
              },
            ),
          ),

          const SizedBox(width: 8),

          // ======================================================
          // CONTINUE / SAVE
          // ======================================================
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 56,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: (_isSaving || _isSharing) ? null : _savePdf,
                  borderRadius: BorderRadius.circular(18),
                  child: Ink(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: const LinearGradient(
                        colors: [Color(0xFF2D7BFF), Color(0xFF0958EA)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF1769FF,
                          ).withValues(alpha: 0.25),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_isSaving)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.2,
                              color: Colors.white,
                            ),
                          )
                        else
                          const Icon(
                            Icons.save_alt_rounded,
                            color: Colors.white,
                            size: 18,
                          ),

                        const SizedBox(width: 5),

                        Flexible(
                          child: Text(
                            _isSaving ? 'Saving...' : 'Continue',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// SMALL INFO CHIP
// ============================================================

class _SmallInfoChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SmallInfoChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCFE0FF)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF1769FF)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Color(0xFF1769FF),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// BOTTOM ACTION
// ============================================================

class _BottomAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool loading;

  const _BottomAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFCFE0FF).withValues(alpha: 0.85),
              ),
            ),
            child: loading
                ? const Padding(
                    padding: EdgeInsets.all(11),
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF536B8E),
                    ),
                  )
                : Icon(icon, color: const Color(0xFF536B8E), size: 20),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF7184A2),
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// GLASS BUTTON
// ============================================================

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
          color: Colors.white.withValues(alpha: 0.40),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFBCD4FF).withValues(alpha: 0.72),
                ),
              ),
              child: Icon(icon, color: const Color(0xFF17345F), size: 19),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// BACKGROUND
// ============================================================

class _PreviewBackground extends StatelessWidget {
  const _PreviewBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -110,
            right: -80,
            child: _BlurCircle(
              size: 290,
              color: const Color(0xFF7EB3FF).withValues(alpha: 0.27),
            ),
          ),
          Positioned(
            top: 300,
            left: -120,
            child: _BlurCircle(
              size: 250,
              color: const Color(0xFF4C8EFF).withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -70,
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

// ============================================================
// BLUR CIRCLE
// ============================================================

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
