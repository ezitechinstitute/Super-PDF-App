import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:pdf_super_app/features/home/screens/pdf_preview_screen.dart';
import 'package:pdf_super_app/features/home/screens/merge_pdf_screen.dart';
import 'package:pdf_super_app/features/home/screens/split_pdf_screen.dart';
import 'package:pdf_super_app/features/home/screens/compress_pdf_screen.dart';
import 'package:pdf_super_app/features/home/screens/protect_pdf_screen.dart';
import 'package:pdf_super_app/features/home/screens/remove_pages_screen.dart';
import 'package:pdf_super_app/features/home/screens/extract_pages_screen.dart';
import 'package:pdf_super_app/features/home/screens/rotate_pdf_screen.dart';
import 'package:pdf_super_app/features/home/screens/sign_pdf_screen.dart';
//import 'package:pdf_super_app/features/home/screens/png_to_pdf_screen.dart';
import 'package:pdf_super_app/features/home/screens/pdf_to_jpg_screen.dart';
import 'package:pdf_super_app/features/home/screens/pdf_to_png_screen.dart';
import 'package:pdf_super_app/features/home/screens/svg_to_pdf_screen.dart';
import 'package:pdf_super_app/features/home/screens/pdf_to_svg_screen.dart';
import 'package:pdf_super_app/features/home/screens/fill_forms_screen.dart';
import 'package:pdf_super_app/features/home/screens/watermark_pdf_screen.dart';
import 'package:pdf_super_app/features/home/screens/add_page_numbers_screen.dart';
import 'package:pdf_super_app/features/home/screens/ocr_screen.dart';
import 'package:pdf_super_app/features/home/screens/ai_summarize_screen.dart';
//import 'package:pdf_super_app/features/home/screens/scan_document_screen.dart';

class FilePickerScreen extends StatefulWidget {
  final String toolName;
  final List<String> allowedExtensions;
  final bool allowMultiple;

  const FilePickerScreen({
    super.key,
    this.toolName = 'Select File',
    this.allowedExtensions = const ['pdf'],
    this.allowMultiple = false,
  });

  @override
  State<FilePickerScreen> createState() => _FilePickerScreenState();
}

