import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_super_app/core/services/api_service.dart';
import 'package:pdf_super_app/features/home/screens/pdf_preview_screen.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class MergePdfScreen extends StatefulWidget {
  final List<PlatformFile> selectedFiles;

  const MergePdfScreen({super.key, this.selectedFiles = const []});

  @override
  State<MergePdfScreen> createState() => _MergePdfScreenState();
}

class _MergePdfScreenState extends State<MergePdfScreen> {
  late List<_PdfFile> _files;

  bool _isMerging = false;
  bool _isLoadingInfo = false;

  @override
  void initState() {
    super.initState();

    _files = widget.selectedFiles.map((file) {
      return _PdfFile(name: file.name, path: file.path);
    }).toList();

    if (_files.isNotEmpty) {
      _loadPdfInformation();
    }
  }

  // ============================================================
  // LOAD PDF INFORMATION
  // ============================================================

  Future<void> _loadPdfInformation() async {
    if (_files.isEmpty) return;

    if (mounted) {
      setState(() {
        _isLoadingInfo = true;
      });
    }

    for (int i = 0; i < _files.length; i++) {
      final file = _files[i];

      final String? filePath = file.path;

      if (filePath == null || filePath.isEmpty) {
        continue;
      }

      try {
        final sourceFile = File(filePath);

        if (!await sourceFile.exists()) {
          continue;
        }

        final Uint8List bytes = await sourceFile.readAsBytes();

        final PdfDocument document = PdfDocument(inputBytes: bytes);

        final int pageCount = document.pages.count;
        final int fileSize = await sourceFile.length();

        document.dispose();

        if (!mounted) return;

        setState(() {
          _files[i] = file.copyWith(
            size: _formatFileSize(fileSize),
            pages: '$pageCount ${pageCount == 1 ? 'page' : 'pages'}',
          );
        });
      } catch (e) {
        debugPrint(
          '❌ Could not read PDF information '
          'for ${file.name}: $e',
        );

        if (!mounted) return;

        setState(() {
          _files[i] = file.copyWith(size: 'PDF', pages: 'Unable to read');
        });
      }
    }

    if (!mounted) return;

    setState(() {
      _isLoadingInfo = false;
    });
  }

  // ============================================================
  // FORMAT FILE SIZE
  // ============================================================

  String _formatFileSize(int bytes) {
    if (bytes <= 0) {
      return '0 KB';
    }

    final double kb = bytes / 1024;

    if (kb < 1024) {
      return '${kb.toStringAsFixed(0)} KB';
    }

    final double mb = kb / 1024;

    if (mb < 1024) {
      return '${mb.toStringAsFixed(1)} MB';
    }

    final double gb = mb / 1024;

    return '${gb.toStringAsFixed(2)} GB';
  }

  // ============================================================
  // REMOVE FILE
  // ============================================================

  void _removeFile(int index) {
    if (_isMerging) return;

    setState(() {
      _files.removeAt(index);
    });
  }

  // ============================================================
  // ADD MORE FILES
  // ============================================================

