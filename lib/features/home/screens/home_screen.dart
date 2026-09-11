import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:pdf_super_app/core/services/api_service.dart';
import 'package:pdf_super_app/features/home/screens/all_tools_screen.dart';
import 'package:pdf_super_app/features/home/screens/file_picker_screen.dart';
import 'package:pdf_super_app/features/home/screens/history_screen.dart';
import 'package:pdf_super_app/features/home/screens/scan_document_screen.dart';
import 'package:pdf_super_app/features/profile/screens/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ApiService _apiService = ApiService.instance;

  String _userName = 'there';
  String? _avatarUrl;

  bool _isLoadingProfile = true;
  bool _isLoadingRecentFiles = true;

  List<_RecentFile> _recentFiles = [];

  final List<_QuickAction> _quickActions = const [
    _QuickAction(
      title: 'Scan',
      icon: Icons.document_scanner_outlined,
      color: Color(0xFF1769FF),
    ),
    _QuickAction(
      title: 'Merge',
      icon: Icons.layers_outlined,
      color: Color(0xFF7A5AF8),
    ),
    _QuickAction(
      title: 'Compress',
      icon: Icons.compress_rounded,
      color: Color(0xFF12B886),
    ),
    _QuickAction(
      title: 'OCR',
      icon: Icons.text_fields_rounded,
      color: Color(0xFFFF8A00),
    ),
    _QuickAction(
      title: 'Convert',
      icon: Icons.sync_rounded,
      color: Color(0xFF1769FF),
    ),
    _QuickAction(
      title: 'Sign',
      icon: Icons.draw_outlined,
      color: Color(0xFFF15B78),
    ),
    _QuickAction(
      title: 'Split',
      icon: Icons.content_cut_rounded,
      color: Color(0xFF00A8A8),
    ),
    _QuickAction(
      title: 'More',
      icon: Icons.grid_view_rounded,
      color: Color(0xFF7183A8),
    ),
  ];

  @override
  void initState() {
    super.initState();

    _loadProfile();
    _loadRecentFiles();
  }

  // ============================================================
  // LOAD PROFILE
  // ============================================================

  Future<void> _loadProfile() async {
    try {
      debugPrint('==========================================');
      debugPrint('🏠 HOME PROFILE');
      debugPrint('📡 Calling /profile...');
      debugPrint('==========================================');

      final response = await _apiService.getProfile();

      debugPrint('==========================================');
      debugPrint('✅ HOME PROFILE RESPONSE');
      debugPrint('Status: ${response.statusCode}');
      debugPrint('Data: ${response.data}');
      debugPrint('==========================================');

      final profile = _extractProfile(response.data);

      if (profile == null) {
        debugPrint('❌ User profile not found in response.');

        if (!mounted) return;

        setState(() {
          _userName = 'there';
          _avatarUrl = null;
          _isLoadingProfile = false;
        });

        return;
      }

      final name = profile['name']?.toString().trim() ?? '';

      final avatar = profile['avatar'];

      String? parsedAvatar;

      if (avatar != null && avatar.toString().trim().isNotEmpty) {
        parsedAvatar = _buildAvatarUrl(avatar.toString().trim());
      }

      debugPrint('👤 Home name: $name');
      debugPrint('🖼️ Home avatar raw: $avatar');
      debugPrint('🖼️ Home avatar URL: $parsedAvatar');

      if (!mounted) return;

      setState(() {
        _userName = name.isNotEmpty ? name : 'there';

        _avatarUrl = parsedAvatar;
        _isLoadingProfile = false;
      });
    } on DioException catch (e) {
      debugPrint('==========================================');
      debugPrint('❌ HOME PROFILE API ERROR');
      debugPrint('Status: ${e.response?.statusCode}');
      debugPrint('Response: ${e.response?.data}');
      debugPrint('Message: ${e.message}');
      debugPrint('==========================================');

      if (!mounted) return;

      setState(() {
        _isLoadingProfile = false;
      });
    } catch (e) {
      debugPrint('==========================================');
      debugPrint('❌ HOME PROFILE ERROR');
      debugPrint('$e');
      debugPrint('==========================================');

      if (!mounted) return;

      setState(() {
        _isLoadingProfile = false;
      });
    }
  }

  // ============================================================
  // EXTRACT PROFILE
  //
  // Current Laravel response:
  // {
  //   success: true,
  //   message: "...",
  //   user: {...}
  // }
  //
  // Also supports:
  // data
  // profile
  // direct object
  // ============================================================

  Map<String, dynamic>? _extractProfile(dynamic responseData) {
    if (responseData is! Map) {
      return null;
    }

    final root = Map<String, dynamic>.from(responseData);

    // Current Laravel response
    final user = root['user'];

    if (user is Map) {
      return Map<String, dynamic>.from(user);
    }

    // Generic data response
    final data = root['data'];

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    // Profile response
    final profile = root['profile'];

    if (profile is Map) {
      return Map<String, dynamic>.from(profile);
    }

    // Direct object response
    if (root.containsKey('name') ||
        root.containsKey('email') ||
        root.containsKey('phone')) {
      return root;
    }

    return null;
  }

  // ============================================================
  // LOAD RECENT FILES
  // ============================================================

  Future<void> _loadRecentFiles() async {
    try {
      final response = await _apiService.getRecentFiles();

      final List<_RecentFile> recentFiles = _parseRecentFiles(response.data);

      if (!mounted) return;

      setState(() {
        _recentFiles = recentFiles;
        _isLoadingRecentFiles = false;
      });
    } on DioException catch (e) {
      debugPrint('❌ RECENT FILES API ERROR: ${e.response?.data}');

      if (!mounted) return;

      setState(() {
        _recentFiles = [];
        _isLoadingRecentFiles = false;
      });
    } catch (e) {
      debugPrint('❌ RECENT FILES ERROR: $e');

      if (!mounted) return;

      setState(() {
        _recentFiles = [];
        _isLoadingRecentFiles = false;
      });
    }
  }

  // ============================================================
  // PARSE RECENT FILES
  // ============================================================

  List<_RecentFile> _parseRecentFiles(dynamic responseData) {
    dynamic rawData;

    if (responseData is Map) {
      final root = Map<String, dynamic>.from(responseData);

      rawData = root['data'];

      if (rawData is Map) {
        final nested = Map<String, dynamic>.from(rawData);

        if (nested['data'] is List) {
          rawData = nested['data'];
        }
      }

      if (rawData is! List) {
        rawData = root['recent_files'];
      }

      if (rawData is! List) {
        rawData = root['histories'];
      }
    }

    if (rawData is! List) {
      return [];
    }

    return rawData
        .whereType<Map>()
        .map((item) => _RecentFile.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  // ============================================================
  // BUILD AVATAR URL
  // ============================================================

  String _buildAvatarUrl(String avatar) {
    if (avatar.startsWith('http://') || avatar.startsWith('https://')) {
      return avatar;
    }

    final baseUrl = ApiService.baseUrl;

    final apiIndex = baseUrl.indexOf('/api');

    if (apiIndex == -1) {
      return avatar;
    }

    final serverUrl = baseUrl.substring(0, apiIndex);

    String cleanAvatar = avatar.trim();

    while (cleanAvatar.startsWith('/')) {
      cleanAvatar = cleanAvatar.substring(1);
    }

    // Already public storage path
    if (cleanAvatar.startsWith('storage/')) {
      return '$serverUrl/$cleanAvatar';
    }

    // Laravel public disk
    return '$serverUrl/storage/$cleanAvatar';
  }

  // ============================================================
  // REFRESH HOME
  // ============================================================

  Future<void> _refreshHome() async {
    await Future.wait([_loadProfile(), _loadRecentFiles()]);
  }

  // ============================================================
  // OPEN PROFILE
  // ============================================================

  Future<void> _openProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );

    if (!mounted) return;

    await _refreshHome();
  }

  // ============================================================
  // QUICK ACTION ROUTING
  // ============================================================

  void _onQuickActionTap(_QuickAction action) {
    if (action.title == 'Scan') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ScanDocumentScreen()),
      );
      return;
    }

    if (action.title == 'Merge') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FilePickerScreen(
            toolName: 'Merge PDF',
            allowedExtensions: const ['pdf'],
            allowMultiple: true,
          ),
        ),
      );
      return;
    }

    if (action.title == 'Compress') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FilePickerScreen(
            toolName: 'Compress PDF',
            allowedExtensions: const ['pdf'],
            allowMultiple: false,
          ),
        ),
      );
      return;
    }

    if (action.title == 'OCR') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FilePickerScreen(
            toolName: 'OCR',
            allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
            allowMultiple: false,
          ),
        ),
      );
      return;
    }

    if (action.title == 'Convert') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AllToolsScreen()),
      );
      return;
    }

    if (action.title == 'Sign') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FilePickerScreen(
            toolName: 'Sign PDF',
            allowedExtensions: const ['pdf'],
            allowMultiple: false,
          ),
        ),
      );
      return;
    }

    if (action.title == 'Split') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => FilePickerScreen(
            toolName: 'Split PDF',
            allowedExtensions: const ['pdf'],
            allowMultiple: false,
          ),
        ),
      );
      return;
    }

    if (action.title == 'More') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AllToolsScreen()),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FilePickerScreen(
          toolName: action.title,
          allowedExtensions: const ['pdf'],
          allowMultiple: false,
        ),
      ),
    );
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
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
  // USER INITIAL
  // ============================================================

  String get _userInitial {
    final name = _userName.trim();

    if (name.isEmpty || name == 'there') {
      return 'U';
    }

    return name.characters.first.toUpperCase();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F9FF),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshHome,
          color: const Color(0xFF1769FF),
          child: Stack(
            children: [
              const _BackgroundDecorations(),

              SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(),

                    const SizedBox(height: 20),

                    _buildSearchBar(),

                    const SizedBox(height: 18),

                    _buildAiAssistantCard(),

                    const SizedBox(height: 22),

                    _buildQuickActions(),

                    const SizedBox(height: 22),

                    _buildRecentFiles(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Good Morning 👋',
                style: TextStyle(
                  color: Color(0xFF627A9E),
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 5),

              Text(
                _isLoadingProfile ? 'Loading...' : _userName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF10255C),
                  fontSize: 27,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                ),
              ),

              const SizedBox(height: 7),

              Text(
                "Let's make your PDF work effortless.",
                style: TextStyle(
                  color: const Color(0xFF627A9E).withValues(alpha: 0.95),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        Row(
          children: [
            _SmallGlassButton(
              icon: Icons.notifications_none_rounded,
              showBadge: true,
              onTap: () {
                _showMessage('Notifications will be added next.');
              },
            ),

            const SizedBox(width: 10),

            GestureDetector(onTap: _openProfile, child: _buildHeaderAvatar()),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // HEADER AVATAR
  // ============================================================

  Widget _buildHeaderAvatar() {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.56),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.80),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6D9EEB).withValues(alpha: 0.14),
            blurRadius: 20,
          ),
        ],
      ),
      child: ClipOval(
        child: _avatarUrl != null && _avatarUrl!.isNotEmpty
            ? Image.network(
                _avatarUrl!,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    return child;
                  }

                  return _avatarPlaceholder();
                },
                errorBuilder: (_, __, ___) {
                  debugPrint('❌ Home avatar failed: $_avatarUrl');

                  return _avatarPlaceholder();
                },
              )
            : _avatarPlaceholder(),
      ),
    );
  }

  Widget _avatarPlaceholder() {
    if (_isLoadingProfile) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF1769FF),
          ),
        ),
      );
    }

    return Container(
      color: Colors.white.withValues(alpha: 0.50),
      child: Center(
        child: Text(
          _userInitial,
          style: const TextStyle(
            color: Color(0xFF1769FF),
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SEARCH BAR
  // ============================================================

  Widget _buildSearchBar() {
    return Row(
      children: [
        Expanded(
          child: _GlassContainer(
            borderRadius: 19,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  color: Color(0xFF6D82A2),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Search tools or files',
                    style: TextStyle(
                      color: const Color(0xFF7184A4).withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 10),

        _SmallGlassButton(
          icon: Icons.tune_rounded,
          onTap: () {
            _showMessage('Filter options will be added next.');
          },
        ),
      ],
    );
  }

  // ============================================================
  // AI ASSISTANT CARD
  // ============================================================

  Widget _buildAiAssistantCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(27),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(27),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF5A9BFF), Color(0xFF1769FF), Color(0xFF0958E8)],
            ),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.38),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1769FF).withValues(alpha: 0.24),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Row(
            children: [
              const _AiIllustration(),

              const SizedBox(width: 16),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI PDF Assistant',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 7),

                    const Text(
                      'Ask anything about your PDF.\n'
                      'Summarize, explain, analyze and more.',
                      style: TextStyle(
                        color: Color(0xFFEAF3FF),
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 13),

                    GestureDetector(
                      onTap: () {
                        _showMessage('AI Assistant will be connected next.');
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.23),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.42),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 21,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // QUICK ACTIONS
  // ============================================================

  Widget _buildQuickActions() {
    return _GlassContainer(
      borderRadius: 28,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Quick Actions',
                  style: TextStyle(
                    color: Color(0xFF10255C),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const AllToolsScreen()),
                  );
                },
                child: const Row(
                  children: [
                    Text(
                      'View All',
                      style: TextStyle(
                        color: Color(0xFF1769FF),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, color: Color(0xFF1769FF)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          GridView.builder(
            itemCount: _quickActions.length,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.90,
            ),
            itemBuilder: (context, index) {
              final action = _quickActions[index];

              return _QuickActionTile(
                action: action,
                onTap: () => _onQuickActionTap(action),
              );
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RECENT FILES
  // ============================================================

  Widget _buildRecentFiles() {
    return _GlassContainer(
      borderRadius: 28,
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent Files',
                  style: TextStyle(
                    color: Color(0xFF10255C),
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),

              GestureDetector(
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  );

                  if (!mounted) return;

                  await _loadRecentFiles();
                },
                child: const Row(
                  children: [
                    Text(
                      'See All',
                      style: TextStyle(
                        color: Color(0xFF1769FF),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.chevron_right_rounded, color: Color(0xFF1769FF)),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          if (_isLoadingRecentFiles)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 30),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF1769FF)),
              ),
            )
          else if (_recentFiles.isEmpty)
            _buildEmptyRecentFiles()
          else
            ...List.generate(_recentFiles.length, (index) {
              final file = _recentFiles[index];

              return _RecentFileTile(
                file: file,
                showDivider: index != _recentFiles.length - 1,
                onTap: () {
                  _showMessage('This file is stored in your phone storage.');
                },
              );
            }),
        ],
      ),
    );
  }

  Widget _buildEmptyRecentFiles() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(Icons.folder_open_rounded, size: 40, color: Color(0xFF8BA1BF)),
          SizedBox(height: 10),
          Text(
            'No recent files yet',
            style: TextStyle(
              color: Color(0xFF7184A4),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// RECENT FILE
// ============================================================

class _RecentFile {
  final int id;
  final String name;
  final String size;
  final String date;
  final IconData icon;
  final Color iconColor;
  final String toolName;
  final String status;

  const _RecentFile({
    required this.id,
    required this.name,
    required this.size,
    required this.date,
    required this.icon,
    required this.iconColor,
    required this.toolName,
    required this.status,
  });

  factory _RecentFile.fromJson(Map<String, dynamic> json) {
    final toolName = (json['tool_name'] ?? 'PDF Tool').toString();

    final fileName =
        (json['output_file_name'] ?? json['file_name'] ?? 'Untitled PDF')
            .toString();

    return _RecentFile(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: fileName,
      size: _formatSize(json['file_size']),
      date: _formatDate(json['created_at']),
      icon: _getToolIcon(toolName),
      iconColor: _getToolColor(toolName),
      toolName: toolName,
      status: (json['status'] ?? 'completed').toString(),
    );
  }

  static String _formatSize(dynamic value) {
    if (value == null) {
      return 'Unknown size';
    }

    final bytes = int.tryParse(value.toString());

    if (bytes == null) {
      return 'Unknown size';
    }

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

  static String _formatDate(dynamic value) {
    if (value == null) {
      return 'Recently';
    }

    final parsed = DateTime.tryParse(value.toString());

    if (parsed == null) {
      return 'Recently';
    }

    final date = parsed.toLocal();

    final now = DateTime.now();

    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Just now';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    }

    if (difference.inDays == 1) {
      return 'Yesterday';
    }

    if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    }

    return '${date.day}/${date.month}/${date.year}';
  }

  static IconData _getToolIcon(String toolName) {
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

    if (name.contains('rotate')) {
      return Icons.rotate_right_rounded;
    }

    if (name.contains('protect')) {
      return Icons.lock_outline_rounded;
    }

    if (name.contains('watermark')) {
      return Icons.branding_watermark_outlined;
    }

    if (name.contains('ai') || name.contains('summar')) {
      return Icons.auto_awesome_rounded;
    }

    return Icons.picture_as_pdf_rounded;
  }

  static Color _getToolColor(String toolName) {
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
}

// ============================================================
// QUICK ACTION TILE
// ============================================================

class _QuickActionTile extends StatelessWidget {
  final _QuickAction action;
  final VoidCallback onTap;

  const _QuickActionTile({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.50),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.78)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: action.color.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(action.icon, color: action.color, size: 22),
                ),
                const SizedBox(height: 7),
                Text(
                  action.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF1A2A47),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
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

// ============================================================
// RECENT FILE TILE
// ============================================================

class _RecentFileTile extends StatelessWidget {
  final _RecentFile file;
  final bool showDivider;
  final VoidCallback onTap;

  const _RecentFileTile({
    required this.file,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 3),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: file.iconColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(file.icon, color: file.iconColor, size: 28),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
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
                        '${file.size}  •  ${file.toolName}  •  ${file.date}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF7385A3),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                const Icon(
                  Icons.more_vert_rounded,
                  color: Color(0xFF657996),
                  size: 21,
                ),
              ],
            ),

            if (showDivider) ...[
              const SizedBox(height: 10),
              Container(height: 1, color: const Color(0xFFD7E4F4)),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SMALL GLASS BUTTON
// ============================================================

class _SmallGlassButton extends StatelessWidget {
  final IconData icon;
  final bool showBadge;
  final VoidCallback onTap;

  const _SmallGlassButton({
    required this.icon,
    required this.onTap,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.48),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.80),
                  ),
                ),
                child: Icon(icon, color: const Color(0xFF4D6487), size: 23),
              ),
            ),
          ),

          if (showBadge)
            Positioned(
              top: 5,
              right: 5,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF1769FF),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// GLASS CONTAINER
// ============================================================

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

// ============================================================
// AI ILLUSTRATION
// ============================================================

class _AiIllustration extends StatelessWidget {
  const _AiIllustration();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 94,
      height: 118,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 10,
            child: Container(
              width: 64,
              height: 18,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
          ),

          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: Colors.white.withValues(alpha: 0.18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.12),
                  blurRadius: 16,
                ),
              ],
            ),
            child: const Center(
              child: Text(
                'AI',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// BACKGROUND DECORATIONS
// ============================================================

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
// QUICK ACTION MODEL
// ============================================================

class _QuickAction {
  final String title;
  final IconData icon;
  final Color color;

  const _QuickAction({
    required this.title,
    required this.icon,
    required this.color,
  });
}
