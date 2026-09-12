import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_super_app/core/services/api_service.dart';
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

class OcrScreen extends StatefulWidget {
  final PlatformFile selectedFile;

  const OcrScreen({super.key, required this.selectedFile});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  final TextRecognizer _textRecognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  String _selectedLanguage = 'English';
  String _selectedMode = 'Image to Text';

  bool _isProcessing = false;
  bool _isCompleted = false;

  String _extractedText = '';

  final List<String> _languages = const ['English', 'Urdu', 'Arabic', 'French'];

  @override
  void dispose() {
    _textRecognizer.close();
    super.dispose();
  }

  // ============================================================
  // OCR PROCESSING
  // ============================================================

  Future<void> _extractText() async {
    FocusScope.of(context).unfocus();

    final String? path = widget.selectedFile.path;

    if (path == null || path.isEmpty) {
      _showMessage('Unable to access the selected file.');
      return;
    }

    final File sourceFile = File(path);

    if (!await sourceFile.exists()) {
      _showMessage('Selected file was not found.');
      return;
    }

    // The existence check above is awaited, so the screen may already be gone.
    if (!mounted) {
      return;
    }

    setState(() {
      _isProcessing = true;
      _isCompleted = false;
      _extractedText = '';
    });

    try {
      final String extension =
          widget.selectedFile.extension?.toLowerCase() ?? '';

      String extractedText;

      if (extension == 'jpg' || extension == 'jpeg' || extension == 'png') {
        extractedText = await _extractFromImage(path);
      } else if (extension == 'pdf') {
        extractedText = await _extractFromPdf(path);
      } else {
        throw Exception('Unsupported file type: $extension');
      }

      if (!mounted) return;

      setState(() {
        _extractedText = extractedText.trim();
        _isProcessing = false;
        _isCompleted = true;
      });

      if (_extractedText.isEmpty) {
        _showMessage('No readable text was found in this file.');
        return;
      }

      // ============================================================
      // SAVE OCR HISTORY
      // History stores metadata only.
      // Extracted text/PDF is NOT uploaded to Laravel.
      // ============================================================

      try {
        final response = await ApiService.instance.createHistory(
          toolName: 'OCR',
          fileName: widget.selectedFile.name,
          status: 'completed',
          fileSize: await sourceFile.length(),
          notes:
              'OCR text extracted successfully. '
              'Mode: $_selectedMode, '
              'Language: $_selectedLanguage, '
              'Characters: ${_extractedText.length}. '
              'Output is kept locally on the phone.',
        );

        debugPrint('✅ OCR history API response: ${response.data}');
      } catch (historyError) {
        debugPrint(
          '⚠️ OCR completed, but history could not be saved: '
          '$historyError',
        );
      }
    } catch (e) {
      debugPrint('❌ OCR processing error: $e');

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _isCompleted = false;
        _extractedText = '';
      });

