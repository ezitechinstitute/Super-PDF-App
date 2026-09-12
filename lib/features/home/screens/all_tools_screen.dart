import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:pdf_super_app/features/home/screens/file_picker_screen.dart';
import 'package:pdf_super_app/features/home/screens/scan_document_screen.dart';
import 'package:pdf_super_app/features/home/screens/jpg_to_pdf_screen.dart';
import 'package:pdf_super_app/features/home/screens/png_to_pdf_screen.dart';
//import 'package:pdf_super_app/features/home/screens/merge_pdf_screen.dart';
//import 'package:pdf_super_app/features/home/screens/compress_pdf_screen.dart';

class AllToolsScreen extends StatefulWidget {
  const AllToolsScreen({super.key});

  @override
  State<AllToolsScreen> createState() => _AllToolsScreenState();
}

class _AllToolsScreenState extends State<AllToolsScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  final List<_ToolItem> _pdfTools = const [
    _ToolItem(
      title: 'Merge PDF',
      subtitle: 'Combine files',
      icon: Icons.layers_outlined,
      color: Color(0xFF1769FF),
    ),
    _ToolItem(
      title: 'Split PDF',
      subtitle: 'Separate pages',
      icon: Icons.content_cut_rounded,
      color: Color(0xFF7A5AF8),
    ),
    _ToolItem(
      title: 'Compress PDF',
      subtitle: 'Reduce size',
      icon: Icons.compress_rounded,
      color: Color(0xFF12B886),
    ),
    _ToolItem(
      title: 'Protect PDF',
      subtitle: 'Add password',
      icon: Icons.lock_outline_rounded,
      color: Color(0xFFE25563),
    ),
    _ToolItem(
      title: 'Remove Pages',
      subtitle: 'Delete pages',
      icon: Icons.delete_outline_rounded,
      color: Color(0xFFFF7A00),
    ),
    _ToolItem(
      title: 'Extract Pages',
      subtitle: 'Save selected pages',
      icon: Icons.file_copy_outlined,
      color: Color(0xFF00A8A8),
    ),
    _ToolItem(
      title: 'Reorder Pages',
      subtitle: 'Change page order',
      icon: Icons.swap_vert_rounded,
      color: Color(0xFF6C5CE7),
    ),
    _ToolItem(
      title: 'Rotate PDF',
      subtitle: 'Rotate pages',
      icon: Icons.rotate_right_rounded,
      color: Color(0xFF1769FF),
    ),
    _ToolItem(
      title: 'Sign PDF',
      subtitle: 'Add signature',
      icon: Icons.draw_outlined,
      color: Color(0xFFF15B78),
    ),
    _ToolItem(
      title: 'Watermark PDF',
      subtitle: 'Add watermark',
      icon: Icons.branding_watermark_outlined,
      color: Color(0xFF5B6CFF),
    ),
    _ToolItem(
      title: 'Add Page Numbers',
      subtitle: 'Number your pages',
      icon: Icons.format_list_numbered_rounded,
      color: Color(0xFF6C63FF),
    ),
  ];

  final List<_ToolItem> _convertTools = const [
    _ToolItem(
      title: 'JPG to PDF',
      subtitle: 'Convert image',
      icon: Icons.image_outlined,
      color: Color(0xFF1769FF),
    ),
    _ToolItem(
      title: 'PNG to PDF',
      subtitle: 'Convert image',
      icon: Icons.photo_outlined,
      color: Color(0xFF12B886),
    ),
    _ToolItem(
      title: 'PDF to JPG',
      subtitle: 'Export images',
      icon: Icons.picture_as_pdf_outlined,
      color: Color(0xFFFF6B6B),
    ),
    _ToolItem(
      title: 'PDF to PNG',
      subtitle: 'Export images',
      icon: Icons.image_search_outlined,
      color: Color(0xFF7A5AF8),
    ),
    _ToolItem(
      title: 'SVG to PDF',
      subtitle: 'Convert vector',
      icon: Icons.polyline_outlined,
      color: Color(0xFFFF9F43),
    ),
    _ToolItem(
      title: 'PDF to SVG',
      subtitle: 'Export vector',
      icon: Icons.auto_graph_rounded,
      color: Color(0xFF00A8A8),
    ),
  ];

  final List<_ToolItem> _smartTools = const [
    _ToolItem(
      title: 'OCR',
      subtitle: 'Extract text',
      icon: Icons.text_fields_rounded,
      color: Color(0xFFFF8A00),
    ),
    _ToolItem(
      title: 'AI Summarize',
      subtitle: 'Smart insights',
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFF7A5AF8),
    ),
    _ToolItem(
      title: 'Scan Document',
      subtitle: 'Use camera',
      icon: Icons.document_scanner_outlined,
      color: Color(0xFF1769FF),
    ),
    _ToolItem(
      title: 'Fill Forms',
      subtitle: 'Complete PDF forms',
      icon: Icons.edit_note_rounded,
      color: Color(0xFF12B886),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  List<_ToolItem> _filteredTools(List<_ToolItem> tools) {
    if (_searchQuery.isEmpty) {
      return tools;
    }

    return tools.where((tool) {
      return tool.title.toLowerCase().contains(_searchQuery) ||
          tool.subtitle.toLowerCase().contains(_searchQuery);
    }).toList();
  }

  void _openTool(_ToolItem tool) {
    // ==========================================================
    // SCAN DOCUMENT
    // ==========================================================

    if (tool.title == 'Scan Document') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ScanDocumentScreen()),
      );
      return;
    }

    // ==========================================================
    // JPG TO PDF
    // ==========================================================

    if (tool.title == 'JPG to PDF') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const JpgToPdfScreen()),
      );
      return;
    }

    // ==========================================================
    // PNG TO PDF
    // ==========================================================

    if (tool.title == 'PNG to PDF') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PngToPdfScreen()),
      );
      return;
    }

    // ==========================================================
    // MERGE PDF
    // ==========================================================

    if (tool.title == 'Merge PDF') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FilePickerScreen(
            toolName: tool.title,
            allowedExtensions: const ['pdf'],
            allowMultiple: true,
          ),
        ),
      );
      return;
    }

    // ==========================================================
    // COMPRESS PDF
    // ==========================================================

    if (tool.title == 'Reorder Pages') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FilePickerScreen(
            toolName: tool.title,
            allowedExtensions: const ['pdf'],
            allowMultiple: false,
          ),
        ),
      );
      return;
    }

    // ==========================================================
    // COMPRESS PDF
    // ==========================================================

    if (tool.title == 'Compress PDF') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FilePickerScreen(
            toolName: tool.title,
            allowedExtensions: const ['pdf'],
            allowMultiple: false,
          ),
        ),
      );
      return;
    }

    // ==========================================================
    // OCR
    // ==========================================================

    if (tool.title == 'OCR') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FilePickerScreen(
            toolName: tool.title,
            allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
            allowMultiple: false,
          ),
        ),
      );
      return;
    }

    // ==========================================================
    // AI SUMMARIZE
    // ==========================================================

    if (tool.title == 'AI Summarize') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FilePickerScreen(
            toolName: tool.title,
            allowedExtensions: const ['pdf'],
            allowMultiple: false,
          ),
        ),
      );
      return;
    }

    // ==========================================================
    // OTHER FILE PICKER TOOLS
    // ==========================================================

    final bool multiple = <String>['SVG to PDF'].contains(tool.title);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FilePickerScreen(
          toolName: tool.title,
          allowedExtensions: _getExtensions(tool.title),
          allowMultiple: multiple,
        ),
      ),
    );
  }

  List<String> _getExtensions(String toolName) {
    switch (toolName) {
      case 'JPG to PDF':
        return ['jpg', 'jpeg'];

      case 'PNG to PDF':
        return ['png'];

      case 'SVG to PDF':
        return ['svg'];

      default:
        return ['pdf'];
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredPdf = _filteredTools(_pdfTools);
    final filteredConvert = _filteredTools(_convertTools);
    final filteredSmart = _filteredTools(_smartTools);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      body: SafeArea(
        child: Stack(
          children: [
            const _ToolsBackground(),

            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _buildHeader()),

                SliverToBoxAdapter(child: _buildSearchBar()),

                if (filteredPdf.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _buildSectionTitle(
                      'PDF Tools',
                      'Manage and edit your PDFs',
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
                    sliver: _buildToolGrid(filteredPdf),
                  ),
                ],

                if (filteredConvert.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _buildSectionTitle(
                      'Convert',
                      'Convert between document formats',
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
                    sliver: _buildToolGrid(filteredConvert),
                  ),
                ],

                if (filteredSmart.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: _buildSectionTitle(
                      'Smart Tools',
                      'Powerful intelligent features',
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
                    sliver: _buildToolGrid(filteredSmart),
                  ),
                ],

                if (filteredPdf.isEmpty &&
                    filteredConvert.isEmpty &&
                    filteredSmart.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptySearch(),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Row(
        children: [
          _GlassIconButton(
            icon: Icons.arrow_back_ios_new_rounded,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All Tools',
                  style: TextStyle(
                    color: Color(0xFF10255C),
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Everything you need for PDFs',
                  style: TextStyle(color: Color(0xFF7184A4), fontSize: 13),
                ),
              ],
            ),
          ),
          _GlassIconButton(
            icon: Icons.bookmark_border_rounded,
            onTap: () {
              _showMessage('Favorites will be added next.');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.52),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF6880A4),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Search tools...',
                      hintStyle: TextStyle(
                        color: Color(0xFF8595AB),
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                    },
                    child: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFF6D809D),
                      size: 20,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 25, 18, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF10255C),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFF7A8CA6),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFE7F0FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF1769FF),
              size: 15,
            ),
          ),
        ],
      ),
    );
  }

  SliverGrid _buildToolGrid(List<_ToolItem> tools) {
    return SliverGrid(
      delegate: SliverChildBuilderDelegate((context, index) {
        final tool = tools[index];

        return _ToolCard(tool: tool, onTap: () => _openTool(tool));
      }, childCount: tools.length),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.28,
      ),
    );
  }

  Widget _buildEmptySearch() {
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
                color: Colors.white.withValues(alpha: 0.48),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                color: Color(0xFF1769FF),
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No tools found',
              style: TextStyle(
                color: Color(0xFF10255C),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try another search term.',
              style: TextStyle(color: Color(0xFF74859F), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final _ToolItem tool;
  final VoidCallback onTap;

  const _ToolCard({required this.tool, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.48),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.82),
                width: 1.1,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6D91C8).withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: tool.color.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(tool.icon, color: tool.color, size: 22),
                    ),
                    const Spacer(),
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.42),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 11,
                        color: Color(0xFF6C82A2),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  tool.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF10255C),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tool.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF7A8BA4),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
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

class _ToolsBackground extends StatelessWidget {
  const _ToolsBackground();

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

class _ToolItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _ToolItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}
