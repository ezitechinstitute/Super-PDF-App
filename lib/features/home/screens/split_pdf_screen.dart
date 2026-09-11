import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_super_app/core/services/api_service.dart';
import 'package:pdf_super_app/features/home/screens/pdf_preview_screen.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class SplitPdfScreen extends StatefulWidget {
  final PlatformFile selectedFile;

  const SplitPdfScreen({super.key, required this.selectedFile});

  @override
  State<SplitPdfScreen> createState() => _SplitPdfScreenState();
}

class _SplitPdfScreenState extends State<SplitPdfScreen> {
  bool _isLoading = true;
  bool _isSplitting = false;

  int _pageCount = 0;

  final Set<int> _selectedPages = <int>{};

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  // ============================================================
  // LOAD PDF
  // ============================================================

  Future<void> _loadPdf() async {
    final String? path = widget.selectedFile.path;

    if (path == null || path.isEmpty) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('Unable to access the selected PDF.');
      return;
    }

    try {
      final File file = File(path);

      if (!await file.exists()) {
        throw Exception('PDF file not found.');
      }

      final Uint8List bytes = await file.readAsBytes();

      final PdfDocument document = PdfDocument(inputBytes: bytes);

      final int count = document.pages.count;

      document.dispose();

      if (!mounted) return;

      setState(() {
        _pageCount = count;
        _isLoading = false;
      });

      debugPrint('==========================================');
      debugPrint('📄 SPLIT PDF');
      debugPrint('📄 File: ${widget.selectedFile.name}');
      debugPrint('📑 Pages: $count');
      debugPrint('==========================================');
    } catch (e) {
      debugPrint('❌ Split PDF load error: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('Unable to read this PDF.');
    }
  }

  // ============================================================
  // PAGE SELECTION
  // ============================================================

  void _togglePage(int index) {
    if (_isSplitting) return;

    setState(() {
      if (_selectedPages.contains(index)) {
        _selectedPages.remove(index);
      } else {
        _selectedPages.add(index);
      }
    });
  }

  void _selectAll() {
    if (_isSplitting || _pageCount == 0) return;

    setState(() {
      _selectedPages
        ..clear()
        ..addAll(List<int>.generate(_pageCount, (index) => index));
    });
  }

  void _clearSelection() {
    if (_isSplitting) return;

    setState(() {
      _selectedPages.clear();
    });
  }

  // ============================================================
  // REAL SPLIT PDF
  // ============================================================

