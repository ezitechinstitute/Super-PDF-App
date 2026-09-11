import 'dart:io';
import 'dart:isolate';
import 'dart:ui';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf_super_app/core/services/api_service.dart';
import 'package:pdf_super_app/features/home/screens/pdf_preview_screen.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

enum _ScanFilter { original, auto, magicColor, grayscale, blackWhite }

class ScanDocumentScreen extends StatefulWidget {
  const ScanDocumentScreen({super.key});

  @override
  State<ScanDocumentScreen> createState() => _ScanDocumentScreenState();
}

// ============================================================================
// BACKGROUND IMAGE PROCESSING
// ============================================================================
// Keep these functions top-level so they can safely run inside a Dart isolate.
// No BuildContext, State, CameraController or Flutter UI object is touched here.

TransferableTypedData _processScanImageInBackground(
  TransferableTypedData transferable,
  int filterIndex,
  int maxDimension,
) {
  final Uint8List bytes = transferable.materialize().asUint8List();
  final img.Image? decoded = img.decodeImage(bytes);

  if (decoded == null) {
    throw Exception('Unable to decode scanned image.');
  }

  img.Image working = decoded;

  final int longest = working.width > working.height
      ? working.width
      : working.height;

  if (longest > maxDimension) {
    if (working.width >= working.height) {
      working = img.copyResize(working, width: maxDimension);
    } else {
      working = img.copyResize(working, height: maxDimension);
    }
  }

  // Keep the same filters/visual treatment as the current working version.
  switch (filterIndex) {
    case 3: // grayscale
      _backgroundApplyGrayscale(working);
      break;
    case 4: // black & white
      _backgroundApplyDocumentBlackWhite(working);
      break;
    case 2: // magic color
      _backgroundApplyMagicColor(working);
      break;
    case 1: // auto
      _backgroundApplyAutoDocumentEnhancement(working);
      break;
    case 0: // original
      break;
  }

  final List<int> encoded = img.encodeJpg(working, quality: 94);
  return TransferableTypedData.fromList(<Uint8List>[
    Uint8List.fromList(encoded),
  ]);
}

void _backgroundApplyGrayscale(img.Image image) {
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final img.Pixel p = image.getPixel(x, y);
      final int value = (0.299 * p.r + 0.587 * p.g + 0.114 * p.b).round().clamp(
        0,
        255,
      );
      image.setPixelRgb(x, y, value, value, value);
    }
  }
}

void _backgroundApplyMagicColor(img.Image image) {
  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final img.Pixel p = image.getPixel(x, y);
      final double r = p.r.toDouble();
      final double g = p.g.toDouble();
      final double b = p.b.toDouble();
      final double avg = (r + g + b) / 3.0;
      final double contrast = (avg - 128.0) * 1.20 + 128.0;
      final double factor = contrast / (avg == 0 ? 1.0 : avg);

      final int nr = (128 + (r - 128) * 1.14 * factor).round().clamp(0, 255);
      final int ng = (128 + (g - 128) * 1.14 * factor).round().clamp(0, 255);
      final int nb = (128 + (b - 128) * 1.14 * factor).round().clamp(0, 255);

      image.setPixelRgb(x, y, nr, ng, nb);
    }
  }
}

void _backgroundApplyAutoDocumentEnhancement(img.Image image) {
  final img.Image illumination = img.gaussianBlur(image.clone(), radius: 10);

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final img.Pixel source = image.getPixel(x, y);
      final img.Pixel light = illumination.getPixel(x, y);

      double r = _backgroundNormalizeChannel(
        source.r.toDouble(),
        light.r.toDouble(),
      );
      double g = _backgroundNormalizeChannel(
        source.g.toDouble(),
        light.g.toDouble(),
      );
      double b = _backgroundNormalizeChannel(
        source.b.toDouble(),
        light.b.toDouble(),
      );

      r = _backgroundDocumentContrast(r);
      g = _backgroundDocumentContrast(g);
      b = _backgroundDocumentContrast(b);

      image.setPixelRgb(
        x,
        y,
        r.round().clamp(0, 255),
        g.round().clamp(0, 255),
        b.round().clamp(0, 255),
      );
    }
  }

  final img.Image blur = img.gaussianBlur(image.clone(), radius: 2);

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final img.Pixel p = image.getPixel(x, y);
      final img.Pixel q = blur.getPixel(x, y);

      final int r = (p.r + (p.r - q.r) * 0.55).round().clamp(0, 255);
      final int g = (p.g + (p.g - q.g) * 0.55).round().clamp(0, 255);
      final int b = (p.b + (p.b - q.b) * 0.55).round().clamp(0, 255);

      image.setPixelRgb(x, y, r, g, b);
    }
  }
}

double _backgroundNormalizeChannel(double value, double light) {
  final double safeLight = light < 35.0 ? 35.0 : light;
  final double normalized = value * (215.0 / safeLight);
  return normalized.clamp(0.0, 255.0);
}

double _backgroundDocumentContrast(double value) {
  const double midpoint = 128.0;
  final double adjusted = midpoint + (value - midpoint) * 1.22;

  if (adjusted > 238.0) {
    return 238.0 + (adjusted - 238.0) * 0.35;
  }

  return adjusted.clamp(0.0, 255.0);
}

