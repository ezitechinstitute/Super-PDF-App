import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:pdf_super_app/core/services/api_service.dart';
import 'package:pdf_super_app/features/home/screens/pdf_preview_screen.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class CompressPdfScreen extends StatefulWidget {
  final PlatformFile selectedFile;

  const CompressPdfScreen({super.key, required this.selectedFile});

  @override
  State<CompressPdfScreen> createState() => _CompressPdfScreenState();
}

class _CompressPdfScreenState extends State<CompressPdfScreen> {
  bool _isLoading = true;
  bool _isCompressing = false;

  int _originalSize = 0;
  int _compressedSize = 0;
  int _pageCount = 0;
  int _formFieldCount = 0;

  String _compressionLevel = 'Recommended';

  @override
  void initState() {
    super.initState();
    _loadPdfInformation();
  }

  // ============================================================
  // LOAD PDF INFORMATION
  // ============================================================

  Future<void> _loadPdfInformation() async {
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

      final int fileSize = await file.length();

      if (fileSize <= 0) {
        throw Exception('PDF file is empty.');
      }

      final Uint8List bytes = await file.readAsBytes();

      final PdfDocument document = PdfDocument(inputBytes: bytes);

      final int pages = document.pages.count;

      int formFields = 0;

      try {
        formFields = document.form.fields.count;
      } catch (e) {
        debugPrint('⚠️ Could not read form fields: $e');
      }

      document.dispose();

      if (!mounted) return;

      setState(() {
        _originalSize = fileSize;
        _pageCount = pages;
        _formFieldCount = formFields;
        _isLoading = false;
      });

      debugPrint('==========================================');
      debugPrint('📄 COMPRESS PDF');
      debugPrint('📄 File: ${widget.selectedFile.name}');
      debugPrint('📑 Pages: $pages');
      debugPrint('📝 Form fields: $formFields');
      debugPrint(
        '📦 Original size: '
        '${_formatFileSize(fileSize)}',
      );
      debugPrint('==========================================');
    } catch (e) {
      debugPrint('❌ Could not read PDF information: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('Unable to read this PDF.');
    }
  }

  // ============================================================
  // FILE SIZE
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
  // SELECT COMPRESSION
  // ============================================================

  void _selectCompression(String level) {
    if (_isCompressing) return;

    setState(() {
      _compressionLevel = level;
      _compressedSize = 0;
    });
  }

  // ============================================================
  // SYNCFUSION COMPRESSION LEVEL
  // ============================================================

  PdfCompressionLevel _getPdfCompressionLevel() {
    switch (_compressionLevel) {
      case 'Light':
        return PdfCompressionLevel.belowNormal;

      case 'Maximum':
        return PdfCompressionLevel.best;

      case 'Recommended':
      default:
        return PdfCompressionLevel.aboveNormal;
    }
  }

  // ============================================================
  // RASTER SCALE
  // ============================================================

  double _getRenderScale() {
    switch (_compressionLevel) {
      case 'Maximum':
        return 1.20;

      case 'Light':
        return 1.80;

      case 'Recommended':
      default:
        return 1.45;
    }
  }

  // ============================================================
  // JPEG QUALITY
  // ============================================================

  int _getJpegQuality() {
    switch (_compressionLevel) {
      case 'Maximum':
        return 52;

      case 'Light':
        return 82;

      case 'Recommended':
      default:
        return 68;
    }
  }

  // ============================================================
  // SAFE IMAGE DIMENSION
  // ============================================================

  int _safeImageDimension(double value) {
    if (value.isNaN || value.isInfinite || value <= 1) {
      return 1;
    }

    const int maxDimension = 5000;

    final int dimension = value.round();

    if (dimension > maxDimension) {
      return maxDimension;
    }

    return dimension;
  }

  // ============================================================
  // NORMAL SYNCFUSION COMPRESSION
  // ============================================================

