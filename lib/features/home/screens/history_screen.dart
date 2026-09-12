import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';

import 'package:pdf_super_app/core/services/api_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final ApiService _apiService = ApiService.instance;

  List<_HistoryItem> _history = [];

  bool _isLoading = true;
  bool _isDeletingAll = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await _apiService.getHistory();

      final List<_HistoryItem> items = _parseHistoryResponse(response.data);

      if (!mounted) return;

      setState(() {
        _history = items;
        _isLoading = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;

      setState(() {
        _history = [];
        _isLoading = false;
      });

      _showMessage(_extractDioError(e));
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _history = [];
        _isLoading = false;
      });

      _showMessage('Unable to load history.');
    }
  }

  List<_HistoryItem> _parseHistoryResponse(dynamic responseData) {
    dynamic rawData;

    if (responseData is Map<String, dynamic>) {
      rawData = responseData['data'];

      // Direct list:
      if (rawData is List) {
        return rawData
            .whereType<Map>()
            .map(
              (item) => _HistoryItem.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      }

      // Laravel paginator:
      if (rawData is Map<String, dynamic>) {
        final paginatorData = rawData['data'];

        if (paginatorData is List) {
          return paginatorData
              .whereType<Map>()
              .map(
                (item) =>
                    _HistoryItem.fromJson(Map<String, dynamic>.from(item)),
              )
              .toList();
        }
      }

      // Fallback if API returns history directly.
      rawData = responseData['history'];

      if (rawData is List) {
        return rawData
            .whereType<Map>()
            .map(
              (item) => _HistoryItem.fromJson(Map<String, dynamic>.from(item)),
            )
            .toList();
      }
    }

    return [];
  }

  Future<void> _deleteHistoryItem(_HistoryItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Delete history'),
          content: Text('Delete "${item.displayName}" from your history?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await _apiService.deleteHistory(historyId: item.id);

      if (!mounted) return;

      setState(() {
        _history.removeWhere((historyItem) => historyItem.id == item.id);
      });

      _showMessage('History item deleted.');
    } on DioException catch (e) {
      _showMessage(_extractDioError(e));
    } catch (_) {
      _showMessage('Unable to delete history item.');
    }
  }

  Future<void> _deleteAllHistory() async {
    if (_history.isEmpty || _isDeletingAll) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Clear all history'),
          content: const Text(
            'Are you sure you want to delete all your history?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Clear All'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    // The dialog above is awaited; the screen can be popped while it is open.
    if (!mounted) return;

    setState(() {
      _isDeletingAll = true;
    });

    try {
      await _apiService.deleteAllHistory();

      if (!mounted) return;

      setState(() {
        _history.clear();
        _isDeletingAll = false;
      });

      _showMessage('All history deleted.');
    } on DioException catch (e) {
      if (!mounted) return;

      setState(() {
        _isDeletingAll = false;
      });

      _showMessage(_extractDioError(e));
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isDeletingAll = false;
      });

      _showMessage('Unable to clear history.');
    }
  }

  String _extractDioError(DioException error) {
    final responseData = error.response?.data;

    if (responseData is Map) {
      final message = responseData['message'];

      if (message is String && message.trim().isNotEmpty) {
        return message;
      }

      final errors = responseData['errors'];

      if (errors is Map) {
        for (final value in errors.values) {
          if (value is List && value.isNotEmpty) {
            return value.first.toString();
          }

          if (value is String && value.trim().isNotEmpty) {
            return value;
          }
        }
      }
    }

    if (error.type == DioExceptionType.connectionError) {
      return 'Unable to connect to server.';
    }

    if (error.type == DioExceptionType.connectionTimeout) {
      return 'Connection timed out.';
    }

    return 'Something went wrong. Please try again.';
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      );
  }

  IconData _toolIcon(String toolName) {
    final name = toolName.toLowerCase();

    if (name.contains('merge')) {
      return Icons.layers_outlined;
    }

    if (name.contains('split')) {
      return Icons.content_cut_rounded;
    }

    if (name.contains('compress')) {
      return Icons.compress_rounded;
    }

    if (name.contains('scan')) {
      return Icons.document_scanner_outlined;
    }

    if (name.contains('ocr')) {
      return Icons.text_fields_rounded;
    }

    if (name.contains('sign')) {
      return Icons.draw_outlined;
    }

    if (name.contains('watermark')) {
      return Icons.branding_watermark_outlined;
    }

    if (name.contains('rotate')) {
      return Icons.rotate_right_rounded;
    }

    if (name.contains('protect')) {
      return Icons.lock_outline_rounded;
    }

    if (name.contains('extract')) {
      return Icons.file_copy_outlined;
    }

    if (name.contains('remove')) {
      return Icons.delete_outline_rounded;
    }

    if (name.contains('page number')) {
      return Icons.format_list_numbered_rounded;
    }

    if (name.contains('jpg') || name.contains('jpeg')) {
      return Icons.image_outlined;
    }

    if (name.contains('png')) {
      return Icons.image_outlined;
    }

    if (name.contains('ai') || name.contains('summar')) {
      return Icons.auto_awesome_rounded;
    }

    return Icons.picture_as_pdf_rounded;
  }

  Color _toolColor(String toolName) {
    final name = toolName.toLowerCase();

    if (name.contains('merge')) {
      return const Color(0xFF7A5AF8);
    }

    if (name.contains('compress')) {
      return const Color(0xFF12B886);
    }

    if (name.contains('scan')) {
      return const Color(0xFF1769FF);
    }

    if (name.contains('ocr')) {
      return const Color(0xFFFF8A00);
    }

    if (name.contains('sign')) {
      return const Color(0xFFF15B78);
    }

    if (name.contains('split')) {
      return const Color(0xFF00A8A8);
    }

    if (name.contains('ai') || name.contains('summar')) {
      return const Color(0xFF8B5CF6);
    }

    return const Color(0xFFF45151);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      body: SafeArea(
        child: Stack(
          children: [
            const _BackgroundDecorations(),

            RefreshIndicator(
              onRefresh: _loadHistory,
              color: const Color(0xFF1769FF),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),

                    const SizedBox(height: 18),

                    _buildSummaryCard(),

                    const SizedBox(height: 18),

                    _buildHistorySection(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
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
                'History',
                style: TextStyle(
                  color: Color(0xFF10255C),
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.6,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Your recent PDF activity',
                style: TextStyle(
                  color: Color(0xFF6D82A2),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),

        _GlassIconButton(
          icon: Icons.refresh_rounded,
          onTap: _isLoading ? () {} : _loadHistory,
        ),
      ],
    );
  }

  Widget _buildSummaryCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(25),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF5A9BFF), Color(0xFF1769FF), Color(0xFF0958E8)],
            ),
            border: Border.all(color: Colors.white.withValues(alpha: 0.32)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1769FF).withValues(alpha: 0.22),
                blurRadius: 24,
                offset: const Offset(0, 11),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: Colors.white,
                  size: 27,
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total Activities',
                      style: TextStyle(
                        color: Color(0xFFEAF3FF),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${_history.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              if (_history.isNotEmpty)
                GestureDetector(
                  onTap: _isDeletingAll ? null : _deleteAllHistory,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.25),
                      ),
                    ),
                    child: _isDeletingAll
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.delete_sweep_outlined,
                                color: Colors.white,
                                size: 18,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Clear',
                                style: TextStyle(
                                  color: Colors.white,
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
    );
  }

  Widget _buildHistorySection() {
    return _GlassContainer(
      borderRadius: 28,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent Activity',
            style: TextStyle(
              color: Color(0xFF10255C),
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 12),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 45),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF1769FF)),
              ),
            )
          else if (_history.isEmpty)
            _buildEmptyState()
          else
            ...List.generate(_history.length, (index) {
              final item = _history[index];

              return _HistoryTile(
                item: item,
                icon: _toolIcon(item.toolName),
                iconColor: _toolColor(item.toolName),
                showDivider: index != _history.length - 1,
                onDelete: () => _deleteHistoryItem(item),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 15),
      child: Column(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: const Color(0xFF1769FF).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.history_rounded,
              color: Color(0xFF6D82A2),
              size: 36,
            ),
          ),

          const SizedBox(height: 15),

          const Text(
            'No history yet',
            style: TextStyle(
              color: Color(0xFF10255C),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 7),

          const Text(
            'Your completed PDF activities will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF7184A4),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryItem {
  final int id;
  final String toolName;
  final String fileName;
  final String? outputFileName;
  final String status;
  final int? fileSize;
  final String? notes;
  final String? createdAt;

  const _HistoryItem({
    required this.id,
    required this.toolName,
    required this.fileName,
    required this.outputFileName,
    required this.status,
    required this.fileSize,
    required this.notes,
    required this.createdAt,
  });

  factory _HistoryItem.fromJson(Map<String, dynamic> json) {
    return _HistoryItem(
      id: _toInt(json['id']),
      toolName: (json['tool_name'] ?? 'PDF Tool').toString(),
      fileName: (json['file_name'] ?? 'Untitled.pdf').toString(),
      outputFileName: json['output_file_name']?.toString(),
      status: (json['status'] ?? 'completed').toString(),
      fileSize: _toNullableInt(json['file_size']),
      notes: json['notes']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }

  String get displayName {
    if (outputFileName != null && outputFileName!.trim().isNotEmpty) {
      return outputFileName!;
    }

    return fileName;
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _toNullableInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString());
  }
}

class _HistoryTile extends StatelessWidget {
  final _HistoryItem item;
  final IconData icon;
  final Color iconColor;
  final bool showDivider;
  final VoidCallback onDelete;

  const _HistoryTile({
    required this.item,
    required this.icon,
    required this.iconColor,
    required this.showDivider,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCompleted = item.status.toLowerCase() == 'completed';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 3),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(icon, color: iconColor, size: 27),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF10255C),
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      item.toolName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF637A9D),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Row(
                      children: [
                        if (item.fileSize != null)
                          Text(
                            _formatSize(item.fileSize!),
                            style: const TextStyle(
                              color: Color(0xFF8192AD),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                        if (item.fileSize != null) const SizedBox(width: 6),

                        Text(
                          '•',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 10,
                          ),
                        ),

                        const SizedBox(width: 6),

                        Text(
                          item.status,
                          style: TextStyle(
                            color: isCompleted
                                ? const Color(0xFF12A76B)
                                : const Color(0xFFD13C3C),
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 6),

              IconButton(
                onPressed: onDelete,
                tooltip: 'Delete',
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Color(0xFF7B8DA8),
                  size: 21,
                ),
              ),
            ],
          ),
        ),

        if (showDivider) Container(height: 1, color: const Color(0xFFD7E4F4)),
      ],
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    }

    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }

    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }

    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

class _GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsets padding;

  const _GlassContainer({
    required this.child,
    required this.borderRadius,
    required this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.48),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.80),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF7A9FD3).withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.white.withValues(alpha: 0.58),
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
              child: Icon(icon, color: const Color(0xFF10255C), size: 21),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackgroundDecorations extends StatelessWidget {
  const _BackgroundDecorations();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -130,
            right: -80,
            child: _BlurCircle(
              size: 290,
              color: const Color(0xFF8AB8FF).withValues(alpha: 0.28),
            ),
          ),
          Positioned(
            top: 220,
            left: -120,
            child: _BlurCircle(
              size: 250,
              color: const Color(0xFF79A8FF).withValues(alpha: 0.12),
            ),
          ),
          Positioned(
            bottom: 40,
            right: -90,
            child: _BlurCircle(
              size: 260,
              color: const Color(0xFFA5CCFF).withValues(alpha: 0.18),
            ),
          ),
        ],
      ),
    );
  }
}

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
