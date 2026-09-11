import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_super_app/core/services/api_service.dart';
import 'package:pdfx/pdfx.dart';

class PdfToSvgScreen extends StatefulWidget {
  final PlatformFile selectedFile;

  const PdfToSvgScreen({super.key, required this.selectedFile});

  @override
  State<PdfToSvgScreen> createState() => _PdfToSvgScreenState();
}

class _PdfToSvgScreenState extends State<PdfToSvgScreen> {
  PdfDocument? _document;

  int _pageCount = 0;
  bool _isLoading = true;
  bool _isConverting = false;

  final Set<int> _selectedPages = <int>{};

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  @override
  void dispose() {
    _document?.close();
    super.dispose();
  }

  // ============================================================
  // LOAD PDF
  // ============================================================

  Future<void> _loadPdf() async {
    final String? path = widget.selectedFile.path;

    if (path == null || path.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      _showMessage('Unable to access the selected PDF file.');
      return;
    }

    try {
      final File file = File(path);

      if (!await file.exists()) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }

        _showMessage('Selected PDF file was not found.');
        return;
      }

      final PdfDocument document = await PdfDocument.openFile(path);

      if (!mounted) {
        await document.close();
        return;
      }

      setState(() {
        _document = document;
        _pageCount = document.pagesCount;
        _isLoading = false;
      });

