import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_super_app/features/home/screens/pdf_preview_screen.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class JpgToPdfScreen extends StatefulWidget {
  const JpgToPdfScreen({super.key});

  @override
  State<JpgToPdfScreen> createState() => _JpgToPdfScreenState();
}

class _JpgToPdfScreenState extends State<JpgToPdfScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  final List<XFile> _images = <XFile>[];

  bool _isPicking = false;
  bool _isConverting = false;

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

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
  // ADD IMAGES
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

      if (!mounted) return;

      setState(() {
        _images.addAll(selectedImages);
      });

      _showMessage(
        '${selectedImages.length} image${selectedImages.length == 1 ? '' : 's'} added.',
      );
    } catch (e) {
      debugPrint('❌ JPG picker error: $e');

      _showMessage('Unable to select images.');
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

    _showMessage('Image removed.');
  }

  // ============================================================
  // CONVERT TO PDF
  // ============================================================

  Future<void> _convertToPdf() async {
    if (_images.isEmpty) {
      _showMessage('Please add at least one JPG image.');
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

        final PdfBitmap bitmap = PdfBitmap(imageBytes);

        final PdfPage page = document.pages.add();

        final Size pageSize = page.getClientSize();

        final double imageWidth = bitmap.width.toDouble();

        final double imageHeight = bitmap.height.toDouble();

        if (imageWidth <= 0 || imageHeight <= 0) {
          continue;
        }

        final double widthScale = pageSize.width / imageWidth;

        final double heightScale = pageSize.height / imageHeight;

        final double scale = widthScale < heightScale
            ? widthScale
            : heightScale;

        final double drawWidth = imageWidth * scale;

        final double drawHeight = imageHeight * scale;

        final double x = (pageSize.width - drawWidth) / 2;

        final double y = (pageSize.height - drawHeight) / 2;

        page.graphics.drawImage(
          bitmap,
          Rect.fromLTWH(x, y, drawWidth, drawHeight),
        );
      }

      final List<int> outputBytes = await document.save();

      final Directory directory = await getApplicationDocumentsDirectory();

      final String fileName =
          'JPG_to_PDF_${DateTime.now().millisecondsSinceEpoch}.pdf';

      final String outputPath = '${directory.path}/$fileName';

      final File outputFile = File(outputPath);

      await outputFile.writeAsBytes(outputBytes, flush: true);

      if (!mounted) return;

      setState(() {
        _isConverting = false;
      });

      _showMessage('JPG to PDF created successfully.');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PdfPreviewScreen(fileName: fileName, filePath: outputPath),
        ),
      );
    } catch (e) {
      debugPrint('❌ JPG to PDF error: $e');

      if (!mounted) return;

      setState(() {
        _isConverting = false;
      });

      _showMessage('Unable to convert JPG images to PDF.');
    } finally {
      document?.dispose();
    }
  }

  // ============================================================
  // IMAGE SIZE
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
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      body: SafeArea(
        child: Stack(
          children: [
            const _ConversionBackground(),

            Column(
              children: [
                _buildTopBar(),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(18, 4, 18, 25),
                    child: Column(
                      children: [
                        _buildFormatHeader(),
                        const SizedBox(height: 16),
                        _buildImageGrid(),
                        const SizedBox(height: 18),
                        _buildAddImagesButton(),
                        const SizedBox(height: 18),
                        _buildOptionsCard(),
                      ],
                    ),
                  ),
                ),

                _buildBottomButton(),
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
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'JPG to PDF',
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
                'Select one or more JPG images, then convert them into a PDF.',
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FORMAT HEADER
  // ============================================================

  Widget _buildFormatHeader() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.48),
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
                  Icons.image_outlined,
                  color: Color(0xFF1769FF),
                  size: 27,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Convert Images to PDF',
                      style: TextStyle(
                        color: Color(0xFF10255C),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_images.length} image${_images.length == 1 ? '' : 's'} selected',
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
                  'JPG',
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
    );
  }

  // ============================================================
  // IMAGE GRID
  // ============================================================

  Widget _buildImageGrid() {
    if (_images.isEmpty) {
      return _buildEmptyImages();
    }

    return GridView.builder(
      itemCount: _images.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.84,
      ),
      itemBuilder: (context, index) {
        final XFile image = _images[index];

        return _ImageCard(
          image: image,
          index: index + 1,
          onDelete: () => _removeImage(index),
          getFileSize: _getFileSize,
        );
      },
    );
  }

  // ============================================================
  // EMPTY IMAGE AREA
  // ============================================================

  Widget _buildEmptyImages() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(21),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: Color(0xFFE7F0FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_photo_alternate_outlined,
                  color: Color(0xFF1769FF),
                  size: 30,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'No JPG images selected',
                style: TextStyle(
                  color: Color(0xFF10255C),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Tap Add Images to select JPG files.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF7A8BA4), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ADD IMAGES BUTTON
  // ============================================================

  Widget _buildAddImagesButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isPicking || _isConverting ? null : _addImages,
          borderRadius: BorderRadius.circular(17),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(17),
              border: Border.all(color: const Color(0xFF9FC2F3), width: 1.1),
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
                      color: Color(0xFF1769FF),
                    ),
                  )
                else
                  const Icon(
                    Icons.add_photo_alternate_outlined,
                    color: Color(0xFF1769FF),
                    size: 21,
                  ),
                const SizedBox(width: 8),
                Text(
                  _isPicking ? 'Opening Gallery...' : 'Add Images',
                  style: const TextStyle(
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
    );
  }

  // ============================================================
  // OPTIONS CARD
  // ============================================================

  Widget _buildOptionsCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.44),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.80)),
          ),
          child: Column(
            children: [
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'PDF Options',
                  style: TextStyle(
                    color: Color(0xFF10255C),
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              _OptionRow(
                icon: Icons.crop_free_rounded,
                title: 'Page Size',
                value: 'A4',
                onTap: () {
                  _showMessage('Page size is currently A4.');
                },
              ),
              _OptionRow(
                icon: Icons.photo_size_select_large_outlined,
                title: 'Image Fit',
                value: 'Fit',
                onTap: () {
                  _showMessage('Images are fitted inside the A4 page.');
                },
              ),
              _OptionRow(
                icon: Icons.swap_vert_rounded,
                title: 'Image Quality',
                value: 'High',
                onTap: () {
                  _showMessage('High image quality is being used.');
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM BUTTON
  // ============================================================

  Widget _buildBottomButton() {
    final bool disabled = _isConverting || _images.isEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.58),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.82)),
        ),
      ),
      child: SizedBox(
        height: 58,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: disabled ? null : _convertToPdf,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: disabled
                    ? const LinearGradient(
                        colors: [Color(0xFF9BBCEB), Color(0xFF7CA4DC)],
                      )
                    : const LinearGradient(
                        colors: [Color(0xFF2D7BFF), Color(0xFF0958EA)],
                      ),
                boxShadow: disabled
                    ? null
                    : [
                        BoxShadow(
                          color: const Color(
                            0xFF1769FF,
                          ).withValues(alpha: 0.25),
                          blurRadius: 20,
                          offset: const Offset(0, 9),
                        ),
                      ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isConverting)
                    const SizedBox(
                      width: 21,
                      height: 21,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.3,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Icon(
                      Icons.picture_as_pdf_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
                  const SizedBox(width: 9),
                  Text(
                    _isConverting ? 'Creating PDF...' : 'Convert to PDF',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// IMAGE CARD
// ============================================================

class _ImageCard extends StatelessWidget {
  final XFile image;
  final int index;
  final VoidCallback onDelete;
  final Future<String> Function(XFile image) getFileSize;

  const _ImageCard({
    required this.image,
    required this.index,
    required this.onDelete,
    required this.getFileSize,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(21),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(21),
            border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6D91C8).withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                          color: const Color(0xFFE7F0FF),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(15),
                          child: Image.file(
                            File(image.path),
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.broken_image_outlined,
                                color: Color(0xFF1769FF),
                                size: 48,
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      top: 14,
                      left: 14,
                      child: Container(
                        width: 28,
                        height: 28,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1769FF),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$index',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      top: 14,
                      right: 14,
                      child: GestureDetector(
                        onTap: onDelete,
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.90),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Color(0xFFE25563),
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(11, 3, 11, 11),
                child: FutureBuilder<String>(
                  future: getFileSize(image),
                  builder: (context, snapshot) {
                    return Column(
                      children: [
                        Text(
                          image.name.isNotEmpty ? image.name : 'JPG Image',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF10255C),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          snapshot.data ?? '--',
                          style: const TextStyle(
                            color: Color(0xFF7A8BA4),
                            fontSize: 9.5,
                          ),
                        ),
                      ],
                    );
                  },
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
// OPTION ROW
// ============================================================

class _OptionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;

  const _OptionRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFE7F0FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF1769FF), size: 20),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF2A3B58),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                color: Color(0xFF1769FF),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF7184A4),
              size: 19,
            ),
          ],
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
          color: Colors.white.withValues(alpha: 0.42),
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
              child: Icon(icon, color: const Color(0xFF17345F), size: 19),
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

class _ConversionBackground extends StatelessWidget {
  const _ConversionBackground();

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
            top: 350,
            left: -110,
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