      _showMessage('Unable to extract text from the selected file.');
    }
  }

  // ============================================================
  // IMAGE OCR
  // ============================================================

  Future<String> _extractFromImage(String path) async {
    final InputImage inputImage = InputImage.fromFilePath(path);

    final RecognizedText result = await _textRecognizer.processImage(
      inputImage,
    );

    return result.text;
  }

  // ============================================================
  // PDF OCR
  // ============================================================

  Future<String> _extractFromPdf(String path) async {
    final PdfDocument pdfDocument = await PdfDocument.openFile(path);

    final List<String> pageTexts = <String>[];

    try {
      final int pageCount = pdfDocument.pagesCount;

      for (int pageNumber = 1; pageNumber <= pageCount; pageNumber++) {
        if (!mounted) {
          break;
        }

        final PdfPage page = await pdfDocument.getPage(pageNumber);

        try {
          final PdfPageImage? pageImage = await page.render(
            width: page.width * 2,
            height: page.height * 2,
            format: PdfPageImageFormat.png,
            backgroundColor: '#FFFFFF',
          );

          if (pageImage == null) {
            continue;
          }

          final Directory ocrDirectory = await getTemporaryDirectory();

          final String imagePath =
              '${ocrDirectory.path}/ocr_page_$pageNumber.png';

          final File imageFile = File(imagePath);

          await imageFile.writeAsBytes(pageImage.bytes, flush: true);

          try {
            final InputImage inputImage = InputImage.fromFilePath(imagePath);

            final RecognizedText result = await _textRecognizer.processImage(
              inputImage,
            );

            final String pageText = result.text.trim();

            if (pageText.isNotEmpty) {
              pageTexts.add('Page $pageNumber\n$pageText');
            }
          } finally {
            if (await imageFile.exists()) {
              await imageFile.delete();
            }
          }
        } finally {
          await page.close();
        }
      }
    } finally {
      await pdfDocument.close();
    }

    return pageTexts.join('\n\n');
  }

  // ============================================================
  // COPY
  // ============================================================

  Future<void> _copyText() async {
    if (_extractedText.trim().isEmpty) {
      _showMessage('There is no extracted text to copy.');
      return;
    }

    await Clipboard.setData(ClipboardData(text: _extractedText));

    _showMessage('Text copied successfully.');
  }

  // ============================================================
  // SHARE
  // ============================================================

  Future<void> _shareText() async {
    if (_extractedText.trim().isEmpty) {
      _showMessage('There is no extracted text to share.');
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(text: _extractedText, subject: 'OCR Extracted Text'),
      );
    } catch (e) {
      debugPrint('❌ OCR share error: $e');

      _showMessage('Unable to share the extracted text.');
    }
  }

  // ============================================================
  // SAVE TEXT
  // ============================================================

  Future<void> _saveText() async {
    if (_extractedText.trim().isEmpty) {
      _showMessage('There is no extracted text to save.');
      return;
    }

    try {
      final Directory directory = await getApplicationDocumentsDirectory();

      final String fileName =
          'OCR_Text_'
          '${DateTime.now().millisecondsSinceEpoch}.txt';

      final String outputPath = '${directory.path}/$fileName';

      final File outputFile = File(outputPath);

      await outputFile.writeAsString(_extractedText, flush: true);

      if (!await outputFile.exists()) {
        throw Exception('OCR text file was not created.');
      }

      final int outputFileSize = await outputFile.length();

      // ============================================================
      // SAVE OUTPUT HISTORY
      // Metadata only — actual TXT stays on phone.
      // ============================================================

      try {
        final response = await ApiService.instance.createHistory(
          toolName: 'OCR',
          fileName: widget.selectedFile.name,
          outputFileName: fileName,
          status: 'completed',
          fileSize: outputFileSize,
          notes:
              'OCR extracted text saved locally. '
              'Mode: $_selectedMode, '
              'Language: $_selectedLanguage, '
              'Characters: ${_extractedText.length}.',
        );

        debugPrint(
          '✅ OCR save history API response: '
          '${response.data}',
        );
      } catch (historyError) {
        debugPrint(
          '⚠️ OCR text saved locally, but history could not '
          'be saved: $historyError',
        );
      }

      if (!mounted) return;

      _showMessage('Text saved successfully.');
    } catch (e) {
      debugPrint('❌ OCR save error: $e');

      _showMessage('Unable to save the extracted text.');
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
            const _OcrBackground(),

            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildModeSelector()),
                SliverToBoxAdapter(child: _buildSelectedFile()),
                SliverToBoxAdapter(child: _buildPreview()),
                SliverToBoxAdapter(child: _buildLanguageSelector()),
                SliverToBoxAdapter(child: _buildExtractButton()),
                if (_isCompleted) SliverToBoxAdapter(child: _buildResult()),
                const SliverPadding(padding: EdgeInsets.only(bottom: 30)),
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
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: Row(
        children: [
          _GlassIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'OCR',
                  style: TextStyle(
                    color: Color(0xFF10255C),
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Extract text from your document',
                  style: TextStyle(color: Color(0xFF7487A4), fontSize: 12),
                ),
              ],
            ),
          ),
          _GlassIconButton(
            icon: Icons.info_outline_rounded,
            onTap: () {
              _showMessage('OCR detects text from images and PDF documents.');
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MODE SELECTOR
  // ============================================================

  Widget _buildModeSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            height: 54,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.46),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _ModeButton(
                    title: 'Image to Text',
                    selected: _selectedMode == 'Image to Text',
                    onTap: () {
                      setState(() {
                        _selectedMode = 'Image to Text';
                        _isCompleted = false;
                      });
                    },
                  ),
                ),
                Expanded(
                  child: _ModeButton(
                    title: 'PDF to Text',
                    selected: _selectedMode == 'PDF to Text',
                    onTap: () {
                      setState(() {
                        _selectedMode = 'PDF to Text';
                        _isCompleted = false;
                      });
                    },
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
  // SELECTED FILE
  // ============================================================

  Widget _buildSelectedFile() {
    final String extension = widget.selectedFile.extension?.toLowerCase() ?? '';

    final bool isPdf = extension == 'pdf';

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isPdf
                        ? const Color(0xFFFFEEEE)
                        : const Color(0xFFEAF3FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isPdf ? Icons.picture_as_pdf_rounded : Icons.image_outlined,
                    color: isPdf
                        ? const Color(0xFFF45151)
                        : const Color(0xFF1769FF),
                    size: 26,
                  ),
                ),
                const SizedBox(width: 11),
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
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isPdf ? 'PDF document' : 'Image file',
                        style: const TextStyle(
                          color: Color(0xFF788BA7),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const _SmallChip(
                  label: 'Ready',
                  icon: Icons.check_circle_rounded,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // PREVIEW
  // ============================================================

  Widget _buildPreview() {
    final bool isProcessing = _isProcessing;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: double.infinity,
            height: 320,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.42),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withValues(alpha: 0.80)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6D91C8).withValues(alpha: 0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                Center(
                  child: Container(
                    width: 205,
                    height: 282,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(9),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF536C94,
                          ).withValues(alpha: 0.13),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 80,
                          height: 9,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1769FF),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Research Paper',
                          style: TextStyle(
                            color: Color(0xFF17284A),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 14),
                        ...List.generate(9, (index) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              width: index == 8 ? 80 : 160,
                              height: 6,
                              decoration: BoxDecoration(
                                color: const Color(0xFFDCE5F2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          );
                        }),
                        const Spacer(),
                        Container(
                          width: double.infinity,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF3FF),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: const Icon(
                            Icons.image_outlined,
                            color: Color(0xFF1769FF),
                            size: 25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  left: 20,
                  top: 20,
                  child: const _CornerMarker(alignment: Alignment.topLeft),
                ),
                Positioned(
                  right: 20,
                  top: 20,
                  child: const _CornerMarker(alignment: Alignment.topRight),
                ),
                Positioned(
                  left: 20,
                  bottom: 20,
                  child: const _CornerMarker(alignment: Alignment.bottomLeft),
                ),
                Positioned(
                  right: 20,
                  bottom: 20,
                  child: const _CornerMarker(alignment: Alignment.bottomRight),
                ),
                Positioned(
                  left: 35,
                  right: 35,
                  top: 150,
                  child: Container(
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          const Color(0xFF1769FF).withValues(alpha: 0.80),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                if (isProcessing)
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.72),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text(
                            'Reading document...',
                            style: TextStyle(
                              color: Color(0xFF1769FF),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
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
  // LANGUAGE
  // ============================================================

  Widget _buildLanguageSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.44),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.80)),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE7F0FF),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.language_rounded,
                    color: Color(0xFF1769FF),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Language',
                        style: TextStyle(
                          color: Color(0xFF243653),
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Choose the text language',
                        style: TextStyle(
                          color: Color(0xFF7A8BA4),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  initialValue: _selectedLanguage,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  onSelected: (value) {
                    setState(() {
                      _selectedLanguage = value;
                      _isCompleted = false;
                    });
                  },
                  itemBuilder: (context) {
                    return _languages
                        .map(
                          (language) => PopupMenuItem<String>(
                            value: language,
                            child: Text(language),
                          ),
                        )
                        .toList();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE7F0FF),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _selectedLanguage,
                          style: const TextStyle(
                            color: Color(0xFF1769FF),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Color(0xFF1769FF),
                          size: 17,
                        ),
                      ],
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
  // EXTRACT BUTTON
  // ============================================================

  Widget _buildExtractButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
      child: SizedBox(
        width: double.infinity,
        height: 58,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isProcessing ? null : _extractText,
            borderRadius: BorderRadius.circular(18),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: LinearGradient(
                  colors: _isProcessing
                      ? [const Color(0xFF7BAEFF), const Color(0xFF5A8FEA)]
                      : [const Color(0xFF2D7BFF), const Color(0xFF0958EA)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1769FF).withValues(alpha: 0.24),
                    blurRadius: 20,
                    offset: const Offset(0, 9),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isProcessing)
                    const SizedBox(
                      width: 19,
                      height: 19,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Icon(
                      Icons.text_snippet_outlined,
                      color: Colors.white,
                      size: 21,
                    ),
                  const SizedBox(width: 9),
                  Text(
                    _isProcessing ? 'Extracting Text...' : 'Extract Text',
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

  // ============================================================
  // RESULT
  // ============================================================

  Widget _buildResult() {
    final bool hasText = _extractedText.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6D91C8).withValues(alpha: 0.08),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Extracted Text',
                        style: TextStyle(
                          color: Color(0xFF10255C),
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (hasText)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F8EF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF12A86B),
                              size: 14,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Done',
                              style: TextStyle(
                                color: Color(0xFF12A86B),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 130),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.60),
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: const Color(0xFFD9E6F5)),
                  ),
                  child: hasText
                      ? SelectableText(
                          _extractedText,
                          style: const TextStyle(
                            color: Color(0xFF334663),
                            fontSize: 13,
                            height: 1.65,
                          ),
                        )
                      : const Text(
                          'No readable text found.',
                          style: TextStyle(
                            color: Color(0xFF7A8BA4),
                            fontSize: 13,
                          ),
                        ),
                ),
                if (hasText) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _ResultButton(
                          icon: Icons.copy_outlined,
                          title: 'Copy',
                          onTap: _copyText,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: _ResultButton(
                          icon: Icons.share_outlined,
                          title: 'Share',
                          onTap: _shareText,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: _ResultButton(
                          icon: Icons.download_outlined,
                          title: 'Save',
                          onTap: _saveText,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// RESULT BUTTON
// ============================================================

class _ResultButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ResultButton({
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
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF3FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD4E4F7)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFF1769FF), size: 17),
              const SizedBox(width: 5),
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF1769FF),
                  fontSize: 11,
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
// MODE BUTTON
// ============================================================

class _ModeButton extends StatelessWidget {
  final String title;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({
    required this.title,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1769FF) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: selected ? Colors.white : const Color(0xFF7184A4),
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SMALL CHIP
// ============================================================

class _SmallChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _SmallChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F5EE),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF12A86B), size: 14),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF12A86B),
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CORNER MARKER
// ============================================================

class _CornerMarker extends StatelessWidget {
  final Alignment alignment;

  const _CornerMarker({required this.alignment});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: CustomPaint(painter: _CornerPainter(alignment: alignment)),
    );
  }
}

// ============================================================
// CORNER PAINTER
// ============================================================

class _CornerPainter extends CustomPainter {
  final Alignment alignment;

  const _CornerPainter({required this.alignment});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = const Color(0xFF1769FF)
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Path path = Path();

    if (alignment == Alignment.topLeft) {
      path.moveTo(2, 27);
      path.lineTo(2, 2);
      path.lineTo(27, 2);
    } else if (alignment == Alignment.topRight) {
      path.moveTo(2, 2);
      path.lineTo(27, 2);
      path.lineTo(27, 27);
    } else if (alignment == Alignment.bottomLeft) {
      path.moveTo(2, 2);
      path.lineTo(2, 27);
      path.lineTo(27, 27);
    } else {
      path.moveTo(2, 27);
      path.lineTo(27, 27);
      path.lineTo(27, 2);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter oldDelegate) {
    return false;
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

class _OcrBackground extends StatelessWidget {
  const _OcrBackground();

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
              color: const Color(0xFF7EB3FF).withValues(alpha: 0.27),
            ),
          ),
          Positioned(
            top: 360,
            left: -120,
            child: _BlurCircle(
              size: 250,
              color: const Color(0xFF4C8EFF).withValues(alpha: 0.13),
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