      debugPrint('==========================================');
      debugPrint('🖼️ PDF TO SVG');
      debugPrint('📄 File: ${widget.selectedFile.name}');
      debugPrint('📑 Pages: $_pageCount');
      debugPrint('==========================================');
    } catch (e) {
      debugPrint('❌ PDF to SVG load error: $e');

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      _showMessage('Unable to open this PDF.');
    }
  }

  // ============================================================
  // PAGE SELECTION
  // ============================================================

  void _togglePage(int pageIndex) {
    if (_isConverting) return;

    setState(() {
      if (_selectedPages.contains(pageIndex)) {
        _selectedPages.remove(pageIndex);
      } else {
        _selectedPages.add(pageIndex);
      }
    });
  }

  void _selectAllPages() {
    if (_isConverting) return;

    setState(() {
      _selectedPages
        ..clear()
        ..addAll(List<int>.generate(_pageCount, (index) => index));
    });
  }

  void _clearSelection() {
    if (_isConverting) return;

    setState(() {
      _selectedPages.clear();
    });
  }

  // ============================================================
  // SVG GENERATION
  // ============================================================

  String _buildSvgFromPng({
    required List<int> pngBytes,
    required double width,
    required double height,
  }) {
    final String base64Image = base64Encode(pngBytes);

    final String widthValue = width.toStringAsFixed(2);

    final String heightValue = height.toStringAsFixed(2);

    return '''
<svg
  xmlns="http://www.w3.org/2000/svg"
  xmlns:xlink="http://www.w3.org/1999/xlink"
  width="$widthValue"
  height="$heightValue"
  viewBox="0 0 $widthValue $heightValue">

  <rect
    width="100%"
    height="100%"
    fill="white"/>

  <image
    x="0"
    y="0"
    width="$widthValue"
    height="$heightValue"
    preserveAspectRatio="none"
    href="data:image/png;base64,$base64Image"
    xlink:href="data:image/png;base64,$base64Image"/>
</svg>
''';
  }

  // ============================================================
  // TOTAL OUTPUT SIZE
  // ============================================================

  Future<int> _calculateTotalOutputSize(List<String> generatedFiles) async {
    int totalSize = 0;

    for (final String path in generatedFiles) {
      try {
        final File file = File(path);

        if (await file.exists()) {
          totalSize += await file.length();
        }
      } catch (e) {
        debugPrint('⚠️ Unable to calculate SVG size for $path: $e');
      }
    }

    return totalSize;
  }

  // ============================================================
  // CONVERT PDF TO SVG
  // ============================================================

  Future<void> _convertToSvg() async {
    final PdfDocument? document = _document;

    if (document == null) {
      _showMessage('PDF is not ready yet.');
      return;
    }

    if (_selectedPages.isEmpty) {
      _showMessage('Please select at least one page.');
      return;
    }

    if (_isConverting) return;

    setState(() {
      _isConverting = true;
    });

    final List<int> pagesToConvert = _selectedPages.toList()..sort();

    final List<String> generatedFiles = <String>[];

    try {
      final Directory directory = await getApplicationDocumentsDirectory();

      final String folderPath =
          '${directory.path}/PDF_to_SVG_'
          '${DateTime.now().millisecondsSinceEpoch}';

      final Directory outputDirectory = Directory(folderPath);

      await outputDirectory.create(recursive: true);

      for (final int pageIndex in pagesToConvert) {
        PdfPage? page;

        try {
          page = await document.getPage(pageIndex + 1);

          final PdfPageImage? pageImage = await page.render(
            width: page.width * 2,
            height: page.height * 2,
            format: PdfPageImageFormat.png,
          );

          if (pageImage == null) {
            throw Exception('Unable to render page ${pageIndex + 1}.');
          }

          final String svgContent = _buildSvgFromPng(
            pngBytes: pageImage.bytes,
            width: page.width,
            height: page.height,
          );

          final String outputPath =
              '${outputDirectory.path}/'
              'Page_${pageIndex + 1}.svg';

          final File outputFile = File(outputPath);

          await outputFile.writeAsString(svgContent, flush: true);

          final int outputSize = await outputFile.length();

          if (outputSize <= 0) {
            throw Exception(
              'Generated SVG is empty for page ${pageIndex + 1}.',
            );
          }

          generatedFiles.add(outputPath);

          debugPrint(
            '✅ SVG created: Page ${pageIndex + 1} '
            '($outputSize bytes)',
          );
        } finally {
          await page?.close();
        }
      }

      if (!mounted) return;

      if (generatedFiles.isEmpty) {
        _showMessage('No SVG files were generated.');
        return;
      }

      // ========================================================
      // CALCULATE OUTPUT SIZE
      // ========================================================

      final int totalOutputSize = await _calculateTotalOutputSize(
        generatedFiles,
      );

      // ========================================================
      // SAVE HISTORY METADATA
      // ========================================================

      try {
        final String outputFileName = generatedFiles.length == 1
            ? generatedFiles.first.split(Platform.pathSeparator).last
            : '${generatedFiles.length}_SVG_files';

        final response = await ApiService.instance.createHistory(
          toolName: 'PDF to SVG',
          fileName: widget.selectedFile.name,
          outputFileName: outputFileName,
          status: 'completed',
          fileSize: totalOutputSize,
          notes:
              'Converted ${generatedFiles.length} selected PDF page'
              '${generatedFiles.length == 1 ? '' : 's'} to SVG.',
        );

        debugPrint(
          '✅ PDF to SVG history API response: '
          '${response.data}',
        );
      } catch (historyError) {
        debugPrint(
          '⚠️ PDF to SVG completed, but history '
          'could not be saved: $historyError',
        );
      }

      // The history call above is awaited, so this screen may have been
      // popped while that request was in flight.
      if (!mounted) {
        return;
      }

      // ========================================================
      // SINGLE SVG
      // ========================================================

      if (generatedFiles.length == 1) {
        final String outputPath = generatedFiles.first;

        final String fileName = outputPath.split(Platform.pathSeparator).last;

        setState(() {
          _isConverting = false;
        });

        _showMessage('SVG generated successfully.');

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                _SvgPreviewScreen(fileName: fileName, filePath: outputPath),
          ),
        );

        return;
      }

      // ========================================================
      // MULTIPLE SVGs
      // ========================================================

      setState(() {
        _isConverting = false;
      });

      _showMessage(
        '${generatedFiles.length} SVG files generated successfully.',
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _SvgFilesScreen(filePaths: generatedFiles),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ PDF to SVG conversion error: $e');

      debugPrint('StackTrace: $stackTrace');

      if (!mounted) return;

      setState(() {
        _isConverting = false;
      });

      _showMessage('Unable to convert PDF pages to SVG.');
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
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      body: SafeArea(
        child: Stack(
          children: [
            const _PdfToSvgBackground(),

            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                if (_isLoading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF1769FF),
                      ),
                    ),
                  )
                else if (_pageCount == 0)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(),
                  )
                else ...[
                  SliverToBoxAdapter(child: _buildFileInfo()),
                  SliverToBoxAdapter(child: _buildSelectionControls()),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
                    sliver: _buildPageGrid(),
                  ),
                  SliverToBoxAdapter(child: _buildConvertButton()),
                  const SliverToBoxAdapter(child: SizedBox(height: 28)),
                ],
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
            onTap: _isConverting ? () {} : () => Navigator.pop(context),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PDF to SVG',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF10255C),
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Convert PDF pages into SVG files',
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
  // FILE INFO
  // ============================================================

  Widget _buildFileInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00A8A8).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.polyline_outlined,
                    color: Color(0xFF00A8A8),
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
                        '$_pageCount page'
                        '${_pageCount == 1 ? '' : 's'}  •  '
                        '${_selectedPages.length} selected',
                        style: const TextStyle(
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
  // SELECTION CONTROLS
  // ============================================================

  Widget _buildSelectionControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 12),
      child: Row(
        children: [
          Expanded(
            child: _SmallActionButton(
              icon: Icons.select_all_rounded,
              title: 'Select All',
              onTap: _selectAllPages,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SmallActionButton(
              icon: Icons.clear_rounded,
              title: 'Clear',
              onTap: _clearSelection,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PAGE GRID
  // ============================================================

  SliverGrid _buildPageGrid() {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate((context, index) {
        final bool selected = _selectedPages.contains(index);

        return _PageCard(
          pageNumber: index + 1,
          selected: selected,
          onTap: () => _togglePage(index),
        );
      }, childCount: _pageCount),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.83,
      ),
    );
  }

  // ============================================================
  // CONVERT BUTTON
  // ============================================================

  Widget _buildConvertButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: _isConverting ? null : _convertToSvg,
          icon: _isConverting
              ? const SizedBox(
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.polyline_outlined),
          label: Text(
            _isConverting
                ? 'Converting to SVG...'
                : _selectedPages.isEmpty
                ? 'Select Pages'
                : 'Convert ${_selectedPages.length} '
                      'Page${_selectedPages.length == 1 ? '' : 's'} '
                      'to SVG',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00A8A8),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(
              0xFF00A8A8,
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
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.52),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.80)),
              ),
              child: const Icon(
                Icons.polyline_outlined,
                color: Color(0xFF00A8A8),
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to load PDF',
              style: TextStyle(
                color: Color(0xFF10255C),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Please select another PDF file.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF74859F), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// PAGE CARD
// ============================================================

class _PageCard extends StatelessWidget {
  final int pageNumber;
  final bool selected;
  final VoidCallback onTap;

  const _PageCard({
    required this.pageNumber,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFFE4F8F8)
                  : Colors.white.withValues(alpha: 0.50),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? const Color(0xFF00A8A8)
                    : Colors.white.withValues(alpha: 0.82),
                width: selected ? 1.5 : 1.0,
              ),
            ),
            child: Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 68,
                        height: 84,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF6D91C8,
                              ).withValues(alpha: 0.10),
                              blurRadius: 12,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              top: 12,
                              left: 10,
                              right: 10,
                              child: _placeholderLine(),
                            ),
                            Positioned(
                              top: 25,
                              left: 10,
                              right: 18,
                              child: _placeholderLine(),
                            ),
                            Positioned(
                              top: 38,
                              left: 10,
                              right: 13,
                              child: _placeholderLine(),
                            ),
                            Positioned(
                              top: 51,
                              left: 10,
                              right: 20,
                              child: _placeholderLine(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 11),
                      Text(
                        'Page $pageNumber',
                        style: const TextStyle(
                          color: Color(0xFF10255C),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selected ? 'Selected for SVG' : 'Tap to select',
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFF00A8A8)
                              : const Color(0xFF7A8CA6),
                          fontSize: 10.5,
                          fontWeight: selected
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF00A8A8)
                          : Colors.white.withValues(alpha: 0.80),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF00A8A8)
                            : const Color(0xFFD3DDEC),
                      ),
                    ),
                    child: Icon(
                      selected ? Icons.check_rounded : Icons.add_rounded,
                      color: selected ? Colors.white : const Color(0xFF6D809D),
                      size: 17,
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

  Widget _placeholderLine() {
    return Container(
      height: 5,
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEF8),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

// ============================================================
// SMALL ACTION BUTTON
// ============================================================

class _SmallActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _SmallActionButton({
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
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.50),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: const Color(0xFF00A8A8)),
              const SizedBox(width: 7),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF17345F),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
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

// ============================================================
// SVG PREVIEW
// ============================================================

class _SvgPreviewScreen extends StatelessWidget {
  final String fileName;
  final String filePath;

  const _SvgPreviewScreen({required this.fileName, required this.filePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          fileName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Color(0xFF10255C),
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF17345F)),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            const _PdfToSvgBackground(),

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
              child: Column(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.72),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(
                              0xFF8FB8FF,
                            ).withValues(alpha: 0.60),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF6D91C8,
                              ).withValues(alpha: 0.08),
                              blurRadius: 18,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                color: Colors.white,
                                alignment: Alignment.center,
                                child: SvgPicture.file(
                                  File(filePath),
                                  fit: BoxFit.contain,
                                  width: constraints.maxWidth,
                                  height: constraints.maxHeight,
                                  placeholderBuilder: (context) => const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF1769FF),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.50),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Color(0xFF00A8A8),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            fileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF17345F),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// MULTIPLE SVG FILES
