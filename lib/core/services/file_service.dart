import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';

class FileService {
  FileService._();

  // ============================================================
  // SAVE FILE TO USER-SELECTED DEVICE LOCATION
  // ============================================================

  static Future<Uri?> saveFile({
    required String filePath,
    String? fileName,
    String mimeType = 'application/octet-stream',
    String? dialogTitle,
  }) async {
    final File sourceFile = File(filePath);

    if (!await sourceFile.exists()) {
      throw Exception('Source file was not found.');
    }

    final Uint8List bytes = await sourceFile.readAsBytes();

    final String finalFileName =
        (fileName == null || fileName.trim().isEmpty)
            ? sourceFile.uri.pathSegments.last
            : fileName.trim();

    final Uri? savedUri = await FilePicker.saveFile(
      dialogTitle: dialogTitle ?? 'Save file',
      fileName: finalFileName,
      bytes: bytes,
      mimeType: mimeType,
    );

    return savedUri;
  }

  // ============================================================
  // SAVE BYTES DIRECTLY
  // ============================================================

  static Future<Uri?> saveBytes({
    required Uint8List bytes,
    required String fileName,
    required String mimeType,
    String? dialogTitle,
  }) async {
    if (bytes.isEmpty) {
      throw Exception('File data is empty.');
    }

    final Uri? savedUri = await FilePicker.saveFile(
      dialogTitle: dialogTitle ?? 'Save file',
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
    );

    return savedUri;
  }

  // ============================================================
  // SAVE PDF
  // ============================================================

  static Future<Uri?> savePdf({
    required String filePath,
    String? fileName,
  }) {
    return saveFile(
      filePath: filePath,
      fileName: fileName,
      mimeType: 'application/pdf',
      dialogTitle: 'Save PDF',
    );
  }

  // ============================================================
  // SAVE JPG
  // ============================================================

  static Future<Uri?> saveJpg({
    required String filePath,
    String? fileName,
  }) {
    return saveFile(
      filePath: filePath,
      fileName: fileName,
      mimeType: 'image/jpeg',
      dialogTitle: 'Save JPG',
    );
  }

  // ============================================================
  // SAVE PNG
  // ============================================================

  static Future<Uri?> savePng({
    required String filePath,
    String? fileName,
  }) {
    return saveFile(
      filePath: filePath,
      fileName: fileName,
      mimeType: 'image/png',
      dialogTitle: 'Save PNG',
    );
  }

  // ============================================================
  // SHARE SINGLE FILE
  // ============================================================

  static Future<ShareResult> shareFile({
    required String filePath,
    String? text,
    String? title,
    String? subject,
    String? fileName,
  }) async {
    final File file = File(filePath);

    if (!await file.exists()) {
      throw Exception('File to share was not found.');
    }

    final String actualFileName =
        (fileName == null || fileName.trim().isEmpty)
            ? file.uri.pathSegments.last
            : fileName.trim();

    final ShareParams params = ShareParams(
      title: title ?? 'Share File',
      subject: subject ?? actualFileName,
      text: text,
      files: [
        XFile(
          filePath,
        ),
      ],
      fileNameOverrides: [
        actualFileName,
      ],
    );

    return SharePlus.instance.share(params);
  }

  // ============================================================
  // SHARE MULTIPLE FILES
  // ============================================================

  static Future<ShareResult> shareFiles({
    required List<String> filePaths,
    String? text,
    String? title,
    String? subject,
    List<String>? fileNames,
  }) async {
    if (filePaths.isEmpty) {
      throw Exception('No files selected for sharing.');
    }

    final List<XFile> files = <XFile>[];

    for (final String path in filePaths) {
      final File file = File(path);

      if (!await file.exists()) {
        throw Exception(
          'File to share was not found: $path',
        );
      }

      files.add(
        XFile(path),
      );
    }

    List<String>? fileNameOverrides;

    if (fileNames != null) {
      if (fileNames.length != files.length) {
        throw Exception(
          'The number of file names must match the number of files.',
        );
      }

      fileNameOverrides = fileNames;
    }

    final ShareParams params = ShareParams(
      title: title ?? 'Share Files',
      subject: subject ?? 'Shared files',
      text: text,
      files: files,
      fileNameOverrides: fileNameOverrides,
    );

    return SharePlus.instance.share(params);
  }

  // ============================================================
  // SHARE PDF
  // ============================================================

  static Future<ShareResult> sharePdf({
    required String filePath,
    String? fileName,
    String? text,
  }) {
    return shareFile(
      filePath: filePath,
      fileName: fileName,
      text: text,
      title: 'Share PDF',
      subject: fileName ?? 'PDF File',
    );
  }

  // ============================================================
  // SHARE JPG
  // ============================================================

  static Future<ShareResult> shareJpg({
    required String filePath,
    String? fileName,
    String? text,
  }) {
    return shareFile(
      filePath: filePath,
      fileName: fileName,
      text: text,
      title: 'Share JPG',
      subject: fileName ?? 'JPG Image',
    );
  }

  // ============================================================
  // SHARE PNG
  // ============================================================

  static Future<ShareResult> sharePng({
    required String filePath,
    String? fileName,
    String? text,
  }) {
    return shareFile(
      filePath: filePath,
      fileName: fileName,
      text: text,
      title: 'Share PNG',
      subject: fileName ?? 'PNG Image',
    );
  }

  // ============================================================
  // CHECK FILE
  // ============================================================

  static Future<bool> exists(String filePath) async {
    return File(filePath).exists();
  }
}