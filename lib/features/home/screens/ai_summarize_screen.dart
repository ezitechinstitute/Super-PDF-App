import 'dart:io';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_super_app/core/services/api_service.dart';
import 'package:pdf_super_app/features/home/screens/pdf_preview_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class AiSummarizeScreen extends StatefulWidget {
  final PlatformFile selectedFile;

  const AiSummarizeScreen({super.key, required this.selectedFile});

  @override
  State<AiSummarizeScreen> createState() => _AiSummarizeScreenState();
}

class _AiSummarizeScreenState extends State<AiSummarizeScreen> {
  String _summaryLength = 'Medium';

  bool _isProcessing = false;
  bool _isCompleted = false;

  String _summaryText = '';
  List<String> _keyPoints = <String>[];

  // ============================================================
  // SUMMARIZE DOCUMENT
  // ============================================================

  Future<void> _summarizeDocument() async {
    FocusScope.of(context).unfocus();

    final String? path = widget.selectedFile.path;

    if (path == null || path.isEmpty) {
      _showMessage('Unable to access the selected PDF.');
      return;
    }

    final File sourceFile = File(path);

    if (!await sourceFile.exists()) {
      _showMessage('Selected PDF file was not found.');
      return;
    }

    setState(() {
      _isProcessing = true;
      _isCompleted = false;
      _summaryText = '';
      _keyPoints = <String>[];
    });

    PdfDocument? document;

    try {
      final List<int> bytes = await sourceFile.readAsBytes();

      document = PdfDocument(inputBytes: bytes);

      final PdfTextExtractor extractor = PdfTextExtractor(document);

      final String extractedText = extractor.extractText().trim();

      if (!mounted) return;

      if (extractedText.isEmpty) {
        setState(() {
          _isProcessing = false;
          _isCompleted = false;
        });

        _showMessage('No readable text was found in this PDF.');
        return;
      }

      final _SummaryResult result = _createLocalSummary(extractedText);

      if (!mounted) return;

      setState(() {
        _summaryText = result.summary;
        _keyPoints = result.keyPoints;
        _isProcessing = false;
        _isCompleted = true;
      });

      // ============================================================
      // SAVE AI SUMMARY HISTORY
      // Metadata only.
      // PDF and summary text are NOT uploaded to Laravel.
      // ============================================================

      try {
        final response = await ApiService.instance.createHistory(
          toolName: 'AI Summarize',
          fileName: widget.selectedFile.name,
          status: 'completed',
          fileSize: await sourceFile.length(),
          notes:
              'Local AI-style summary generated successfully. '
              'Summary length: $_summaryLength. '
              'Key points: ${_keyPoints.length}. '
              'Characters analyzed: ${extractedText.length}. '
              'PDF remains stored locally on the phone.',
        );

        debugPrint(
          '✅ AI Summarize history API response: '
          '${response.data}',
        );
      } catch (historyError) {
        debugPrint(
          '⚠️ AI Summarize completed, but history could not '
          'be saved: $historyError',
        );
      }
    } catch (e) {
      debugPrint('❌ AI Summarize error: $e');

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
        _isCompleted = false;
      });