void _backgroundApplyDocumentBlackWhite(img.Image image) {
  _backgroundApplyGrayscale(image);

  final List<int> histogram = List<int>.filled(256, 0);

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final int value = image.getPixel(x, y).r.round().clamp(0, 255);
      histogram[value]++;
    }
  }

  int total = 0;
  double weighted = 0;

  for (int i = 0; i < 256; i++) {
    total += histogram[i];
    weighted += i * histogram[i];
  }

  double sumBackground = 0;
  int backgroundWeight = 0;
  double threshold = 170.0;
  double bestVariance = -1.0;

  for (int t = 0; t < 256; t++) {
    backgroundWeight += histogram[t];
    if (backgroundWeight == 0) continue;

    final int foregroundWeight = total - backgroundWeight;
    if (foregroundWeight == 0) break;

    sumBackground += t * histogram[t];

    final double meanBackground = sumBackground / backgroundWeight;
    final double meanForeground = (weighted - sumBackground) / foregroundWeight;

    final double variance =
        backgroundWeight.toDouble() *
        foregroundWeight.toDouble() *
        (meanBackground - meanForeground) *
        (meanBackground - meanForeground);

    if (variance > bestVariance) {
      bestVariance = variance;
      threshold = t.toDouble();
    }
  }

  threshold = threshold.clamp(120.0, 205.0);

  for (int y = 0; y < image.height; y++) {
    for (int x = 0; x < image.width; x++) {
      final int value = image.getPixel(x, y).r.round();
      final int output = value >= threshold ? 255 : 0;
      image.setPixelRgb(x, y, output, output, output);
    }
  }
}

