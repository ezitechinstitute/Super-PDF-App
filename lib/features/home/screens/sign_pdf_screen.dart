import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdfx/pdfx.dart' as pdfx;
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:pdf_super_app/core/services/api_service.dart';
import 'package:pdf_super_app/features/home/screens/pdf_preview_screen.dart';

class SignPdfScreen extends StatefulWidget {
  final PlatformFile selectedFile;

  const SignPdfScreen({super.key, required this.selectedFile});

  @override
  State<SignPdfScreen> createState() => _SignPdfScreenState();
}

enum _SignatureMethod { draw, type }

class _SignPdfScreenState extends State<SignPdfScreen> {
  // ============================================================
  // DRAW SIGNATURE
  // ============================================================

  final GlobalKey _signatureCanvasKey = GlobalKey();

  final List<List<Offset>> _signatureStrokes = <List<Offset>>[];

  List<Offset>? _currentStroke;

  // ============================================================
  // TYPE SIGNATURE
  // ============================================================

  final TextEditingController _typedSignatureController =
      TextEditingController();

  _SignatureMethod _signatureMethod = _SignatureMethod.draw;

  /// Where the signature sits on the page, as a fraction of page width and
  /// height, measured to the centre of the signature. The default matches the
  /// bottom-centre placement this screen used before it could be moved.
  Offset _signatureAnchor = const Offset(0.5, 0.88);

  /// Dancing Script, read from the bundle so it can be embedded in the PDF.
  /// Standard PDF fonts have no cursive face, so without this the "Cursive"
  /// style could only ever be italic Times.
  Uint8List? _cursiveFontBytes;

  /// A render of the selected page, shown behind the draggable signature so
  /// the position can be judged against the actual content.
  Uint8List? _pagePreview;
  bool _isRenderingPreview = false;
  double _pageAspectRatio = 1 / 1.414;

  int _selectedSignatureStyle = 0;

  final List<String> _signatureFontFamilies = <String>[
    'Cursive',
    'Serif',
    'Sans',
  ];

  /// Reads the bundled cursive font. A failure here is not fatal: the typed
  /// signature falls back to the italic serif face it used before.
  Future<void> _loadCursiveFont() async {
    try {
      final ByteData data = await rootBundle.load(
        'assets/fonts/DancingScript-Regular.ttf',
      );

      if (!mounted) return;

      setState(() {
        _cursiveFontBytes = data.buffer.asUint8List();
      });
    } catch (e) {
      debugPrint('⚠️ Cursive font could not be loaded: $e');
    }
  }

  // ============================================================
  // PDF
  // ============================================================

  PdfDocument? _document;

  int _pageCount = 0;
  int _selectedPageIndex = 0;

  bool _isLoading = true;
  bool _isSigning = false;

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void initState() {
    super.initState();
    unawaited(_loadCursiveFont());
    _loadPdf();
  }