class _FilePickerScreenState extends State<FilePickerScreen> {
  bool _isPicking = false;

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
            const _PickerBackground(),
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 18),
                  _buildHeroCard(context),
                  const SizedBox(height: 20),
                  _buildSupportedFormats(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // FILE PICKER
  // ============================================================

  Future<void> _pickFiles() async {
    if (_isPicking) return;

    setState(() {
      _isPicking = true;
    });

    try {
      final List<PlatformFile> files;

      if (widget.allowMultiple) {
        files = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: widget.allowedExtensions,
        );
      } else {
        files = [
          await FilePicker.pickFile(
            type: FileType.custom,
            allowedExtensions: widget.allowedExtensions,
          ),
        ].whereType<PlatformFile>().toList();
      }

      if (files.isEmpty) {
        return;
      }

      debugPrint('==========================================');
      debugPrint('📁 FILE PICKER');
      debugPrint('🛠️ Tool: ${widget.toolName}');
      debugPrint('📄 Files selected: ${files.length}');

      for (final file in files) {
        debugPrint('📄 ${file.name}');
        debugPrint('📍 Path: ${file.path}');
      }

      debugPrint('==========================================');

      if (!mounted) return;

      // ==========================================================
      // MERGE PDF
      // ==========================================================

      if (widget.toolName == 'Merge PDF') {
        if (files.length < 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please select at least 2 PDF files to merge.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => MergePdfScreen(selectedFiles: files),
          ),
        );

        return;
      }

      // ==========================================================
      // SPLIT PDF
      // ==========================================================

      if (widget.toolName == 'Split PDF') {
        final file = files.first;

        if (file.path == null || file.path!.isEmpty) {
          _showMessage('Unable to access the selected PDF file.');
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SplitPdfScreen(selectedFile: file)),
        );

        return;
      }
      // ==========================================================
      // COMPRESS PDF
      // ==========================================================

      if (widget.toolName == 'Compress PDF') {
        final file = files.first;

        if (file.path == null || file.path!.isEmpty) {
          _showMessage('Unable to access the selected PDF file.');
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CompressPdfScreen(selectedFile: file),
          ),
        );

        return;
      }
      // ==========================================================
      // PROTECT PDF
      // ==========================================================

      if (widget.toolName == 'Protect PDF') {
        final file = files.first;

        if (file.path == null || file.path!.isEmpty) {
          _showMessage('Unable to access the selected PDF file.');
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ProtectPdfScreen(selectedFile: file),
          ),
        );

        return;
      }
      // ==========================================================
      // REMOVE PAGES
      // ==========================================================

      if (widget.toolName == 'Remove Pages') {
        final file = files.first;

        if (file.path == null || file.path!.isEmpty) {
          _showMessage('Unable to access the selected PDF file.');
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RemovePagesScreen(selectedFile: file),
          ),
        );

        return;
      }
      // ==========================================================
      // EXTRACT PAGES
      // ==========================================================

      if (widget.toolName == 'Extract Pages') {
        final file = files.first;

        if (file.path == null || file.path!.isEmpty) {
          _showMessage('Unable to access the selected PDF file.');
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ExtractPagesScreen(selectedFile: file),
          ),
        );

        return;
      }
      // ==========================================================
      // ROTATE PDF
      // ==========================================================

      if (widget.toolName == 'Rotate PDF') {
        final file = files.first;

        if (file.path == null || file.path!.isEmpty) {
          _showMessage('Unable to access the selected PDF file.');
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RotatePdfScreen(selectedFile: file),
          ),
        );

        return;
      }
      // ==========================================================
      // SIGN PDF
      // ==========================================================

      if (widget.toolName == 'Sign PDF') {
        final file = files.first;

        if (file.path == null || file.path!.isEmpty) {
          _showMessage('Unable to access the selected PDF file.');
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SignPdfScreen(selectedFile: file)),
        );

        return;
      }
      // ==========================================================
      // PNG TO PDF
      // ==========================================================

      // ==========================================================
      // PDF TO JPG
      // ==========================================================

      if (widget.toolName == 'PDF to JPG') {
        final file = files.first;

        if (file.path == null || file.path!.isEmpty) {
          _showMessage('Unable to access the selected PDF file.');
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PdfToJpgScreen(selectedFile: file)),
        );

        return;
      }
      // ==========================================================
      // PDF TO PNG
      // ==========================================================

      if (widget.toolName == 'PDF to PNG') {
        final file = files.first;

        if (file.path == null || file.path!.isEmpty) {
          _showMessage('Unable to access the selected PDF file.');
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PdfToPngScreen(selectedFile: file)),
        );

        return;
      }
      // ==========================================================
      // SVG TO PDF
      // ==========================================================

      if (widget.toolName == 'SVG to PDF') {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SvgToPdfScreen(selectedFiles: files),
          ),
        );

        return;
      }
      // ==========================================================
      // PDF TO SVG
      // ==========================================================

      if (widget.toolName == 'PDF to SVG') {
        final file = files.first;

        if (file.path == null || file.path!.isEmpty) {
          _showMessage('Unable to access the selected PDF file.');
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PdfToSvgScreen(selectedFile: file)),
        );

        return;
      }
      // ==========================================================
      // FILL FORMS
      // ==========================================================

      if (widget.toolName == 'Fill Forms') {
        final file = files.first;

        if (file.path == null || file.path!.isEmpty) {
          _showMessage('Unable to access the selected PDF file.');
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FillFormsScreen(selectedFile: file),
          ),
        );

        return;
      }
      if (widget.toolName == 'Watermark PDF') {
        if (files.isEmpty) {
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => WatermarkPdfScreen(selectedFile: files.first),
          ),
        );
        return;
      }
      if (widget.toolName == 'Add Page Numbers') {
        if (files.isEmpty) {
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AddPageNumbersScreen(selectedFile: files.first),
          ),
        );
        return;
      }
      if (widget.toolName == 'OCR') {
        if (files.isEmpty) {
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OcrScreen(selectedFile: files.first),
          ),
        );
        return;
      }
      if (widget.toolName == 'AI Summarize') {
        if (files.isEmpty) {
          return;
        }

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => AiSummarizeScreen(selectedFile: files.first),
          ),
        );
        return;
      }
      // ==========================================================
      // OTHER FILE PICKER TOOLS
      // ==========================================================

      final firstFile = files.first;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PdfPreviewScreen(
            fileName: firstFile.name,
            filePath: firstFile.path,
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ File picker error: $e');

      if (!mounted) return;

      _showMessage('Unable to select file.');
    } finally {
      if (mounted) {
        setState(() {
          _isPicking = false;
        });
      }
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(BuildContext context) {
    return Row(
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
              Text(
                widget.toolName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF10255C),
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose a file to continue',
                style: TextStyle(color: Color(0xFF7184A4), fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // HERO CARD
  // ============================================================

  Widget _buildHeroCard(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.65),
                const Color(0xFFEAF4FF).withValues(alpha: 0.58),
              ],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.85),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6D91C8).withValues(alpha: 0.10),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4B95FF), Color(0xFF0755E8)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1769FF).withValues(alpha: 0.22),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: _isPicking
                    ? const Padding(
                        padding: EdgeInsets.all(29),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(
                        Icons.cloud_upload_rounded,
                        color: Colors.white,
                        size: 42,
                      ),
              ),

              const SizedBox(height: 18),

              const Text(
                'Select Your File',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF10255C),
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Choose the file${widget.allowMultiple ? 's' : ''} '
                'you need for ${widget.toolName}.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF7184A4),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),

              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      icon: _isPicking
                          ? Icons.hourglass_top_rounded
                          : Icons.folder_open_rounded,
                      title: _isPicking ? 'Opening...' : 'Browse Files',
                      onTap: _isPicking ? () {} : _pickFiles,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SUPPORTED FORMATS
  // ============================================================

  Widget _buildSupportedFormats() {
    final formats = <_FormatItem>[];

    if (widget.allowedExtensions.contains('pdf')) {
      formats.add(
        const _FormatItem(
          title: 'PDF',
          subtitle: 'Documents',
          icon: Icons.picture_as_pdf_rounded,
          color: Color(0xFFF45151),
        ),
      );
    }

    if (widget.allowedExtensions.contains('jpg') ||
        widget.allowedExtensions.contains('jpeg')) {
      formats.add(
        const _FormatItem(
          title: 'JPG',
          subtitle: 'Images',
          icon: Icons.image_outlined,
          color: Color(0xFF1769FF),
        ),
      );
    }

    if (widget.allowedExtensions.contains('png')) {
      formats.add(
        const _FormatItem(
          title: 'PNG',
          subtitle: 'Images',
          icon: Icons.photo_outlined,
          color: Color(0xFF12B886),
        ),
      );
    }

    if (widget.allowedExtensions.contains('svg')) {
      formats.add(
        const _FormatItem(
          title: 'SVG',
          subtitle: 'Vector',
          icon: Icons.polyline_outlined,
          color: Color(0xFFFF8A00),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Supported Formats',
          style: TextStyle(
            color: Color(0xFF10255C),
            fontSize: 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          widget.allowMultiple ? 'Select one or more files' : 'Select one file',
          style: const TextStyle(color: Color(0xFF7A8CA6), fontSize: 11.5),
        ),
        const SizedBox(height: 12),
        if (formats.isNotEmpty)
          Row(
            children: formats.map((format) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: format == formats.last ? 0 : 8,
                  ),
                  child: _FormatCard(format: format),
                ),
              );
            }).toList(),
          )
        else
          const Text(
            'No supported formats selected.',
            style: TextStyle(color: Color(0xFF7184A4), fontSize: 12),
          ),
      ],
    );
  }
}