      _showMessage('Unable to process the selected PDF.');
    } finally {
      document?.dispose();
    }
  }

  // ============================================================
  // LOCAL SUMMARY
  // ============================================================

  _SummaryResult _createLocalSummary(String text) {
    final String normalizedText = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (normalizedText.isEmpty) {
      return const _SummaryResult(
        summary: 'No readable text was found.',
        keyPoints: <String>[],
      );
    }

    final List<String> sentences = normalizedText
        .split(RegExp(r'(?<=[.!?])\s+'))
        .map((sentence) => sentence.trim())
        .where((sentence) => sentence.isNotEmpty)
        .toList();

    int targetSentenceCount;

    switch (_summaryLength) {
      case 'Short':
        targetSentenceCount = 3;
        break;

      case 'Detailed':
        targetSentenceCount = 8;
        break;

      case 'Medium':
      default:
        targetSentenceCount = 5;
        break;
    }

    final List<String> selectedSentences = sentences
        .take(targetSentenceCount)
        .toList();

    final String summary = selectedSentences.isEmpty
        ? normalizedText.substring(
            0,
            normalizedText.length > 800 ? 800 : normalizedText.length,
          )
        : selectedSentences.join(' ');

    final List<String> keyPoints = _buildKeyPoints(sentences);

    return _SummaryResult(summary: summary, keyPoints: keyPoints);
  }

  // ============================================================
  // KEY POINTS
  // ============================================================

  List<String> _buildKeyPoints(List<String> sentences) {
    final List<String> points = <String>[];

    for (final String sentence in sentences) {
      final String cleanSentence = sentence.trim();

      if (cleanSentence.length < 35) {
        continue;
      }

      points.add(cleanSentence);

      if (points.length >= 4) {
        break;
      }
    }

    if (points.isEmpty && sentences.isNotEmpty) {
      points.add(sentences.first);
    }

    return points;
  }

  // ============================================================
  // COPY SUMMARY
  // ============================================================

  Future<void> _copySummary() async {
    if (_summaryText.trim().isEmpty) {
      _showMessage('There is no summary to copy.');
      return;
    }

    final String textToCopy = _buildShareableText();

    await Clipboard.setData(ClipboardData(text: textToCopy));

    _showMessage('Summary copied successfully.');
  }

  // ============================================================
  // SHARE SUMMARY
  // ============================================================

  Future<void> _shareSummary() async {
    if (_summaryText.trim().isEmpty) {
      _showMessage('There is no summary to share.');
      return;
    }

    try {
      await SharePlus.instance.share(
        ShareParams(text: _buildShareableText(), subject: 'AI Summary'),
      );
    } catch (e) {
      debugPrint('❌ Summary share error: $e');

      _showMessage('Unable to share the summary.');
    }
  }

  // ============================================================
  // SAVE SUMMARY
  // ============================================================

  Future<void> _saveSummary() async {
    if (_summaryText.trim().isEmpty) {
      _showMessage('There is no summary to save.');
      return;
    }

    try {
      final Directory directory = await getApplicationDocumentsDirectory();

      final String fileName =
          'AI_Summary_'
          '${DateTime.now().millisecondsSinceEpoch}.txt';

      final String outputPath = '${directory.path}/$fileName';

      final File outputFile = File(outputPath);

      final String shareableText = _buildShareableText();

      await outputFile.writeAsString(shareableText, flush: true);

      if (!await outputFile.exists()) {
        throw Exception('Summary file was not created.');
      }

      final int outputFileSize = await outputFile.length();

      // ============================================================
      // SAVE OUTPUT HISTORY
      // Metadata only.
      // Actual TXT stays on phone.
      // ============================================================

      try {
        final response = await ApiService.instance.createHistory(
          toolName: 'AI Summarize',
          fileName: widget.selectedFile.name,
          outputFileName: fileName,
          status: 'completed',
          fileSize: outputFileSize,
          notes:
              'Local AI summary saved as TXT. '
              'Summary length: $_summaryLength. '
              'Key points: ${_keyPoints.length}.',
        );

        debugPrint(
          '✅ AI Summary save history API response: '
          '${response.data}',
        );
      } catch (historyError) {
        debugPrint(
          '⚠️ Summary saved locally, but history could not '
          'be saved: $historyError',
        );
      }

      if (!mounted) return;

      _showMessage('Summary saved successfully.');
    } catch (e) {
      debugPrint('❌ Summary save error: $e');

      _showMessage('Unable to save the summary.');
    }
  }

  // ============================================================
  // SHAREABLE TEXT
  // ============================================================

  String _buildShareableText() {
    final StringBuffer buffer = StringBuffer();

    buffer.writeln('AI Summary');
    buffer.writeln();
    buffer.writeln(_summaryText);

    if (_keyPoints.isNotEmpty) {
      buffer.writeln();
      buffer.writeln('Key Points');

      for (final String point in _keyPoints) {
        buffer.writeln('• $point');
      }
    }

    return buffer.toString().trim();
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
            const _AiBackground(),
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildHeroBanner()),
                SliverToBoxAdapter(child: _buildFileCard()),
                SliverToBoxAdapter(child: _buildLengthSelector()),
                SliverToBoxAdapter(child: _buildSummarizeButton()),
                if (_isCompleted)
                  SliverToBoxAdapter(child: _buildSummaryResult()),
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
                  'AI Summarize',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Color(0xFF10255C),
                    fontSize: 27,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Understand your document faster',
                  style: TextStyle(color: Color(0xFF7487A4), fontSize: 12),
                ),
              ],
            ),
          ),
          _GlassIconButton(
            icon: Icons.auto_awesome_rounded,
            iconColor: const Color(0xFF7A5AF8),
            onTap: () {
              _showMessage('AI Assistant is ready.');
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HERO BANNER
  // ============================================================

  Widget _buildHeroBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF5A98FF),
                  Color(0xFF1769FF),
                  Color(0xFF0958E8),
                ],
              ),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1769FF).withValues(alpha: 0.23),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.24),
                    ),
                  ),
                  child: const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI-Powered Summary',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 5),
                      Text(
                        'Get a clear summary and important points from your document.',
                        style: TextStyle(
                          color: Color(0xFFEAF3FF),
                          fontSize: 11.5,
                          height: 1.45,
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
  // FILE CARD
  // ============================================================

  Widget _buildFileCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.46),
              borderRadius: BorderRadius.circular(23),
              border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
            ),
            child: Row(
              children: [
                Container(
                  width: 49,
                  height: 49,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEEEE),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf_rounded,
                    color: Color(0xFFF45151),
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
                      const Text(
                        'Selected PDF',
                        style: TextStyle(
                          color: Color(0xFF788BA7),
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF3FF),
                    borderRadius: BorderRadius.circular(11),
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
  // LENGTH SELECTOR
  // ============================================================

  Widget _buildLengthSelector() {
    const List<String> lengths = ['Short', 'Medium', 'Detailed'];

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.44),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withValues(alpha: 0.80)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Summary Length',
                  style: TextStyle(
                    color: Color(0xFF243653),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 11),
                Row(
                  children: lengths.map((length) {
                    final bool selected = _summaryLength == length;

                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: length == lengths.last ? 0 : 7,
                        ),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _summaryLength = length;
                              _isCompleted = false;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            height: 44,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: selected
                                  ? const Color(0xFF1769FF)
                                  : Colors.white.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: selected
                                    ? const Color(0xFF1769FF)
                                    : const Color(0xFFD7E4F4),
                              ),
                            ),
                            child: Text(
                              length,
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : const Color(0xFF647994),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SUMMARIZE BUTTON
  // ============================================================

  Widget _buildSummarizeButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: SizedBox(
        width: double.infinity,
        height: 58,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isProcessing ? null : _summarizeDocument,
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
                    color: const Color(0xFF1769FF).withValues(alpha: 0.25),
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
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 21,
                    ),
                  const SizedBox(width: 9),
                  Text(
                    _isProcessing ? 'Analyzing PDF...' : 'Summarize Document',
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
  // SUMMARY RESULT
  // ============================================================

  Widget _buildSummaryResult() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
      child: Column(
        children: [
          _buildSummaryCard(),
          const SizedBox(height: 14),
          _buildKeyPointsCard(),
          const SizedBox(height: 14),
          _buildResultActions(),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY CARD
  // ============================================================

  Widget _buildSummaryCard() {
    return ClipRRect(
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
              const Row(
                children: [
                  Icon(
                    Icons.summarize_outlined,
                    color: Color(0xFF1769FF),
                    size: 21,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Summary',
                    style: TextStyle(
                      color: Color(0xFF10255C),
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.58),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: const Color(0xFFD9E6F5)),
                ),
                child: SelectableText(
                  _summaryText,
                  style: const TextStyle(
                    color: Color(0xFF334663),
                    fontSize: 13,
                    height: 1.6,
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
  // KEY POINTS
  // ============================================================

  Widget _buildKeyPointsCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.46),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    color: Color(0xFFFF9F43),
                    size: 21,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Key Points',
                    style: TextStyle(
                      color: Color(0xFF10255C),
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              if (_keyPoints.isEmpty)
                const Text(
                  'No key points found.',
                  style: TextStyle(color: Color(0xFF4E6380), fontSize: 12),
                )
              else
                ..._keyPoints.map((point) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Color(0xFF1769FF),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Text(
                            point,
                            style: const TextStyle(
                              color: Color(0xFF4E6380),
                              fontSize: 12,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // RESULT ACTIONS
  // ============================================================

  Widget _buildResultActions() {
    return Row(
      children: [
        Expanded(
          child: _ResultAction(
            icon: Icons.copy_outlined,
            title: 'Copy',
            onTap: _copySummary,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _ResultAction(
            icon: Icons.share_outlined,
            title: 'Share',
            onTap: _shareSummary,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _ResultAction(
            icon: Icons.download_outlined,
            title: 'Save',
            onTap: _saveSummary,
          ),
        ),
      ],
    );
  }
}

// ============================================================
// SUMMARY RESULT MODEL
// ============================================================

class _SummaryResult {
  final String summary;
  final List<String> keyPoints;

  const _SummaryResult({required this.summary, required this.keyPoints});
}

// ============================================================
// RESULT ACTION
// ============================================================

class _ResultAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _ResultAction({
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
          height: 48,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD6E4F4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: const Color(0xFF1769FF), size: 18),
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
// GLASS ICON BUTTON
// ============================================================

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final VoidCallback onTap;

  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    this.iconColor,
  });

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
              child: Icon(
                icon,
                color: iconColor ?? const Color(0xFF17345F),
                size: 19,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// AI BACKGROUND
// ============================================================

class _AiBackground extends StatelessWidget {
  const _AiBackground();

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
            top: 330,
            left: -120,
            child: _BlurCircle(
              size: 250,
              color: const Color(0xFF4C8EFF).withValues(alpha: 0.13),
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