  @override
  void dispose() {
    _document?.dispose();
    _typedSignatureController.dispose();
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
        _selectedPageIndex = 0;
        _isLoading = false;
      });

      unawaited(_renderPagePreview());

      debugPrint('==========================================');
      debugPrint('✍️ SIGN PDF');
      debugPrint('📄 File: ${widget.selectedFile.name}');
      debugPrint('📑 Pages: $pages');
      debugPrint('==========================================');
    } catch (e) {
      debugPrint('❌ Sign PDF load error: $e');

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

  void _selectPage(int index) {
    if (_isSigning) return;

    setState(() {
      _selectedPageIndex = index;
    });

    unawaited(_renderPagePreview());
  }

  // ============================================================
  // PAGE PREVIEW
  // ============================================================

  /// Renders the selected page so the signature can be positioned against the
  /// real content. Failure is not fatal: the positioner falls back to a blank
  /// sheet of the right shape.
  Future<void> _renderPagePreview() async {
    final String? path = widget.selectedFile.path;

    if (path == null || path.trim().isEmpty) return;

    setState(() {
      _isRenderingPreview = true;
      _pagePreview = null;
    });

    pdfx.PdfDocument? document;
    pdfx.PdfPage? page;

    try {
      document = await pdfx.PdfDocument.openFile(path);
      page = await document.getPage(_selectedPageIndex + 1);

      final pdfx.PdfPageImage? image = await page.render(
        width: page.width,
        height: page.height,
        format: pdfx.PdfPageImageFormat.jpeg,
        backgroundColor: '#FFFFFF',
        quality: 70,
      );

      if (!mounted) return;

      setState(() {
        _pagePreview = image?.bytes;
        if (page != null && page.width > 0) {
          _pageAspectRatio = page.width / page.height;
        }
        _isRenderingPreview = false;
      });
    } catch (e) {
      debugPrint('⚠️ Page preview failed: $e');

      if (!mounted) return;

      setState(() {
        _isRenderingPreview = false;
      });
    } finally {
      await page?.close();
      await document?.close();
    }
  }

  // ============================================================
  // SIGNATURE METHOD
  // ============================================================

  void _selectSignatureMethod(_SignatureMethod method) {
    if (_isSigning) return;

    setState(() {
      _signatureMethod = method;
    });
  }

  // ============================================================
  // DRAW STROKE START
  // ============================================================

  void _startSignatureStroke(Offset position) {
    if (_isSigning) return;

    setState(() {
      _currentStroke = <Offset>[position];
      _signatureStrokes.add(_currentStroke!);
    });
  }

  // ============================================================
  // DRAW STROKE UPDATE
  // ============================================================

  void _updateSignatureStroke(Offset position) {
    if (_isSigning || _currentStroke == null) {
      return;
    }

    setState(() {
      _currentStroke!.add(position);
    });
  }

  // ============================================================
  // DRAW STROKE END
  // ============================================================

  void _endSignatureStroke() {
    _currentStroke = null;
  }

  // ============================================================
  // HAS DRAW SIGNATURE
  // ============================================================

  bool get _hasDrawSignature {
    return _signatureStrokes.isNotEmpty;
  }

  // ============================================================
  // HAS TYPE SIGNATURE
  // ============================================================

  bool get _hasTypedSignature {
    return _typedSignatureController.text.trim().isNotEmpty;
  }

  // ============================================================
  // CLEAR
  // ============================================================

  void _clearSignature() {
    if (_isSigning) return;

    setState(() {
      _signatureStrokes.clear();
      _currentStroke = null;
      _typedSignatureController.clear();
    });
  }

  // ============================================================
  // CREATE DRAW SIGNATURE IMAGE
  // ============================================================

  Future<Uint8List> _createDrawSignatureImage() async {
    final BuildContext? canvasContext = _signatureCanvasKey.currentContext;

    if (canvasContext == null) {
      throw Exception('Signature canvas is not ready.');
    }

    final RenderObject? renderObject = canvasContext.findRenderObject();

    if (renderObject is! RenderRepaintBoundary) {
      throw Exception('Signature canvas renderer is not ready.');
    }

    if (!_hasDrawSignature) {
      throw Exception('No drawn signature found.');
    }

    final RenderRepaintBoundary boundary = renderObject;

    final ui.Image image = await boundary.toImage(pixelRatio: 4.0);

    try {
      final ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        throw Exception('Unable to create signature PNG.');
      }

      final Uint8List bytes = byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      );

      debugPrint('✅ Draw signature PNG created');
      debugPrint('📦 PNG bytes: ${bytes.length}');

      return bytes;
    } finally {
      image.dispose();
    }
  }

  // ============================================================
  // CREATE TYPED SIGNATURE PDF
  // ============================================================

  void _drawTypedSignature(PdfPage page) {
    final String text = _typedSignatureController.text.trim();

    if (text.isEmpty) {
      throw Exception('Typed signature is empty.');
    }

    final Size pageSize = page.getClientSize();

    double fontSize = pageSize.width * 0.065;

    fontSize = fontSize.clamp(22.0, 48.0);

    final PdfFont font = _getTypedSignatureFont(fontSize);

    final PdfStringFormat format = PdfStringFormat(
      alignment: PdfTextAlignment.center,
      lineAlignment: PdfVerticalAlignment.middle,
    );

    double boxWidth = pageSize.width * 0.72;

    boxWidth = boxWidth.clamp(250.0, pageSize.width - 30);

    const double boxHeight = 80.0;

    double left = _signatureAnchor.dx * pageSize.width - boxWidth / 2;

    double top = _signatureAnchor.dy * pageSize.height - boxHeight / 2;

    left = left.clamp(10.0, (pageSize.width - boxWidth - 10).clamp(10.0, double.infinity));
    top = top.clamp(10.0, (pageSize.height - boxHeight - 10).clamp(10.0, double.infinity));

    final Rect textRect = Rect.fromLTWH(left, top, boxWidth, boxHeight);

    page.graphics.drawString(
      text,
      font,
      bounds: textRect,
      brush: PdfSolidBrush(PdfColor(16, 37, 92)),
      format: format,
    );

    // Signature underline.
    page.graphics.drawLine(
      PdfPen(PdfColor(180, 193, 215), width: 0.8),
      Offset(left + 35, top + boxHeight - 10),
      Offset(left + boxWidth - 35, top + boxHeight - 10),
    );

    debugPrint('✅ Typed signature added');
    debugPrint('📝 Text: $text');
    debugPrint(
      '🔤 Style: '
      '${_signatureFontFamilies[_selectedSignatureStyle]}',
    );
  }

  // ============================================================
  // TYPED SIGNATURE FONT
  // ============================================================

  PdfFont _getTypedSignatureFont(double fontSize) {
    switch (_selectedSignatureStyle) {
      case 1:
        return PdfStandardFont(
          PdfFontFamily.timesRoman,
          fontSize,
          style: PdfFontStyle.italic,
        );

      case 2:
        return PdfStandardFont(
          PdfFontFamily.helvetica,
          fontSize,
          style: PdfFontStyle.italic,
        );

      case 0:
      default:
        final Uint8List? cursive = _cursiveFontBytes;

        if (cursive != null) {
          return PdfTrueTypeFont(cursive, fontSize);
        }

        // Bundle read failed; italic serif is the closest standard face.
        return PdfStandardFont(
          PdfFontFamily.timesRoman,
          fontSize,
          style: PdfFontStyle.italic,
        );
    }
  }

  // ============================================================
  // SIGN PDF
  // ============================================================

  Future<void> _signPdf() async {
    if (_document == null) {
      _showMessage('PDF is not ready yet.');
      return;
    }

    // ----------------------------------------------------------
    // VALIDATE CURRENT METHOD
    // ----------------------------------------------------------

    if (_signatureMethod == _SignatureMethod.draw && !_hasDrawSignature) {
      _showMessage('Please draw your signature first.');
      return;
    }

    if (_signatureMethod == _SignatureMethod.type && !_hasTypedSignature) {
      _showMessage('Please type your signature first.');
      return;
    }

    if (_isSigning) return;

    setState(() {
      _isSigning = true;
    });

    try {
      debugPrint('==========================================');
      debugPrint('✍️ SIGNING PDF STARTED');
      debugPrint(
        '📑 Selected page: '
        '${_selectedPageIndex + 1}',
      );
      debugPrint(
        '🛠️ Method: '
        '${_signatureMethod == _SignatureMethod.draw ? 'Draw' : 'Type'}',
      );
      debugPrint('==========================================');

      final PdfPage page = _document!.pages[_selectedPageIndex];

      // ========================================================
      // DRAW MODE
      // ========================================================

      if (_signatureMethod == _SignatureMethod.draw) {
        final Uint8List signatureBytes = await _createDrawSignatureImage();

        if (signatureBytes.isEmpty) {
          throw Exception('Signature image is empty.');
        }

        final PdfBitmap signatureBitmap = PdfBitmap(signatureBytes);

        final Size pageSize = page.getClientSize();

        double signatureWidth = pageSize.width * 0.36;

        signatureWidth = signatureWidth.clamp(130.0, 230.0);

        final double bitmapWidth = signatureBitmap.width.toDouble();

        final double bitmapHeight = signatureBitmap.height.toDouble();

        double signatureHeight;

        if (bitmapWidth > 0 && bitmapHeight > 0) {
          signatureHeight = signatureWidth * bitmapHeight / bitmapWidth;
        } else {
          signatureHeight = 75.0;
        }

        signatureHeight = signatureHeight.clamp(50.0, 120.0);

        // Anchor is the signature's centre, as a fraction of the page.
        double left = _signatureAnchor.dx * pageSize.width - signatureWidth / 2;

        double top = _signatureAnchor.dy * pageSize.height - signatureHeight / 2;

        if (left < 10) {
          left = 10;
        }

        if (top < 10) {
          top = 10;
        }

        if (left + signatureWidth > pageSize.width - 10) {
          left = pageSize.width - signatureWidth - 10;
        }

        if (top + signatureHeight > pageSize.height - 10) {
          top = pageSize.height - signatureHeight - 10;
        }

        final Rect signatureRect = Rect.fromLTWH(
          left,
          top,
          signatureWidth,
          signatureHeight,
        );

        page.graphics.drawImage(signatureBitmap, signatureRect);

        debugPrint('✅ Draw signature added to PDF');
      }
      // ========================================================
      // TYPE MODE
      // ========================================================
      else {
        _drawTypedSignature(page);
      }

      // ========================================================
      // SAVE
      // ========================================================

      final List<int> outputBytes = await _document!.save();

      if (outputBytes.isEmpty) {
        throw Exception('Signed PDF is empty.');
      }

      final Directory directory = await getApplicationDocumentsDirectory();

      final String fileName =
          'Signed_Document_'
          '${DateTime.now().millisecondsSinceEpoch}.pdf';

      final String outputPath = '${directory.path}/$fileName';

      final File outputFile = File(outputPath);

      await outputFile.writeAsBytes(outputBytes, flush: true);

      final int outputSize = await outputFile.length();

      if (outputSize <= 0) {
        throw Exception('Signed PDF file is empty.');
      }

      debugPrint('✅ Signed PDF written to disk');
      debugPrint('📦 Output size: $outputSize bytes');

      // ========================================================
      // SAVE HISTORY METADATA
      // ========================================================

      try {
        final response = await ApiService.instance.createHistory(
          toolName: 'Sign PDF',
          fileName: widget.selectedFile.name,
          outputFileName: fileName,
          status: 'completed',
          fileSize: outputSize,
          notes:
              'PDF signed using '
              '${_signatureMethod == _SignatureMethod.draw ? 'draw' : 'typed'} '
              'signature on page ${_selectedPageIndex + 1}.',
        );

        debugPrint(
          '✅ Sign PDF history API response: '
          '${response.data}',
        );
      } catch (historyError) {
        debugPrint(
          '⚠️ Sign PDF completed, but history '
          'could not be saved: $historyError',
        );
      }

      debugPrint('==========================================');
      debugPrint('✅ SIGNING COMPLETED');
      debugPrint('==========================================');

      if (!mounted) return;

      setState(() {
        _isSigning = false;
      });

      _showMessage('PDF signed successfully.');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PdfPreviewScreen(fileName: fileName, filePath: outputPath),
        ),
      );
    } catch (e) {
      debugPrint('==========================================');
      debugPrint('❌ SIGN PDF FAILED');
      debugPrint('❌ Error: $e');
      debugPrint('==========================================');

      if (!mounted) return;

      setState(() {
        _isSigning = false;
      });

      _showMessage('Unable to add the signature to this PDF.');
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
            const _SignPdfBackground(),

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
                  SliverToBoxAdapter(child: _buildPageSelector()),
                  SliverToBoxAdapter(child: _buildMethodSelector()),
                  SliverToBoxAdapter(child: _buildSignatureSection()),
                  SliverToBoxAdapter(child: _buildSignButton()),
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
            onTap: _isSigning ? () {} : () => Navigator.pop(context),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sign PDF',
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
                  'Add a signature to your PDF',
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
  // FILE INFO
  // ============================================================

  Widget _buildFileInfo() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
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
                    color: const Color(0xFFF15B78).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: const Icon(
                    Icons.draw_outlined,
                    color: Color(0xFFF15B78),
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
                        'Page ${_selectedPageIndex + 1} selected',
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
  // PAGE SELECTOR
  // ============================================================

  Widget _buildPageSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Page',
            style: TextStyle(
              color: Color(0xFF10255C),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Choose the page where your signature will be added.',
            style: TextStyle(color: Color(0xFF7A8CA6), fontSize: 11.5),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: _pageCount,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final bool selected = _selectedPageIndex == index;

                return GestureDetector(
                  onTap: () => _selectPage(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 72,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFFEFF2FF)
                          : Colors.white.withValues(alpha: 0.50),
                      borderRadius: BorderRadius.circular(17),
                      border: Border.all(
                        color: selected
                            ? const Color(0xFFF15B78)
                            : Colors.white.withValues(alpha: 0.82),
                        width: selected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.picture_as_pdf_rounded,
                          size: 22,
                          color: selected
                              ? const Color(0xFFF15B78)
                              : const Color(0xFF7184A4),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: selected
                                ? const Color(0xFFF15B78)
                                : const Color(0xFF10255C),
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // METHOD SELECTOR
  // ============================================================

  Widget _buildMethodSelector() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Signature Method',
            style: TextStyle(
              color: Color(0xFF10255C),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Draw your signature or type your name.',
            style: TextStyle(color: Color(0xFF7A8CA6), fontSize: 11.5),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _MethodCard(
                  icon: Icons.edit_rounded,
                  title: 'Draw',
                  subtitle: 'Use finger',
                  selected: _signatureMethod == _SignatureMethod.draw,
                  onTap: () => _selectSignatureMethod(_SignatureMethod.draw),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MethodCard(
                  icon: Icons.keyboard_rounded,
                  title: 'Type',
                  subtitle: 'Type name',
                  selected: _signatureMethod == _SignatureMethod.type,
                  onTap: () => _selectSignatureMethod(_SignatureMethod.type),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SIGNATURE SECTION
  // ============================================================

  Widget _buildSignatureSection() {
    if (_signatureMethod == _SignatureMethod.type) {
      return _buildTypedSignatureSection();
    }

    return _buildDrawSignatureSection();
  }

  // ============================================================
  // DRAW SECTION
  // ============================================================

  Widget _buildDrawSignatureSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Draw Signature',
                      style: TextStyle(
                        color: Color(0xFF10255C),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Use your finger to draw your signature.',
                      style: TextStyle(
                        color: Color(0xFF7A8CA6),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _isSigning ? null : _clearSignature,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text(
                  'Clear',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFF15B78),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: double.infinity,
              height: 210,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFBFD6FF).withValues(alpha: 0.85),
                  width: 1.25,
                ),
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: RepaintBoundary(
                      key: _signatureCanvasKey,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onPanStart: (details) {
                          _startSignatureStroke(details.localPosition);
                        },
                        onPanUpdate: (details) {
                          _updateSignatureStroke(details.localPosition);
                        },
                        onPanEnd: (_) {
                          _endSignatureStroke();
                        },
                        child: SizedBox.expand(
                          child: CustomPaint(
                            painter: _SignaturePainter(
                              strokes: _signatureStrokes,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (!_hasDrawSignature)
                    const IgnorePointer(
                      child: Center(
                        child: Text(
                          'Draw your signature here',
                          style: TextStyle(
                            color: Color(0xFF8E9FB8),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    left: 28,
                    right: 28,
                    bottom: 45,
                    child: IgnorePointer(
                      child: Container(
                        height: 1,
                        color: const Color(0xFFC7D4E7),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildPositionSection(),
        ],
      ),
    );
  }

  // ============================================================
  // TYPE SECTION
  // ============================================================

  Widget _buildTypedSignatureSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Type Signature',
                      style: TextStyle(
                        color: Color(0xFF10255C),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Type your name and use it as your signature.',
                      style: TextStyle(
                        color: Color(0xFF7A8CA6),
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: _isSigning ? null : _clearSignature,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text(
                  'Clear',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFF15B78),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.60),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.86),
                  ),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _typedSignatureController,
                      enabled: !_isSigning,
                      maxLength: 60,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) {
                        setState(() {});
                      },
                      style: const TextStyle(
                        color: Color(0xFF10255C),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      decoration: InputDecoration(
                        counterText: '',
                        hintText: 'Enter text',
                        prefixIcon: const Icon(
                          Icons.edit_outlined,
                          color: Color(0xFF1769FF),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFFD9E6FA),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF1769FF),
                            width: 1.3,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: const Text(
                        'Signature Style',
                        style: TextStyle(
                          color: Color(0xFF10255C),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    SizedBox(
                      height: 78,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _signatureFontFamilies.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final bool selected =
                              _selectedSignatureStyle == index;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedSignatureStyle = index;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              width: 116,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? const Color(0xFFEAF2FF)
                                    : Colors.white.withValues(alpha: 0.62),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFF1769FF)
                                      : const Color(0xFFD9E6FA),
                                  width: selected ? 1.4 : 1,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  _typedSignatureController.text.trim().isEmpty
                                      ? 'text'
                                      : _typedSignatureController.text.trim(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: const Color(0xFF10255C),
                                    fontSize: 17,
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FontStyle.italic,
                                    fontFamily: _getPreviewFontFamily(index),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildPositionSection(),
        ],
      ),
    );
  }

  // ============================================================
  // PREVIEW FONT
  // ============================================================

  /// 'cursive' is a CSS generic, not a font family — Flutter never resolved
  /// it, so the cursive preview looked like the default face on Android and
  /// all three looked alike on iOS. The bundled family fixes that, and the
  /// other two use names that do exist on the platform.
  String? _getPreviewFontFamily(int index) {
    switch (index) {
      case 0:
        return 'DancingScript';
      case 1:
        return 'serif';
      case 2:
        return 'sans-serif';
      default:
        return null;
    }
  }

  // ============================================================
  // INFO BOX
  // ============================================================

  // ============================================================
  // POSITION
  // ============================================================

  Widget _buildPositionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Position',
          style: TextStyle(
            color: Color(0xFF10255C),
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Drag the signature to where it should sit on the page.',
          style: TextStyle(color: Color(0xFF7A8CA6), fontSize: 11),
        ),
        const SizedBox(height: 12),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 320),
            child: AspectRatio(
              aspectRatio: _pageAspectRatio,
              child: _buildPositionCanvas(),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton.icon(
            onPressed: _isSigning
                ? null
                : () {
                    setState(() {
                      _signatureAnchor = const Offset(0.5, 0.88);
                    });
                  },
            icon: const Icon(Icons.restart_alt_rounded, size: 18),
            label: const Text('Reset to bottom-centre'),
          ),
        ),
      ],
    );
  }

  Widget _buildPositionCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double w = constraints.maxWidth;
        final double h = constraints.maxHeight;

        // The signature box drawn into the PDF is 36% of page width, so the
        // handle mirrors that. Height follows the drawn strokes' aspect.
        final double boxWidth = w * 0.36;
        final double boxHeight = boxWidth * 0.42;

        void moveTo(Offset local) {
          final double halfW = boxWidth / 2 / w;
          final double halfH = boxHeight / 2 / h;

          setState(() {
            _signatureAnchor = Offset(
              (local.dx / w).clamp(halfW, 1 - halfW),
              (local.dy / h).clamp(halfH, 1 - halfH),
            );
          });
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _isSigning ? null : (d) => moveTo(d.localPosition),
            onPanUpdate: _isSigning ? null : (d) => moveTo(d.localPosition),
            child: Stack(
              fit: StackFit.expand,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFC7D4E7)),
                  ),
                  child: _pagePreview != null
                      ? Image.memory(_pagePreview!, fit: BoxFit.fill)
                      : Center(
                          child: _isRenderingPreview
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.description_outlined,
                                  color: Color(0xFFC7D4E7),
                                  size: 34,
                                ),
                        ),
                ),
                Positioned(
                  left: _signatureAnchor.dx * w - boxWidth / 2,
                  top: _signatureAnchor.dy * h - boxHeight / 2,
                  width: boxWidth,
                  height: boxHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1769FF).withValues(alpha: 0.10),
                      border: Border.all(
                        color: const Color(0xFF1769FF),
                        width: 1.4,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.draw_rounded,
                        size: 18,
                        color: Color(0xFF1769FF),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // SIGN BUTTON
  // ============================================================

  Widget _buildSignButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: _isSigning ? null : _signPdf,
          icon: _isSigning
              ? const SizedBox(
                  width: 21,
                  height: 21,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.draw_rounded),
          label: Text(
            _isSigning ? 'Signing PDF...' : 'Apply Signature',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF15B78),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(
              0xFFF15B78,
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
                color: Color(0xFFF15B78),
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
// METHOD CARD
// ============================================================

class _MethodCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _MethodCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFEAF2FF)
              : Colors.white.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? const Color(0xFF1769FF) : const Color(0xFFD9E6FA),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: selected
                    ? const Color(0xFF1769FF).withValues(alpha: 0.12)
                    : const Color(0xFFEAF2FF),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                icon,
                color: selected
                    ? const Color(0xFF1769FF)
                    : const Color(0xFF7085A5),
                size: 21,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF10255C),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: Color(0xFF7A8CA6),
                      fontSize: 10,
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
}

// ============================================================
// SIGNATURE PAINTER
// ============================================================

class _SignaturePainter extends CustomPainter {
  final List<List<Offset>> strokes;

  const _SignaturePainter({required this.strokes});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint strokePaint = Paint()
      ..color = const Color(0xFF10255C)
      ..strokeWidth = 3.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke
      ..isAntiAlias = true;

    final Paint dotPaint = Paint()
      ..color = const Color(0xFF10255C)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    for (final List<Offset> stroke in strokes) {
      if (stroke.isEmpty) {
        continue;
      }

      if (stroke.length == 1) {
        canvas.drawCircle(stroke.first, 2.0, dotPaint);
        continue;
      }

      final Path path = Path();

      path.moveTo(stroke.first.dx, stroke.first.dy);

      for (int i = 1; i < stroke.length; i++) {
        path.lineTo(stroke[i].dx, stroke[i].dy);
      }

      canvas.drawPath(path, strokePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) {
    return true;
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

class _SignPdfBackground extends StatelessWidget {
  const _SignPdfBackground();

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