  Future<void> _splitPdf() async {
    if (_selectedPages.isEmpty) {
      _showMessage('Please select at least one page.');
      return;
    }

    final String? path = widget.selectedFile.path;

    if (path == null || path.isEmpty) {
      _showMessage('Selected PDF could not be accessed.');
      return;
    }

    if (!mounted) return;

    setState(() {
      _isSplitting = true;
    });

    PdfDocument? outputDocument;
    PdfDocument? sourceDocument;

    try {
      final File sourceFile = File(path);

      if (!await sourceFile.exists()) {
        throw Exception('PDF file not found.');
      }

      final Uint8List sourceBytes = await sourceFile.readAsBytes();

      sourceDocument = PdfDocument(inputBytes: sourceBytes);

      outputDocument = PdfDocument();

      final List<int> orderedPages = _selectedPages.toList()..sort();

      debugPrint('==========================================');
      debugPrint('✂️ SPLIT PDF STARTED');
      debugPrint('📄 Source: ${widget.selectedFile.name}');
      debugPrint('📑 Selected pages: ${orderedPages.length}');
      debugPrint('==========================================');

      for (final int pageIndex in orderedPages) {
        if (pageIndex < 0 || pageIndex >= sourceDocument.pages.count) {
          continue;
        }

        final PdfPage sourcePage = sourceDocument.pages[pageIndex];

        final PdfTemplate template = sourcePage.createTemplate();

        final Size sourceSize = sourcePage.getClientSize();

        final PdfSection section = outputDocument.sections!.add();

        section.pageSettings.size = sourceSize;
        section.pageSettings.margins.all = 0;

        final PdfPage targetPage = section.pages.add();

        final Size targetSize = targetPage.getClientSize();

        targetPage.graphics.drawPdfTemplate(template, Offset.zero, targetSize);
      }

      if (outputDocument.pages.count == 0) {
        throw Exception('No valid pages were selected.');
      }

      final List<int> outputBytes = await outputDocument.save();

      final Directory directory = await getApplicationDocumentsDirectory();

      final String outputFileName =
          'Split_Document_'
          '${DateTime.now().millisecondsSinceEpoch}.pdf';

      final String outputPath = '${directory.path}/$outputFileName';

      final File outputFile = File(outputPath);

      await outputFile.writeAsBytes(outputBytes, flush: true);

      final int generatedPageCount = outputDocument.pages.count;

      final int outputFileSize = await outputFile.length();

      sourceDocument.dispose();
      sourceDocument = null;

      outputDocument.dispose();
      outputDocument = null;

      debugPrint('==========================================');
      debugPrint('✅ SPLIT PDF COMPLETED');
      debugPrint('📑 Output pages: $generatedPageCount');
      debugPrint('📦 Output size: $outputFileSize bytes');
      debugPrint('📍 Output: $outputPath');
      debugPrint('==========================================');

      // ==========================================================
      // SAVE HISTORY TO LARAVEL API
      // ==========================================================

      try {
        final response = await ApiService.instance.createHistory(
          toolName: 'Split PDF',
          fileName: widget.selectedFile.name,
          outputFileName: outputFileName,
          status: 'completed',
          fileSize: outputFileSize,
          notes:
              'Extracted $generatedPageCount '
              '${generatedPageCount == 1 ? 'page' : 'pages'} '
              'from ${widget.selectedFile.name}.',
        );

        debugPrint(
          '✅ Split history API response: '
          '${response.data}',
        );
      } catch (historyError) {
        // PDF operation stays successful even if
        // history API temporarily fails.
        debugPrint(
          '⚠️ Split PDF completed, but history '
          'could not be saved: $historyError',
        );
      }

      if (!mounted) return;

      setState(() {
        _isSplitting = false;
      });

      // ==========================================================
      // OPEN REAL SPLIT PDF IN PREVIEW
      // ==========================================================

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PdfPreviewScreen(fileName: outputFileName, filePath: outputPath),
        ),
      );
    } catch (e) {
      debugPrint('==========================================');
      debugPrint('❌ SPLIT PDF FAILED');
      debugPrint('❌ Error: $e');
      debugPrint('==========================================');

      sourceDocument?.dispose();
      outputDocument?.dispose();

      if (!mounted) return;

      setState(() {
        _isSplitting = false;
      });

      _showMessage('Unable to split this PDF. Please try again.');
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
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
      backgroundColor: const Color(0xFFF4F8FF),
      body: SafeArea(
        child: Stack(
          children: [
            const _SplitBackground(),

            Column(
              children: [
                _buildHeader(),
                _buildInfoCard(),
                Expanded(child: _buildPages()),
                _buildBottomSection(),
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
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
      child: Row(
        children: [
          _GlassIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: _isSplitting ? () {} : () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Split PDF',
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
              _showMessage('Select the pages you want in the new PDF.');
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFO CARD
  // ============================================================

  Widget _buildInfoCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.46),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7A5AF8).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.content_cut_rounded,
                    color: Color(0xFF7A5AF8),
                    size: 28,
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
                      const SizedBox(height: 5),
                      Text(
                        _isLoading
                            ? 'Reading PDF...'
                            : '$_pageCount pages  •  '
                                  '${_selectedPages.length} selected',
                        style: const TextStyle(
                          color: Color(0xFF7588A5),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFEAFF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'PDF',
                    style: TextStyle(
                      color: Color(0xFF7A5AF8),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
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
  // PAGE GRID
  // ============================================================

  Widget _buildPages() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1769FF)),
      );
    }

    if (_pageCount == 0) {
      return const Center(
        child: Text(
          'No pages found.',
          style: TextStyle(color: Color(0xFF7184A4), fontSize: 13),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 20),
      physics: const BouncingScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.76,
      ),
      itemCount: _pageCount,
      itemBuilder: (context, index) {
        final bool selected = _selectedPages.contains(index);

        return GestureDetector(
          onTap: _isSplitting ? null : () => _togglePage(index),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFE8F1FF)
                      : Colors.white.withValues(alpha: 0.50),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: selected
                        ? const Color(0xFF1769FF)
                        : Colors.white.withValues(alpha: 0.82),
                    width: selected ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            const Center(
                              child: Icon(
                                Icons.description_outlined,
                                color: Color(0xFF9AAAC2),
                                size: 52,
                              ),
                            ),
                            Positioned(
                              top: 8,
                              left: 9,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: selected
                                      ? const Color(0xFF1769FF)
                                      : const Color(0xFFF0F4FA),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Text(
                                  'Page ${index + 1}',
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : const Color(0xFF5D718E),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            if (selected)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  width: 25,
                                  height: 25,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFF1769FF),
                                  ),
                                  child: const Icon(
                                    Icons.check_rounded,
                                    color: Colors.white,
                                    size: 17,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Page ${index + 1}',
                            style: const TextStyle(
                              color: Color(0xFF10255C),
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        Icon(
                          selected
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked,
                          color: selected
                              ? const Color(0xFF1769FF)
                              : const Color(0xFF9AAAC2),
                          size: 19,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // BOTTOM SECTION
  // ============================================================

  Widget _buildBottomSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.82)),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSplitting ? null : _selectAll,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1769FF),
                    side: const BorderSide(color: Color(0xFF9FC2F3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text(
                    'Select All',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSplitting ? null : _clearSelection,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF7184A4),
                    side: const BorderSide(color: Color(0xFFD3DEEE)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: const Text(
                    'Clear',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isSplitting ? null : _splitPdf,
                borderRadius: BorderRadius.circular(18),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: _isSplitting
                        ? const LinearGradient(
                            colors: [Color(0xFF8AA6DD), Color(0xFF718DCA)],
                          )
                        : const LinearGradient(
                            colors: [Color(0xFF2D7BFF), Color(0xFF0958EA)],
                          ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isSplitting) ...[
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.3,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 9),
                        const Text(
                          'Splitting PDF...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ] else ...[
                        const Icon(
                          Icons.content_cut_rounded,
                          color: Colors.white,
                          size: 21,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _selectedPages.isEmpty
                              ? 'Select Pages'
                              : 'Split '
                                    '${_selectedPages.length} '
                                    '${_selectedPages.length == 1 ? 'Page' : 'Pages'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ],
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
          color: Colors.white.withValues(alpha: 0.40),
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
              child: Icon(icon, size: 19, color: const Color(0xFF17345F)),
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

class _SplitBackground extends StatelessWidget {
  const _SplitBackground();

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
              color: const Color(0xFF7EB3FF).withValues(alpha: 0.26),
            ),
          ),
          Positioned(
            top: 330,
            left: -120,
            child: _BlurCircle(
              size: 250,
              color: const Color(0xFF4C8EFF).withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            bottom: -90,
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
