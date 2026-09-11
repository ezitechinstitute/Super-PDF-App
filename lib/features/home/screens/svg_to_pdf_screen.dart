import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_super_app/core/services/api_service.dart';
import 'package:pdf_super_app/features/home/screens/pdf_preview_screen.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class SvgToPdfScreen extends StatefulWidget {
  final List<PlatformFile> selectedFiles;

  const SvgToPdfScreen({super.key, required this.selectedFiles});

  @override
  State<SvgToPdfScreen> createState() => _SvgToPdfScreenState();
}

class _SvgToPdfScreenState extends State<SvgToPdfScreen> {
  late List<PlatformFile> _selectedFiles;

  bool _isConverting = false;

  @override
  void initState() {
    super.initState();
    _selectedFiles = List<PlatformFile>.from(widget.selectedFiles);
  }

  // ============================================================
  // ADD MORE SVG FILES
  // ============================================================

  Future<void> _addMoreFiles() async {
    if (_isConverting) return;

    try {
      final List<PlatformFile> files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['svg'],
      );

      if (files.isEmpty) return;

      final Set<String> existingKeys = _selectedFiles
          .map(_fileKey)
          .where((key) => key.isNotEmpty)
          .toSet();

      final List<PlatformFile> newFiles = <PlatformFile>[];

      for (final PlatformFile file in files) {
        final String key = _fileKey(file);

        final bool isSvg = _isSvgFile(file);

        if (!isSvg) {
          continue;
        }

        if (key.isNotEmpty && existingKeys.contains(key)) {
          continue;
        }

        if (key.isNotEmpty) {
          existingKeys.add(key);
        }

        newFiles.add(file);
      }

      if (newFiles.isEmpty) {
        _showMessage('No new SVG files were selected.');
        return;
      }

      if (!mounted) return;

      setState(() {
        _selectedFiles.addAll(newFiles);
      });
    } catch (e) {
      debugPrint('❌ Add SVG files error: $e');

      if (mounted) {
        _showMessage('Unable to select SVG files.');
      }
    }
  }

  // ============================================================
  // FILE HELPERS
  // ============================================================

  bool _isSvgFile(PlatformFile file) {
    final String extension =
        file.extension?.toLowerCase().trim() ?? _extensionFromName(file.name);

    return extension == 'svg';
  }

  String _extensionFromName(String name) {
    final int dotIndex = name.lastIndexOf('.');

    if (dotIndex == -1 || dotIndex == name.length - 1) {
      return '';
    }

    return name.substring(dotIndex + 1).toLowerCase().trim();
  }

  String _fileKey(PlatformFile file) {
    final String? path = file.path;

    if (path != null && path.isNotEmpty) {
      return path.toLowerCase();
    }

    return file.name.toLowerCase();
  }

  // ============================================================
  // REMOVE FILE
  // ============================================================

  void _removeFile(int index) {
    if (_isConverting) return;

    if (index < 0 || index >= _selectedFiles.length) {
      return;
    }

    setState(() {
      _selectedFiles.removeAt(index);
    });
  }

  // ============================================================
  // READ SVG FILE
  // ============================================================

  Future<Uint8List> _readSvgBytes(PlatformFile file) async {
    final String? path = file.path;

    if (path == null || path.isEmpty) {
      throw Exception('Unable to access ${file.name}.');
    }

    final File svgFile = File(path);

    if (!await svgFile.exists()) {
      throw Exception('SVG file not found: ${file.name}');
    }

    return await svgFile.readAsBytes();
  }

  // ============================================================
  // SVG -> PNG BYTES
  // ============================================================

  Future<Uint8List> _renderSvgAsPng(PlatformFile file) async {
    final Uint8List svgBytes = await _readSvgBytes(file);

    final String svgData = String.fromCharCodes(svgBytes);

    final PictureInfo pictureInfo = await vg.loadPicture(
      SvgStringLoader(svgData),
      null,
    );

    try {
      double width = pictureInfo.size.width;

      double height = pictureInfo.size.height;

      if (!width.isFinite || !height.isFinite || width <= 0 || height <= 0) {
        width = 1200;
        height = 1200;
      }

      const double scale = 2.0;

      final int imageWidth = (width * scale).round().clamp(1, 4000);

      final int imageHeight = (height * scale).round().clamp(1, 4000);

      final ui.Image image = await pictureInfo.picture.toImage(
        imageWidth,
        imageHeight,
      );

      try {
        final ByteData? byteData = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );

        if (byteData == null) {
          throw Exception('Unable to render ${file.name} as PNG.');
        }

        return byteData.buffer.asUint8List();
      } finally {
        image.dispose();
      }
    } finally {
      pictureInfo.picture.dispose();
    }
  }

  // ============================================================
  // CONVERT SVG TO PDF
  // ============================================================

  Future<void> _convertToPdf() async {
    if (_selectedFiles.isEmpty) {
      _showMessage('Please select at least one SVG file.');
      return;
    }

    if (_isConverting) return;

    setState(() {
      _isConverting = true;
    });

    PdfDocument? document;

    try {
      document = PdfDocument();

      for (final PlatformFile file in _selectedFiles) {
        if (!_isSvgFile(file)) {
          throw Exception('${file.name} is not an SVG file.');
        }

        final Uint8List pngBytes = await _renderSvgAsPng(file);

        final PdfBitmap image = PdfBitmap(pngBytes);

        final PdfSection section = document.sections!.add();

        section.pageSettings.size = PdfPageSize.a4;

        section.pageSettings.margins.all = 24;

        final PdfPage page = section.pages.add();

        final Size pageSize = page.getClientSize();

        final double imageWidth = image.width.toDouble();

        final double imageHeight = image.height.toDouble();

        if (imageWidth <= 0 || imageHeight <= 0) {
          throw Exception('Invalid SVG dimensions for ${file.name}.');
        }

        final double widthRatio = pageSize.width / imageWidth;

        final double heightRatio = pageSize.height / imageHeight;

        final double scale = widthRatio < heightRatio
            ? widthRatio
            : heightRatio;

        final double drawWidth = imageWidth * scale;

        final double drawHeight = imageHeight * scale;

        final double left = (pageSize.width - drawWidth) / 2;

        final double top = (pageSize.height - drawHeight) / 2;

        page.graphics.drawImage(
          image,
          Rect.fromLTWH(left, top, drawWidth, drawHeight),
        );
      }

      final List<int> outputBytes = await document.save();

      if (outputBytes.isEmpty) {
        throw Exception('Generated PDF is empty.');
      }

      final Directory directory = await getApplicationDocumentsDirectory();

      final String fileName =
          'SVG_to_PDF_'
          '${DateTime.now().millisecondsSinceEpoch}.pdf';

      final String outputPath = '${directory.path}/$fileName';

      final File outputFile = File(outputPath);

      await outputFile.writeAsBytes(outputBytes, flush: true);

      final int outputSize = await outputFile.length();

      if (outputSize <= 0) {
        throw Exception('Generated PDF file is empty.');
      }

      debugPrint('✅ SVG to PDF written to disk');
      debugPrint('📦 Output size: $outputSize bytes');

      // ========================================================
      // SAVE HISTORY METADATA
      // ========================================================

      try {
        final String sourceName = _selectedFiles.length == 1
            ? _selectedFiles.first.name
            : '${_selectedFiles.length} SVG files';

        final response = await ApiService.instance.createHistory(
          toolName: 'SVG to PDF',
          fileName: sourceName,
          outputFileName: fileName,
          status: 'completed',
          fileSize: outputSize,
          notes:
              'Converted ${_selectedFiles.length} SVG file'
              '${_selectedFiles.length == 1 ? '' : 's'} to PDF.',
        );

        debugPrint(
          '✅ SVG to PDF history API response: '
          '${response.data}',
        );
      } catch (historyError) {
        debugPrint(
          '⚠️ SVG to PDF completed, but history '
          'could not be saved: $historyError',
        );
      }

      if (!mounted) return;

      setState(() {
        _isConverting = false;
      });

      _showMessage('SVG to PDF created successfully.');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PdfPreviewScreen(fileName: fileName, filePath: outputPath),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ SVG to PDF error: $e');
      debugPrint('StackTrace: $stackTrace');

      if (!mounted) return;

      setState(() {
        _isConverting = false;
      });

      _showMessage('Unable to convert SVG files to PDF.');
    } finally {
      document?.dispose();
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
            const _SvgToPdfBackground(),

            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildInfoCard()),
                SliverToBoxAdapter(child: _buildAddButton()),
                if (_selectedFiles.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(),
                  )
                else ...[
                  SliverToBoxAdapter(child: _buildSectionTitle()),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                    sliver: _buildFileList(),
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
                  'SVG to PDF',
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
                  'Convert SVG graphics into PDF pages',
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
  // INFO CARD
  // ============================================================

  Widget _buildInfoCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
            ),
            child: Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9F43).withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.polyline_outlined,
                    color: Color(0xFFFF9F43),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SVG Graphics',
                        style: TextStyle(
                          color: Color(0xFF10255C),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Each selected SVG will be placed on its own PDF page.',
                        style: TextStyle(
                          color: Color(0xFF7A8CA6),
                          fontSize: 11.5,
                          height: 1.4,
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
  // ADD BUTTON
  // ============================================================

  Widget _buildAddButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isConverting ? null : _addMoreFiles,
          borderRadius: BorderRadius.circular(17),
          child: Ink(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.50),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: const Color(0xFFF0CEA4), width: 1.1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.add_photo_alternate_outlined,
                  color: Color(0xFFFF9F43),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Add More SVG Files',
                  style: TextStyle(
                    color: _isConverting
                        ? const Color(0xFF9DA8B6)
                        : const Color(0xFFB86600),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
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
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Selected SVG Files',
              style: TextStyle(
                color: Color(0xFF10255C),
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF2E5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_selectedFiles.length}',
              style: const TextStyle(
                color: Color(0xFFB86600),
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FILE LIST
  // ============================================================

  SliverList _buildFileList() {
    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final PlatformFile file = _selectedFiles[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _SvgFileCard(
            index: index,
            file: file,
            onDelete: () => _removeFile(index),
          ),
        );
      }, childCount: _selectedFiles.length),
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
          onPressed: _isConverting ? null : _convertToPdf,
          icon: _isConverting
              ? const SizedBox(
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.picture_as_pdf_rounded),
          label: Text(
            _isConverting ? 'Converting to PDF...' : 'Convert to PDF',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF9F43),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(
              0xFFFF9F43,
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
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.52),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.80)),
              ),
              child: const Icon(
                Icons.polyline_outlined,
                color: Color(0xFFFF9F43),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No SVG files selected',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF10255C),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add one or more SVG files to create your PDF.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF74859F),
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: _isConverting ? null : _addMoreFiles,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 19),
                label: const Text(
                  'Select SVG Files',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9F43),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  elevation: 0,
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
// SVG FILE CARD
// ============================================================

class _SvgFileCard extends StatelessWidget {
  final int index;
  final PlatformFile file;
  final VoidCallback onDelete;

  const _SvgFileCard({
    required this.index,
    required this.file,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.50),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF9F43).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.polyline_outlined,
                  color: Color(0xFFFF9F43),
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
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
                    const SizedBox(height: 5),
                    Text(
                      'Page ${index + 1}  •  SVG',
                      style: const TextStyle(
                        color: Color(0xFF7A8CA6),
                        fontSize: 10.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onDelete,
                  borderRadius: BorderRadius.circular(13),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEEF0),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      color: Color(0xFFE25563),
                      size: 20,
                    ),
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
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
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

class _SvgToPdfBackground extends StatelessWidget {
  const _SvgToPdfBackground();

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
      imageFilter: ui.ImageFilter.blur(sigmaX: 45, sigmaY: 45),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
