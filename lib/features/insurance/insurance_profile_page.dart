import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:road_rescue/theme/road_rescue_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class InsuranceProfilePage extends StatefulWidget {
  const InsuranceProfilePage({super.key});

  @override
  State<InsuranceProfilePage> createState() => _InsuranceProfilePageState();
}

class _InsuranceProfilePageState extends State<InsuranceProfilePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoading = true;

  String _name = 'Insurance Officer';
  String _email = '';
  String _companyName = 'Insurance Provider';
  String _role = 'insurance_provider';
  String? _photoUrl;
  bool _isSavingPhoto = false;

  // ============================================================
  // PREMIUM ROADRESCUE DESIGN SYSTEM
  // ============================================================

  static const Color _background = RoadRescueColors.background;
  static const Color _surface = RoadRescueColors.surface;
  static const Color _surfaceLight = RoadRescueColors.elevatedSurface;
  static const Color _surfaceSecondary = RoadRescueColors.surface;

  static const Color _yellow = RoadRescueColors.accent;
  static const Color _white = RoadRescueColors.foreground;
  static const Color _muted = RoadRescueColors.muted;
  static const Color _mutedDark = RoadRescueColors.mutedDark;
  static const Color _border = RoadRescueColors.border;

  static const Color _red = Color(0xFFFF5055);
  static const Color _blue = Color(0xFF2697FF);
  static const Color _green = Color(0xFF19D98B);
  static const Color _purple = Color(0xFFB36BFF);

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ============================================================
  // LOAD PROFILE
  // ============================================================

  Future<void> _loadProfile() async {
    try {
      final User? user = _auth.currentUser;

      if (user == null) {
        if (!mounted) return;

        setState(() {
          _isLoading = false;
        });

        return;
      }

      _email = user.email ?? '';

      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .get();

      if (snapshot.exists) {
        final Map<String, dynamic>? data = snapshot.data();

        if (data != null) {
          _name = _getValue(data, ['name', 'displayName', 'fullName'], _name);

          _companyName = _getValue(data, [
            'companyName',
            'company',
          ], _companyName);

          _role = _getValue(data, ['role'], _role);
          _photoUrl = _getValue(data, [
            'photoUrl',
            'profilePhotoUrl',
            'profileImageUrl',
          ], '');

          if (_email.isEmpty) {
            _email = _getValue(data, ['email'], '');
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Profile loading error: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // GET VALUE
  // ============================================================

  String _getValue(
    Map<String, dynamic> data,
    List<String> keys,
    String fallback,
  ) {
    for (final String key in keys) {
      final dynamic value = data[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    return fallback;
  }

  // ============================================================
  // FORMAT ROLE
  // ============================================================

  String _formatRole(String role) {
    if (role.isEmpty) {
      return 'Insurance Officer';
    }

    return role
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? ''
              : word[0].toUpperCase() + word.substring(1).toLowerCase(),
        )
        .join(' ');
  }

  // ============================================================
  // INITIALS
  // ============================================================

  String get _initials {
    final List<String> parts = _name.trim().split(RegExp(r'\s+'));

    if (parts.isEmpty || parts[0].isEmpty) {
      return 'IO';
    }

    if (parts.length == 1) {
      return parts[0][0].toUpperCase();
    }

    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Future<void> _chooseProfilePhoto() async {
    if (_isSavingPhoto) return;

    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: _mutedDark,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Update profile photo',
                style: GoogleFonts.poppins(
                  color: _white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              _photoSourceTile(
                icon: Icons.photo_library_rounded,
                title: 'Choose from gallery',
                source: ImageSource.gallery,
              ),
              _photoSourceTile(
                icon: Icons.camera_alt_rounded,
                title: 'Take a photo',
                source: ImageSource.camera,
              ),
              if (_photoUrl != null && _photoUrl!.isNotEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete_outline, color: _red),
                  title: Text(
                    'Remove current photo',
                    style: GoogleFonts.poppins(
                      color: _red,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _removeProfilePhoto();
                  },
                ),
            ],
          ),
        ),
      ),
    );

    if (source == null || !mounted) return;
    final XFile? picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 90,
      maxWidth: 1600,
    );
    if (picked == null || !mounted) return;

    final CroppedFile? cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      compressQuality: 88,
      maxWidth: 1200,
      maxHeight: 1200,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop profile photo',
          toolbarColor: _surface,
          toolbarWidgetColor: _white,
          activeControlsWidgetColor: _yellow,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop profile photo',
          aspectRatioLockEnabled: true,
        ),
      ],
    );
    if (cropped != null && mounted) await _saveProfilePhoto(cropped);
  }

  Widget _photoSourceTile({
    required IconData icon,
    required String title,
    required ImageSource source,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: _yellow),
      title: Text(
        title,
        style: GoogleFonts.poppins(color: _white, fontSize: 12),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: _mutedDark),
      onTap: () => Navigator.pop(context, source),
    );
  }

  Future<void> _saveProfilePhoto(CroppedFile cropped) async {
    final User? user = _auth.currentUser;
    if (user == null) return;
    setState(() => _isSavingPhoto = true);

    try {
      final Reference reference = _storage
          .ref()
          .child('profile_photos')
          .child(user.uid)
          .child('profile.jpg');
      await reference.putData(
        await cropped.readAsBytes(),
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await reference.getDownloadURL();
      await _firestore.collection('users').doc(user.uid).set({
        'photoUrl': url,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => _photoUrl = url);
      _showPhotoMessage('Profile photo updated.');
    } catch (e) {
      debugPrint('Profile photo save error: $e');
      if (mounted) {
        _showPhotoMessage('Unable to save profile photo.', error: true);
      }
    } finally {
      if (mounted) setState(() => _isSavingPhoto = false);
    }
  }

  Future<void> _removeProfilePhoto() async {
    final User? user = _auth.currentUser;
    if (user == null) return;
    setState(() => _isSavingPhoto = true);

    try {
      final reference = _storage
          .ref()
          .child('profile_photos')
          .child(user.uid)
          .child('profile.jpg');
      try {
        await reference.delete();
      } on FirebaseException catch (e) {
        if (e.code != 'object-not-found') rethrow;
      }
      await _firestore.collection('users').doc(user.uid).set({
        'photoUrl': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => _photoUrl = null);
      _showPhotoMessage('Profile photo removed.');
    } catch (e) {
      debugPrint('Profile photo remove error: $e');
      if (mounted) {
        _showPhotoMessage('Unable to remove profile photo.', error: true);
      }
    } finally {
      if (mounted) setState(() => _isSavingPhoto = false);
    }
  }

  void _showPhotoMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? _red : _surfaceSecondary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 30,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    color: _red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: _red,
                    size: 27,
                  ),
                ),

                const SizedBox(height: 15),

                Text(
                  'Logout',
                  style: GoogleFonts.poppins(
                    color: _white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),

                const SizedBox(height: 7),

                Text(
                  'Are you sure you want to logout from your insurance account?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: _muted,
                    fontSize: 11,
                    height: 1.45,
                  ),
                ),

                const SizedBox(height: 22),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.pop(context, false);
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _white,
                          side: const BorderSide(color: _border),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _red,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Logout',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _auth.signOut();

      if (!mounted) return;

      Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: _surface,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          content: Text(
            'Unable to logout. Please try again.',
            style: GoogleFonts.poppins(color: _white, fontSize: 11),
          ),
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),

            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : RefreshIndicator(
                      color: _yellow,
                      backgroundColor: _surface,
                      onRefresh: _loadProfile,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                        children: [
                          _buildProfileHeader(),

                          const SizedBox(height: 20),

                          _buildSectionTitle(
                            'PROFILE INFORMATION',
                            'Your insurance account details',
                          ),

                          const SizedBox(height: 10),

                          _buildInformationSection(),

                          const SizedBox(height: 20),

                          _buildSectionTitle(
                            'ACCOUNT SETTINGS',
                            'Manage your RoadRescue account',
                          ),

                          const SizedBox(height: 10),

                          _buildAccountSection(),

                          const SizedBox(height: 20),

                          _buildLogoutButton(),

                          const SizedBox(height: 12),

                          Center(
                            child: Text(
                              'ROADRESCUE • INSURANCE PORTAL',
                              style: GoogleFonts.poppins(
                                color: _mutedDark,
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
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
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'INSURANCE PORTAL',
                  style: GoogleFonts.poppins(
                    color: _yellow,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.5,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  'My Profile',
                  style: GoogleFonts.poppins(
                    color: _white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),

          _buildIconButton(
            icon: Icons.refresh_rounded,
            iconColor: _yellow,
            onTap: _loadProfile,
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onTap,
    Color iconColor = _white,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            color: _white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.7,
          ),
        ),

        const SizedBox(height: 2),

        Text(
          subtitle,
          style: GoogleFonts.poppins(
            color: _mutedDark,
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PROFILE HEADER
  // ============================================================

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_surfaceLight, _surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: _yellow.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                height: 104,
                width: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFE45A), Color(0xFFFFC107)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _yellow.withValues(alpha: 0.2),
                      blurRadius: 25,
                      spreadRadius: 3,
                    ),
                  ],
                ),
                child: Center(
                  child: _photoUrl != null && _photoUrl!.isNotEmpty
                      ? ClipOval(
                          child: Image.network(
                            _photoUrl!,
                            width: 104,
                            height: 104,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _buildInitialAvatar(),
                          ),
                        )
                      : _buildInitialAvatar(),
                ),
              ),

              Positioned(
                right: 0,
                bottom: 3,
                child: Container(
                  height: 30,
                  width: 30,
                  decoration: BoxDecoration(
                    color: _green,
                    shape: BoxShape.circle,
                    border: Border.all(color: _surface, width: 4),
                  ),
                  child: IconButton(
                    onPressed: _isSavingPhoto ? null : _chooseProfilePhoto,
                    padding: EdgeInsets.zero,
                    tooltip: 'Change profile photo',
                    icon: _isSavingPhoto
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.black,
                            size: 15,
                          ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Text(
            _name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              color: _white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 6),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            decoration: BoxDecoration(
              color: _yellow.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _yellow.withValues(alpha: 0.13)),
            ),
            child: Text(
              _formatRole(_role).toUpperCase(),
              style: GoogleFonts.poppins(
                color: _yellow,
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),

          const SizedBox(height: 9),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.business_rounded, color: _mutedDark, size: 14),

              const SizedBox(width: 5),

              Flexible(
                child: Text(
                  _companyName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: _muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),

          if (_email.isNotEmpty) ...[
            const SizedBox(height: 5),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.email_rounded, color: _mutedDark, size: 13),

                const SizedBox(width: 5),

                Flexible(
                  child: Text(
                    _email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      color: _mutedDark,
                      fontSize: 9.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInitialAvatar() {
    return Text(
      _initials,
      style: GoogleFonts.poppins(
        color: Colors.black,
        fontSize: 30,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  // ============================================================
  // INFORMATION SECTION
  // ============================================================

  Widget _buildInformationSection() {
    return _buildSectionCard(
      children: [
        _buildInfoTile(
          icon: Icons.person_rounded,
          iconColor: _yellow,
          title: 'Full Name',
          value: _name,
        ),

        _buildDivider(),

        _buildInfoTile(
          icon: Icons.email_rounded,
          iconColor: _blue,
          title: 'Email Address',
          value: _email.isEmpty ? 'Not available' : _email,
        ),

        _buildDivider(),

        _buildInfoTile(
          icon: Icons.business_rounded,
          iconColor: _green,
          title: 'Insurance Company',
          value: _companyName,
        ),

        _buildDivider(),

        _buildInfoTile(
          icon: Icons.badge_rounded,
          iconColor: _purple,
          title: 'Account Role',
          value: _formatRole(_role),
        ),
      ],
    );
  }

  // ============================================================
  // ACCOUNT SETTINGS
  // ============================================================

  Widget _buildAccountSection() {
    return _buildSectionCard(
      children: [
        _buildActionTile(
          icon: Icons.security_rounded,
          iconColor: _blue,
          title: 'Security',
          subtitle: 'Your account is protected by Firebase Authentication',
          onTap: () {
            _showComingSoon('Security settings');
          },
        ),

        _buildDivider(),

        _buildActionTile(
          icon: Icons.notifications_active_rounded,
          iconColor: _yellow,
          title: 'Notifications',
          subtitle: 'Manage insurance claim notifications',
          onTap: () {
            _showComingSoon('Notification settings');
          },
        ),

        _buildDivider(),

        _buildActionTile(
          icon: Icons.info_rounded,
          iconColor: _green,
          title: 'About RoadRescue',
          subtitle: 'Vehicle breakdown and roadside assistance platform',
          onTap: () {
            _showAboutDialog();
          },
        ),
      ],
    );
  }

  // ============================================================
  // SECTION CARD
  // ============================================================

  Widget _buildSectionCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.16),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  // ============================================================
  // INFO TILE
  // ============================================================

  Widget _buildInfoTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: iconColor.withValues(alpha: 0.08)),
            ),
            child: Icon(icon, color: iconColor, size: 21),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    color: _mutedDark,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    color: _white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACTION TILE
  // ============================================================

  Widget _buildActionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: iconColor, size: 21),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        color: _white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(
                        color: _muted,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w400,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Container(
                height: 30,
                width: 30,
                decoration: BoxDecoration(
                  color: _surfaceSecondary,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.chevron_right_rounded,
                  color: _mutedDark,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // DIVIDER
  // ============================================================

  Widget _buildDivider() {
    return Container(height: 1, color: _border.withValues(alpha: 0.65));
  }

  // ============================================================
  // LOGOUT BUTTON
  // ============================================================

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: _logout,
        style: OutlinedButton.styleFrom(
          foregroundColor: _red,
          side: BorderSide(color: _red.withValues(alpha: 0.35)),
          backgroundColor: _red.withValues(alpha: 0.035),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        icon: const Icon(Icons.logout_rounded, size: 19),
        label: Text(
          'Logout from Account',
          style: GoogleFonts.poppins(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 64,
            width: 64,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: _border),
            ),
            child: const Center(
              child: SizedBox(
                height: 25,
                width: 25,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: _yellow,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            'Loading profile...',
            style: GoogleFonts.poppins(
              color: _white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'Getting your account information',
            style: GoogleFonts.poppins(color: _mutedDark, fontSize: 10),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // COMING SOON
  // ============================================================

  void _showComingSoon(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _surface,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: _border),
        ),
        content: Row(
          children: [
            Container(
              height: 32,
              width: 32,
              decoration: BoxDecoration(
                color: _yellow.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(
                Icons.construction_rounded,
                color: _yellow,
                size: 17,
              ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Text(
                '$title will be available soon.',
                style: GoogleFonts.poppins(
                  color: _white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ABOUT DIALOG
  // ============================================================

  void _showAboutDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: _border),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  height: 64,
                  width: 64,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFFE45A), Color(0xFFFFC107)],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.shield_rounded,
                    color: Colors.black,
                    size: 32,
                  ),
                ),

                const SizedBox(height: 15),

                Text(
                  'RoadRescue',
                  style: GoogleFonts.poppins(
                    color: _yellow,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 7),

                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _yellow.withValues(alpha: 0.09),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    'INSURANCE PORTAL',
                    style: GoogleFonts.poppins(
                      color: _yellow,
                      fontSize: 8,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  'RoadRescue is a vehicle breakdown and roadside assistance platform designed to connect vehicle owners with roadside assistance providers and support insurance claim processing.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: _muted,
                    fontSize: 10.5,
                    height: 1.55,
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _yellow,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
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
}