  Future<Uint8List> _createSyncfusionCompressedPdf(
    Uint8List sourceBytes,
  ) async {
    final PdfDocument document = PdfDocument(inputBytes: sourceBytes);

    try {
      document.fileStructure.incrementalUpdate = false;

      document.compressionLevel = _getPdfCompressionLevel();

      final List<int> output = await document.save();

      if (output.isEmpty) {
        throw Exception('Syncfusion compression produced an empty PDF.');
      }

      return Uint8List.fromList(output);
    } finally {
      document.dispose();
    }
  }

  // ============================================================
  // IMAGE-BASED COMPRESSION
  // ============================================================

  Future<Uint8List> _createRasterCompressedPdf(String sourcePath) async {
    final pdfx.PdfDocument document = await pdfx.PdfDocument.openFile(
      sourcePath,
    );

    final pw.Document outputDocument = pw.Document();

    final double scale = _getRenderScale();

    final int quality = _getJpegQuality();

    debugPrint('==========================================');
    debugPrint('🖼️ RASTER COMPRESSION STARTED');
    debugPrint('🎚️ Level: $_compressionLevel');
    debugPrint('🔍 Render scale: $scale');
    debugPrint('🎞️ JPEG quality: $quality');
    debugPrint('📑 Pages: $_pageCount');
    debugPrint('==========================================');

    try {
      for (int pageNumber = 1; pageNumber <= _pageCount; pageNumber++) {
        pdfx.PdfPage? page;

        try {
          page = await document.getPage(pageNumber);

          final int renderWidth = _safeImageDimension(page.width * scale);

          final int renderHeight = _safeImageDimension(page.height * scale);

          final pdfx.PdfPageImage? pageImage = await page.render(
            width: renderWidth.toDouble(),
            height: renderHeight.toDouble(),
            format: pdfx.PdfPageImageFormat.jpeg,
            backgroundColor: '#FFFFFF',
            quality: quality,
          );

          if (pageImage == null || pageImage.bytes.isEmpty) {
            throw Exception(
              'Unable to render page '
              '$pageNumber.',
            );
          }

          final pw.MemoryImage image = pw.MemoryImage(pageImage.bytes);

          final double pageWidth = page.width;

          final double pageHeight = page.height;

          outputDocument.addPage(
            pw.Page(
              pageFormat: pdf.PdfPageFormat(
                pageWidth,
                pageHeight,
                marginAll: 0,
              ),
              build: (pw.Context context) {
                return pw.SizedBox(
                  width: pageWidth,
                  height: pageHeight,
                  child: pw.Image(image, fit: pw.BoxFit.fill),
                );
              },
            ),
          );

          debugPrint(
            '🖼️ Page '
            '$pageNumber/$_pageCount '
            'rendered',
          );
        } finally {
          if (page != null) {
            try {
              await page.close();
            } catch (e) {
              debugPrint('⚠️ Page close error: $e');
            }
          }
        }
      }

      final Uint8List result = await outputDocument.save();

      if (result.isEmpty) {
        throw Exception('Raster compression produced an empty PDF.');
      }

      debugPrint('==========================================');
      debugPrint('✅ RASTER COMPRESSION COMPLETED');
      debugPrint(
        '📦 Result: '
        '${_formatFileSize(result.length)}',
      );
      debugPrint('==========================================');

      return result;
    } finally {
      try {
        await document.close();
      } catch (e) {
        debugPrint('⚠️ PDF document close error: $e');
      }
    }
  }

  // ============================================================
  // RASTER FALLBACK SAFETY
  // ============================================================

  bool _canUseRasterFallback() {
    if (_formFieldCount > 0) {
      debugPrint('⚠️ Raster fallback skipped.');
      debugPrint(
        '⚠️ Interactive form fields detected: '
        '$_formFieldCount',
      );

      return false;
    }

    return true;
  }

  // ============================================================
  // FIND BEST OUTPUT
  // ============================================================

