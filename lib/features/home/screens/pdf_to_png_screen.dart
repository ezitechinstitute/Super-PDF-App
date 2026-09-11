import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_super_app/core/services/api_service.dart';
import 'package:pdfx/pdfx.dart';

class PdfToPngScreen extends StatefulWidget {
  final PlatformFile selectedFile;

  const PdfToPngScreen({super.key, required this.selectedFile});

  @override
  State<PdfToPngScreen> createState() => _PdfToPngScreenState();
}

class _PdfToPngScreenState extends State<PdfToPngScreen> {
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
      debugPrint('🖼️ PDF TO PNG');
      debugPrint('📄 File: ${widget.selectedFile.name}');
      debugPrint('📑 Pages: $_pageCount');
      debugPrint('==========================================');
    } catch (e) {
      debugPrint('❌ PDF to PNG load error: $e');

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
        debugPrint('⚠️ Unable to calculate PNG size for $path: $e');
      }
    }

    return totalSize;
  }

  // ============================================================
  // CONVERT PDF TO PNG
  // ============================================================

  Future<void> _convertToPng() async {
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
          '${directory.path}/PDF_to_PNG_'
          '${DateTime.now().millisecondsSinceEpoch}';

      final Directory outputDirectory = Directory(folderPath);

      await outputDirectory.create(recursive: true);

      for (final int pageIndex in pagesToConvert) {
        PdfPage? page;

        try {
          // pdfx page numbers start from 1.
          page = await document.getPage(pageIndex + 1);

          final PdfPageImage? pageImage = await page.render(
            width: page.width * 2,
            height: page.height * 2,
            format: PdfPageImageFormat.png,
          );

          if (pageImage == null) {
            throw Exception('Unable to render page ${pageIndex + 1}.');
          }

          final String outputPath =
              '${outputDirectory.path}/'
              'Page_${pageIndex + 1}.png';

          final File outputFile = File(outputPath);

          await outputFile.writeAsBytes(pageImage.bytes, flush: true);

          final int outputSize = await outputFile.length();

          if (outputSize <= 0) {
            throw Exception(
              'Generated PNG is empty for page ${pageIndex + 1}.',
            );
          }

          generatedFiles.add(outputPath);

          debugPrint(
            '✅ PNG created: Page ${pageIndex + 1} '
            '($outputSize bytes)',
          );
        } finally {
          await page?.close();
        }
      }

      if (!mounted) return;

      if (generatedFiles.isEmpty) {
        _showMessage('No PNG images were generated.');
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
            : '${generatedFiles.length}_PNG_images';

        final response = await ApiService.instance.createHistory(
          toolName: 'PDF to PNG',
          fileName: widget.selectedFile.name,
          outputFileName: outputFileName,
          status: 'completed',
          fileSize: totalOutputSize,
          notes:
              'Converted ${generatedFiles.length} selected PDF page'
              '${generatedFiles.length == 1 ? '' : 's'} to PNG.',
        );

        debugPrint(
          '✅ PDF to PNG history API response: '
          '${response.data}',
        );
      } catch (historyError) {
        debugPrint(
          '⚠️ PDF to PNG completed, but history '
          'could not be saved: $historyError',
        );
      }

      // ========================================================
      // SINGLE PNG
      // ========================================================

      if (generatedFiles.length == 1) {
        final String outputPath = generatedFiles.first;

        final String fileName = outputPath.split(Platform.pathSeparator).last;

        setState(() {
          _isConverting = false;
        });

        _showMessage('PNG generated successfully.');

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                _PngPreviewScreen(fileName: fileName, filePath: outputPath),
          ),
        );

        return;
      }

      // ========================================================
      // MULTIPLE PNGs
      // ========================================================

      setState(() {
        _isConverting = false;
      });

      _showMessage(
        '${generatedFiles.length} PNG images generated successfully.',
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _PngFilesScreen(filePaths: generatedFiles),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ PDF to PNG conversion error: $e');
      debugPrint('StackTrace: $stackTrace');

      if (!mounted) return;

      setState(() {
        _isConverting = false;
      });

      _showMessage('Unable to convert PDF pages to PNG.');
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
            const _PdfToPngBackground(),

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
                  'PDF to PNG',
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
                  'Convert PDF pages into PNG images',
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
                    color: const Color(0xFF7A5AF8).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.image_search_outlined,
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
          onPressed: _isConverting ? null : _convertToPng,
          icon: _isConverting
              ? const SizedBox(
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.image_outlined),
          label: Text(
            _isConverting
                ? 'Converting to PNG...'
                : _selectedPages.isEmpty
                ? 'Select Pages'
                : 'Convert ${_selectedPages.length} '
                      'Page${_selectedPages.length == 1 ? '' : 's'} to PNG',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7A5AF8),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(
              0xFF7A5AF8,
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
                Icons.image_outlined,
                color: Color(0xFF7A5AF8),
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
                  ? const Color(0xFFF0ECFF)
                  : Colors.white.withValues(alpha: 0.50),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? const Color(0xFF7A5AF8)
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
                              child: Container(
                                height: 5,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8EEF8),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 25,
                              left: 10,
                              right: 18,
                              child: Container(
                                height: 5,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8EEF8),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 38,
                              left: 10,
                              right: 13,
                              child: Container(
                                height: 5,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8EEF8),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 51,
                              left: 10,
                              right: 20,
                              child: Container(
                                height: 5,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE8EEF8),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
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
                        selected ? 'Selected for PNG' : 'Tap to select',
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFF7A5AF8)
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
                          ? const Color(0xFF7A5AF8)
                          : Colors.white.withValues(alpha: 0.80),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF7A5AF8)
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
              Icon(icon, size: 18, color: const Color(0xFF7A5AF8)),
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
// PNG PREVIEW
// ============================================================

class _PngPreviewScreen extends StatelessWidget {
  final String fileName;
  final String filePath;

  const _PngPreviewScreen({required this.fileName, required this.filePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'PNG Preview',
          style: TextStyle(
            color: Color(0xFF10255C),
            fontWeight: FontWeight.w800,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF17345F)),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            const _PdfToPngBackground(),
            Center(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    child: InteractiveViewer(
                      minScale: 0.5,
                      maxScale: 4.0,
                      child: Image.file(
                        File(filePath),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Text(
                              'Unable to preview image.',
                              style: TextStyle(color: Color(0xFF74859F)),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// MULTIPLE PNG FILES
// ============================================================

class _PngFilesScreen extends StatelessWidget {
  final List<String> filePaths;

  const _PngFilesScreen({required this.filePaths});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '${filePaths.length} PNG Files',
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
            const _PdfToPngBackground(),
            ListView.builder(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 30),
              itemCount: filePaths.length,
              itemBuilder: (context, index) {
                final String path = filePaths[index];

                final String name = path.split(Platform.pathSeparator).last;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _PngResultCard(
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
// PNG RESULT CARD
// ============================================================

class _PngResultCard extends StatelessWidget {
  final int pageNumber;
  final String fileName;
  final String filePath;

  const _PngResultCard({
    required this.pageNumber,
    required this.fileName,
    required this.filePath,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                _PngPreviewScreen(fileName: fileName, filePath: filePath),
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
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF7A5AF8).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.image_outlined,
                    color: Color(0xFF7A5AF8),
                    size: 27,
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
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF7184A4),
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

class _PdfToPngBackground extends StatelessWidget {
  const _PdfToPngBackground();

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
