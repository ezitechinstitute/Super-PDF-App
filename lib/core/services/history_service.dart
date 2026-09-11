import 'package:pdf_super_app/core/services/api_service.dart';

class HistoryService {
  HistoryService._();

  static final HistoryService instance = HistoryService._();

  final ApiService _apiService = ApiService.instance;

  Future<void> recordSuccess({
    required String toolName,
    required String fileName,
    String? outputFileName,
    int? fileSize,
    String? notes,
  }) async {
    try {
      await _apiService.createHistory(
        toolName: toolName,
        fileName: fileName,
        outputFileName: outputFileName,
        status: 'completed',
        fileSize: fileSize,
        notes: notes,
      );
    } catch (e) {
      // History must never break the actual PDF operation.
      //
      // The PDF operation has already succeeded, so a history
      // API failure should not show as a tool failure.
      //
      // We intentionally keep this silent for the user.
    }
  }

  Future<void> recordFailure({
    required String toolName,
    required String fileName,
    String? notes,
  }) async {
    try {
      await _apiService.createHistory(
        toolName: toolName,
        fileName: fileName,
        status: 'failed',
        notes: notes,
      );
    } catch (_) {
      // History logging failure should not affect the tool.
    }
  }
}
