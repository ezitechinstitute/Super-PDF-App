import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_super_app/core/services/api_service.dart';
import 'package:pdf_super_app/features/home/screens/pdf_preview_screen.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class AddPageNumbersScreen extends StatefulWidget {
  final PlatformFile selectedFile;

  const AddPageNumbersScreen({super.key, required this.selectedFile});

  @override
  State<AddPageNumbersScreen> createState() => _AddPageNumbersScreenState();
}

class _AddPageNumbersScreenState extends State<AddPageNumbersScreen> {
  bool _isSaving = false;

  int _fontSize = 12;
  int _startingNumber = 1;

  String _position = 'Bottom Center';
  String _format = '1, 2, 3';

  final List<String> _positions = const [
    'Top Left',
    'Top Center',
    'Top Right',
    'Bottom Left',
    'Bottom Center',
    'Bottom Right',
  ];

  final List<String> _formats = const [
    '1, 2, 3',
    'Page 1, Page 2',
    '1 / Total',
    'Page 1 / Total',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      body: SafeArea(
        child: Stack(
          children: [
            const _PageNumbersBackground(),
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildFileCard()),
                SliverToBoxAdapter(child: _buildSettingsCard()),
                SliverToBoxAdapter(child: _buildInfoCard()),
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
                  'Add Page Numbers',
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
                  'Add automatic numbers to your PDF',
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
                    color: const Color(0xFF6C63FF).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.format_list_numbered_rounded,
                    color: Color(0xFF6C63FF),
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
                        'Page numbers will be added to all pages',
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
  // SETTINGS CARD
  // ============================================================

  Widget _buildSettingsCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: _GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Page Number Settings',
              style: TextStyle(
                color: Color(0xFF10255C),
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 15),

            // --------------------------------------------------
            // FORMAT
            // --------------------------------------------------
            const Text(
              'Format',
              style: TextStyle(
                color: Color(0xFF617594),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),

            DropdownButtonFormField<String>(
              initialValue: _format,
              items: _formats
                  .map(
                    (format) => DropdownMenuItem<String>(
                      value: format,
                      child: Text(format),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _format = value;
                });
              },
              decoration: _dropdownDecoration('Select format'),
            ),

            const SizedBox(height: 15),

            // --------------------------------------------------
            // POSITION
            // --------------------------------------------------
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

            const SizedBox(height: 15),

            // --------------------------------------------------
            // FONT SIZE
            // --------------------------------------------------
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
                    value: _fontSize.toDouble(),
                    min: 8,
                    max: 24,
                    divisions: 16,
                    activeColor: const Color(0xFF6C63FF),
                    onChanged: (value) {
                      setState(() {
                        _fontSize = value.round();
                      });
                    },
                  ),
                ),
                SizedBox(
                  width: 45,
                  child: Text(
                    '$_fontSize',
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

            // --------------------------------------------------
            // STARTING NUMBER
            // --------------------------------------------------
            const Text(
              'Starting Number',
              style: TextStyle(
                color: Color(0xFF617594),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                _numberButton(
                  icon: Icons.remove_rounded,
                  onTap: () {
                    if (_startingNumber <= 1) return;

                    setState(() {
                      _startingNumber--;
                    });
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                    child: Text(
                      '$_startingNumber',
                      style: const TextStyle(
                        color: Color(0xFF10255C),
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _numberButton(
                  icon: Icons.add_rounded,
                  onTap: () {
                    setState(() {
                      _startingNumber++;
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // NUMBER BUTTON
  // ============================================================

  Widget _numberButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(0xFF6C63FF).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: const Color(0xFF6C63FF).withValues(alpha: 0.18),
          ),
        ),
        child: Icon(icon, color: const Color(0xFF6C63FF), size: 20),
      ),
    );
  }

  // ============================================================
  // INFO CARD
  // ============================================================

  Widget _buildInfoCard() {
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
              color: Color(0xFF6C63FF),
              size: 19,
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                'Page numbers will be placed on every page '
                'without removing existing PDF content.',
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
          onPressed: _isSaving ? null : _addPageNumbers,
          icon: _isSaving
              ? const SizedBox(
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.format_list_numbered_rounded),
          label: Text(
            _isSaving ? 'Creating PDF...' : 'Add Page Numbers',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF6C63FF),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(
              0xFF6C63FF,
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
  // ADD PAGE NUMBERS
  // ============================================================

  Future<void> _addPageNumbers() async {
    final String? path = widget.selectedFile.path;

    if (path == null || path.isEmpty) {
      _showMessage('Unable to access the selected PDF file.');
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

      final int totalPages = document.pages.count;

      for (int index = 0; index < totalPages; index++) {
        final PdfPage page = document.pages[index];

        final int pageNumber = _startingNumber + index;

        final String pageText = _buildPageText(pageNumber, totalPages);

        _drawPageNumber(page, pageText);
      }

      final List<int> outputBytes = await document.save();

      final Directory directory = await getApplicationDocumentsDirectory();

      final String outputFileName =
          'Numbered_PDF_'
          '${DateTime.now().millisecondsSinceEpoch}.pdf';

      final String outputPath = '${directory.path}/$outputFileName';

      final File outputFile = File(outputPath);

      await outputFile.writeAsBytes(outputBytes, flush: true);

      if (!await outputFile.exists()) {
        throw Exception('Numbered PDF was not created.');
      }

      final int outputFileSize = await outputFile.length();

      // ============================================================
      // SAVE HISTORY
      // Only metadata is sent to Laravel.
      // Actual PDF remains stored locally on the phone.
      // ============================================================

      try {
        final response = await ApiService.instance.createHistory(
          toolName: 'Add Page Numbers',
          fileName: widget.selectedFile.name,
          outputFileName: outputFileName,
          status: 'completed',
          fileSize: outputFileSize,
          notes:
              'Page numbers added to $totalPages page(s). '
              'Format: $_format, '
              'Position: $_position, '
              'Font size: $_fontSize, '
              'Starting number: $_startingNumber.',
        );

        debugPrint(
          '✅ Add Page Numbers history API response: '
          '${response.data}',
        );
      } catch (historyError) {
        debugPrint(
          '⚠️ Add Page Numbers completed, but history '
          'could not be saved: $historyError',
        );
      }

      if (!mounted) return;

      _showMessage('Page numbers added successfully.');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PdfPreviewScreen(fileName: outputFileName, filePath: outputPath),
        ),
      );
    } catch (e) {
      debugPrint('❌ Add Page Numbers error: $e');

      if (mounted) {
        _showMessage('Unable to add page numbers to the PDF.');
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
  // PAGE TEXT
  // ============================================================

  String _buildPageText(int pageNumber, int totalPages) {
    switch (_format) {
      case 'Page 1, Page 2':
        return 'Page $pageNumber';

      case '1 / Total':
        return '$pageNumber / $totalPages';

      case 'Page 1 / Total':
        return 'Page $pageNumber / $totalPages';

      case '1, 2, 3':
      default:
        return '$pageNumber';
    }
  }

  // ============================================================
  // DRAW PAGE NUMBER
  // ============================================================

  void _drawPageNumber(PdfPage page, String text) {
    final PdfGraphics graphics = page.graphics;

    final PdfFont font = PdfStandardFont(
      PdfFontFamily.helvetica,
      _fontSize.toDouble(),
    );

    final PdfBrush brush = PdfSolidBrush(PdfColor(70, 85, 110));

    final Size pageSize = page.getClientSize();

    const double horizontalMargin = 24;
    const double verticalMargin = 20;

    const double textWidth = 130;

    final double textHeight = _fontSize + 10;

    final double x = _getTextX(pageSize.width, textWidth, horizontalMargin);

    final double y = _getTextY(pageSize.height, textHeight, verticalMargin);

    final PdfStringFormat format = PdfStringFormat(
      alignment: PdfTextAlignment.center,
      lineAlignment: PdfVerticalAlignment.middle,
    );

    graphics.drawString(
      text,
      font,
      brush: brush,
      bounds: Rect.fromLTWH(x, y, textWidth, textHeight),
      format: format,
    );
  }

  // ============================================================
  // TEXT X POSITION
  // ============================================================

  double _getTextX(double pageWidth, double textWidth, double margin) {
    switch (_position) {
      case 'Top Left':
      case 'Bottom Left':
        return margin;

      case 'Top Center':
      case 'Bottom Center':
        return (pageWidth - textWidth) / 2;

      case 'Top Right':
      case 'Bottom Right':
        return pageWidth - textWidth - margin;
    }

    return (pageWidth - textWidth) / 2;
  }

  // ============================================================
  // TEXT Y POSITION
  // ============================================================

  double _getTextY(double pageHeight, double textHeight, double margin) {
    switch (_position) {
      case 'Top Left':
      case 'Top Center':
      case 'Top Right':
        return margin;

      case 'Bottom Left':
      case 'Bottom Center':
      case 'Bottom Right':
        return pageHeight - textHeight - margin;
    }

    return pageHeight - textHeight - margin;
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

class _PageNumbersBackground extends StatelessWidget {
  const _PageNumbersBackground();

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
            top: 360,
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