  Future<void> _addMoreFiles() async {
    if (_isMerging) return;

    try {
      final List<PlatformFile> files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
      );

      if (files.isEmpty) {
        return;
      }

      final List<_PdfFile> newFiles = files.map((file) {
        return _PdfFile(name: file.name, path: file.path);
      }).toList();

      if (!mounted) return;

      setState(() {
        _files.addAll(newFiles);
      });

      await _loadPdfInformation();
    } catch (e) {
      debugPrint('❌ Add PDF error: $e');

      if (!mounted) return;

      _showMessage('Unable to add PDF files.');
    }
  }

  // ============================================================
  // REAL PDF MERGE
  // ============================================================

  Future<void> _mergeFiles() async {
    if (_files.length < 2) {
      _showMessage('Please add at least 2 PDF files.');
      return;
    }

    final List<_PdfFile> validFiles = _files.where((file) {
      return file.path != null && file.path!.trim().isNotEmpty;
    }).toList();

    if (validFiles.length < 2) {
      _showMessage('Selected PDF files could not be accessed.');
      return;
    }

    if (!mounted) return;

    setState(() {
      _isMerging = true;
    });

    PdfDocument? mergedDocument;

    try {
      debugPrint('==========================================');
      debugPrint('📄 REAL PDF MERGE STARTED');
      debugPrint('📚 Files: ${validFiles.length}');
      debugPrint('==========================================');

      // ==========================================================
      // CREATE MERGED PDF
      // ==========================================================

      mergedDocument = PdfDocument();

      for (final pdfFile in validFiles) {
        final String? filePath = pdfFile.path;

        if (filePath == null || filePath.trim().isEmpty) {
          continue;
        }

        final File sourceFile = File(filePath);

        if (!await sourceFile.exists()) {
          throw Exception('File not found: ${pdfFile.name}');
        }

        final Uint8List sourceBytes = await sourceFile.readAsBytes();

        final PdfDocument sourceDocument = PdfDocument(inputBytes: sourceBytes);

        try {
          for (
            int pageIndex = 0;
            pageIndex < sourceDocument.pages.count;
            pageIndex++
          ) {
            final PdfPage sourcePage = sourceDocument.pages[pageIndex];

            final PdfTemplate template = sourcePage.createTemplate();

            final PdfSection section = mergedDocument.sections!.add();

            section.pageSettings.size = template.size;
            section.pageSettings.margins.all = 0;

            final PdfPage targetPage = section.pages.add();

            final Size targetSize = targetPage.getClientSize();

            targetPage.graphics.drawPdfTemplate(
              template,
              Offset.zero,
              targetSize,
            );
          }
        } finally {
          sourceDocument.dispose();
        }
      }

      if (mergedDocument.pages.count == 0) {
        throw Exception('No PDF pages were available to merge.');
      }

      // ==========================================================
      // SAVE MERGED PDF
      // ==========================================================

      final List<int> outputBytes = await mergedDocument.save();

      final Directory directory = await getApplicationDocumentsDirectory();

      final String outputFileName =
          'Merged_Document_'
          '${DateTime.now().millisecondsSinceEpoch}.pdf';

      final String outputPath = '${directory.path}/$outputFileName';

      final File outputFile = File(outputPath);

      await outputFile.writeAsBytes(outputBytes, flush: true);

      final int outputFileSize = await outputFile.length();

      debugPrint('==========================================');
      debugPrint('✅ PDF MERGE COMPLETED');
      debugPrint('📄 Pages: ${mergedDocument.pages.count}');
      debugPrint('📍 Output: $outputPath');
      debugPrint('📦 Size: $outputFileSize bytes');
      debugPrint('==========================================');

      // ==========================================================
      // DISPOSE PDF DOCUMENT
      // ==========================================================

      mergedDocument.dispose();
      mergedDocument = null;

      // ==========================================================
      // SAVE HISTORY TO LARAVEL
      // ==========================================================

      try {
        final response = await ApiService.instance.createHistory(
          toolName: 'Merge PDF',
          fileName: validFiles.map((file) => file.name).join(', '),
          outputFileName: outputFileName,
          status: 'completed',
          fileSize: outputFileSize,
          notes: 'Merged ${validFiles.length} PDF files.',
        );

        debugPrint(
          '✅ Merge history API response: '
          '${response.data}',
        );
      } catch (historyError) {
        debugPrint(
          '⚠️ PDF merged successfully, but history '
          'could not be saved: $historyError',
        );
      }

      if (!mounted) return;

      setState(() {
        _isMerging = false;
      });

      // ==========================================================
      // OPEN MERGED PDF PREVIEW
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
      debugPrint('❌ PDF MERGE FAILED');
      debugPrint('❌ Error: $e');
      debugPrint('==========================================');

      mergedDocument?.dispose();

      if (!mounted) return;

      setState(() {
        _isMerging = false;
      });

      _showMessage('Unable to merge the selected PDF files.');
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
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
            const _MergeBackground(),

            Column(
              children: [
                _buildTopBar(),
                _buildInfoHeader(),
                Expanded(child: _buildFileList()),
                _buildBottomSection(),
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
            onTap: _isMerging ? () {} : () => Navigator.pop(context),
          ),

          const SizedBox(width: 12),

          const Expanded(
            child: Text(
              'Merge PDF',
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
                'Arrange the files in the order you want them merged.',
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFO HEADER
  // ============================================================

  Widget _buildInfoHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: double.infinity,
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
                    color: const Color(0xFF1769FF).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.layers_outlined,
                    color: Color(0xFF1769FF),
                    size: 28,
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Files to Merge',
                        style: TextStyle(
                          color: Color(0xFF10255C),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _isLoadingInfo
                            ? 'Reading PDF information...'
                            : '${_files.length} PDF files selected',
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
                    color: const Color(0xFFE7F0FF),
                    borderRadius: BorderRadius.circular(12),
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
          ),
        ),
      ),
    );
  }

  // ============================================================
  // FILE LIST
  // ============================================================

  Widget _buildFileList() {
    if (_files.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
                child: const Icon(
                  Icons.picture_as_pdf_outlined,
                  color: Color(0xFF1769FF),
                  size: 35,
                ),
              ),

              const SizedBox(height: 14),

              const Text(
                'No PDF files selected',
                style: TextStyle(
                  color: Color(0xFF10255C),
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 6),

              const Text(
                'Add at least two PDF files to merge them.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF74859F), fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 20),
      physics: const BouncingScrollPhysics(),
      itemCount: _files.length,
      onReorderItem: (oldIndex, newIndex) {
        if (_isMerging) return;

        setState(() {
          final item = _files.removeAt(oldIndex);
          _files.insert(newIndex, item);
        });
      },
      itemBuilder: (context, index) {
        final file = _files[index];

        return _PdfFileCard(
          key: ValueKey('${file.id}_${file.path ?? index}'),
          file: file,
          index: index + 1,
          onDelete: _isMerging ? () {} : () => _removeFile(index),
        );
      },
    );
  }

  // ============================================================
  // BOTTOM SECTION
  // ============================================================

  Widget _buildBottomSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.82)),
        ),
      ),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isMerging ? null : _addMoreFiles,
                borderRadius: BorderRadius.circular(17),
                child: Ink(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.48),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(
                      color: const Color(0xFF9FC2F3),
                      width: 1.1,
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        color: Color(0xFF1769FF),
                        size: 21,
                      ),
                      SizedBox(width: 7),
                      Text(
                        'Add More Files',
                        style: TextStyle(
                          color: Color(0xFF1769FF),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            height: 58,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _isMerging ? null : _mergeFiles,
                borderRadius: BorderRadius.circular(18),
                child: Ink(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: _isMerging
                        ? const LinearGradient(
                            colors: [Color(0xFF7FA6E8), Color(0xFF6688D0)],
                          )
                        : const LinearGradient(
                            colors: [Color(0xFF2D7BFF), Color(0xFF0958EA)],
                          ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1769FF).withValues(alpha: 0.25),
                        blurRadius: 20,
                        offset: const Offset(0, 9),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_isMerging) ...[
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 9),
                        const Text(
                          'Merging PDFs...',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ] else ...[
                        const Icon(
                          Icons.merge_type_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 9),
                        const Text(
                          'Merge PDF',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
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
// PDF FILE CARD
// ============================================================

class _PdfFileCard extends StatelessWidget {
  final _PdfFile file;
  final int index;
  final VoidCallback onDelete;

  const _PdfFileCard({
    super.key,
    required this.file,
    required this.index,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6D91C8).withValues(alpha: 0.08),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEEEE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Color(0xFFF45151),
                    size: 27,
                  ),
                ),

                const SizedBox(width: 11),

                Container(
                  width: 25,
                  height: 25,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F0FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      color: Color(0xFF1769FF),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),

                const SizedBox(width: 9),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF10255C),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 4),

                      Text(
                        '${file.size}  •  ${file.pages}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF7A8BA4),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),

                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: Color(0xFFE25563),
                    size: 21,
                  ),
                ),

                const Icon(
                  Icons.drag_indicator_rounded,
                  color: Color(0xFF8293AA),
                  size: 22,
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

class _MergeBackground extends StatelessWidget {
  const _MergeBackground();

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

// ============================================================
// PDF FILE MODEL
// ============================================================

class _PdfFile {
  final String name;
  final String? path;
  final String size;
  final String pages;
  final String id;

  const _PdfFile({
    required this.name,
    required this.path,
    this.size = 'Reading...',
    this.pages = 'Reading...',
  }) : id = name;

  _PdfFile copyWith({String? name, String? path, String? size, String? pages}) {
    return _PdfFile(
      name: name ?? this.name,
      path: path ?? this.path,
      size: size ?? this.size,
      pages: pages ?? this.pages,
    );
  }
}
