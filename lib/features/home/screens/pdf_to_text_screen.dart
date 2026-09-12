import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_super_app/core/services/api_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Pulls the text layer straight out of a PDF.
///
/// This is not OCR. A PDF produced by a word processor already carries its
/// text, so reading it directly is instant and exact, where rendering each
/// page and running recognition over it is slow and only ever approximate.
/// Scanned PDFs have no text layer, and for those this screen says so and
/// points at the OCR tool instead of returning an empty result.
class PdfToTextScreen extends StatefulWidget {
  final PlatformFile selectedFile;

  const PdfToTextScreen({super.key, required this.selectedFile});

  @override
  State<PdfToTextScreen> createState() => _PdfToTextScreenState();
}

class _PdfToTextScreenState extends State<PdfToTextScreen> {
  bool _isExtracting = false;
  bool _isCompleted = false;

  /// Empty result plus this flag means the PDF carries no text layer.
  bool _looksScanned = false;

  String _extractedText = '';
  int _pageCount = 0;
  bool _includePageMarkers = true;

  @override
  void initState() {
    super.initState();
    _extractText();
  }

  // ============================================================
  // EXTRACT
  // ============================================================

  Future<void> _extractText() async {
    final String? path = widget.selectedFile.path;

    if (path == null || path.trim().isEmpty) {
      _showMessage('Unable to access the selected PDF.');
      return;
    }

    final File sourceFile = File(path);

    if (!await sourceFile.exists()) {
      _showMessage('Selected PDF was not found.');
      return;
    }

    if (!mounted) return;

    setState(() {
      _isExtracting = true;
      _isCompleted = false;
      _looksScanned = false;
      _extractedText = '';
    });

    PdfDocument? document;

    try {
      final Uint8List bytes = await sourceFile.readAsBytes();

      document = PdfDocument(inputBytes: bytes);

      _pageCount = document.pages.count;

      final PdfTextExtractor extractor = PdfTextExtractor(document);

      final StringBuffer buffer = StringBuffer();

      int pagesWithText = 0;

      for (int index = 0; index < _pageCount; index++) {
        final String pageText = extractor
            .extractText(startPageIndex: index, endPageIndex: index)
            .trim();

        if (pageText.isEmpty) continue;

        pagesWithText++;

        if (_includePageMarkers) {
          if (buffer.isNotEmpty) buffer.writeln();
          buffer.writeln('Page ${index + 1}');
        }

        buffer.writeln(pageText);
      }

      final String text = buffer.toString().trim();

      debugPrint('==========================================');
      debugPrint('📝 PDF TO TEXT');
      debugPrint('📄 File: ${widget.selectedFile.name}');
      debugPrint('📑 Pages: $_pageCount, with text: $pagesWithText');
      debugPrint('🔤 Characters: ${text.length}');
      debugPrint('==========================================');

      if (!mounted) return;

      setState(() {
        _extractedText = text;
        _looksScanned = text.isEmpty;
        _isExtracting = false;
        _isCompleted = true;
      });

      if (text.isEmpty) return;

      // ==========================================================
      // SAVE HISTORY TO LARAVEL API
      // ==========================================================

      try {
        final response = await ApiService.instance.createHistory(
          toolName: 'PDF to Text',
          fileName: widget.selectedFile.name,
          status: 'completed',
          notes:
              'Extracted ${text.length} characters from '
              '$pagesWithText of $_pageCount '
              'page${_pageCount == 1 ? '' : 's'}.',
        );

        debugPrint('✅ PDF to Text history API response: ${response.data}');
      } catch (historyError) {
        debugPrint(
          '⚠️ Text extracted, but history could not be saved: $historyError',
        );
      }
    } catch (e) {
      debugPrint('❌ PDF to Text error: $e');

      if (!mounted) return;

      setState(() {
        _isExtracting = false;
      });

      _showMessage('Unable to read text from this PDF.');
    } finally {
      document?.dispose();
    }
  }

  // ============================================================
  // ACTIONS
  // ============================================================

  Future<void> _copyText() async {
    if (_extractedText.trim().isEmpty) {
      _showMessage('There is no text to copy.');
      return;
    }

    await Clipboard.setData(ClipboardData(text: _extractedText));

    _showMessage('Text copied.');
  }