  Future<Uint8List> _getBestCompressedPdf(
    Uint8List sourceBytes,
    String sourcePath,
  ) async {
    Uint8List bestBytes = sourceBytes;

    // ----------------------------------------------------------
    // METHOD 1
    // Syncfusion structural compression
    // ----------------------------------------------------------

    try {
      debugPrint('------------------------------------------');
      debugPrint('1️⃣ Trying Syncfusion compression');

      final Uint8List syncfusionBytes = await _createSyncfusionCompressedPdf(
        sourceBytes,
      );

      debugPrint(
        '📦 Syncfusion result: '
        '${_formatFileSize(syncfusionBytes.length)}',
      );

      if (syncfusionBytes.length < bestBytes.length) {
        bestBytes = syncfusionBytes;

        debugPrint('✅ Syncfusion result is smaller.');
      } else {
        debugPrint('ℹ️ Syncfusion result is not smaller.');
      }
    } catch (e) {
      debugPrint('⚠️ Syncfusion compression failed: $e');
    }

    // ----------------------------------------------------------
    // METHOD 2
    // Raster/image compression
    // ----------------------------------------------------------

    if (_canUseRasterFallback()) {
      try {
        debugPrint('------------------------------------------');
        debugPrint('2️⃣ Trying image compression');

        final Uint8List rasterBytes = await _createRasterCompressedPdf(
          sourcePath,
        );

        debugPrint(
          '📦 Raster result: '
          '${_formatFileSize(rasterBytes.length)}',
        );

        if (rasterBytes.length < bestBytes.length) {
          bestBytes = rasterBytes;

          debugPrint('✅ Raster result is smaller.');
        } else {
          debugPrint('ℹ️ Raster result is not smaller.');
        }
      } catch (e) {
        debugPrint('⚠️ Raster compression failed: $e');
      }
    }

    return bestBytes;
  }

  // ============================================================
  // COMPRESS PDF
  // ============================================================