// ============================================================

class _SvgFilesScreen extends StatelessWidget {
  final List<String> filePaths;

  const _SvgFilesScreen({required this.filePaths});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '${filePaths.length} SVG Files',
          style: const TextStyle(
            color: Color(0xFF10255C),
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF17345F)),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            const _PdfToSvgBackground(),
            ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
              itemCount: filePaths.length,
              itemBuilder: (context, index) {
                final String path = filePaths[index];

                final String name = path.split(Platform.pathSeparator).last;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _SvgResultCard(
                    pageNumber: index + 1,
                    fileName: name,
                    filePath: path,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SVG RESULT CARD
// ============================================================

class _SvgResultCard extends StatelessWidget {
  final int pageNumber;
  final String fileName;
  final String filePath;

  const _SvgResultCard({
    required this.pageNumber,
    required this.fileName,
    required this.filePath,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                _SvgPreviewScreen(fileName: fileName, filePath: filePath),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.50),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
            ),
            child: Row(
              children: [
                Container(
                  width: 76,
                  height: 88,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE3EAF6)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: SvgPicture.file(
                      File(filePath),
                      fit: BoxFit.contain,
                      placeholderBuilder: (context) => const Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF1769FF),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF10255C),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'Page $pageNumber',
                        style: const TextStyle(
                          color: Color(0xFF7A8CA6),
                          fontSize: 10.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Tap to preview',
                        style: TextStyle(
                          color: Color(0xFF00A8A8),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Color(0xFF7A8CA6),
                ),
              ],
            ),
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

class _PdfToSvgBackground extends StatelessWidget {
  const _PdfToSvgBackground();

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
            top: 330,
            left: -120,
            child: _BlurCircle(
              size: 250,
              color: const Color(0xFF4C8EFF).withValues(alpha: 0.12),
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
