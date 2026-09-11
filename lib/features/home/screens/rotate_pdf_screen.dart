import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_super_app/core/services/api_service.dart';
import 'package:pdf_super_app/features/home/screens/pdf_preview_screen.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class RotatePdfScreen extends StatefulWidget {
  final PlatformFile selectedFile;

  const RotatePdfScreen({super.key, required this.selectedFile});

  @override
  State<RotatePdfScreen> createState() => _RotatePdfScreenState();
}

class _RotatePdfScreenState extends State<RotatePdfScreen> {
  PdfDocument? _document;

  int _pageCount = 0;
  bool _isLoading = true;
  bool _isRotating = false;

  final Set<int> _selectedPages = <int>{};

  int _rotationIndex = 0;

  final List<_RotationOption> _rotationOptions = const <_RotationOption>[
    _RotationOption(
      title: '90° Clockwise',
      subtitle: 'Rotate right',
      icon: Icons.rotate_right_rounded,
      angle: PdfPageRotateAngle.rotateAngle90,
    ),
    _RotationOption(
      title: '180°',
      subtitle: 'Turn upside down',
      icon: Icons.sync_alt_rounded,
      angle: PdfPageRotateAngle.rotateAngle180,
    ),
    _RotationOption(
      title: '90° Counterclockwise',
      subtitle: 'Rotate left',
      icon: Icons.rotate_left_rounded,
      angle: PdfPageRotateAngle.rotateAngle270,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  @override
  void dispose() {
    _document?.dispose();
    super.dispose();
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

      _showMessage('Unable to access the selected PDF file.');
      return;
    }

    try {
      final File file = File(path);

      if (!await file.exists()) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        _showMessage('Selected PDF file was not found.');
        return;
      }

      final List<int> bytes = await file.readAsBytes();

      final PdfDocument document = PdfDocument(inputBytes: bytes);

      if (!mounted) {
        document.dispose();
        return;
      }

      setState(() {
        _document = document;
        _pageCount = document.pages.count;
        _isLoading = false;
      });

      debugPrint('==========================================');
      debugPrint('📄 ROTATE PDF');
      debugPrint('📄 File: ${widget.selectedFile.name}');
      debugPrint('📑 Pages: $_pageCount');
      debugPrint('==========================================');
    } catch (e) {
      debugPrint('❌ Rotate PDF load error: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('Unable to open this PDF.');
    }
  }

  // ============================================================
  // PAGE SELECTION
  // ============================================================

  void _togglePage(int pageIndex) {
    if (_isRotating) return;

    setState(() {
      if (_selectedPages.contains(pageIndex)) {
        _selectedPages.remove(pageIndex);
      } else {
        _selectedPages.add(pageIndex);
      }
    });
  }

  void _selectAllPages() {
    if (_isRotating || _pageCount == 0) {
      return;
    }

    setState(() {
      _selectedPages
        ..clear()
        ..addAll(List<int>.generate(_pageCount, (index) => index));
    });
  }

  void _clearSelection() {
    if (_isRotating) return;

    setState(() {
      _selectedPages.clear();
    });
  }

  // ============================================================
  // ROTATION OPTION
  // ============================================================

  void _selectRotation(int index) {
    if (_isRotating) return;

    setState(() {
      _rotationIndex = index;
    });
  }

  // ============================================================
  // ROTATE PDF
  // ============================================================

  Future<void> _rotatePdf() async {
    if (_document == null) {
      _showMessage('PDF is not ready yet.');
      return;
    }

    if (_selectedPages.isEmpty) {
      _showMessage('Please select at least one page to rotate.');
      return;
    }

    if (_isRotating) return;

    if (!mounted) return;

    setState(() {
      _isRotating = true;
    });

    PdfDocument? outputDocument;

    try {
      final PdfDocument sourceDocument = _document!;

      outputDocument = PdfDocument();

      final PdfPageRotateAngle selectedAngle =
          _rotationOptions[_rotationIndex].angle;

      // Create a new PDF while keeping the
      // original page order.
      //
      // Selected pages receive the requested
      // rotation. Other pages remain at 0°.
      for (int pageIndex = 0; pageIndex < _pageCount; pageIndex++) {
        final PdfPage sourcePage = sourceDocument.pages[pageIndex];

        final PdfTemplate template = sourcePage.createTemplate();

        final PdfSection section = outputDocument.sections!.add();

        section.pageSettings.size = template.size;

        section.pageSettings.margins.all = 0;

        section.pageSettings.rotate = _selectedPages.contains(pageIndex)
            ? selectedAngle
            : PdfPageRotateAngle.rotateAngle0;

        final PdfPage targetPage = section.pages.add();

        final Size targetSize = targetPage.getClientSize();

        targetPage.graphics.drawPdfTemplate(template, Offset.zero, targetSize);
      }

      if (outputDocument.pages.count == 0) {
        throw Exception('No pages were generated.');
      }

      final List<int> outputBytes = await outputDocument.save();

      if (outputBytes.isEmpty) {
        throw Exception('Rotated PDF is empty.');
      }

      // ==========================================================
      // SAVE LOCAL FILE
      // ==========================================================

      final Directory directory = await getApplicationDocumentsDirectory();

      final String outputFileName =
          'Rotated_Document_'
          '${DateTime.now().millisecondsSinceEpoch}.pdf';

      final String outputPath = '${directory.path}/$outputFileName';

      final File outputFile = File(outputPath);

      await outputFile.writeAsBytes(outputBytes, flush: true);

      final int outputFileSize = await outputFile.length();

      if (outputFileSize <= 0) {
        throw Exception('Rotated PDF file is empty.');
      }

      debugPrint('==========================================');
      debugPrint('✅ ROTATE PDF COMPLETED');
      debugPrint('📄 Source: ${widget.selectedFile.name}');
      debugPrint('📑 Total pages: $_pageCount');
      debugPrint('🔄 Rotated pages: ${_selectedPages.length}');
      debugPrint(
        '🔄 Angle: '
        '${_rotationOptions[_rotationIndex].title}',
      );
      debugPrint('📦 Output size: $outputFileSize bytes');
      debugPrint('📍 Output: $outputPath');
      debugPrint('==========================================');

      // ==========================================================
      // SAVE HISTORY METADATA
      // ==========================================================

      try {
        final response = await ApiService.instance.createHistory(
          toolName: 'Rotate PDF',
          fileName: widget.selectedFile.name,
          outputFileName: outputFileName,
          status: 'completed',
          fileSize: outputFileSize,
          notes:
              'Rotated ${_selectedPages.length} '
              'page${_selectedPages.length == 1 ? '' : 's'} '
              'by ${_rotationOptions[_rotationIndex].title}.',
        );

        debugPrint(
          '✅ Rotate PDF history API response: '
          '${response.data}',
        );
      } catch (historyError) {
        // The actual PDF operation succeeded.
        // History failure should not break the tool.
        debugPrint(
          '⚠️ PDF rotated successfully, '
          'but history could not be saved: '
          '$historyError',
        );
      }

      if (!mounted) return;

      setState(() {
        _isRotating = false;
      });

      // ==========================================================
      // OPEN PREVIEW
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
      debugPrint('❌ ROTATE PDF FAILED');
      debugPrint('❌ Error: $e');
      debugPrint('==========================================');

      outputDocument?.dispose();

      if (!mounted) return;

      setState(() {
        _isRotating = false;
      });

      _showMessage('Unable to rotate the selected pages.');
    } finally {
      // Only dispose if it is still active.
      if (outputDocument != null) {
        try {
          outputDocument.dispose();
        } catch (e) {
          debugPrint('⚠️ Output document dispose error: $e');
        }
      }
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
            const _RotatePdfBackground(),

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
                  SliverToBoxAdapter(child: _buildRotationOptions()),
                  SliverToBoxAdapter(child: _buildSelectionControls()),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
                    sliver: _buildPageGrid(),
                  ),
                  SliverToBoxAdapter(child: _buildRotateButton()),
                  const SliverToBoxAdapter(child: SizedBox(height: 25)),
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
            onTap: _isRotating ? () {} : () => Navigator.pop(context),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rotate PDF',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF10255C),
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _pageCount == 0
                      ? 'Choose pages to rotate'
                      : 'Select pages and rotation angle',
                  style: const TextStyle(
                    color: Color(0xFF7184A4),
                    fontSize: 13,
                  ),
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
                    color: const Color(0xFF1769FF).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.rotate_right_rounded,
                    color: Color(0xFF1769FF),
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
  // ROTATION OPTIONS
  // ============================================================

  Widget _buildRotationOptions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rotation Angle',
            style: TextStyle(
              color: Color(0xFF10255C),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Choose how the selected pages should rotate.',
            style: TextStyle(color: Color(0xFF7A8CA6), fontSize: 11.5),
          ),
          const SizedBox(height: 12),
          ...List.generate(_rotationOptions.length, (index) {
            final _RotationOption option = _rotationOptions[index];

            return Padding(
              padding: EdgeInsets.only(
                bottom: index == _rotationOptions.length - 1 ? 0 : 9,
              ),
              child: _RotationOptionCard(
                option: option,
                selected: _rotationIndex == index,
                onTap: _isRotating ? () {} : () => _selectRotation(index),
              ),
            );
          }),
        ],
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
              onTap: _isRotating ? () {} : _selectAllPages,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SmallActionButton(
              icon: Icons.clear_rounded,
              title: 'Clear',
              onTap: _isRotating ? () {} : _clearSelection,
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
          onTap: _isRotating ? () {} : () => _togglePage(index),
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
  // ROTATE BUTTON
  // ============================================================

  Widget _buildRotateButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: _isRotating ? null : _rotatePdf,
          icon: _isRotating
              ? const SizedBox(
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.rotate_right_rounded),
          label: Text(
            _isRotating
                ? 'Rotating PDF...'
                : _selectedPages.isEmpty
                ? 'Select Pages to Rotate'
                : 'Rotate '
                      '${_selectedPages.length} '
                      'Page'
                      '${_selectedPages.length == 1 ? '' : 's'}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1769FF),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(
              0xFF1769FF,
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
                Icons.picture_as_pdf_rounded,
                color: Color(0xFF1769FF),
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
// ROTATION OPTION MODEL
// ============================================================

class _RotationOption {
  final String title;
  final String subtitle;
  final IconData icon;
  final PdfPageRotateAngle angle;

  const _RotationOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.angle,
  });
}

// ============================================================
// ROTATION OPTION CARD
// ============================================================

class _RotationOptionCard extends StatelessWidget {
  final _RotationOption option;
  final bool selected;
  final VoidCallback onTap;

  const _RotationOptionCard({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFE7F0FF)
              : Colors.white.withValues(alpha: 0.48),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? const Color(0xFF1769FF)
                : Colors.white.withValues(alpha: 0.82),
            width: selected ? 1.4 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF1769FF).withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.50),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                option.icon,
                color: const Color(0xFF1769FF),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: const TextStyle(
                      color: Color(0xFF10255C),
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    option.subtitle,
                    style: const TextStyle(
                      color: Color(0xFF7A8CA6),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? const Color(0xFF1769FF) : Colors.transparent,
                border: Border.all(
                  color: selected
                      ? const Color(0xFF1769FF)
                      : const Color(0xFFB9C7DB),
                ),
              ),
              child: selected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 15,
                    )
                  : null,
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
                  ? const Color(0xFFE7F0FF)
                  : Colors.white.withValues(alpha: 0.50),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected
                    ? const Color(0xFF1769FF)
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
                        selected ? 'Selected to rotate' : 'Tap to select',
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFF1769FF)
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
                          ? const Color(0xFF1769FF)
                          : Colors.white.withValues(alpha: 0.80),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected
                            ? const Color(0xFF1769FF)
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
              Icon(icon, size: 18, color: const Color(0xFF1769FF)),
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

class _RotatePdfBackground extends StatelessWidget {
  const _RotatePdfBackground();

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
