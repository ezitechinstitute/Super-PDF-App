import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_super_app/core/services/api_service.dart';
import 'package:pdf_super_app/features/home/screens/pdf_preview_screen.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart';

class ReorderPagesScreen extends StatefulWidget {
  final PlatformFile selectedFile;

  const ReorderPagesScreen({super.key, required this.selectedFile});

  @override
  State<ReorderPagesScreen> createState() => _ReorderPagesScreenState();
}

class _ReorderPagesScreenState extends State<ReorderPagesScreen> {
  PdfDocument? _document;

  int _pageCount = 0;
  bool _isLoading = true;
  bool _isSaving = false;

  /// The page order the user has arranged, as zero-based indexes into the
  /// source document. Starts as 0, 1, 2, … and is what gets written out.
  List<int> _order = <int>[];

  /// Thumbnails keyed by source page index, so they survive reordering.
  final Map<int, Uint8List> _thumbnails = <int, Uint8List>{};

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

  bool get _orderChanged {
    for (int i = 0; i < _order.length; i++) {
      if (_order[i] != i) return true;
    }
    return false;
  }

  // ============================================================
  // LOAD PDF
  // ============================================================

  Future<void> _loadPdf() async {
    try {
      final String? path = widget.selectedFile.path;

      if (path == null || path.trim().isEmpty) {
        throw Exception('Selected PDF path is empty.');
      }

      final File file = File(path);

      if (!await file.exists()) {
        throw Exception('Selected PDF was not found.');
      }

      final Uint8List bytes = await file.readAsBytes();

      if (bytes.isEmpty) {
        throw Exception('PDF file is empty.');
      }

      final PdfDocument document = PdfDocument(inputBytes: bytes);

      final int pages = document.pages.count;

      if (pages <= 0) {
        document.dispose();
        throw Exception('PDF contains no pages.');
      }

      if (!mounted) {
        document.dispose();
        return;
      }

      setState(() {
        _document = document;
        _pageCount = pages;
        _order = List<int>.generate(pages, (index) => index);
        _isLoading = false;
      });

      debugPrint('==========================================');
      debugPrint('🔀 REORDER PAGES');
      debugPrint('📄 File: ${widget.selectedFile.name}');
      debugPrint('📑 Pages: $pages');
      debugPrint('==========================================');

      await _loadThumbnails(path);
    } catch (e) {
      debugPrint('❌ Reorder Pages load error: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('Unable to open this PDF.');
    }
  }

  /// Renders a small image of every page. Reordering is guesswork without
  /// them, so they are worth the wait — but a failure here is not fatal, the
  /// list falls back to numbered placeholders.
  Future<void> _loadThumbnails(String path) async {
    pdfx.PdfDocument? document;

    try {
      document = await pdfx.PdfDocument.openFile(path);

      for (int index = 1; index <= _pageCount; index++) {
        if (!mounted) return;

        pdfx.PdfPage? page;

        try {
          page = await document.getPage(index);

          final pdfx.PdfPageImage? image = await page.render(
            width: 150,
            height: 150 * page.height / page.width,
            format: pdfx.PdfPageImageFormat.jpeg,
            backgroundColor: '#FFFFFF',
            quality: 70,
          );

          final Uint8List? bytes = image?.bytes;

          if (bytes != null && mounted) {
            setState(() {
              _thumbnails[index - 1] = bytes;
            });
          }
        } finally {
          await page?.close();
        }
      }
    } catch (e) {
      debugPrint('⚠️ Thumbnail rendering failed: $e');
    } finally {
      await document?.close();
    }
  }

  // ============================================================
  // ORDER EDITING
  // ============================================================

  void _movePage(int oldIndex, int newIndex) {
    if (_isSaving) return;

    setState(() {
      final int page = _order.removeAt(oldIndex);
      _order.insert(newIndex, page);
    });
  }

  void _resetOrder() {
    if (_isSaving) return;

    setState(() {
      _order = List<int>.generate(_pageCount, (index) => index);
    });
  }

  void _reverseOrder() {
    if (_isSaving) return;

    setState(() {
      _order = _order.reversed.toList();
    });
  }

  // ============================================================
  // SAVE REORDERED PDF
  // ============================================================

  Future<void> _saveReorderedPdf() async {
    if (_document == null) {
      _showMessage('PDF is not ready yet.');
      return;
    }

    if (!_orderChanged) {
      _showMessage('Move at least one page first.');
      return;
    }

    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    PdfDocument? outputDocument;

    try {
      final PdfDocument sourceDocument = _document!;

      outputDocument = PdfDocument();

      for (final int sourceIndex in _order) {
        final PdfPage sourcePage = sourceDocument.pages[sourceIndex];

        final PdfTemplate template = sourcePage.createTemplate();

        final PdfSection section = outputDocument.sections!.add();

        section.pageSettings.size = template.size;

        section.pageSettings.margins.all = 0;

        final PdfPage targetPage = section.pages.add();

        final Size targetSize = targetPage.getClientSize();

        targetPage.graphics.drawPdfTemplate(template, Offset.zero, targetSize);
      }

      if (outputDocument.pages.count != _pageCount) {
        throw Exception('Reordered PDF lost pages.');
      }

      final List<int> outputBytes = await outputDocument.save();

      if (outputBytes.isEmpty) {
        throw Exception('Generated PDF is empty.');
      }

      final Directory directory = await getApplicationDocumentsDirectory();

      final String outputFileName =
          'Pages_Reordered_'
          '${DateTime.now().millisecondsSinceEpoch}.pdf';

      final String outputPath = '${directory.path}/$outputFileName';

      final File outputFile = File(outputPath);

      await outputFile.writeAsBytes(outputBytes, flush: true);

      final int outputFileSize = await outputFile.length();

      if (outputFileSize <= 0) {
        throw Exception('Generated PDF file is empty.');
      }

      debugPrint('==========================================');
      debugPrint('✅ REORDER PAGES COMPLETED');
      debugPrint('📄 Source: ${widget.selectedFile.name}');
      debugPrint('🔀 New order: ${_order.map((i) => i + 1).toList()}');
      debugPrint('📦 Output size: $outputFileSize bytes');
      debugPrint('📍 Output: $outputPath');
      debugPrint('==========================================');

      // ==========================================================
      // SAVE HISTORY TO LARAVEL API
      // ==========================================================

      try {
        final response = await ApiService.instance.createHistory(
          toolName: 'Reorder Pages',
          fileName: widget.selectedFile.name,
          outputFileName: outputFileName,
          status: 'completed',
          fileSize: outputFileSize,
          notes:
              'Reordered $_pageCount '
              'page${_pageCount == 1 ? '' : 's'}. '
              'New order: ${_order.map((i) => i + 1).join(', ')}.',
        );

        debugPrint('✅ Reorder Pages history API response: ${response.data}');
      } catch (historyError) {
        // The PDF is already written; a history failure must not surface
        // as a failed operation.
        debugPrint(
          '⚠️ Pages reordered successfully, '
          'but history could not be saved: $historyError',
        );
      }

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showMessage('Pages reordered.');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PdfPreviewScreen(fileName: outputFileName, filePath: outputPath),
        ),
      );
    } catch (e) {
      debugPrint('==========================================');
      debugPrint('❌ REORDER PAGES FAILED');
      debugPrint('❌ Error: $e');
      debugPrint('==========================================');

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showMessage('Unable to reorder the pages.');
    } finally {
      outputDocument?.dispose();
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
            const _ReorderBackground(),
            Column(
              children: [
                _buildHeader(),
                _buildFileInfo(),
                _buildControls(),
                Expanded(
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _pageCount == 0
                      ? _buildEmptyState()
                      : _buildPageList(),
                ),
                _buildSaveButton(),
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
            onTap: _isSaving ? () {} : () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reorder Pages',
                  style: TextStyle(
                    color: Color(0xFF10255C),
                    fontSize: 23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  'Drag a page to move it',
                  style: TextStyle(color: Color(0xFF7A8CA6), fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
      child: Container(
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
                color: const Color(0xFF1769FF).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.swap_vert_rounded,
                color: Color(0xFF1769FF),
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
                    _isLoading
                        ? 'Reading pages...'
                        : '$_pageCount page${_pageCount == 1 ? '' : 's'}'
                              '${_orderChanged ? '  •  order changed' : ''}',
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
      ),
    );
  }

  Widget _buildControls() {
    if (_isLoading || _pageCount < 2) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: Row(
        children: [
          Expanded(
            child: _SmallActionButton(
              icon: Icons.swap_vert_rounded,
              label: 'Reverse',
              onTap: _isSaving ? () {} : _reverseOrder,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SmallActionButton(
              icon: Icons.restart_alt_rounded,
              label: 'Reset',
              onTap: _isSaving || !_orderChanged ? () {} : _resetOrder,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      itemCount: _order.length,
      onReorderItem: _movePage,
      proxyDecorator: (child, index, animation) {
        return Material(
          color: Colors.transparent,
          elevation: 8,
          borderRadius: BorderRadius.circular(16),
          child: child,
        );
      },
      itemBuilder: (context, position) {
        final int sourceIndex = _order[position];

        return _ReorderPageTile(
          key: ValueKey<int>(sourceIndex),
          position: position,
          sourcePageNumber: sourceIndex + 1,
          thumbnail: _thumbnails[sourceIndex],
          moved: _order[position] != position,
        );
      },
    );
  }

  Widget _buildSaveButton() {
    final bool enabled = !_isSaving && _orderChanged;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
      child: SizedBox(
        height: 56,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? _saveReorderedPdf : null,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: enabled
                      ? const [Color(0xFF2D7BFF), Color(0xFF0958EA)]
                      : const [Color(0xFFBFD3F0), Color(0xFFAEC6EA)],
                ),
              ),
              child: Center(
                child: _isSaving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.save_rounded, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            'Save New Order',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text(
        'This PDF has no pages to reorder.',
        style: TextStyle(color: Color(0xFF7A8CA6), fontSize: 13),
      ),
    );
  }
}

// ============================================================
// PAGE TILE
// ============================================================

class _ReorderPageTile extends StatelessWidget {
  final int position;
  final int sourcePageNumber;
  final Uint8List? thumbnail;
  final bool moved;

  const _ReorderPageTile({
    super.key,
    required this.position,
    required this.sourcePageNumber,
    required this.thumbnail,
    required this.moved,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: moved
                ? const Color(0xFF1769FF).withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.85),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 34,
              child: Text(
                '${position + 1}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF10255C),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 52,
                height: 68,
                color: const Color(0xFFEFF4FC),
                child: thumbnail != null
                    ? Image.memory(thumbnail!, fit: BoxFit.cover)
                    : const Icon(
                        Icons.description_outlined,
                        color: Color(0xFFB9C9E2),
                        size: 22,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Page $sourcePageNumber',
                    style: const TextStyle(
                      color: Color(0xFF10255C),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    moved ? 'Moved from position $sourcePageNumber' : 'In place',
                    style: TextStyle(
                      color: moved
                          ? const Color(0xFF1769FF)
                          : const Color(0xFF7A8CA6),
                      fontSize: 11,
                      fontWeight: moved ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            ReorderableDragStartListener(
              index: position,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6),
                child: Icon(
                  Icons.drag_handle_rounded,
                  color: Color(0xFF7A8CA6),
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
// SMALL ACTION BUTTON
// ============================================================

class _SmallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SmallActionButton({
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
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.85)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: const Color(0xFF1769FF)),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xFF10255C),
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

class _ReorderBackground extends StatelessWidget {
  const _ReorderBackground();

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