// ============================================================
// ACTION BUTTON
// ============================================================

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool outlined;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.title,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Ink(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            gradient: outlined
                ? null
                : const LinearGradient(
                    colors: [Color(0xFF2D7BFF), Color(0xFF0958EA)],
                  ),
            color: outlined ? Colors.white.withValues(alpha: 0.45) : null,
            border: outlined
                ? Border.all(color: const Color(0xFF9FC2F3), width: 1.1)
                : null,
            boxShadow: outlined
                ? null
                : [
                    BoxShadow(
                      color: const Color(0xFF1769FF).withValues(alpha: 0.20),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: outlined ? const Color(0xFF1769FF) : Colors.white,
                size: 21,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: outlined ? const Color(0xFF1769FF) : Colors.white,
                    fontSize: 13,
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
// FORMAT CARD
// ============================================================

class _FormatCard extends StatelessWidget {
  final _FormatItem format;

  const _FormatCard({required this.format});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(19),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 88,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: Colors.white.withValues(alpha: 0.80)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: format.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(format.icon, color: format.color, size: 18),
              ),
              const SizedBox(height: 5),
              Text(
                format.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF1A2A47),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                format.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFF7A8BA4), fontSize: 8.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// RECENT FILE ROW
// ============================================================

class _RecentFileRow extends StatelessWidget {
  final String name;
  final String size;
  final IconData icon;
  final Color color;

  const _RecentFileRow({
    required this.name,
    required this.size,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 24),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF10255C),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$size  •  Recently',
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
            size: 20,
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

class _PickerBackground extends StatelessWidget {
  const _PickerBackground();

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
            top: 320,
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

// ============================================================
// FORMAT ITEM
// ============================================================

class _FormatItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _FormatItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
