import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_super_app/core/services/api_service.dart';
import 'package:pdf_super_app/features/home/screens/pdf_preview_screen.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class WatermarkPdfScreen extends StatefulWidget {
  final PlatformFile selectedFile;

  const WatermarkPdfScreen({super.key, required this.selectedFile});

  @override
  State<WatermarkPdfScreen> createState() => _WatermarkPdfScreenState();
}

class _WatermarkPdfScreenState extends State<WatermarkPdfScreen> {
  final TextEditingController _watermarkController = TextEditingController(
    text: 'CONFIDENTIAL',
  );

  bool _isSaving = false;

  double _fontSize = 42;
  double _opacity = 0.25;

  int _rotation = 45;

  String _position = 'Center';

  final List<String> _positions = const [
    'Top Left',
    'Top Center',
    'Top Right',
    'Center',
    'Bottom Left',
    'Bottom Center',
    'Bottom Right',
  ];

  @override
  void dispose() {
    _watermarkController.dispose();
    super.dispose();
  }

  // ============================================================
  // SAVE WATERMARKED PDF
  // ============================================================

  Future<void> _addWatermark() async {
    final String? path = widget.selectedFile.path;

    if (path == null || path.isEmpty) {
      _showMessage('Unable to access the selected PDF file.');
      return;
    }

    final String watermarkText = _watermarkController.text.trim();

    if (watermarkText.isEmpty) {
      _showMessage('Please enter watermark text.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    PdfDocument? document;

    try {
      final File sourceFile = File(path);

      if (!await sourceFile.exists()) {
        _showMessage('Selected PDF file was not found.');
        return;
      }

      final List<int> bytes = await sourceFile.readAsBytes();

      document = PdfDocument(inputBytes: bytes);

      for (int pageIndex = 0; pageIndex < document.pages.count; pageIndex++) {
        final PdfPage page = document.pages[pageIndex];

        _drawWatermark(page, watermarkText);
      }

      final List<int> outputBytes = await document.save();

      final Directory directory = await getApplicationDocumentsDirectory();

      final String outputFileName =
          'Watermarked_PDF_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final String outputPath = '${directory.path}/$outputFileName';

      final File outputFile = File(outputPath);

      await outputFile.writeAsBytes(outputBytes, flush: true);

      if (!await outputFile.exists()) {
        throw Exception('Watermarked PDF was not created.');
      }

      final int outputFileSize = await outputFile.length();

      // ============================================================
      // SAVE HISTORY
      // Only metadata is sent to Laravel.
      // Actual PDF remains stored locally on the phone.
      // ============================================================

      try {
        final response = await ApiService.instance.createHistory(
          toolName: 'Watermark',
          fileName: widget.selectedFile.name,
          outputFileName: outputFileName,
          status: 'completed',
          fileSize: outputFileSize,
          notes:
              'Watermark "$watermarkText" added to all pages. '
              'Font size: ${_fontSize.round()}, '
              'Opacity: ${(_opacity * 100).round()}%, '
              'Rotation: $_rotation°, '
              'Position: $_position.',
        );

        debugPrint('✅ Watermark history API response: ${response.data}');
      } catch (historyError) {
        debugPrint(
          '⚠️ Watermark completed, but history could not be saved: '
          '$historyError',
        );
      }

      if (!mounted) return;

      _showMessage('Watermark added successfully.');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PdfPreviewScreen(fileName: outputFileName, filePath: outputPath),
        ),
      );
    } catch (e) {
      debugPrint('❌ Watermark PDF error: $e');

      if (mounted) {
        _showMessage('Unable to add watermark to the PDF.');
      }
    } finally {
      document?.dispose();

      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // DRAW WATERMARK
  // ============================================================

  void _drawWatermark(PdfPage page, String text) {
    final PdfGraphics graphics = page.graphics;

    final PdfFont font = PdfStandardFont(
      PdfFontFamily.helvetica,
      _fontSize,
      style: PdfFontStyle.bold,
    );

    final PdfBrush brush = PdfSolidBrush(
      PdfColor(80, 95, 120, (_opacity * 255).round()),
    );

    final PdfStringFormat format = PdfStringFormat(
      alignment: PdfTextAlignment.center,
      lineAlignment: PdfVerticalAlignment.middle,
    );

    final Size pageSize = page.getClientSize();

    final double centerX = pageSize.width / 2;
    final double centerY = pageSize.height / 2;

    final double watermarkWidth = pageSize.width * 0.72;
    final double watermarkHeight = _fontSize * 2.2;

    final double positionX = _getPositionX(pageSize.width, watermarkWidth);

    final double positionY = _getPositionY(pageSize.height, watermarkHeight);

    graphics.save();

    graphics.translateTransform(
      positionX + watermarkWidth / 2,
      positionY + watermarkHeight / 2,
    );

    graphics.rotateTransform(_rotation.toDouble());

    graphics.drawString(
      text,
      font,
      brush: brush,
      bounds: Rect.fromLTWH(
        -watermarkWidth / 2,
        -watermarkHeight / 2,
        watermarkWidth,
        watermarkHeight,
      ),
      format: format,
    );

    graphics.restore();

    if (centerX < 0 || centerY < 0) {
      debugPrint('Invalid page center.');
    }
  }

  // ============================================================
  // POSITION X
  // ============================================================

  double _getPositionX(double pageWidth, double watermarkWidth) {
    switch (_position) {
      case 'Top Left':
      case 'Bottom Left':
        return 25;

      case 'Top Center':
      case 'Center':
      case 'Bottom Center':
        return (pageWidth - watermarkWidth) / 2;

      case 'Top Right':
      case 'Bottom Right':
        return pageWidth - watermarkWidth - 25;
    }

    return (pageWidth - watermarkWidth) / 2;
  }

  // ============================================================
  // POSITION Y
  // ============================================================

  double _getPositionY(double pageHeight, double watermarkHeight) {
    switch (_position) {
      case 'Top Left':
      case 'Top Center':
      case 'Top Right':
        return 35;

      case 'Center':
        return (pageHeight - watermarkHeight) / 2;

      case 'Bottom Left':
      case 'Bottom Center':
      case 'Bottom Right':
        return pageHeight - watermarkHeight - 35;
    }

    return (pageHeight - watermarkHeight) / 2;
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
            const _WatermarkBackground(),

            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildFileCard()),
                SliverToBoxAdapter(child: _buildWatermarkInput()),
                SliverToBoxAdapter(child: _buildSettingsCard()),
                SliverToBoxAdapter(child: _buildPreviewInfo()),
                SliverToBoxAdapter(child: _buildSaveButton()),
                const SliverToBoxAdapter(child: SizedBox(height: 30)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
      child: Row(
        children: [
          _GlassIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Watermark PDF',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF10255C),
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Add a custom watermark to your PDF',
                  style: TextStyle(color: Color(0xFF7184A4), fontSize: 13),
                ),
              ],
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.50),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF5B6CFF).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.branding_watermark_outlined,
                    color: Color(0xFF5B6CFF),
                    size: 27,
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
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'All pages will be watermarked',
                        style: TextStyle(
                          color: Color(0xFF7A8CA6),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // WATERMARK INPUT
  // ============================================================

  Widget _buildWatermarkInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: _GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Watermark Text',
              style: TextStyle(
                color: Color(0xFF10255C),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _watermarkController,
              maxLines: 2,
              style: const TextStyle(color: Color(0xFF10255C), fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Enter watermark text',
                hintStyle: const TextStyle(
                  color: Color(0xFF9AA9BE),
                  fontSize: 12,
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.55),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: const BorderSide(
                    color: Color(0xFF5B6CFF),
                    width: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SETTINGS
  // ============================================================

  Widget _buildSettingsCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: _GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Watermark Settings',
              style: TextStyle(
                color: Color(0xFF10255C),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),

            const Text(
              'Font Size',
              style: TextStyle(
                color: Color(0xFF617594),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),

            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _fontSize,
                    min: 18,
                    max: 72,
                    divisions: 18,
                    activeColor: const Color(0xFF5B6CFF),
                    onChanged: (value) {
                      setState(() {
                        _fontSize = value;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 42,
                  child: Text(
                    '${_fontSize.round()}',
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: Color(0xFF10255C),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            const Text(
              'Opacity',
              style: TextStyle(
                color: Color(0xFF617594),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),

            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _opacity,
                    min: 0.05,
                    max: 1.0,
                    divisions: 19,
                    activeColor: const Color(0xFF5B6CFF),
                    onChanged: (value) {
                      setState(() {
                        _opacity = value;
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 42,
                  child: Text(
                    '${(_opacity * 100).round()}%',
                    textAlign: TextAlign.end,
                    style: const TextStyle(
                      color: Color(0xFF10255C),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            const Text(
              'Rotation',
              style: TextStyle(
                color: Color(0xFF617594),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _rotationChip(0),
                _rotationChip(45),
                _rotationChip(90),
                _rotationChip(-45),
              ],
            ),

            const SizedBox(height: 14),

            const Text(
              'Position',
              style: TextStyle(
                color: Color(0xFF617594),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              initialValue: _position,
              items: _positions
                  .map(
                    (position) => DropdownMenuItem<String>(
                      value: position,
                      child: Text(position),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _position = value;
                });
              },
              decoration: _dropdownDecoration('Select position'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ROTATION CHIP
  // ============================================================

  Widget _rotationChip(int value) {
    final bool selected = _rotation == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          _rotation = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF5B6CFF)
              : Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xFF5B6CFF)
                : Colors.white.withValues(alpha: 0.80),
          ),
        ),
        child: Text(
          '${value >= 0 ? '+' : ''}$value°',
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF385276),
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PREVIEW INFO
  // ============================================================

  Widget _buildPreviewInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF0FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFC9D6FF)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: Color(0xFF5B6CFF),
              size: 19,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'The watermark will be added to every page '
                'of the selected PDF.',
                style: const TextStyle(
                  color: Color(0xFF526A98),
                  fontSize: 11.5,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SAVE BUTTON
  // ============================================================

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: _isSaving ? null : _addWatermark,
          icon: _isSaving
              ? const SizedBox(
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.branding_watermark_rounded),
          label: Text(
            _isSaving ? 'Creating PDF...' : 'Add Watermark',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5B6CFF),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(
              0xFF5B6CFF,
            ).withValues(alpha: 0.55),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 0,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DROPDOWN DECORATION
  // ============================================================

  InputDecoration _dropdownDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9AA9BE), fontSize: 12),
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.55),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.82)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.82)),
      ),
    );
  }
}

// ============================================================
// GLASS CARD
// ============================================================

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.50),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ============================================================
// GLASS ICON BUTTON
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
              child: Icon(icon, size: 18, color: const Color(0xFF17345F)),
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

class _WatermarkBackground extends StatelessWidget {
  const _WatermarkBackground();

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
              color: const Color(0xFF7EB3FF).withValues(alpha: 0.27),
            ),
          ),
          Positioned(
            top: 350,
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
