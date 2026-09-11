import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_super_app/core/services/api_service.dart';
import 'package:pdf_super_app/features/home/screens/pdf_preview_screen.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PngToPdfScreen extends StatefulWidget {
  const PngToPdfScreen({super.key});

  @override
  State<PngToPdfScreen> createState() => _PngToPdfScreenState();
}

class _PngToPdfScreenState extends State<PngToPdfScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  final List<XFile> _images = <XFile>[];

  bool _isPicking = false;
  bool _isConverting = false;

  // ============================================================
  // ADD PNG IMAGES
  // ============================================================

  Future<void> _addImages() async {
    if (_isPicking || _isConverting) return;

    setState(() {
      _isPicking = true;
    });

    try {
      final List<XFile> selectedImages = await _imagePicker.pickMultiImage(
        imageQuality: 95,
      );

      if (selectedImages.isEmpty) {
        return;
      }

      // Keep selected images.
      final List<XFile> pngImages = List<XFile>.from(selectedImages);

      if (pngImages.isEmpty) {
        _showMessage('Please select at least one image.');
        return;
      }

      final Set<String> existingPaths = _images
          .map((image) => image.path)
          .where((path) => path.isNotEmpty)
          .toSet();

      final List<XFile> newImages = <XFile>[];

      for (final XFile image in pngImages) {
        if (!existingPaths.contains(image.path)) {
          newImages.add(image);
          existingPaths.add(image.path);
        }
      }

      if (newImages.isEmpty) {
        _showMessage('Selected PNG images are already in the list.');
        return;
      }

      if (!mounted) return;

      setState(() {
        _images.addAll(newImages);
      });

      _showMessage(
        '${newImages.length} PNG image'
        '${newImages.length == 1 ? '' : 's'} added.',
      );
    } catch (e) {
      debugPrint('❌ PNG image picker error: $e');

      _showMessage('Unable to select PNG images.');
    } finally {
      if (mounted) {
        setState(() {
          _isPicking = false;
        });
      }
    }
  }

  // ============================================================
  // REMOVE IMAGE
  // ============================================================

  void _removeImage(int index) {
    if (_isConverting) return;

    if (index < 0 || index >= _images.length) {
      return;
    }

    setState(() {
      _images.removeAt(index);
    });

    _showMessage('PNG image removed.');
  }

  // ============================================================
  // FILE SIZE
  // ============================================================

  Future<String> _getFileSize(XFile image) async {
    try {
      final int bytes = await File(image.path).length();

      if (bytes < 1024) {
        return '$bytes B';
      }

      if (bytes < 1024 * 1024) {
        return '${(bytes / 1024).toStringAsFixed(1)} KB';
      }

      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } catch (_) {
      return '--';
    }
  }

  // ============================================================
  // CONVERT PNG TO PDF
  // ============================================================

  Future<void> _convertToPdf() async {
    if (_images.isEmpty) {
      _showMessage('Please add at least one PNG image.');
      return;
    }

    if (_isConverting) return;

    setState(() {
      _isConverting = true;
    });

    PdfDocument? document;

    try {
      document = PdfDocument();

      for (final XFile imageFile in _images) {
        final List<int> imageBytes = await imageFile.readAsBytes();

        if (imageBytes.isEmpty) {
          throw Exception('${imageFile.name} is empty.');
        }

        final PdfBitmap image = PdfBitmap(imageBytes);

        final double imageWidth = image.width.toDouble();

        final double imageHeight = image.height.toDouble();

        if (imageWidth <= 0 || imageHeight <= 0) {
          throw Exception('Invalid image dimensions: ${imageFile.name}');
        }

        final PdfSection section = document.sections!.add();

        if (imageWidth >= imageHeight) {
          section.pageSettings.size = const Size(842, 595);
        } else {
          section.pageSettings.size = const Size(595, 842);
        }

        section.pageSettings.margins.all = 24;

        final PdfPage page = section.pages.add();

        final Size pageSize = page.getClientSize();

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
          'PNG_to_PDF_'
          '${DateTime.now().millisecondsSinceEpoch}.pdf';

      final String outputPath = '${directory.path}/$fileName';

      final File outputFile = File(outputPath);

      await outputFile.writeAsBytes(outputBytes, flush: true);

      final int outputSize = await outputFile.length();

      if (outputSize <= 0) {
        throw Exception('Generated PDF file is empty.');
      }

      debugPrint('✅ PNG to PDF written to disk');
      debugPrint('📦 Output size: $outputSize bytes');

      // ========================================================
      // SAVE HISTORY METADATA
      // ========================================================

      try {
        final String sourceName = _images.length == 1
            ? _images.first.name
            : '${_images.length} PNG images';

        final response = await ApiService.instance.createHistory(
          toolName: 'PNG to PDF',
          fileName: sourceName,
          outputFileName: fileName,
          status: 'completed',
          fileSize: outputSize,
          notes:
              'Converted ${_images.length} PNG image'
              '${_images.length == 1 ? '' : 's'} to PDF.',
        );

        debugPrint(
          '✅ PNG to PDF history API response: '
          '${response.data}',
        );
      } catch (historyError) {
        debugPrint(
          '⚠️ PNG to PDF completed, but history '
          'could not be saved: $historyError',
        );
      }

      if (!mounted) return;

      setState(() {
        _isConverting = false;
      });

      _showMessage('PNG to PDF created successfully.');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PdfPreviewScreen(fileName: fileName, filePath: outputPath),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('❌ PNG to PDF error: $e');
      debugPrint('StackTrace: $stackTrace');

      if (!mounted) return;

      setState(() {
        _isConverting = false;
      });

      _showMessage('Unable to convert PNG images to PDF.');
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
            const _PngToPdfBackground(),
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildInfoCard()),
                SliverToBoxAdapter(child: _buildAddButton()),
                if (_images.isEmpty)
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
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'PNG to PDF',
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
                  'Convert one or more PNG images into PDF',
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
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
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
                    color: const Color(0xFF12B886).withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.image_outlined,
                    color: Color(0xFF12B886),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PNG Images',
                        style: TextStyle(
                          color: Color(0xFF10255C),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_images.length} image'
                        '${_images.length == 1 ? '' : 's'} selected',
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
  // ADD BUTTON
  // ============================================================

  Widget _buildAddButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isPicking || _isConverting ? null : _addImages,
          borderRadius: BorderRadius.circular(17),
          child: Ink(
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.50),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: const Color(0xFFB8D8CC), width: 1.1),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isPicking)
                  const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Color(0xFF12B886),
                    ),
                  )
                else
                  const Icon(
                    Icons.add_photo_alternate_outlined,
                    color: Color(0xFF12B886),
                    size: 20,
                  ),
                const SizedBox(width: 8),
                Text(
                  _isPicking ? 'Opening Gallery...' : 'Add Images',
                  style: TextStyle(
                    color: _isConverting
                        ? const Color(0xFF9DA8B6)
                        : const Color(0xFF087B5D),
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
              'Selected Images',
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
              color: const Color(0xFFE5F8F2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_images.length}',
              style: const TextStyle(
                color: Color(0xFF087B5D),
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
        final XFile image = _images[index];

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _PngFileCard(
            index: index,
            image: image,
            onDelete: () => _removeImage(index),
            getFileSize: _getFileSize,
          ),
        );
      }, childCount: _images.length),
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
          onPressed: _isConverting || _images.isEmpty ? null : _convertToPdf,
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
            backgroundColor: const Color(0xFF12B886),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(
              0xFF12B886,
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
                Icons.image_outlined,
                color: Color(0xFF12B886),
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No PNG images selected',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF10255C),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Add one or more PNG images to create your PDF.',
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
                onPressed: _isPicking ? null : _addImages,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 19),
                label: const Text(
                  'Select PNG Images',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF12B886),
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
// PNG FILE CARD
// ============================================================

class _PngFileCard extends StatelessWidget {
  final int index;
  final XFile image;
  final VoidCallback onDelete;
  final Future<String> Function(XFile image) getFileSize;

  const _PngFileCard({
    required this.index,
    required this.image,
    required this.onDelete,
    required this.getFileSize,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
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
                  color: const Color(0xFF12B886).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.file(
                    File(image.path),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.image_outlined,
                        color: Color(0xFF12B886),
                        size: 27,
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      image.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF10255C),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    FutureBuilder<String>(
                      future: getFileSize(image),
                      builder: (context, snapshot) {
                        return Text(
                          'Page ${index + 1}  •  '
                          '${snapshot.data ?? '--'}',
                          style: const TextStyle(
                            color: Color(0xFF7A8CA6),
                            fontSize: 10.5,
                          ),
                        );
                      },
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

class _PngToPdfBackground extends StatelessWidget {
  const _PngToPdfBackground();

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
