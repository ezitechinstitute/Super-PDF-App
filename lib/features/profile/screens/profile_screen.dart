import 'dart:ui';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/api_service.dart';
import '../../auth/screens/login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ApiService _apiService = ApiService.instance;
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  bool _isDeletingAvatar = false;
  bool _isLoggingOut = false;

  String? _avatarUrl;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD PROFILE
  // ============================================================

  Future<void> _loadProfile() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      debugPrint('==========================================');
      debugPrint('👤 GET PROFILE');
      debugPrint('📡 Calling /profile...');
      debugPrint('==========================================');

      final response = await _apiService.getProfile();

      debugPrint('==========================================');
      debugPrint('✅ PROFILE API RESPONSE');
      debugPrint('Status: ${response.statusCode}');
      debugPrint('Data: ${response.data}');
      debugPrint('==========================================');

      final profile = _extractProfile(response.data);

      if (profile == null) {
        throw Exception('Profile data was not found in the API response.');
      }

      final name = profile['name']?.toString().trim() ?? '';
      final email = profile['email']?.toString().trim() ?? '';
      final phone = profile['phone']?.toString().trim() ?? '';
      final avatar = profile['avatar'];

      String? parsedAvatar;

      if (avatar != null && avatar.toString().trim().isNotEmpty) {
        parsedAvatar = _buildAvatarUrl(avatar.toString().trim());
      }

      debugPrint('👤 Name: $name');
      debugPrint('📧 Email: $email');
      debugPrint('📱 Phone: $phone');
      debugPrint('🖼️ Avatar raw: $avatar');
      debugPrint('🖼️ Avatar URL: $parsedAvatar');

      _nameController.text = name;
      _emailController.text = email;
      _phoneController.text = phone;

      if (!mounted) return;

      setState(() {
        _avatarUrl = parsedAvatar;
        _isLoading = false;
      });
    } on DioException catch (e) {
      debugPrint('==========================================');
      debugPrint('❌ PROFILE API ERROR');
      debugPrint('Status: ${e.response?.statusCode}');
      debugPrint('Response: ${e.response?.data}');
      debugPrint('Message: ${e.message}');
      debugPrint('==========================================');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = _extractDioError(e);
      });
    } catch (e) {
      debugPrint('==========================================');
      debugPrint('❌ PROFILE ERROR');
      debugPrint('$e');
      debugPrint('==========================================');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load profile.';
      });
    }
  }

  // ============================================================
  // EXTRACT PROFILE
  // Supports:
  // {user: {...}}
  // {data: {...}}
  // {profile: {...}}
  // direct object
  // ============================================================

  Map<String, dynamic>? _extractProfile(dynamic responseData) {
    if (responseData is! Map) {
      return null;
    }

    final root = Map<String, dynamic>.from(responseData);

    // Current Laravel response:
    // {
    //   success: true,
    //   message: "...",
    //   user: {...}
    // }
    final user = root['user'];

    if (user is Map) {
      return Map<String, dynamic>.from(user);
    }

    // Generic API response:
    // { data: {...} }
    final data = root['data'];

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    // Generic profile response:
    // { profile: {...} }
    final profile = root['profile'];

    if (profile is Map) {
      return Map<String, dynamic>.from(profile);
    }

    // Direct object
    if (root.containsKey('name') ||
        root.containsKey('email') ||
        root.containsKey('phone')) {
      return root;
    }

    return null;
  }

  // ============================================================
  // AVATAR URL
  //
  // Laravel public disk:
  // avatars/file.jpg
  //
  // Public URL:
  // http://IP:8000/storage/avatars/file.jpg
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

    // Already contains storage/
    if (cleanAvatar.startsWith('storage/')) {
      return '$serverUrl/$cleanAvatar';
    }

    // Laravel public disk path
    return '$serverUrl/storage/$cleanAvatar';
  }

  // ============================================================
  // SAVE PROFILE
  // ============================================================

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final phone = _phoneController.text.trim();

    if (name.isEmpty) {
      _showMessage('Name is required.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      debugPrint('==========================================');
      debugPrint('💾 UPDATE PROFILE');
      debugPrint('Name: $name');
      debugPrint('Phone: $phone');
      debugPrint('==========================================');

      final response = await _apiService.updateProfile(
        name: name,
        phone: phone,
      );

      debugPrint('✅ UPDATE PROFILE RESPONSE');
      debugPrint('${response.data}');

      final profile = _extractProfile(response.data);

      if (profile != null) {
        final updatedName = profile['name']?.toString().trim();

        final updatedPhone = profile['phone']?.toString().trim();

        final avatar = profile['avatar'];

        if (updatedName != null && updatedName.isNotEmpty) {
          _nameController.text = updatedName;
        }

        if (updatedPhone != null) {
          _phoneController.text = updatedPhone;
        }

        if (avatar != null && avatar.toString().trim().isNotEmpty) {
          _avatarUrl = _buildAvatarUrl(avatar.toString().trim());
        }
      }

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showMessage('Profile updated successfully.');
    } on DioException catch (e) {
      debugPrint('❌ UPDATE PROFILE ERROR');
      debugPrint('${e.response?.data}');

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showMessage(_extractDioError(e));
    } catch (e) {
      debugPrint('❌ UPDATE PROFILE ERROR: $e');

      if (!mounted) return;

      setState(() {
        _isSaving = false;
      });

      _showMessage('Unable to update profile.');
    }
  }

  // ============================================================
  // PICK AVATAR
  // ============================================================

  Future<void> _pickAvatar() async {
    if (_isUploadingAvatar || _isDeletingAvatar) {
      return;
    }

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
        maxHeight: 1200,
      );

      if (image == null) {
        return;
      }

      await _uploadAvatar(image.path);
    } catch (e) {
      debugPrint('❌ IMAGE PICKER ERROR: $e');

      if (!mounted) return;

      _showMessage('Unable to select image.');
    }
  }

  // ============================================================
  // UPLOAD AVATAR
  // ============================================================

  Future<void> _uploadAvatar(String filePath) async {
    if (!mounted) return;

    setState(() {
      _isUploadingAvatar = true;
    });

    try {
      debugPrint('==========================================');
      debugPrint('🖼️ UPLOAD AVATAR');
      debugPrint('📁 File: $filePath');
      debugPrint('==========================================');

      final response = await _apiService.uploadAvatar(filePath: filePath);

      debugPrint('✅ AVATAR UPLOAD RESPONSE');
      debugPrint('${response.data}');

      String? avatarValue;

      // Current Laravel response:
      // {
      //   success: true,
      //   message: "...",
      //   avatar: "avatars/xxxxx.jpg"
      // }
      if (response.data is Map) {
        final root = Map<String, dynamic>.from(response.data);

        final directAvatar = root['avatar'];

        if (directAvatar != null && directAvatar.toString().trim().isNotEmpty) {
          avatarValue = directAvatar.toString().trim();
        }

        // Fallback: data.avatar
        if (avatarValue == null) {
          final data = root['data'];

          if (data is Map) {
            final nestedAvatar = data['avatar'];

            if (nestedAvatar != null &&
                nestedAvatar.toString().trim().isNotEmpty) {
              avatarValue = nestedAvatar.toString().trim();
            }
          }
        }

        // Fallback: user.avatar
        if (avatarValue == null) {
          final user = root['user'];

          if (user is Map) {
            final userAvatar = user['avatar'];

            if (userAvatar != null && userAvatar.toString().trim().isNotEmpty) {
              avatarValue = userAvatar.toString().trim();
            }
          }
        }

        // Fallback: avatar_url
        if (avatarValue == null) {
          final avatarUrl = root['avatar_url'];

          if (avatarUrl != null && avatarUrl.toString().trim().isNotEmpty) {
            avatarValue = avatarUrl.toString().trim();
          }
        }
      }

      final finalAvatarUrl = avatarValue != null
          ? _buildAvatarUrl(avatarValue)
          : null;

      debugPrint('🖼️ Avatar value: $avatarValue');

      debugPrint('🖼️ Final avatar URL: $finalAvatarUrl');

      if (!mounted) return;

      setState(() {
        _avatarUrl = finalAvatarUrl;
        _isUploadingAvatar = false;
      });

      // Safest fallback.
      // Reload profile if URL wasn't returned.
      if (finalAvatarUrl == null) {
        await _loadProfile();
      }

      if (!mounted) return;

      _showMessage('Profile photo updated.');
    } on DioException catch (e) {
      debugPrint('❌ AVATAR UPLOAD ERROR');

      debugPrint('Status: ${e.response?.statusCode}');

      debugPrint('Response: ${e.response?.data}');

      if (!mounted) return;

      setState(() {
        _isUploadingAvatar = false;
      });

      _showMessage(_extractDioError(e));
    } catch (e) {
      debugPrint('❌ AVATAR UPLOAD ERROR: $e');

      if (!mounted) return;

      setState(() {
        _isUploadingAvatar = false;
      });

      _showMessage('Unable to upload profile photo.');
    }
  }

  // ============================================================
  // DELETE AVATAR
  // ============================================================

  Future<void> _deleteAvatar() async {
    if (_isDeletingAvatar || _isUploadingAvatar) {
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Remove profile photo'),
          content: const Text(
            'Are you sure you want to remove your profile photo?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isDeletingAvatar = true;
    });

    try {
      debugPrint('🗑️ DELETE AVATAR');

      await _apiService.deleteAvatar();

      if (!mounted) return;

      setState(() {
        _avatarUrl = null;
        _isDeletingAvatar = false;
      });

      _showMessage('Profile photo removed.');
    } on DioException catch (e) {
      debugPrint('❌ DELETE AVATAR ERROR');

      debugPrint('${e.response?.data}');

      if (!mounted) return;

      setState(() {
        _isDeletingAvatar = false;
      });

      _showMessage(_extractDioError(e));
    } catch (e) {
      debugPrint('❌ DELETE AVATAR ERROR: $e');

      if (!mounted) return;

      setState(() {
        _isDeletingAvatar = false;
      });

      _showMessage('Unable to remove profile photo.');
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text(
            'Are you sure you want to logout from your account?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext, false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isLoggingOut = true;
    });

    try {
      await _apiService.logout();
    } catch (e) {
      debugPrint('Logout error: $e');
    }

    if (!mounted) return;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String? get _displayInitial {
    final name = _nameController.text.trim();

    if (name.isEmpty) {
      return null;
    }

    return name.characters.first.toUpperCase();
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
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF7FBFF), Color(0xFFEAF4FF), Color(0xFFDCEBFF)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              const _BackgroundDecoration(),

              RefreshIndicator(
                onRefresh: _loadProfile,
                color: const Color(0xFF1769FF),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
                  child: _isLoading
                      ? const SizedBox(
                          height: 650,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF1769FF),
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildHeader(),

                            const SizedBox(height: 24),

                            _buildProfileCard(),

                            const SizedBox(height: 18),

                            _buildAccountCard(),

                            const SizedBox(height: 18),

                            _buildLogoutButton(),
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

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Row(
      children: [
        _CircleIconButton(
          icon: Icons.arrow_back_rounded,
          onTap: () => Navigator.pop(context),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Text(
            'Profile',
            style: TextStyle(
              color: Color(0xFF10255C),
              fontSize: 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
        ),
        _CircleIconButton(
          icon: Icons.refresh_rounded,
          onTap: _isLoading ? () {} : _loadProfile,
        ),
      ],
    );
  }

  // ============================================================
  // PROFILE CARD
  // ============================================================

  Widget _buildProfileCard() {
    return _GlassCard(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              _buildAvatar(),

              GestureDetector(
                onTap: _pickAvatar,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1769FF),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF1769FF).withValues(alpha: 0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: _isUploadingAvatar
                      ? const Padding(
                          padding: EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.camera_alt_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            _nameController.text.trim().isEmpty
                ? 'Your Name'
                : _nameController.text.trim(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF10255C),
              fontSize: 21,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            _emailController.text.trim().isEmpty
                ? 'No email'
                : _emailController.text.trim(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),

          if (_avatarUrl != null && _avatarUrl!.isNotEmpty) ...[
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: _isDeletingAvatar ? null : _deleteAvatar,
              icon: _isDeletingAvatar
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.delete_outline_rounded, size: 19),
              label: const Text('Remove Photo'),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // AVATAR
  // ============================================================

  Widget _buildAvatar() {
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      return Container(
        width: 112,
        height: 112,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1769FF).withValues(alpha: 0.18),
              blurRadius: 24,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.network(
            _avatarUrl!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) {
                return child;
              }

              return const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF1769FF),
                ),
              );
            },
            errorBuilder: (_, __, ___) {
              debugPrint('❌ Avatar image failed: $_avatarUrl');

              return _avatarPlaceholder();
            },
          ),
        ),
      );
    }

    return _avatarPlaceholder();
  }

  Widget _avatarPlaceholder() {
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2878FF), Color(0xFF0755E8)],
        ),
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1769FF).withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Center(
        child: _displayInitial != null
            ? Text(
                _displayInitial!,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                ),
              )
            : const Icon(Icons.person_rounded, color: Colors.white, size: 54),
      ),
    );
  }

  // ============================================================
  // ACCOUNT CARD
  // ============================================================

  Widget _buildAccountCard() {
    return _GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account Information',
            style: TextStyle(
              color: Color(0xFF10255C),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 18),

          _buildInput(
            label: 'Full Name',
            controller: _nameController,
            icon: Icons.person_outline_rounded,
          ),

          const SizedBox(height: 14),

          _buildInput(
            label: 'Email Address',
            controller: _emailController,
            icon: Icons.email_outlined,
            readOnly: true,
          ),

          const SizedBox(height: 14),

          _buildInput(
            label: 'Phone Number',
            controller: _phoneController,
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _isSaving ? null : _saveProfile,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1769FF),
                disabledBackgroundColor: const Color(0xFF9DBBEE),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_rounded, size: 21),
                        SizedBox(width: 8),
                        Text(
                          'Save Changes',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool readOnly = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: Color(0xFF10255C),
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF64748B)),
        prefixIcon: Icon(icon, color: const Color(0xFF1769FF)),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.72),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 17,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.9)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.9)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF1769FF), width: 1.4),
        ),
      ),
    );
  }

  // ============================================================
  // LOGOUT BUTTON
  // ============================================================

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton.icon(
        onPressed: _isLoggingOut ? null : _logout,
        icon: _isLoggingOut
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.logout_rounded),
        label: Text(
          _isLoggingOut ? 'Logging out...' : 'Logout',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFFD92D20),
          side: BorderSide(
            color: const Color(0xFFD92D20).withValues(alpha: 0.35),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// GLASS CARD
// ============================================================

class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.68),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.82),
              width: 1.1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1769FF).withValues(alpha: 0.07),
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
// CIRCLE BUTTON
// ============================================================

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

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
                border: Border.all(color: Colors.white.withValues(alpha: 0.8)),
              ),
              child: Icon(icon, color: const Color(0xFF10255C), size: 22),
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

class _BackgroundDecoration extends StatelessWidget {
  const _BackgroundDecoration();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -80,
            child: _BlurCircle(
              size: 280,
              color: const Color(0xFF7DB2FF).withValues(alpha: 0.30),
            ),
          ),
          Positioned(
            top: 260,
            left: -120,
            child: _BlurCircle(
              size: 240,
              color: const Color(0xFF4E8DFF).withValues(alpha: 0.16),
            ),
          ),
          Positioned(
            bottom: 40,
            right: -100,
            child: _BlurCircle(
              size: 230,
              color: const Color(0xFF9BC6FF).withValues(alpha: 0.24),
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
      imageFilter: ImageFilter.blur(sigmaX: 35, sigmaY: 35),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