  Future<void> _shareText() async {
    if (_extractedText.trim().isEmpty) {
      _showMessage('There is no text to share.');
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(text: _extractedText, subject: 'Extracted PDF text'),
      );
    } catch (e) {
      debugPrint('❌ PDF to Text share error: $e');

      _showMessage('Unable to share the text.');
    }
  }

  Future<void> _saveText() async {
    if (_extractedText.trim().isEmpty) {
      _showMessage('There is no text to save.');
      return;
    }

    try {
      final Directory directory = await getApplicationDocumentsDirectory();

      final String fileName =
          'PDF_Text_'
          '${DateTime.now().millisecondsSinceEpoch}.txt';

      final String outputPath = '${directory.path}/$fileName';

      final File outputFile = File(outputPath);

      await outputFile.writeAsString(_extractedText, flush: true);

      if (!await outputFile.exists()) {
        throw Exception('Text file was not created.');
      }

      debugPrint('✅ Text saved to $outputPath');

      if (!mounted) return;

      _showMessage('Saved as $fileName');
    } catch (e) {
      debugPrint('❌ PDF to Text save error: $e');

      if (!mounted) return;

      _showMessage('Unable to save the text file.');
    }
  }

  void _togglePageMarkers() {
    if (_isExtracting) return;

    setState(() {
      _includePageMarkers = !_includePageMarkers;
    });

    _extractText();
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
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      body: SafeArea(
        child: Stack(
          children: [
            const _TextBackground(),
            Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildFileCard(),
                        const SizedBox(height: 14),
                        _buildOptions(),
                        const SizedBox(height: 14),
                        if (_isExtracting)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (_looksScanned)
                          _buildScannedNotice()
                        else if (_isCompleted)
                          _buildResult(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      child: Row(
        children: [
          _GlassIconButton(
            onTap: _isExtracting ? () {} : () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'PDF to Text',
                  style: TextStyle(
                    color: Color(0xFF10255C),
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Read the text layer of a PDF',
                  style: TextStyle(color: Color(0xFF7A8CA6), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF12B886).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.text_snippet_outlined,
              color: Color(0xFF12B886),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.selectedFile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF10255C),
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isExtracting
                      ? 'Reading text...'
                      : _isCompleted
                      ? '$_pageCount page${_pageCount == 1 ? '' : 's'}  •  '
                            '${_extractedText.length} characters'
                      : 'Ready',
                  style: const TextStyle(
                    color: Color(0xFF7A8CA6),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
      ),
      child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        value: _includePageMarkers,
        onChanged: _isExtracting ? null : (_) => _togglePageMarkers(),
        activeThumbColor: const Color(0xFF1769FF),
        title: const Text(
          'Mark page breaks',
          style: TextStyle(
            color: Color(0xFF10255C),
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: const Text(
          'Write "Page N" before each page\'s text',
          style: TextStyle(color: Color(0xFF7A8CA6), fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildScannedNotice() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFF8A00).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFFF8A00).withValues(alpha: 0.35),
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Color(0xFFC96A00)),
              SizedBox(width: 8),
              Text(
                'No text layer found',
                style: TextStyle(
                  color: Color(0xFFC96A00),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'This PDF holds only images, which usually means it was '
            'scanned or photographed. There is no text to read out of '
            'it directly. Use the OCR tool instead — it recognises text '
            'inside the page images.',
            style: TextStyle(
              color: Color(0xFF8A5A18),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Extracted Text',
              style: TextStyle(
                color: Color(0xFF10255C),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF12B886).withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 13,
                    color: Color(0xFF0E8F6B),
                  ),
                  SizedBox(width: 4),
                  Text(
                    'Done',
                    style: TextStyle(
                      color: Color(0xFF0E8F6B),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
          ),
          child: SelectableText(
            _extractedText,
            style: const TextStyle(
              color: Color(0xFF2A3B57),
              fontSize: 13,
              height: 1.55,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ResultAction(
                icon: Icons.copy_rounded,
                label: 'Copy',
                onTap: _copyText,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ResultAction(
                icon: Icons.share_rounded,
                label: 'Share',
                onTap: _shareText,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ResultAction(
                icon: Icons.download_rounded,
                label: 'Save',
                onTap: _saveText,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================
// RESULT ACTION
// ============================================================

class _ResultAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ResultAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.62),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 17, color: const Color(0xFF1769FF)),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF10255C),
                  fontSize: 11,
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

// ============================================================
// GLASS ICON BUTTON
// ============================================================

class _GlassIconButton extends StatelessWidget {
  final VoidCallback onTap;

  const _GlassIconButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.white.withValues(alpha: 0.38),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.80)),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 18,
                color: Color(0xFF17345F),
              ),
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

class _TextBackground extends StatelessWidget {
  const _TextBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -120,
            right: -80,
            child: _BlurCircle(
              size: 300,
              color: const Color(0xFF7EB3FF).withValues(alpha: 0.26),
            ),
          ),
          Positioned(
            bottom: -90,
            left: -80,
            child: _BlurCircle(
              size: 270,
              color: const Color(0xFF7FE3C4).withValues(alpha: 0.20),
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