  Future<void> _compressPdf() async {
    final String? path = widget.selectedFile.path;

    if (path == null || path.isEmpty) {
      _showMessage('Selected PDF could not be accessed.');
      return;
    }

    if (_isCompressing) return;

    if (_originalSize <= 0) {
      _showMessage('PDF information is not ready yet.');
      return;
    }

    if (!mounted) return;

    setState(() {
      _isCompressing = true;
      _compressedSize = 0;
    });

    File? outputFile;

    try {
      final File sourceFile = File(path);

      if (!await sourceFile.exists()) {
        throw Exception('PDF file not found.');
      }

      final Uint8List sourceBytes = await sourceFile.readAsBytes();

      if (sourceBytes.isEmpty) {
        throw Exception('Source PDF is empty.');
      }

      debugPrint('==========================================');
      debugPrint('🗜️ COMPRESSION STARTED');
      debugPrint('🎚️ Level: $_compressionLevel');
      debugPrint(
        '📦 Original: '
        '${_formatFileSize(_originalSize)}',
      );
      debugPrint(
        '📝 Form fields: '
        '$_formFieldCount',
      );
      debugPrint('==========================================');

      final Uint8List bestCompressedBytes = await _getBestCompressedPdf(
        sourceBytes,
        path,
      );

      if (bestCompressedBytes.isEmpty) {
        throw Exception('Compression result is empty.');
      }

      final Directory directory = await getApplicationDocumentsDirectory();

      final String fileName =
          'Compressed_Document_'
          '${DateTime.now().millisecondsSinceEpoch}.pdf';

      final String outputPath = '${directory.path}/$fileName';

      outputFile = File(outputPath);

      await outputFile.writeAsBytes(bestCompressedBytes, flush: true);

      final int compressedFileSize = await outputFile.length();

      if (compressedFileSize <= 0) {
        throw Exception('Compressed PDF is empty.');
      }

      // ----------------------------------------------------------
      // CALCULATE RESULT
      // ----------------------------------------------------------

      final int saved = _originalSize - compressedFileSize;

      final double percentage = _originalSize > 0 && saved > 0
          ? (saved / _originalSize) * 100
          : 0;

      if (!mounted) return;

      setState(() {
        _compressedSize = compressedFileSize;
      });

      debugPrint('==========================================');
      debugPrint('✅ COMPRESSION COMPLETED');
      debugPrint(
        '📦 Original: '
        '${_formatFileSize(_originalSize)}',
      );
      debugPrint(
        '📦 Compressed: '
        '${_formatFileSize(compressedFileSize)}',
      );
      debugPrint(
        '💾 Saved: '
        '${_formatFileSize(saved > 0 ? saved : 0)}',
      );
      debugPrint(
        '📊 Reduction: '
        '${percentage.toStringAsFixed(1)}%',
      );
      debugPrint('📍 Output: $outputPath');
      debugPrint('==========================================');

      // ==========================================================
      // SAVE HISTORY TO LARAVEL API
      // ==========================================================

      try {
        final response = await ApiService.instance.createHistory(
          toolName: 'Compress PDF',
          fileName: widget.selectedFile.name,
          outputFileName: fileName,
          status: 'completed',
          fileSize: compressedFileSize,
          notes:
              'Compressed PDF using '
              '$_compressionLevel compression.',
        );

        debugPrint(
          '✅ Compress history API response: '
          '${response.data}',
        );
      } catch (historyError) {
        // PDF remains successful even if history
        // API temporarily fails.
        debugPrint(
          '⚠️ PDF compressed successfully, '
          'but history could not be saved: '
          '$historyError',
        );
      }

      if (!mounted) return;

      setState(() {
        _isCompressing = false;
      });

      // ==========================================================
      // OPEN PDF PREVIEW
      // ==========================================================

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PdfPreviewScreen(fileName: fileName, filePath: outputPath),
        ),
      );
    } catch (e) {
      debugPrint('==========================================');
      debugPrint('❌ PDF COMPRESSION FAILED');
      debugPrint('❌ Error: $e');
      debugPrint('==========================================');

      if (outputFile != null) {
        try {
          if (await outputFile.exists()) {
            await outputFile.delete();
          }
        } catch (_) {
          // Ignore cleanup failure.
        }
      }

      if (!mounted) return;

      setState(() {
        _isCompressing = false;
        _compressedSize = 0;
      });

      _showMessage('Unable to compress this PDF.');
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
      backgroundColor: const Color(0xFFF4F8FF),
      body: SafeArea(
        child: Stack(
          children: [
            const _CompressBackground(),

            Column(
              children: [
                _buildHeader(),
                _buildInfoCard(),
                Expanded(child: _buildContent()),
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
            onTap: _isCompressing ? () {} : () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Compress PDF',
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
                'Choose a compression level, then compress your PDF.',
              );
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
                    color: const Color(0xFF12B886).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.compress_rounded,
                    color: Color(0xFF12B886),
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
                                  '${_formatFileSize(_originalSize)}',
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
                    color: const Color(0xFFE8FFF7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'PDF',
                    style: TextStyle(
                      color: Color(0xFF12B886),
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
  // CONTENT
  // ============================================================

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF1769FF)),
      );
    }

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSizeCard(),
          const SizedBox(height: 18),
          const Text(
            'Compression Level',
            style: TextStyle(
              color: Color(0xFF10255C),
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Choose how much you want to reduce the file size.',
            style: TextStyle(color: Color(0xFF7A8CA6), fontSize: 11.5),
          ),
          const SizedBox(height: 13),
          _CompressionOption(
            title: 'Recommended',
            subtitle: 'Good balance between size and quality',
            icon: Icons.auto_awesome_rounded,
            level: 'Recommended',
            selected: _compressionLevel == 'Recommended',
            onTap: () => _selectCompression('Recommended'),
          ),
          const SizedBox(height: 10),
          _CompressionOption(
            title: 'Maximum',
            subtitle: 'Smallest possible file size',
            icon: Icons.compress_rounded,
            level: 'Maximum',
            selected: _compressionLevel == 'Maximum',
            onTap: () => _selectCompression('Maximum'),
          ),
          const SizedBox(height: 10),
          _CompressionOption(
            title: 'Light',
            subtitle: 'Preserve more quality',
            icon: Icons.high_quality_rounded,
            level: 'Light',
            selected: _compressionLevel == 'Light',
            onTap: () => _selectCompression('Light'),
          ),
          if (_compressedSize > 0) ...[
            const SizedBox(height: 18),
            _buildResultCard(),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // SIZE CARD
  // ============================================================

  Widget _buildSizeCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _SizeColumn(
                  title: 'Original',
                  value: _formatFileSize(_originalSize),
                  icon: Icons.insert_drive_file_outlined,
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: const BoxDecoration(
                  color: Color(0xFFE7F0FF),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFF1769FF),
                  size: 20,
                ),
              ),
              Expanded(
                child: _SizeColumn(
                  title: 'After compression',
                  value: _compressedSize > 0
                      ? _formatFileSize(_compressedSize)
                      : '—',
                  icon: Icons.compress_rounded,
                  alignEnd: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // RESULT CARD
  // ============================================================

  Widget _buildResultCard() {
    final int saved = _originalSize - _compressedSize;

    final bool actuallySmaller = saved > 0;

    final double percentage = _originalSize > 0 && actuallySmaller
        ? (saved / _originalSize) * 100
        : 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: actuallySmaller
            ? const Color(0xFFE8FFF7)
            : const Color(0xFFFFF6E8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: actuallySmaller
              ? const Color(0xFFBFEFDC)
              : const Color(0xFFF0D6A5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: actuallySmaller
                  ? const Color(0xFF12B886)
                  : const Color(0xFFFFA726),
              shape: BoxShape.circle,
            ),
            child: Icon(
              actuallySmaller
                  ? Icons.check_rounded
                  : Icons.info_outline_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  actuallySmaller
                      ? 'Compression complete'
                      : 'PDF already optimized',
                  style: TextStyle(
                    color: actuallySmaller
                        ? const Color(0xFF0F684F)
                        : const Color(0xFF8A611E),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  actuallySmaller
                      ? 'Saved '
                            '${_formatFileSize(saved)} '
                            '(${percentage.toStringAsFixed(0)}%)'
                      : _formFieldCount > 0
                      ? 'This PDF contains interactive form fields, so image compression was skipped.'
                      : 'No smaller PDF was produced without increasing file size.',
                  style: TextStyle(
                    color: actuallySmaller
                        ? const Color(0xFF438773)
                        : const Color(0xFF977338),
                    fontSize: 10.5,
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
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isCompressing ? null : _compressPdf,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: _isCompressing
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
                  if (_isCompressing) ...[
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
                      'Compressing PDF...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ] else ...[
                    const Icon(
                      Icons.compress_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Compress PDF',
                      style: TextStyle(
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
    );
  }
}

// ============================================================
// COMPRESSION OPTION
// ============================================================

class _CompressionOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final String level;
  final bool selected;
  final VoidCallback onTap;

  const _CompressionOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.level,
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
              ? const Color(0xFF1769FF).withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.48),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? const Color(0xFF1769FF)
                : Colors.white.withValues(alpha: 0.82),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF1769FF).withValues(alpha: 0.14)
                    : const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                icon,
                color: selected
                    ? const Color(0xFF1769FF)
                    : const Color(0xFF6E83A4),
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF10255C),
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF7A8BA4),
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected
                  ? const Color(0xFF1769FF)
                  : const Color(0xFF9AAAC2),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SIZE COLUMN
// ============================================================

class _SizeColumn extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final bool alignEnd;

  const _SizeColumn({
    required this.title,
    required this.value,
    required this.icon,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF7B8DA8), size: 20),
        const SizedBox(height: 7),
        Text(
          title,
          style: const TextStyle(color: Color(0xFF7A8CA6), fontSize: 10),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF10255C),
            fontSize: 15,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
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

class _CompressBackground extends StatelessWidget {
  const _CompressBackground();

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