class _ScanDocumentScreenState extends State<ScanDocumentScreen>
    with WidgetsBindingObserver {
  CameraController? _cameraController;

  final ImagePicker _imagePicker = ImagePicker();

  final List<XFile> _batchImages = <XFile>[];

  XFile? _capturedImage;

  bool _isInitializing = true;
  bool _flashOn = false;
  bool _isBatchMode = false;
  bool _isProcessing = false;

  bool _isPickingFromGallery = false;

  // ============================================================
  // DOCUMENT ENHANCEMENT
  // ============================================================

  bool _showEnhanceScreen = false;
  bool _isEnhancing = false;
  int _enhancePageIndex = 0;
  _ScanFilter _selectedFilter = _ScanFilter.auto;
  final Map<String, String> _processedImagePaths = <String, String>{};
  String? _enhancePreviewPath;
  bool _filterAppliedToAll = false;

  String? _cameraError;

  // Prevent overlapping camera initialize/dispose operations.
  bool _isCameraInitializing = false;
  int _cameraInitGeneration = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    _cameraInitGeneration++;
    _cameraController?.dispose();

    super.dispose();
  }

  // ============================================================
  // CAMERA INITIALIZE
  // ============================================================

  Future<void> _initializeCamera() async {
    if (!mounted || _isPickingFromGallery || _showEnhanceScreen) {
      return;
    }

    // Never start a second initialize while another initialize is running.
    if (_isCameraInitializing) {
      return;
    }

    final CameraController? existingController = _cameraController;

    // If a working controller already exists, keep it. Disposing and creating
    // another controller here can race with CameraX and cancel configuration.
    if (existingController != null && existingController.value.isInitialized) {
      if (_isInitializing) {
        setState(() {
          _isInitializing = false;
          _cameraError = null;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isInitializing = true;
        _cameraError = null;
      });
    }

    _isCameraInitializing = true;
    final int generation = ++_cameraInitGeneration;
    CameraController? controller;

    try {
      final List<CameraDescription> cameras = await availableCameras();

      if (!mounted ||
          generation != _cameraInitGeneration ||
          _isPickingFromGallery ||
          _showEnhanceScreen) {
        return;
      }

      if (cameras.isEmpty) {
        throw Exception('No camera was found on this device.');
      }

      CameraDescription selectedCamera = cameras.first;

      for (final CameraDescription camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.back) {
          selectedCamera = camera;
          break;
        }
      }

      controller = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      controller.addListener(() {
        if (!mounted || !identical(_cameraController, controller)) {
          return;
        }

        if (controller!.value.hasError) {
          setState(() {
            _cameraError =
                controller!.value.errorDescription ?? 'Camera error occurred.';
          });
        }
      });

      await controller.initialize();

      // The app may have changed state while CameraX was initializing.
      if (!mounted ||
          generation != _cameraInitGeneration ||
          _isPickingFromGallery ||
          _showEnhanceScreen) {
        await controller.dispose();
        controller = null;
        return;
      }

      await controller.setFlashMode(FlashMode.off);

      if (!mounted || generation != _cameraInitGeneration) {
        await controller.dispose();
        controller = null;
        return;
      }

      _cameraController = controller;
      controller = null;

      setState(() {
        _isInitializing = false;
        _flashOn = false;
        _cameraError = null;
      });
    } on CameraException catch (e) {
      debugPrint('❌ Camera initialization error: ${e.code} - ${e.description}');

      if (controller != null) {
        try {
          await controller.dispose();
        } catch (_) {}
      }

      if (!mounted || generation != _cameraInitGeneration) {
        return;
      }

      setState(() {
        _isInitializing = false;
        _cameraError = _cameraErrorMessage(e);
      });
    } catch (e) {
      debugPrint('❌ Camera error: $e');

      if (controller != null) {
        try {
          await controller.dispose();
        } catch (_) {}
      }

      if (!mounted || generation != _cameraInitGeneration) {
        return;
      }

      setState(() {
        _isInitializing = false;
        _cameraError = 'Unable to initialize the camera.';
      });
    } finally {
      _isCameraInitializing = false;
    }
  }

  // ============================================================
  // CAMERA ERROR
  // ============================================================

  String _cameraErrorMessage(CameraException exception) {
    switch (exception.code) {
      case 'CameraAccessDenied':
        return 'Camera permission was denied.';

      case 'CameraAccessDeniedWithoutPrompt':
        return 'Camera permission is disabled. Enable it from Settings.';

      case 'CameraAccessRestricted':
        return 'Camera access is restricted.';

      default:
        return exception.description ?? 'Unable to access the camera.';
    }
  }

  // ============================================================
  // CAMERA LIFECYCLE
  // ============================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // Invalidate any in-flight initialization so its result cannot install
      // a stale controller after the app leaves the foreground.
      _cameraInitGeneration++;

      final CameraController? controller = _cameraController;
      _cameraController = null;

      if (controller != null) {
        controller.dispose().catchError((_) {});
      }

      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }

      return;
    }

    if (state == AppLifecycleState.resumed) {
      if (_isPickingFromGallery ||
          _showEnhanceScreen ||
          _capturedImage != null ||
          _cameraController != null ||
          _isCameraInitializing) {
        return;
      }

      // Let Android finish returning camera ownership before reopening it.
      Future<void>.delayed(const Duration(milliseconds: 200), () {
        if (mounted &&
            !_isPickingFromGallery &&
            !_showEnhanceScreen &&
            _capturedImage == null &&
            _cameraController == null) {
          _initializeCamera();
        }
      });
    }
  }

  // ============================================================
  // FLASH
  // ============================================================

  Future<void> _toggleFlash() async {
    final CameraController? controller = _cameraController;

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    try {
      final bool newFlashState = !_flashOn;

      await controller.setFlashMode(
        newFlashState ? FlashMode.torch : FlashMode.off,
      );

      if (!mounted) return;

      setState(() {
        _flashOn = newFlashState;
      });
    } catch (e) {
      debugPrint('❌ Flash error: $e');

      _showMessage('Flash is not available.');
    }
  }

  // ============================================================
  // CAMERA CAPTURE
  // ============================================================

  Future<void> _captureDocument() async {
    final CameraController? controller = _cameraController;

    if (controller == null || !controller.value.isInitialized) {
      _showMessage('Camera is not ready yet.');
      return;
    }

    if (controller.value.isTakingPicture || _isProcessing) {
      return;
    }

    try {
      setState(() {
        _isProcessing = true;
      });

      final XFile image = await controller.takePicture();

      if (!mounted) return;

      setState(() {
        _capturedImage = image;
        _isProcessing = false;
      });
    } on CameraException catch (e) {
      debugPrint(
        '❌ Capture error: '
        '${e.code} - ${e.description}',
      );

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      _showMessage('Unable to capture the document.');
    } catch (e) {
      debugPrint('❌ Capture error: $e');

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      _showMessage('Unable to capture the document.');
    }
  }

  // ============================================================
  // GALLERY
  // ============================================================

  Future<void> _openGallery() async {
    if (_isProcessing || _isPickingFromGallery) {
      return;
    }

    _isPickingFromGallery = true;

    final CameraController? controller = _cameraController;

    if (controller != null) {
      try {
        await controller.dispose();
      } catch (e) {
        debugPrint('⚠️ Camera dispose before gallery error: $e');
      }

      if (identical(_cameraController, controller)) {
        _cameraController = null;
      }
    }

    if (mounted) {
      setState(() {
        _isInitializing = false;
        _flashOn = false;
      });
    }

    try {
      // ========================================================
      // BATCH GALLERY
      // ========================================================

      if (_isBatchMode) {
        final List<PlatformFile> files = await FilePicker.pickFiles(
          type: FileType.image,
        );

        if (files.isEmpty) {
          return;
        }

        final List<XFile> validImages = <XFile>[];

        for (final PlatformFile file in files) {
          final String? path = file.path;

          if (path == null || path.isEmpty) {
            continue;
          }

          final XFile image = XFile(path);

          if (await _isImageReadable(image)) {
            validImages.add(image);
          }
        }

        if (validImages.isEmpty) {
          _showMessage('Selected images could not be read.');
          return;
        }

        if (!mounted) return;

        setState(() {
          _batchImages.addAll(validImages);
          _capturedImage = null;
        });

        _showMessage(
          '${validImages.length} image'
          '${validImages.length == 1 ? '' : 's'} '
          'added to batch.',
        );

        return;
      }

      // ========================================================
      // SINGLE GALLERY
      // ========================================================

      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 95,
      );

      if (image == null) {
        return;
      }

      final bool readable = await _isImageReadable(image);

      if (!readable) {
        _showMessage('Selected image could not be read.');
        return;
      }

      if (!mounted) return;

      setState(() {
        _capturedImage = image;
      });
    } catch (e, stackTrace) {
      debugPrint('❌ Gallery error: $e');

      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        _showMessage('Unable to select image from gallery.');
      }
    } finally {
      _isPickingFromGallery = false;

      if (mounted && _capturedImage == null) {
        await Future<void>.delayed(const Duration(milliseconds: 250));

        if (mounted && !_isPickingFromGallery && _capturedImage == null) {
          await _initializeCamera();
        }
      }
    }
  }

  // ============================================================
  // IMAGE VALIDATION
  // ============================================================

  Future<bool> _isImageReadable(XFile image) async {
    try {
      final File file = File(image.path);

      if (!await file.exists()) {
        return false;
      }

      final int size = await file.length();

      return size > 0;
    } catch (e) {
      debugPrint('❌ Image validation error: $e');

      return false;
    }
  }

  // ============================================================
  // RETAKE
  // ============================================================

  void _retakeImage() {
    setState(() {
      _capturedImage = null;
    });

    _initializeCamera();
  }

  // ============================================================
  // USE SCAN
  // ============================================================

  Future<void> _useScan() async {
    final XFile? image = _capturedImage;

    if (image == null) {
      return;
    }

    if (_isBatchMode) {
      setState(() {
        _batchImages.add(image);
        _capturedImage = null;
      });

      _showMessage(
        '${_batchImages.length} page'
        '${_batchImages.length == 1 ? '' : 's'} '
        'in batch.',
      );

      await _initializeCamera();

      return;
    }

    await _openEnhancement(<XFile>[image]);
  }

  // ============================================================
  // DOCUMENT ENHANCEMENT
  // ============================================================

  Future<void> _openEnhancement(List<XFile> images) async {
    if (images.isEmpty || _isProcessing || _isEnhancing) {
      return;
    }

    // The camera is no longer needed while enhancement is running.
    // Release its native buffers before decoding the document image.
    final CameraController? controller = _cameraController;
    _cameraController = null;

    if (controller != null) {
      try {
        await controller.dispose();
      } catch (e) {
        debugPrint('⚠️ Camera dispose before enhancement error: $e');
      }
    }

    if (!mounted) return;

    setState(() {
      _showEnhanceScreen = true;
      _enhancePageIndex = 0;
      _selectedFilter = _ScanFilter.auto;
      _enhancePreviewPath = null;
      _filterAppliedToAll = false;
      _processedImagePaths.clear();
    });

    // Start only after the camera has been released.
    await _prepareEnhancementPreview();
  }

  Future<void> _closeEnhancementScreen() async {
    if (_isEnhancing) return;

    setState(() {
      _showEnhanceScreen = false;
      _enhancePreviewPath = null;
    });

    // In batch mode the user can continue scanning after going back.
    if (mounted && _isBatchMode && _capturedImage == null) {
      await _initializeCamera();
    }
  }

  List<XFile> get _enhancementImages {
    if (_isBatchMode) {
      return List<XFile>.from(_batchImages);
    }
    if (_capturedImage != null) {
      return <XFile>[_capturedImage!];
    }
    return <XFile>[];
  }

  Future<void> _prepareEnhancementPreview() async {
    final List<XFile> images = _enhancementImages;
    if (images.isEmpty || !mounted) {
      return;
    }

    final int safeIndex = _enhancePageIndex.clamp(0, images.length - 1);
    final XFile source = images[safeIndex];

    if (_selectedFilter == _ScanFilter.original) {
      if (!mounted) return;
      setState(() {
        _enhancePreviewPath = source.path;
        _isEnhancing = false;
      });
      return;
    }

    setState(() {
      _isEnhancing = true;
    });

    try {
      final String outputPath = await _createEnhancedImage(
        source,
        _selectedFilter,
      );

      if (!mounted) return;
      setState(() {
        _enhancePreviewPath = outputPath;
        _processedImagePaths[source.path] = outputPath;
        _isEnhancing = false;
      });
    } catch (e, stackTrace) {
      debugPrint('❌ Enhancement preview error: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _isEnhancing = false;
        _enhancePreviewPath = source.path;
      });
      _showMessage('Unable to enhance this image.');
    }
  }

  Future<String> _createEnhancedImage(XFile source, _ScanFilter filter) async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final Uint8List bytes = await source.readAsBytes();

    if (bytes.isEmpty) {
      throw Exception('Scanned image is empty.');
    }

    // IMPORTANT:
    // Image decoding + filtering is deliberately moved to a background
    // isolate. The UI isolate must never do millions of pixel operations,
    // otherwise the camera/enhancement screen can freeze or be killed by
    // Android on high-resolution phones.
    final TransferableTypedData input = TransferableTypedData.fromList(
      <Uint8List>[bytes],
    );

    const int maxDimension = 2200;

    final TransferableTypedData result = await Isolate.run(
      () => _processScanImageInBackground(input, filter.index, maxDimension),
    );

    final Uint8List outputBytes = result.materialize().asUint8List();

    if (outputBytes.isEmpty) {
      throw Exception('Enhanced image is empty.');
    }

    final String safeName =
        'scan_${DateTime.now().microsecondsSinceEpoch}_${filter.name}.jpg';
    final String outputPath = '${directory.path}/$safeName';

    final File outputFile = File(outputPath);
    await outputFile.writeAsBytes(outputBytes, flush: true);

    return outputPath;
  }

  Future<void> _applyFilterToAllPages() async {
    final List<XFile> images = _enhancementImages;
    if (images.isEmpty || _isEnhancing) return;

    setState(() {
      _isEnhancing = true;
    });

    try {
      for (final XFile image in images) {
        if (_selectedFilter == _ScanFilter.original) {
          _processedImagePaths[image.path] = image.path;
        } else {
          final String output = await _createEnhancedImage(
            image,
            _selectedFilter,
          );
          _processedImagePaths[image.path] = output;
        }
      }

      if (!mounted) return;
      setState(() {
        _filterAppliedToAll = true;
        _isEnhancing = false;
      });
      _showMessage('Filter applied to all pages.');
    } catch (e, stackTrace) {
      debugPrint('❌ Batch enhancement error: $e');
      debugPrintStack(stackTrace: stackTrace);
      if (!mounted) return;
      setState(() {
        _isEnhancing = false;
      });
      _showMessage('Unable to apply filter to all pages.');
    }
  }

  Future<void> _saveEnhancedScan() async {
    final List<XFile> images = _enhancementImages;
    if (images.isEmpty || _isEnhancing) return;

    if (_isBatchMode && !_filterAppliedToAll) {
      await _applyFilterToAllPages();
      return;
    }

    final List<XFile> finalImages = <XFile>[];
    for (final XFile image in images) {
      final String? processed = _processedImagePaths[image.path];
      finalImages.add(processed == null ? image : XFile(processed));
    }

    setState(() {
      _showEnhanceScreen = false;
    });

    await _createPdfFromImages(finalImages);
  }

  String _filterLabel(_ScanFilter filter) {
    switch (filter) {
      case _ScanFilter.original:
        return 'Original';
      case _ScanFilter.auto:
        return 'Auto Enhance';
      case _ScanFilter.magicColor:
        return 'Magic Color';
      case _ScanFilter.grayscale:
        return 'Grayscale';
      case _ScanFilter.blackWhite:
        return 'B&W';
    }
  }

  // ============================================================
  // CREATE PDF
  // ============================================================

  Future<void> _createPdfFromImages(List<XFile> images) async {
    if (images.isEmpty) {
      _showMessage('No scanned pages available.');
      return;
    }

    if (_isProcessing) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    PdfDocument? document;

    try {
      document = PdfDocument();

      int validImageCount = 0;

      for (final XFile image in images) {
        final List<int> imageBytes = await image.readAsBytes();

        if (imageBytes.isEmpty) {
          continue;
        }

        final PdfBitmap bitmap = PdfBitmap(imageBytes);

        final PdfPage page = document.pages.add();

        final Size pageSize = page.getClientSize();

        final double imageWidth = bitmap.width.toDouble();

        final double imageHeight = bitmap.height.toDouble();

        if (imageWidth <= 0 || imageHeight <= 0) {
          continue;
        }

        validImageCount++;

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

      if (document.pages.count == 0 || validImageCount == 0) {
        throw Exception('No valid images were available for PDF creation.');
      }

      final List<int> outputBytes = await document.save();

      if (outputBytes.isEmpty) {
        throw Exception('Generated PDF is empty.');
      }

      final Directory directory = await getApplicationDocumentsDirectory();

      final String outputFileName =
          'Scanned_Document_'
          '${DateTime.now().millisecondsSinceEpoch}.pdf';

      final String outputPath = '${directory.path}/$outputFileName';

      final File outputFile = File(outputPath);

      await outputFile.writeAsBytes(outputBytes, flush: true);

      if (!await outputFile.exists()) {
        throw Exception('Scanned PDF was not created.');
      }

      final int outputFileSize = await outputFile.length();

      // ============================================================
      // SAVE HISTORY
      //
      // Only metadata is sent to Laravel.
      // Actual scanned PDF remains on the phone.
      // ============================================================

      try {
        final response = await ApiService.instance.createHistory(
          toolName: 'Scan Document',
          fileName: _buildSourceFileName(images.length),
          outputFileName: outputFileName,
          status: 'completed',
          fileSize: outputFileSize,
          notes:
              'Scanned PDF created successfully. '
              'Pages: ${document.pages.count}. '
              'Mode: ${_isBatchMode ? 'Batch' : 'Single'}. '
              'Enhancement: ${_filterLabel(_selectedFilter)}. '
              'Output remains stored locally on the phone.',
        );

        debugPrint(
          '✅ Scan Document history API response: '
          '${response.data}',
        );
      } catch (historyError) {
        debugPrint(
          '⚠️ Scan Document completed, but history '
          'could not be saved: $historyError',
        );
      }

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      _showMessage('Scanned PDF created successfully.');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              PdfPreviewScreen(fileName: outputFileName, filePath: outputPath),
        ),
      );
    } catch (e) {
      debugPrint('❌ Scan PDF creation error: $e');

      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      _showMessage('Unable to create scanned PDF.');
    } finally {
      document?.dispose();
    }
  }

  // ============================================================
  // SOURCE FILE NAME FOR HISTORY
  // ============================================================

  String _buildSourceFileName(int imageCount) {
    if (imageCount == 1) {
      if (_capturedImage != null) {
        return _capturedImage!.name;
      }

      if (_batchImages.length == 1) {
        return _batchImages.first.name;
      }

      return 'Scanned Image';
    }

    return '$imageCount scanned images';
  }

  // ============================================================
  // CREATE BATCH PDF
  // ============================================================

  Future<void> _createBatchPdf() async {
    if (_batchImages.isEmpty) {
      _showMessage('No pages have been added yet.');
      return;
    }

    await _openEnhancement(List<XFile>.from(_batchImages));
  }

  // ============================================================
  // REMOVE BATCH PAGE
  // ============================================================

  void _removeBatchImage(int index) {
    if (index < 0 || index >= _batchImages.length) {
      return;
    }

    setState(() {
      _batchImages.removeAt(index);
    });

    _showMessage('Page ${index + 1} removed.');
  }

  // ============================================================
  // CLEAR BATCH
  // ============================================================

  void _clearBatch() {
    if (_batchImages.isEmpty) {
      return;
    }

    setState(() {
      _batchImages.clear();
    });

    _showMessage('Batch cleared.');
  }

  // ============================================================
  // OPEN BATCH IMAGE
  // ============================================================

  void _openBatchImage(int index) {
    if (index < 0 || index >= _batchImages.length) {
      return;
    }

    final XFile image = _batchImages[index];

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.82),
      builder: (_) {
        return Dialog(
          backgroundColor: const Color(0xFF0B1829),
          insetPadding: const EdgeInsets.all(18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Page ${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.file(
                    File(image.path),
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const SizedBox(
                        height: 360,
                        child: Center(
                          child: Text(
                            'Unable to preview image.',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
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
    if (_showEnhanceScreen) {
      return _buildEnhancementScreen();
    }

    if (_capturedImage != null) {
      return _buildCapturedImageScreen();
    }

    return _buildScannerScreen();
  }

  // ============================================================
  // SCANNER SCREEN
  // ============================================================

  Widget _buildScannerScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF08111F),
      body: SafeArea(
        child: Stack(
          children: [
            const _ScannerBackground(),
            Column(
              children: [
                _buildTopBar(),
                Expanded(child: _buildScannerView()),
                _buildBottomControls(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CAPTURED SCREEN
  // ============================================================

  Widget _buildCapturedImageScreen() {
    return Scaffold(
      backgroundColor: const Color(0xFF08111F),
      body: SafeArea(
        child: Column(
          children: [
            _buildPreviewTopBar(),
            Expanded(child: _buildCapturedImagePreview()),
            _buildPreviewBottomControls(),
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          _GlassIconButton(
            icon: Icons.close_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Scan Document',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          _GlassIconButton(
            icon: _flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded,
            onTap: _toggleFlash,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PREVIEW TOP BAR
  // ============================================================

  Widget _buildPreviewTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          _GlassIconButton(
            icon: Icons.close_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Scan Preview',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (_isBatchMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.13)),
              ),
              child: Text(
                '${_batchImages.length + 1} Pages',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // CAMERA VIEW
  // ============================================================

  Widget _buildScannerView() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          children: [
            _buildCameraPreview(),
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.14),
                      width: 1,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 24,
              right: 24,
              top: 28,
              child: const Row(
                children: [
                  _StatusChip(
                    icon: Icons.auto_awesome_rounded,
                    label: 'Auto detect',
                  ),
                  Spacer(),
                  _StatusChip(icon: Icons.high_quality_rounded, label: 'HD'),
                ],
              ),
            ),
            Center(child: _ScanFrame(isBatchMode: _isBatchMode)),
            if (_isProcessing)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
                ),
              ),
            if (_isBatchMode && _batchImages.isNotEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: _buildBatchPreviewStrip(compact: true),
              ),
            if (!_isBatchMode)
              Positioned(
                left: 0,
                right: 0,
                bottom: 25,
                child: Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        child: const Text(
                          'Place document inside the frame',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // BATCH PREVIEW STRIP
  // ============================================================

  Widget _buildBatchPreviewStrip({bool compact = false}) {
    final double thumbnailSize = compact ? 58 : 72;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          height: compact ? 82 : 100,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: compact ? 0.50 : 0.35),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
          ),
          child: Row(
            children: [
              Expanded(
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _batchImages.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final XFile image = _batchImages[index];

                    return GestureDetector(
                      onTap: () => _openBatchImage(index),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: thumbnailSize,
                            height: thumbnailSize,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.24),
                              ),
                              color: const Color(0xFF142236),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.file(
                              File(image.path),
                              cacheWidth: 260,
                              cacheHeight: 320,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.broken_image_outlined,
                                  color: Colors.white54,
                                  size: 24,
                                );
                              },
                            ),
                          ),
                          Positioned(
                            left: 5,
                            bottom: 5,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.62),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Text(
                                '${index + 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            top: -5,
                            right: -5,
                            child: GestureDetector(
                              onTap: () => _removeBatchImage(index),
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF1A2A3D),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.25),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                  size: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${_batchImages.length}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Text(
                    'pages',
                    style: TextStyle(
                      color: Color(0xFFA3B1C4),
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
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
  // CAMERA PREVIEW
  // ============================================================

  Widget _buildCameraPreview() {
    if (_isInitializing) {
      return Container(
        color: const Color(0xFF0B1829),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF4A9AFF)),
              SizedBox(height: 14),
              Text(
                'Starting camera...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_cameraError != null) {
      return Container(
        color: const Color(0xFF0B1829),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.camera_alt_outlined,
                    color: Color(0xFF7EB3FF),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Camera Unavailable',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _cameraError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFAEBBCA),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _initializeCamera,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry Camera'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1769FF),
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final CameraController? controller = _cameraController;

    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.previewSize == null) {
      return Container(color: const Color(0xFF0B1829));
    }

    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.previewSize!.height,
          height: controller.value.previewSize!.width,
          child: CameraPreview(controller),
        ),
      ),
    );
  }

  // ============================================================
  // CAPTURED IMAGE PREVIEW
  // ============================================================

  Widget _buildCapturedImagePreview() {
    final XFile? image = _capturedImage;

    if (image == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0B1829),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InteractiveViewer(
        minScale: 1,
        maxScale: 4,
        child: Center(
          child: Image.file(
            File(image.path),
            cacheWidth: 1800,
            cacheHeight: 2400,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Text(
                'Unable to preview image.',
                style: TextStyle(color: Colors.white),
              );
            },
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ENHANCEMENT SCREEN
  // ============================================================

  Widget _buildEnhancementScreen() {
    final List<XFile> images = _enhancementImages;
    final String? previewPath = _enhancePreviewPath;

    return Scaffold(
      backgroundColor: const Color(0xFF08111F),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  _GlassIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: _isEnhancing ? () {} : _closeEnhancementScreen,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Enhance Scan',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_isBatchMode)
                    Text(
                      '${images.length} Pages',
                      style: const TextStyle(
                        color: Color(0xFFA3B1C4),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0B1829),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.10),
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          if (previewPath != null)
                            Positioned.fill(
                              child: InteractiveViewer(
                                minScale: 1,
                                maxScale: 4,
                                child: Image.file(
                                  File(previewPath),
                                  cacheWidth: 1800,
                                  cacheHeight: 2400,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(
                                      child: Text(
                                        'Unable to preview image.',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            )
                          else
                            const Center(
                              child: CircularProgressIndicator(
                                color: Color(0xFF4A9AFF),
                              ),
                            ),
                          if (_isEnhancing)
                            Positioned.fill(
                              child: Container(
                                color: Colors.black.withValues(alpha: 0.38),
                                child: const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          Positioned(
                            top: 16,
                            left: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 11,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.48),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                _filterLabel(_selectedFilter),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (images.length > 1)
                    SizedBox(
                      height: 76,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        scrollDirection: Axis.horizontal,
                        itemCount: images.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 9),
                        itemBuilder: (context, index) {
                          final bool selected = index == _enhancePageIndex;
                          final String path =
                              _processedImagePaths[images[index].path] ??
                              images[index].path;
                          return GestureDetector(
                            onTap: _isEnhancing
                                ? null
                                : () {
                                    setState(() {
                                      _enhancePageIndex = index;
                                      _enhancePreviewPath = null;
                                    });
                                    _prepareEnhancementPreview();
                                  },
                            child: Container(
                              width: 58,
                              height: 68,
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: selected
                                      ? const Color(0xFF4A9AFF)
                                      : Colors.white.withValues(alpha: 0.14),
                                  width: selected ? 2 : 1,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Image.file(
                                File(path),
                                cacheWidth: 260,
                                cacheHeight: 320,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(
                                    Icons.broken_image_outlined,
                                    color: Colors.white54,
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 104,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: _ScanFilter.values.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final _ScanFilter filter = _ScanFilter.values[index];
                        final bool selected = _selectedFilter == filter;
                        final String imagePath = images.isEmpty
                            ? ''
                            : images[_enhancePageIndex].path;
                        final String thumbnailPath =
                            filter == _selectedFilter &&
                                _enhancePreviewPath != null
                            ? _enhancePreviewPath!
                            : imagePath;
                        return GestureDetector(
                          onTap: _isEnhancing
                              ? null
                              : () {
                                  setState(() {
                                    _selectedFilter = filter;
                                    _enhancePreviewPath = null;
                                    _filterAppliedToAll = false;
                                    _processedImagePaths.clear();
                                  });
                                  _prepareEnhancementPreview();
                                },
                          child: SizedBox(
                            width: 88,
                            child: Column(
                              children: [
                                Container(
                                  width: 70,
                                  height: 70,
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(
                                      color: selected
                                          ? const Color(0xFF4A9AFF)
                                          : Colors.white.withValues(
                                              alpha: 0.12,
                                            ),
                                      width: selected ? 2 : 1,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: thumbnailPath.isEmpty
                                      ? const ColoredBox(
                                          color: Color(0xFF142236),
                                        )
                                      : Image.file(
                                          File(thumbnailPath),
                                          cacheWidth: 260,
                                          cacheHeight: 320,
                                          fit: BoxFit.cover,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return const ColoredBox(
                                                  color: Color(0xFF142236),
                                                );
                                              },
                                        ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  filter == _ScanFilter.auto
                                      ? 'Auto ⭐'
                                      : _filterLabel(filter),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: selected
                                        ? Colors.white
                                        : const Color(0xFFA3B1C4),
                                    fontSize: 10,
                                    fontWeight: selected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                    color: const Color(0xFF091421),
                    child: Column(
                      children: [
                        if (_isBatchMode)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _isEnhancing
                                  ? null
                                  : _applyFilterToAllPages,
                              icon: const Icon(Icons.auto_awesome_rounded),
                              label: Text(
                                _filterAppliedToAll
                                    ? 'Applied to All Pages'
                                    : 'Apply to All Pages',
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.18),
                                ),
                                minimumSize: const Size(0, 48),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                            ),
                          ),
                        if (_isBatchMode) const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isEnhancing ? null : _saveEnhancedScan,
                            icon: const Icon(Icons.check_rounded),
                            label: Text(
                              _isBatchMode
                                  ? (_filterAppliedToAll
                                        ? 'Create PDF'
                                        : 'Apply Filter & Continue')
                                  : 'Save & Create PDF',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1769FF),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(0, 54),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(17),
                              ),
                            ),
                          ),
                        ),
                      ],
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

  // ============================================================
  // BOTTOM CONTROLS
  // ============================================================

  Widget _buildBottomControls() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF091421),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Column(
        children: [
          _buildModeSelector(),
          if (_isBatchMode && _batchImages.isNotEmpty)
            const SizedBox(height: 12),
          if (_isBatchMode && _batchImages.isNotEmpty)
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_batchImages.length} page${_batchImages.length == 1 ? '' : 's'} selected',
                    style: const TextStyle(
                      color: Color(0xFFA3B1C4),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _clearBatch,
                  icon: const Icon(Icons.delete_sweep_outlined, size: 17),
                  label: const Text('Clear'),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFFF8B8B),
                  ),
                ),
              ],
            ),
          if (_isBatchMode && _batchImages.isNotEmpty)
            const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: _BottomControl(
                  icon: Icons.photo_library_outlined,
                  label: 'Gallery',
                  onTap: _openGallery,
                ),
              ),
              const SizedBox(width: 12),
              _CaptureButton(onTap: _captureDocument),
              const SizedBox(width: 12),
              Expanded(
                child: _BottomControl(
                  icon: Icons.document_scanner_outlined,
                  label: _isBatchMode ? 'Batch' : 'Single',
                  onTap: () {
                    setState(() {
                      _isBatchMode = !_isBatchMode;
                    });
                  },
                ),
              ),
            ],
          ),
          if (_isBatchMode && _batchImages.isNotEmpty) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isProcessing ? null : _createBatchPdf,
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                label: Text('Create PDF from ${_batchImages.length} Pages'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1769FF),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 52),
                  disabledBackgroundColor: const Color(
                    0xFF1769FF,
                  ).withValues(alpha: 0.45),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // PREVIEW CONTROLS
  // ============================================================

  Widget _buildPreviewBottomControls() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF091421),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _isProcessing ? null : _retakeImage,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retake'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.20)),
                minimumSize: const Size(0, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _isProcessing ? null : _useScan,
              icon: _isBatchMode
                  ? const Icon(Icons.add_rounded)
                  : const Icon(Icons.check_rounded),
              label: Text(_isBatchMode ? 'Add Page' : 'Use Scan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1769FF),
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 54),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MODE SELECTOR
  // ============================================================

  Widget _buildModeSelector() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          height: 48,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _ModeButton(
                  title: 'Single',
                  selected: !_isBatchMode,
                  onTap: () {
                    setState(() {
                      _isBatchMode = false;
                    });
                  },
                ),
              ),
              Expanded(
                child: _ModeButton(
                  title: 'Batch',
                  selected: _isBatchMode,
                  onTap: () {
                    setState(() {
                      _isBatchMode = true;
                    });
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
// SCAN FRAME
// ============================================================

class _ScanFrame extends StatelessWidget {
  final bool isBatchMode;

  const _ScanFrame({required this.isBatchMode});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 245,
      height: 345,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: const Color(0xFF4FA0FF).withValues(alpha: 0.15),
                  width: 1,
                ),
              ),
            ),
          ),
          const _Corner(alignment: Alignment.topLeft),
          const _Corner(alignment: Alignment.topRight),
          const _Corner(alignment: Alignment.bottomLeft),
          const _Corner(alignment: Alignment.bottomRight),
          Positioned(
            top: 20,
            left: 24,
            right: 24,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 2,
              color: const Color(0xFF2E8BFF).withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CORNER
// ============================================================

class _Corner extends StatelessWidget {
  final Alignment alignment;

  const _Corner({required this.alignment});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: SizedBox(
        width: 34,
        height: 34,
        child: CustomPaint(painter: _CornerPainter(alignment: alignment)),
      ),
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
      ..color = const Color(0xFF41A0FF)
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final Path path = Path();

    if (alignment == Alignment.topLeft) {
      path.moveTo(2, 30);
      path.lineTo(2, 2);
      path.lineTo(30, 2);
    } else if (alignment == Alignment.topRight) {
      path.moveTo(2, 2);
      path.lineTo(30, 2);
      path.lineTo(30, 30);
    } else if (alignment == Alignment.bottomLeft) {
      path.moveTo(2, 2);
      path.lineTo(2, 30);
      path.lineTo(30, 30);
    } else {
      path.moveTo(2, 30);
      path.lineTo(30, 30);
      path.lineTo(30, 2);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _CornerPainter oldDelegate) {
    return false;
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
            color: selected ? Colors.white : const Color(0xFFA7B6C9),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// BOTTOM CONTROL
// ============================================================

class _BottomControl extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _BottomControl({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Icon(icon, color: Colors.white, size: 21),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFFA3B1C4),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// CAPTURE BUTTON
// ============================================================

class _CaptureButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CaptureButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: const Color(0xFF4A9AFF), width: 5),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1769FF).withValues(alpha: 0.30),
              blurRadius: 24,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.all(7),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFF1F6FD),
          ),
          child: const Icon(
            Icons.camera_alt_rounded,
            color: Color(0xFF1769FF),
            size: 27,
          ),
        ),
      ),
    );
  }
}

// ============================================================
// STATUS CHIP
// ============================================================

class _StatusChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StatusChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.30),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: const Color(0xFF8EC5FF), size: 14),
              const SizedBox(width: 5),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
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
      borderRadius: BorderRadius.circular(15),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Material(
          color: Colors.white.withValues(alpha: 0.09),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(15),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
              ),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// SCANNER BACKGROUND
// ============================================================

class _ScannerBackground extends StatelessWidget {
  const _ScannerBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -90,
            child: _BlurLight(
              size: 300,
              color: const Color(0xFF1769FF).withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child: _BlurLight(
              size: 280,
              color: const Color(0xFF4A9AFF).withValues(alpha: 0.10),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// BLUR LIGHT
// ============================================================

class _BlurLight extends StatelessWidget {
  final double size;
  final Color color;

  const _BlurLight({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return ImageFiltered(
      imageFilter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
