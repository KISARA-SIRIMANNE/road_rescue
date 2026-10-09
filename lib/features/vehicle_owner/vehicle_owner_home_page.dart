import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'request_assistance_page.dart';
import 'vehicle_owner_notifications_page.dart';

class VehicleOwnerHomePage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const VehicleOwnerHomePage({super.key, required this.userData});

  @override
  State<VehicleOwnerHomePage> createState() => _VehicleOwnerHomePageState();
}

class _VehicleOwnerHomePageState extends State<VehicleOwnerHomePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _imagePicker = ImagePicker();

  bool _isLoadingRequests = false;
  bool _isSavingProfile = false;
  bool _isUploadingPhoto = false;
  String _profilePhotoUrl = '';
  String _contactNumber = '';
  List<Map<String, dynamic>> _requestHistory = [];
  String? _requestHistoryError;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _notificationsStream;

  String get userId {
    return widget.userData['uid']?.toString() ?? _auth.currentUser?.uid ?? '';
  }

  // ============================================================
  // COLORS
  // ============================================================

  static const Color backgroundColor = Color(0xFF05090B);
  static const Color cardColor = Color(0xFF11181C);
  static const Color yellowColor = Color(0xFFFFD21F);
  static const Color whiteColor = Color(0xFFF5F7F8);
  static const Color greyColor = Color(0xFFA5ADB3);
  static const Color borderColor = Color(0xFF263036);

  // ============================================================
  // STATE
  // ============================================================

  int _selectedIndex = 0;

  // ============================================================
  // USER DATA
  // ============================================================

  @override
  void initState() {
    super.initState();
    _profilePhotoUrl = widget.userData['profilePhotoUrl']?.toString() ?? '';
    _contactNumber = widget.userData['contactNumber']?.toString() ?? '';
    if (userId.isNotEmpty) {
      _notificationsStream = _firestore
          .collection('notifications')
          .where('userId', isEqualTo: userId)
          .snapshots();
    }
    _loadRecentRequests();
    _loadProfilePhoto();
  }

  String get userName {
    final name = widget.userData['name'];

    if (name == null || name.toString().trim().isEmpty) {
      return 'there';
    }

    return name.toString().trim();
  }

  String get vehicleType {
    final vehicle = widget.userData['vehicleType'];

    if (vehicle == null || vehicle.toString().trim().isEmpty) {
      return 'Vehicle';
    }

    return vehicle.toString().trim();
  }

  String get email {
    final email = widget.userData['email'];
    if (email == null || email.toString().trim().isEmpty) {
      return 'Email not available';
    }
    return email.toString().trim();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: IndexedStack(
          index: _selectedIndex,
          children: [
            _buildHomePage(),
            _buildRequestsPage(),
            _buildProfilePage(),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  // ============================================================
  // HOME PAGE
  // ============================================================

  Widget _buildHomePage() {
    return RefreshIndicator(
      color: yellowColor,
      backgroundColor: cardColor,
      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 600));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopBar(),

            const SizedBox(height: 28),

            _buildGreeting(),

            const SizedBox(height: 25),

            _buildEmergencyCard(),

            const SizedBox(height: 26),

            _buildSectionTitle(
              title: 'Quick Services',
              actionText: 'View All',
              onActionPressed: () {},
            ),

            const SizedBox(height: 14),

            _buildQuickServices(),

            const SizedBox(height: 28),

            _buildSectionTitle(
              title: 'My Vehicle',
              actionText: 'Edit',
              onActionPressed: () {
                _showComingSoon('Vehicle editing will be available soon.');
              },
            ),

            const SizedBox(height: 14),

            _buildVehicleCard(),

            const SizedBox(height: 28),

            _buildSectionTitle(
              title: 'Recent Requests',
              actionText: 'View All',
              onActionPressed: () {
                setState(() {
                  _selectedIndex = 1;
                });
              },
            ),

            const SizedBox(height: 14),

            _buildRecentRequests(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _buildTopBar() {
    return Row(
      children: [
        // Logo
        Container(
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: yellowColor,
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: const Text(
            '⚡',
            style: TextStyle(
              color: backgroundColor,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(width: 11),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              'RoadRescue',
              style: TextStyle(
                color: whiteColor,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'ALWAYS THERE FOR YOU',
              style: TextStyle(
                color: greyColor,
                fontSize: 6.5,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.6,
              ),
            ),
          ],
        ),

        const Spacer(),

        // Notification
        _buildNotificationButton(),

        const SizedBox(width: 9),

        // Profile
        GestureDetector(
          onTap: () {
            setState(() {
              _selectedIndex = 2;
            });
          },
          child: Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: whiteColor,
              size: 22,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // GREETING
  // ============================================================

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello, $userName 👋',
          style: const TextStyle(
            color: whiteColor,
            fontSize: 27,
            fontWeight: FontWeight.bold,
            height: 1.2,
          ),
        ),

        const SizedBox(height: 7),

        const Text(
          'How can we help you today?',
          style: TextStyle(color: greyColor, fontSize: 14),
        ),
      ],
    );
  }

  // ============================================================
  // EMERGENCY CARD
  // ============================================================

  Widget _buildEmergencyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: yellowColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: yellowColor.withValues(alpha: 0.12),
            blurRadius: 25,
            offset: const Offset(0, 10),
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
                  color: backgroundColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: backgroundColor,
                  size: 25,
                ),
              ),

              const Spacer(),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: backgroundColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, color: Color(0xFF1B5E20), size: 8),
                    SizedBox(width: 5),
                    Text(
                      'Available 24/7',
                      style: TextStyle(
                        color: backgroundColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          const Text(
            'Need roadside help?',
            style: TextStyle(
              color: backgroundColor,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'Request assistance and get help from a nearby provider.',
            style: TextStyle(
              color: backgroundColor.withValues(alpha: 0.65),
              fontSize: 12.5,
              height: 1.45,
            ),
          ),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        RequestAssistancePage(userData: widget.userData),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: backgroundColor,
                foregroundColor: yellowColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.car_repair_rounded, size: 20),
                  SizedBox(width: 9),
                  Text(
                    'Request Assistance',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.bold,
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

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _buildSectionTitle({
    required String title,
    required String actionText,
    required VoidCallback onActionPressed,
  }) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            color: whiteColor,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),

        const Spacer(),

        GestureDetector(
          onTap: onActionPressed,
          child: Text(
            actionText,
            style: const TextStyle(
              color: yellowColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // QUICK SERVICES
  // ============================================================

  Widget _buildQuickServices() {
    return Row(
      children: [
        Expanded(
          child: _buildServiceCard(
            icon: Icons.local_shipping_outlined,
            title: 'Towing',
            subtitle: 'Vehicle towing',
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _buildServiceCard(
            icon: Icons.tire_repair_outlined,
            title: 'Flat Tire',
            subtitle: 'Tire assistance',
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _buildServiceCard(
            icon: Icons.battery_alert_outlined,
            title: 'Battery',
            subtitle: 'Jump start',
          ),
        ),

        const SizedBox(width: 10),

        Expanded(
          child: _buildServiceCard(
            icon: Icons.local_gas_station_outlined,
            title: 'Fuel',
            subtitle: 'Fuel delivery',
          ),
        ),
      ],
    );
  }

  Widget _buildServiceCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return GestureDetector(
      onTap: () {
        _showComingSoon('$title assistance will be available soon.');
      },
      child: Container(
        constraints: const BoxConstraints(minHeight: 112),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: yellowColor.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(icon, color: yellowColor, size: 21),
            ),

            const SizedBox(height: 9),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: whiteColor,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 3),

            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: greyColor, fontSize: 8.5),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // VEHICLE CARD
  // ============================================================

  Widget _buildVehicleCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              color: yellowColor.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.directions_car_rounded,
              color: yellowColor,
              size: 29,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'My Vehicle',
                  style: TextStyle(color: greyColor, fontSize: 11),
                ),

                const SizedBox(height: 4),

                Text(
                  vehicleType,
                  style: const TextStyle(
                    color: whiteColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                const Text(
                  'Vehicle information',
                  style: TextStyle(color: greyColor, fontSize: 10),
                ),
              ],
            ),
          ),

          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.chevron_right_rounded,
              color: greyColor,
              size: 21,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RECENT REQUESTS
  // ============================================================

  Future<void> _loadRecentRequests() async {
    final String uid = userId;
    if (uid.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoadingRequests = false;
          _requestHistoryError = 'User account could not be identified.';
        });
      }
      return;
    }

    if (!mounted) return;

    setState(() {
      _isLoadingRequests = true;
      _requestHistoryError = null;
    });

    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('assistance_requests')
          .where('userId', isEqualTo: uid)
          .get();

      final List<Map<String, dynamic>> history =
          snapshot.docs
              .map(
                (doc) => {
                  'id': doc.id,
                  ...(doc.data() as Map<String, dynamic>),
                },
              )
              .toList()
            ..sort((a, b) {
              DateTime? createdAt(Map<String, dynamic> request) {
                final value = request['createdAt'];
                if (value is Timestamp) return value.toDate();
                if (value is DateTime) return value;
                return null;
              }

              final aDate = createdAt(a);
              final bDate = createdAt(b);
              if (aDate == null) return bDate == null ? 0 : 1;
              if (bDate == null) return -1;
              return bDate.compareTo(aDate);
            });

      if (!mounted) return;

      setState(() {
        _requestHistory = history;
        _isLoadingRequests = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingRequests = false;
        _requestHistory = [];
        _requestHistoryError = 'Unable to load your requests right now.';
      });
      debugPrint('Recent requests load error: $e');
    }
  }

  Future<void> _loadProfilePhoto() async {
    final String uid = userId;
    if (uid.isEmpty) return;

    try {
      final DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(uid)
          .get();
      if (!userDoc.exists || userDoc.data() == null) {
        return;
      }

      final Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
      final String photoUrl = data['profilePhotoUrl']?.toString() ?? '';

      if (!mounted) return;

      setState(() {
        _profilePhotoUrl = photoUrl;
      });
    } catch (e) {
      debugPrint('Profile photo load error: $e');
    }
  }

  Future<void> _uploadProfilePhoto() async {
    final String uid = userId;
    if (uid.isEmpty) {
      _showComingSoon('Unable to identify your account.');
      return;
    }

    try {
      final XFile? picked = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 900,
        maxHeight: 900,
      );

      if (picked == null) return;

      if (!mounted) return;
      setState(() {
        _isUploadingPhoto = true;
      });

      final Reference ref = _storage
          .ref()
          .child('vehicle_owner_profile_photos')
          .child('$uid.jpg');
      await ref.putData(
        await picked.readAsBytes(),
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final String downloadUrl = await ref.getDownloadURL();

      await _firestore.collection('users').doc(uid).update({
        'profilePhotoUrl': downloadUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() {
        _profilePhotoUrl = downloadUrl;
        _isUploadingPhoto = false;
      });
      _showComingSoon('Profile photo updated.');
    } catch (e) {
      debugPrint('Profile photo upload error: $e');
      if (!mounted) return;
      setState(() {
        _isUploadingPhoto = false;
      });
      _showComingSoon('Unable to upload profile photo.');
    }
  }

  Future<void> _saveProfileDetails({
    required String name,
    required String contactNumber,
    required BuildContext dialogContext,
  }) async {
    final String trimmedName = name.trim();
    final String trimmedContact = contactNumber.trim();
    final String uid = userId;

    if (trimmedName.isEmpty) {
      _showComingSoon('Please enter your name.');
      return;
    }

    if (uid.isEmpty) {
      _showComingSoon('Unable to identify your account.');
      return;
    }

    setState(() {
      _isSavingProfile = true;
    });

    try {
      await _firestore.collection('users').doc(uid).update({
        'name': trimmedName,
        'contactNumber': trimmedContact,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted || !dialogContext.mounted) return;
      setState(() {
        widget.userData['name'] = trimmedName;
        widget.userData['contactNumber'] = trimmedContact;
        _contactNumber = trimmedContact;
      });

      if (Navigator.canPop(dialogContext)) {
        Navigator.pop(dialogContext);
      }
      _showComingSoon('Profile updated successfully.');
    } catch (e) {
      debugPrint('Save profile error: $e');
      if (mounted) {
        _showComingSoon('Failed to update profile. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingProfile = false;
        });
      }
    }
  }

  void _showEditProfileDialog() {
    final nameController = TextEditingController(
      text: userName == 'there' ? '' : userName,
    );
    final contactController = TextEditingController(text: _contactNumber);
    final emailController = TextEditingController(
      text: email == 'Email not available' ? '' : email,
    );

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Edit Profile',
            style: TextStyle(color: whiteColor, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(color: whiteColor),
                  decoration: InputDecoration(
                    labelText: 'Full Name',
                    labelStyle: const TextStyle(color: greyColor),
                    prefixIcon: const Icon(
                      Icons.person_outline,
                      color: yellowColor,
                    ),
                    filled: true,
                    fillColor: backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: contactController,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: whiteColor),
                  decoration: InputDecoration(
                    labelText: 'Contact Number',
                    labelStyle: const TextStyle(color: greyColor),
                    prefixIcon: const Icon(
                      Icons.phone_outlined,
                      color: yellowColor,
                    ),
                    filled: true,
                    fillColor: backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  enabled: false,
                  controller: emailController,
                  style: const TextStyle(color: greyColor),
                  decoration: InputDecoration(
                    labelText: 'Email',
                    labelStyle: const TextStyle(color: greyColor),
                    prefixIcon: const Icon(
                      Icons.email_outlined,
                      color: greyColor,
                    ),
                    filled: true,
                    fillColor: backgroundColor,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: _isSavingProfile
                  ? null
                  : () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: greyColor)),
            ),
            ElevatedButton(
              onPressed: _isSavingProfile
                  ? null
                  : () async {
                      setDialogState(() {});
                      await _saveProfileDetails(
                        name: nameController.text,
                        contactNumber: contactController.text,
                        dialogContext: dialogContext,
                      );
                      if (dialogContext.mounted) {
                        setDialogState(() {});
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: yellowColor,
                foregroundColor: backgroundColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSavingProfile
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: backgroundColor,
                      ),
                    )
                  : const Text(
                      'Save Changes',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    ).whenComplete(() {
      nameController.dispose();
      contactController.dispose();
      emailController.dispose();
    });
  }

  Widget _buildRecentRequests({bool showAll = false}) {
    if (_isLoadingRequests) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: borderColor),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: yellowColor,
            ),
          ),
        ),
      );
    }

    if (_requestHistoryError != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: borderColor),
        ),
        child: Text(
          _requestHistoryError!,
          textAlign: TextAlign.center,
          style: const TextStyle(color: greyColor, fontSize: 12.5),
        ),
      );
    }

    if (_requestHistory.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.history_rounded,
                color: greyColor,
                size: 27,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'No requests yet',
              style: TextStyle(
                color: whiteColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Requests you create will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: greyColor, fontSize: 11.5, height: 1.4),
            ),
          ],
        ),
      );
    }

    final requests = showAll
        ? _requestHistory
        : _requestHistory.take(3).toList();

    return Column(
      children: requests.map((request) {
        final service =
            request['issueType']?.toString() ??
            request['serviceType']?.toString() ??
            'Roadside Assistance';
        final status = request['status']?.toString() ?? 'Pending';
        final timestamp = request['createdAt'];
        final requestId =
            request['requestId']?.toString() ?? request['id']?.toString() ?? '';
        String subtitle = requestId.isEmpty
            ? 'Request submitted'
            : 'Request #${requestId.substring(0, requestId.length < 8 ? requestId.length : 8)}';

        if (timestamp is Timestamp) {
          final date = timestamp.toDate();
          subtitle = '${date.day}/${date.month}/${date.year} · $subtitle';
        } else if (timestamp is DateTime) {
          subtitle =
              '${timestamp.day}/${timestamp.month}/${timestamp.year} · $subtitle';
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: yellowColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.car_repair_rounded,
                  color: yellowColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service,
                      style: const TextStyle(
                        color: whiteColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: greyColor, fontSize: 11),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: status.toLowerCase() == 'completed'
                      ? const Color(0xFF183C2A)
                      : status.toLowerCase() == 'accepted'
                      ? const Color(0xFF2F3C12)
                      : const Color(0xFF2B2E35),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: TextStyle(
                    color: status.toLowerCase() == 'completed'
                        ? const Color(0xFF7DE0A3)
                        : status.toLowerCase() == 'accepted'
                        ? const Color(0xFFF3D55F)
                        : const Color(0xFFD6DADE),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // ============================================================
  // REQUESTS PAGE
  // ============================================================

  Widget _buildRequestsPage() {
    return RefreshIndicator(
      color: yellowColor,
      backgroundColor: cardColor,
      onRefresh: _loadRecentRequests,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(22, 25, 22, 30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPageHeader(
              title: 'My Requests',
              subtitle: 'All roadside assistance requests you have created.',
            ),
            const SizedBox(height: 28),
            _buildRecentRequests(showAll: true),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PROFILE PAGE
  // ============================================================

  Widget _buildProfilePage() {
    final profileEmail = email == 'Email not available' ? '' : email;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Driver Profile',
            style: TextStyle(
              color: whiteColor,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Manage your personal and vehicle information',
            style: TextStyle(color: greyColor, fontSize: 12),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: yellowColor.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: yellowColor.withValues(alpha: 0.35),
                          width: 1.5,
                        ),
                        image: _profilePhotoUrl.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(_profilePhotoUrl),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _profilePhotoUrl.isEmpty
                          ? const Icon(
                              Icons.person_rounded,
                              color: yellowColor,
                              size: 44,
                            )
                          : null,
                    ),
                    if (_isUploadingPhoto)
                      Container(
                        width: 88,
                        height: 88,
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 26,
                            height: 26,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: whiteColor,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  userName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: whiteColor,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  profileEmail.isEmpty ? 'Email not available' : profileEmail,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: greyColor, fontSize: 11),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _isUploadingPhoto ? null : _uploadProfilePhoto,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.camera_alt_outlined,
                        color: yellowColor,
                        size: 16,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _isUploadingPhoto ? 'Uploading...' : 'Change Photo',
                        style: const TextStyle(
                          color: yellowColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isSavingProfile ? null : _showEditProfileDialog,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text(
                      'Edit Profile',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: yellowColor,
                      foregroundColor: backgroundColor,
                      disabledBackgroundColor: yellowColor.withValues(
                        alpha: 0.4,
                      ),
                      disabledForegroundColor: Colors.black54,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildProfileInfoTile(
            icon: Icons.directions_car_outlined,
            title: 'Vehicle Type',
            value: vehicleType,
          ),
          const SizedBox(height: 10),
          _buildProfileInfoTile(
            icon: Icons.phone_outlined,
            title: 'Contact Number',
            value: _contactNumber.isEmpty ? 'Not provided' : _contactNumber,
          ),
          const SizedBox(height: 10),
          _buildProfileInfoTile(
            icon: Icons.email_outlined,
            title: 'Email',
            value: profileEmail.isEmpty ? 'Not available' : profileEmail,
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _showLogoutDialog,
              icon: const Icon(Icons.logout_rounded),
              label: const Text(
                'Log Out',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: whiteColor,
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // PAGE HEADER
  // ============================================================

  Widget _buildPageHeader({required String title, required String subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: whiteColor,
            fontSize: 27,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 7),

        Text(subtitle, style: const TextStyle(color: greyColor, fontSize: 13)),
      ],
    );
  }

  // ============================================================
  // PROFILE INFO TILE
  // ============================================================

  Widget _buildProfileInfoTile({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: yellowColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: yellowColor, size: 21),
          ),

          const SizedBox(width: 13),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: greyColor, fontSize: 10),
                ),

                const SizedBox(height: 4),

                Text(
                  value,
                  style: const TextStyle(
                    color: whiteColor,
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
  // BOTTOM NAVIGATION
  // ============================================================

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: const BoxDecoration(
        color: cardColor,
        border: Border(top: BorderSide(color: borderColor, width: 0.6)),
      ),
      child: NavigationBar(
        height: 68,
        backgroundColor: cardColor,
        surfaceTintColor: Colors.transparent,
        indicatorColor: yellowColor.withValues(alpha: 0.12),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined, color: greyColor),
            selectedIcon: Icon(Icons.home_rounded, color: yellowColor),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined, color: greyColor),
            selectedIcon: Icon(Icons.assignment_rounded, color: yellowColor),
            label: 'Requests',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded, color: greyColor),
            selectedIcon: Icon(Icons.person_rounded, color: yellowColor),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ICON BUTTON
  // ============================================================

  Widget _buildNotificationButton() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _notificationsStream,
      builder: (context, snapshot) {
        final unreadCount =
            snapshot.data?.docs.where((document) {
              final data = document.data();
              return data['read'] != true && data['isRead'] != true;
            }).length ??
            0;

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const VehicleOwnerNotificationsPage(),
              ),
            );
          },
          child: Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  color: whiteColor,
                  size: 22,
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: -5,
                    right: -5,
                    child: Container(
                      constraints: const BoxConstraints(
                        minWidth: 17,
                        minHeight: 17,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFF5252),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        unreadCount > 9 ? '9+' : '$unreadCount',
                        style: const TextStyle(
                          color: whiteColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
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
  // LOGOUT DIALOG
  // ============================================================

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          title: const Text(
            'Log Out',
            style: TextStyle(color: whiteColor, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to log out of RoadRescue?',
            style: TextStyle(color: greyColor, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel', style: TextStyle(color: greyColor)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                _showComingSoon('Logout functionality will be connected next.');
              },
              child: const Text(
                'Log Out',
                style: TextStyle(
                  color: Color(0xFFFF5252),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // COMING SOON
  // ============================================================

  void _showComingSoon(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: cardColor,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }
}
