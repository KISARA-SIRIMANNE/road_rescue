import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class RoadsideProviderHomePage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const RoadsideProviderHomePage({
    super.key,
    required this.userData,
  });

  @override
  State<RoadsideProviderHomePage> createState() =>
      _RoadsideProviderHomePageState();
}

class _RoadsideProviderHomePageState
    extends State<RoadsideProviderHomePage> {
  int _selectedIndex = 0;

  bool _isOnline = false;
  bool _isGettingLocation = false;

  Position? _currentPosition;

  StreamSubscription<Position>? _positionSubscription;

  // ============================================================
  // ASSISTANCE REQUEST STATE
  // ============================================================

  StreamSubscription<QuerySnapshot>? _requestSubscription;

  final List<QueryDocumentSnapshot> _incomingRequests = [];

  bool _isLoadingRequests = false;

  // ============================================================
  // FIREBASE
  // ============================================================

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  // ============================================================
  // COLORS
  // ============================================================

  final Color _backgroundColor =
      const Color(0xFF08090A);

  final Color _cardColor =
      const Color(0xFF171C20);

  final Color _yellowColor =
      const Color(0xFFF6E900);

  // ============================================================
  // PROVIDER DATA
  // ============================================================

  String get _providerName {
    return widget.userData['name']?.toString() ??
        widget.userData['companyName']?.toString() ??
        'Provider';
  }

  String get _email {
    return widget.userData['email']?.toString() ?? '';
  }

  String get _workshopLocation {
    return widget.userData['workshopLocation']?.toString() ??
        'Location not set';
  }

  String get _providerId {
    return widget.userData['uid']?.toString() ??
        _auth.currentUser?.uid ??
        '';
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _loadProviderAvailability();
  }

  // ============================================================
  // LOAD PROVIDER AVAILABILITY
  // ============================================================

  Future<void> _loadProviderAvailability() async {
    try {
      if (_providerId.isEmpty) {
        return;
      }

      final DocumentSnapshot document =
          await _firestore
              .collection('users')
              .doc(_providerId)
              .get();

      if (!document.exists) {
        return;
      }

      final Map<String, dynamic>? data =
          document.data() as Map<String, dynamic>?;

      if (data == null) {
        return;
      }

      final bool savedOnlineStatus =
          data['isOnline'] == true;

      if (!mounted) {
        return;
      }

      setState(() {
        _isOnline = savedOnlineStatus;

        if (data['latitude'] != null &&
            data['longitude'] != null) {
          _currentPosition = Position(
            latitude:
                (data['latitude'] as num).toDouble(),
            longitude:
                (data['longitude'] as num).toDouble(),
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            altitudeAccuracy: 0,
            heading: 0,
            headingAccuracy: 0,
            speed: 0,
            speedAccuracy: 0,
          );
        }
      });

      if (savedOnlineStatus) {
        _startLocationStream();
        _startRequestListener();
      }
    } catch (e) {
      debugPrint(
        'Error loading provider availability: $e',
      );
    }
  }

  // ============================================================
  // LOCATION PERMISSION
  // ============================================================

  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      if (mounted) {
        _showLocationServiceMessage();
      }

      return false;
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission =
          await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      if (mounted) {
        _showMessage(
          'Location permission is required to go online.',
        );
      }

      return false;
    }

    if (permission ==
        LocationPermission.deniedForever) {
      if (mounted) {
        _showPermissionSettingsMessage();
      }

      return false;
    }

    return true;
  }

  // ============================================================
  // GO ONLINE
  // ============================================================

  Future<void> _goOnline() async {
    if (_isGettingLocation) {
      return;
    }

    setState(() {
      _isGettingLocation = true;
    });

    try {
      final bool permissionGranted =
          await _checkLocationPermission();

      if (!permissionGranted) {
        if (mounted) {
          setState(() {
            _isOnline = false;
            _isGettingLocation = false;
          });
        }

        return;
      }

      final Position position =
          await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      _currentPosition = position;

      await _updateProviderLocation(
        position,
        isOnline: true,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isOnline = true;
        _isGettingLocation = false;
      });

      _startLocationStream();

      // Start listening for assistance requests.
      _startRequestListener();

      _showMessage(
        'You are now online.',
      );
    } catch (e) {
      debugPrint(
        'Error going online: $e',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _isOnline = false;
        _isGettingLocation = false;
      });

      _showMessage(
        'Could not get your current location.',
      );
    }
  }

  // ============================================================
  // GO OFFLINE
  // ============================================================

  Future<void> _goOffline() async {
    await _stopLocationTracking();

    // Stop receiving assistance requests.
    await _stopRequestListener();

    try {
      if (_providerId.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(_providerId)
            .update({
          'isOnline': false,
          'updatedAt':
              FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint(
        'Error going offline: $e',
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isOnline = false;
    });

    _showMessage(
      'You are now offline.',
    );
  }

  // ============================================================
  // START LOCATION STREAM
  // ============================================================

  void _startLocationStream() {
    _positionSubscription?.cancel();

    const LocationSettings settings =
        LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionSubscription =
        Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      (Position position) async {
        if (!_isOnline) {
          return;
        }

        _currentPosition = position;

        if (mounted) {
          setState(() {});
        }

        await _updateProviderLocation(
          position,
          isOnline: true,
        );
      },
      onError: (error) {
        debugPrint(
          'Provider location stream error: $error',
        );
      },
    );
  }

  // ============================================================
  // UPDATE FIRESTORE LOCATION
  // ============================================================

  Future<void> _updateProviderLocation(
    Position position, {
    required bool isOnline,
  }) async {
    if (_providerId.isEmpty) {
      debugPrint(
        'Provider ID is empty. Cannot update location.',
      );

      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(_providerId)
          .update({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'isOnline': isOnline,
        'locationUpdatedAt':
            FieldValue.serverTimestamp(),
        'updatedAt':
            FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint(
        'Error updating provider location: $e',
      );
    }
  }

  // ============================================================
  // STOP LOCATION TRACKING
  // ============================================================

  Future<void> _stopLocationTracking() async {
    await _positionSubscription?.cancel();

    _positionSubscription = null;
  }

  // ============================================================
  // ASSISTANCE REQUESTS
  // ============================================================

  void _startRequestListener() {
    if (_providerId.isEmpty) {
      return;
    }

    // Prevent duplicate listeners.
    _requestSubscription?.cancel();

    if (mounted) {
      setState(() {
        _isLoadingRequests = true;
      });
    }

    _requestSubscription = _firestore
        .collection('assistance_requests')
        .where(
          'status',
          whereIn: [
            'pending',
            'searching',
          ],
        )
        .snapshots()
        .listen(
      (QuerySnapshot snapshot) {
        final List<QueryDocumentSnapshot>
            requests =
            snapshot.docs.where((document) {
          final Map<String, dynamic> data =
              document.data()
                  as Map<String, dynamic>;

          final List<dynamic> deniedBy =
              data['deniedBy'] is List
                  ? List<dynamic>.from(
                      data['deniedBy'] as List,
                    )
                  : <dynamic>[];

          // If this provider has denied the request,
          // don't display it to this provider.
          return !deniedBy.contains(
            _providerId,
          );
        }).toList();

        // Sort newest requests first.
        requests.sort((a, b) {
          final Map<String, dynamic> aData =
              a.data()
                  as Map<String, dynamic>;

          final Map<String, dynamic> bData =
              b.data()
                  as Map<String, dynamic>;

          final Timestamp? aTime =
              aData['createdAt'] is Timestamp
                  ? aData['createdAt']
                      as Timestamp
                  : null;

          final Timestamp? bTime =
              bData['createdAt'] is Timestamp
                  ? bData['createdAt']
                      as Timestamp
                  : null;

          if (aTime == null &&
              bTime == null) {
            return 0;
          }

          if (aTime == null) {
            return 1;
          }

          if (bTime == null) {
            return -1;
          }

          return bTime.compareTo(aTime);
        });

        if (!mounted) {
          return;
        }

        setState(() {
          _incomingRequests
            ..clear()
            ..addAll(requests);

          _isLoadingRequests = false;
        });
      },
      onError: (error) {
        debugPrint(
          'Assistance request listener error: $error',
        );

        if (mounted) {
          setState(() {
            _isLoadingRequests = false;
          });
        }
      },
    );
  }

  // ============================================================
  // STOP REQUEST LISTENER
  // ============================================================

  Future<void> _stopRequestListener() async {
    await _requestSubscription?.cancel();

    _requestSubscription = null;

    if (!mounted) {
      return;
    }

    setState(() {
      _incomingRequests.clear();
      _isLoadingRequests = false;
    });
  }

  // ============================================================
  // ACCEPT REQUEST
  // ============================================================

  Future<void> _acceptRequest(
    QueryDocumentSnapshot requestDocument,
  ) async {
    if (_providerId.isEmpty) {
      return;
    }

    final DocumentReference requestReference =
        _firestore
            .collection('assistance_requests')
            .doc(requestDocument.id);

    try {
      await _firestore.runTransaction(
        (transaction) async {
          final DocumentSnapshot snapshot =
              await transaction.get(
            requestReference,
          );

          if (!snapshot.exists) {
            throw Exception(
              'This request no longer exists.',
            );
          }

          final Map<String, dynamic> data =
              snapshot.data()
                  as Map<String, dynamic>;

          final String status =
              data['status']?.toString() ??
                  'pending';

          final List<dynamic> deniedBy =
              data['deniedBy'] is List
                  ? List<dynamic>.from(
                      data['deniedBy'] as List,
                    )
                  : <dynamic>[];

          if (deniedBy.contains(
            _providerId,
          )) {
            throw Exception(
              'You have already denied this request.',
            );
          }

          if (status != 'pending' &&
              status != 'searching') {
            throw Exception(
              'This request has already been accepted '
              'by another provider.',
            );
          }

          transaction.update(
            requestReference,
            {
              'status': 'accepted',
              'providerId': _providerId,
              'providerName': _providerName,
              'providerEmail': _email,
              'acceptedAt':
                  FieldValue.serverTimestamp(),
              'updatedAt':
                  FieldValue.serverTimestamp(),
            },
          );
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _incomingRequests.removeWhere(
          (request) =>
              request.id ==
              requestDocument.id,
        );
      });

      _showMessage(
        'Request accepted successfully.',
      );
    } catch (e) {
      debugPrint(
        'Error accepting request: $e',
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // ============================================================
  // DENY REQUEST
  // ============================================================

  Future<void> _denyRequest(
    QueryDocumentSnapshot requestDocument,
  ) async {
    if (_providerId.isEmpty) {
      return;
    }

    final DocumentReference requestReference =
        _firestore
            .collection('assistance_requests')
            .doc(requestDocument.id);

    try {
      await _firestore.runTransaction(
        (transaction) async {
          final DocumentSnapshot snapshot =
              await transaction.get(
            requestReference,
          );

          if (!snapshot.exists) {
            throw Exception(
              'This request no longer exists.',
            );
          }

          final Map<String, dynamic> data =
              snapshot.data()
                  as Map<String, dynamic>;

          final String status =
              data['status']?.toString() ??
                  'pending';

          if (status != 'pending' &&
              status != 'searching') {
            throw Exception(
              'This request is no longer available.',
            );
          }

          final List<dynamic> deniedBy =
              data['deniedBy'] is List
                  ? List<dynamic>.from(
                      data['deniedBy'] as List,
                    )
                  : <dynamic>[];

          if (!deniedBy.contains(
            _providerId,
          )) {
            deniedBy.add(_providerId);
          }

          transaction.update(
            requestReference,
            {
              'deniedBy': deniedBy,
              'updatedAt':
                  FieldValue.serverTimestamp(),
            },
          );
        },
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _incomingRequests.removeWhere(
          (request) =>
              request.id ==
              requestDocument.id,
        );
      });

      _showMessage(
        'Request denied.',
      );
    } catch (e) {
      debugPrint(
        'Error denying request: $e',
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        e.toString().replaceFirst(
          'Exception: ',
          '',
        ),
      );
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    await _stopLocationTracking();

    // Stop listening for requests.
    await _stopRequestListener();

    try {
      if (_providerId.isNotEmpty) {
        await _firestore
            .collection('users')
            .doc(_providerId)
            .update({
          'isOnline': false,
          'updatedAt':
              FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint(
        'Error updating logout status: $e',
      );
    }

    await _auth.signOut();

    if (!mounted) {
      return;
    }

    Navigator.of(context)
        .popUntil((route) => route.isFirst);
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _positionSubscription?.cancel();

    // Cancel request listener.
    _requestSubscription?.cancel();

    super.dispose();
  }

  // ============================================================
  // MAIN BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
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
      bottomNavigationBar:
          _buildBottomNavigationBar(),
    );
  }

  // ============================================================
  // HOME PAGE
  // ============================================================

  Widget _buildHomePage() {
    return SingleChildScrollView(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        18,
        20,
        24,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _buildTopBar(),

          const SizedBox(height: 28),

          _buildGreeting(),

          const SizedBox(height: 24),

          _buildAvailabilityCard(),

          const SizedBox(height: 24),

          _buildStatistics(),

          const SizedBox(height: 28),

          _buildSectionTitle(
            title: 'Incoming Requests',
            actionText: 'View All',
            onActionTap: () {
              setState(() {
                _selectedIndex = 1;
              });
            },
          ),

          const SizedBox(height: 12),

          // CHANGED:
          // Show real incoming requests instead
          // of the old empty placeholder.
          _buildIncomingRequests(),

          const SizedBox(height: 28),

          _buildSectionTitle(
            title: 'Quick Actions',
          ),

          const SizedBox(height: 12),

          _buildQuickActions(),

          const SizedBox(height: 28),

          _buildCurrentLocationCard(),

          const SizedBox(height: 16),

          _buildWorkshopCard(),
        ],
      ),
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _buildTopBar() {
    return Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: _yellowColor,
            borderRadius:
                BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.car_repair_rounded,
            color: Colors.black,
            size: 25,
          ),
        ),

        const SizedBox(width: 12),

        const Expanded(
          child: Text(
            'RoadRescue',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
        ),

        IconButton(
          onPressed: () {
            _showComingSoon(
              'Notifications',
            );
          },
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: Colors.white,
          ),
        ),

        PopupMenuButton<String>(
          color: _cardColor,
          icon: const Icon(
            Icons.more_vert_rounded,
            color: Colors.white,
          ),
          onSelected: (value) {
            if (value == 'logout') {
              _logout();
            }
          },
          itemBuilder: (context) {
            return [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(
                      Icons.logout_rounded,
                      color: Colors.white70,
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Logout',
                      style: TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      ],
    );
  }

  // ============================================================
  // GREETING
  // ============================================================

  Widget _buildGreeting() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Hello, $_providerName 👋',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'Ready to help drivers on the road?',
          style: TextStyle(
            color: Colors.white60,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // AVAILABILITY
  // ============================================================

  Widget _buildAvailabilityCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _yellowColor,
        borderRadius:
            BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.black
                  .withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: _isGettingLocation
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child:
                        CircularProgressIndicator(
                      color: Colors.black,
                      strokeWidth: 3,
                    ),
                  )
                : Icon(
                    _isOnline
                        ? Icons
                            .radio_button_checked_rounded
                        : Icons
                            .radio_button_off_rounded,
                    color: Colors.black,
                    size: 27,
                  ),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Availability',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  _isGettingLocation
                      ? 'Getting Location...'
                      : _isOnline
                          ? 'You are Online'
                          : 'You are Offline',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 19,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(height: 2),

                Text(
                  _isOnline
                      ? 'You can receive assistance requests'
                      : 'You will not receive new requests',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          Switch(
            value: _isOnline,
            onChanged: _isGettingLocation
                ? null
                : (value) {
                    if (value) {
                      _goOnline();
                    } else {
                      _goOffline();
                    }
                  },
            activeThumbColor: Colors.black,
            activeTrackColor: Colors.black26,
            inactiveThumbColor:
                Colors.black54,
            inactiveTrackColor:
                Colors.black12,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  Widget _buildStatistics() {
    return Row(
      children: [
        Expanded(
          child: _buildStatisticCard(
            icon: Icons.assignment_rounded,
            value: '0',
            label: 'Requests',
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _buildStatisticCard(
            icon:
                Icons.check_circle_rounded,
            value: '0',
            label: 'Completed',
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _buildStatisticCard(
            icon: Icons.star_rounded,
            value: '0.0',
            label: 'Rating',
          ),
        ),
      ],
    );
  }

  Widget _buildStatisticCard({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        vertical: 18,
        horizontal: 10,
      ),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: _yellowColor,
            size: 22,
          ),

          const SizedBox(height: 10),

          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
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
    String? actionText,
    VoidCallback? onActionTap,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),

        if (actionText != null)
          TextButton(
            onPressed: onActionTap,
            child: Text(
              actionText,
              style: TextStyle(
                color: _yellowColor,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // EMPTY REQUESTS
  // ============================================================

  Widget _buildEmptyRequestsCard() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        vertical: 32,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _yellowColor
                  .withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_rounded,
              color: _yellowColor,
              size: 31,
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            'No nearby requests',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'New assistance requests near you will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INCOMING REQUESTS
  // ============================================================

  Widget _buildIncomingRequests() {
    if (!_isOnline) {
      return _buildOfflineRequestsCard();
    }

    if (_isLoadingRequests) {
      return Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(
          vertical: 28,
          horizontal: 20,
        ),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius:
              BorderRadius.circular(20),
        ),
        child: const Center(
          child:
              CircularProgressIndicator(),
        ),
      );
    }

    if (_incomingRequests.isEmpty) {
      return _buildEmptyRequestsCard();
    }

    return Column(
      children: _incomingRequests
          .map(_buildRequestCard)
          .toList(),
    );
  }

  // ============================================================
  // REQUEST CARD
  // ============================================================

  Widget _buildRequestCard(
    QueryDocumentSnapshot requestDocument,
  ) {
    final Map<String, dynamic> data =
        requestDocument.data()
            as Map<String, dynamic>;

    final String userName =
        data['userName']?.toString() ??
            'Driver';

    final String vehicleType =
        data['vehicleType']?.toString() ??
            'Vehicle';

    final String issueType =
        data['issueType']?.toString() ??
            'Assistance needed';

    final String status =
        data['status']?.toString() ??
            'pending';

    final num? latitude =
        data['latitude'] as num?;

    final num? longitude =
        data['longitude'] as num?;

    final String locationText =
        latitude != null &&
                longitude != null
            ? '${latitude.toStringAsFixed(5)}, '
                '${longitude.toStringAsFixed(5)}'
            : 'Location unavailable';

    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(
        bottom: 14,
      ),
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: _yellowColor
              .withValues(alpha: 0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _yellowColor
                      .withValues(alpha: 0.12),
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.car_repair_rounded,
                  color: _yellowColor,
                  size: 24,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'New Assistance Request',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: _yellowColor,
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w700,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          _buildRequestInfoRow(
            Icons.person_outline_rounded,
            'Driver',
            userName,
          ),

          _buildRequestInfoRow(
            Icons.directions_car_outlined,
            'Vehicle',
            vehicleType,
          ),

          _buildRequestInfoRow(
            Icons.build_outlined,
            'Issue',
            issueType,
          ),

          _buildRequestInfoRow(
            Icons.location_on_outlined,
            'Location',
            locationText,
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () =>
                      _denyRequest(
                    requestDocument,
                  ),
                  style:
                      OutlinedButton.styleFrom(
                    foregroundColor:
                        Colors.redAccent,
                    side:
                        const BorderSide(
                      color:
                          Colors.redAccent,
                    ),
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 13,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                  ),
                  child: const Text(
                    'Deny',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: ElevatedButton(
                  onPressed: () =>
                      _acceptRequest(
                    requestDocument,
                  ),
                  style:
                      ElevatedButton.styleFrom(
                    backgroundColor:
                        _yellowColor,
                    foregroundColor:
                        Colors.black,
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 13,
                    ),
                    elevation: 0,
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                  ),
                  child: const Text(
                    'Accept',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REQUEST INFO ROW
  // ============================================================

  Widget _buildRequestInfoRow(
    IconData icon,
    String title,
    String value,
  ) {
    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 11,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: Colors.white54,
            size: 20,
          ),

          const SizedBox(width: 11),

          SizedBox(
            width: 68,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12,
              ),
            ),
          ),

          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow:
                  TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // OFFLINE REQUESTS CARD
  // ============================================================

  Widget _buildOfflineRequestsCard() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        vertical: 30,
        horizontal: 20,
      ),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            color: Colors.white38,
            size: 35,
          ),

          const SizedBox(height: 12),

          const Text(
            'You are offline',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight:
                  FontWeight.w700,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Go online to receive new assistance requests.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // QUICK ACTIONS
  // ============================================================

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _buildQuickAction(
            icon:
                Icons.assignment_outlined,
            title: 'Requests',
            onTap: () {
              setState(() {
                _selectedIndex = 1;
              });
            },
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _buildQuickAction(
            icon:
                Icons.location_on_outlined,
            title: 'My Location',
            onTap: () {
              if (_currentPosition !=
                  null) {
                _showMessage(
                  'Location: '
                  '${_currentPosition!.latitude.toStringAsFixed(5)}, '
                  '${_currentPosition!.longitude.toStringAsFixed(5)}',
                );
              } else {
                _showMessage(
                  'Current location is not available.',
                );
              }
            },
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _buildQuickAction(
            icon:
                Icons.person_outline_rounded,
            title: 'Profile',
            onTap: () {
              setState(() {
                _selectedIndex = 2;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(18),
      child: Container(
        padding:
            const EdgeInsets.symmetric(
          vertical: 18,
          horizontal: 8,
        ),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius:
              BorderRadius.circular(18),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: _yellowColor,
              size: 25,
            ),

            const SizedBox(height: 9),

            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CURRENT LOCATION CARD
  // ============================================================

  Widget _buildCurrentLocationCard() {
    final Position? position =
        _currentPosition;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _yellowColor
                  .withValues(alpha: 0.10),
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.my_location_rounded,
              color: _yellowColor,
              size: 25,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current GPS Location',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  position == null
                      ? 'Location not available'
                      : '${position.latitude.toStringAsFixed(5)}, '
                        '${position.longitude.toStringAsFixed(5)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),

                if (_isOnline &&
                    position != null) ...[
                  const SizedBox(height: 4),
                  const Text(
                    'Location is being updated',
                    style: TextStyle(
                      color:
                          Colors.greenAccent,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // WORKSHOP
  // ============================================================

  Widget _buildWorkshopCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _yellowColor
                  .withValues(alpha: 0.10),
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.build_circle_outlined,
              color: _yellowColor,
              size: 26,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Service Location',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  _workshopLocation,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed: () {
              _showComingSoon(
                'Location editing',
              );
            },
            icon: const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white54,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REQUESTS PAGE
  // ============================================================

  Widget _buildRequestsPage() {
    return SingleChildScrollView(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        18,
        20,
        24,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Assistance Requests',
            style: TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(height: 7),

          const Text(
            'Requests from drivers near your service area.',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),

          const SizedBox(height: 25),

          // CHANGED:
          // Show real incoming requests.
          _buildIncomingRequests(),
        ],
      ),
    );
  }

  // ============================================================
  // PROFILE PAGE
  // ============================================================

  Widget _buildProfilePage() {
    return SingleChildScrollView(
      padding:
          const EdgeInsets.fromLTRB(
        20,
        18,
        20,
        24,
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),

          Container(
            width: 82,
            height: 82,
            decoration: BoxDecoration(
              color: _yellowColor,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.handyman_rounded,
              color: Colors.black,
              size: 40,
            ),
          ),

          const SizedBox(height: 15),

          Text(
            _providerName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight:
                  FontWeight.w800,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            _email,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 28),

          _buildProfileItem(
            icon: Icons.email_outlined,
            title: 'Email',
            value: _email,
          ),

          _buildProfileItem(
            icon:
                Icons.location_on_outlined,
            title: 'Workshop Location',
            value: _workshopLocation,
          ),

          _buildProfileItem(
            icon: Icons.badge_outlined,
            title: 'Role',
            value:
                'Roadside Assistance Provider',
          ),

          if (_currentPosition != null)
            _buildProfileItem(
              icon:
                  Icons.my_location_rounded,
              title: 'Current GPS',
              value:
                  '${_currentPosition!.latitude.toStringAsFixed(5)}, '
                  '${_currentPosition!.longitude.toStringAsFixed(5)}',
            ),

          const SizedBox(height: 15),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(
                Icons.logout_rounded,
              ),
              label:
                  const Text('Logout'),
              style:
                  OutlinedButton.styleFrom(
                foregroundColor:
                    Colors.redAccent,
                side:
                    const BorderSide(
                  color: Colors.redAccent,
                ),
                padding:
                    const EdgeInsets
                        .symmetric(
                  vertical: 15,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: _yellowColor,
            size: 23,
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  value.isEmpty
                      ? 'Not available'
                      : value,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight:
                        FontWeight.w600,
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
    return NavigationBar(
      backgroundColor: _cardColor,
      indicatorColor:
          _yellowColor.withValues(
        alpha: 0.15,
      ),
      selectedIndex: _selectedIndex,
      onDestinationSelected: (index) {
        setState(() {
          _selectedIndex = index;
        });
      },
      destinations: [
        NavigationDestination(
          icon: const Icon(
            Icons.home_outlined,
            color: Colors.white54,
          ),
          selectedIcon: Icon(
            Icons.home_rounded,
            color: _yellowColor,
          ),
          label: 'Home',
        ),

        NavigationDestination(
          icon: const Icon(
            Icons.assignment_outlined,
            color: Colors.white54,
          ),
          selectedIcon: Icon(
            Icons.assignment_rounded,
            color: _yellowColor,
          ),
          label: 'Requests',
        ),

        NavigationDestination(
          icon: const Icon(
            Icons.person_outline_rounded,
            color: Colors.white54,
          ),
          selectedIcon: Icon(
            Icons.person_rounded,
            color: _yellowColor,
          ),
          label: 'Profile',
        ),
      ],
    );
  }

  // ============================================================
  // MESSAGES
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _cardColor,
      ),
    );
  }

  void _showLocationServiceMessage() {
    if (!mounted) {
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _cardColor,
          title: const Text(
            'Location is turned off',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          content: const Text(
            'Please turn on Location Services on your phone to go online.',
            style: TextStyle(
              color: Colors.white70,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                'OK',
                style: TextStyle(
                  color: _yellowColor,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showPermissionSettingsMessage() {
    if (!mounted) {
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _cardColor,
          title: const Text(
            'Location permission required',
            style: TextStyle(
              color: Colors.white,
            ),
          ),
          content: const Text(
            'Location permission was permanently denied. Please enable it from the app settings.',
            style: TextStyle(
              color: Colors.white70,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.white70,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);

                await Geolocator
                    .openAppSettings();
              },
              child: Text(
                'Open Settings',
                style: TextStyle(
                  color: _yellowColor,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showComingSoon(String feature) {
    _showMessage(
      '$feature will be available soon.',
    );
  }
}