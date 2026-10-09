import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'provider_directions_page.dart';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class RoadsideProviderHomePage extends StatefulWidget {
  final Map<String, dynamic> userData;

  const RoadsideProviderHomePage({super.key, required this.userData});

  @override
  State<RoadsideProviderHomePage> createState() =>
      _RoadsideProviderHomePageState();
}

class _RoadsideProviderHomePageState extends State<RoadsideProviderHomePage> {
  // ============================================================
  // STATE
  // ============================================================

  int _selectedIndex = 0;

  bool _isOnline = false;
  bool _isGettingLocation = false;
  bool _isLoadingRequests = false;
  bool _isSavingProfile = false;

  String _profileName = '';
  String _profileWorkshopLocation = '';
  String _profilePhotoUrl = '';

  bool _isUploadingProfilePhoto = false;

  bool _isLoadingStats = false;
  String? _statisticsError;
  bool _hasLoadedAssignedStatistics = false;
  bool _hasLoadedDeniedStatistics = false;

  int _completedJobs = 0;
  int _deniedRequests = 0;
  int _activeJobs = 0;
  int _assignedJobs = 0;
  double _totalEarnings = 0.0;

  bool _isLoadingJobHistory = false;
  String? _jobHistoryError;

  List<Map<String, dynamic>> _jobHistory = [];

  Position? _currentPosition;

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<QuerySnapshot>? _requestSubscription;

  // Currently accepted assistance request.
  String? _activeRequestId;

  Map<String, dynamic>? _activeJobData;

  bool _isLoadingActiveJob = false;

  final List<QueryDocumentSnapshot> _incomingRequests = [];

  // ============================================================
  // FIREBASE
  // ============================================================

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FirebaseStorage _storage = FirebaseStorage.instance;

  final ImagePicker _imagePicker = ImagePicker();

  // ============================================================
  // COLORS
  // ============================================================

  final Color _backgroundColor = const Color(0xFF05090B);

  final Color _cardColor = const Color(0xFF11181C);

  final Color _yellowColor = const Color(0xFFFFD21F);

  // ============================================================
  // PROVIDER DATA
  // ============================================================

  String get _providerName {
    if (_profileName.isNotEmpty) {
      return _profileName;
    }
    return widget.userData['name']?.toString() ??
        widget.userData['companyName']?.toString() ??
        'Provider';
  }

  String get _email {
    return widget.userData['email']?.toString() ?? '';
  }

  String get _workshopLocation {
    if (_profileWorkshopLocation.isNotEmpty) {
      return _profileWorkshopLocation;
    }
    return widget.userData['workshopLocation']?.toString() ??
        'Location not set';
  }

  String get _providerId {
    return widget.userData['uid']?.toString() ?? _auth.currentUser?.uid ?? '';
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _profileName =
        widget.userData['name']?.toString() ??
        widget.userData['companyName']?.toString() ??
        'Provider';

    _profileWorkshopLocation =
        widget.userData['workshopLocation']?.toString() ?? 'Location not set';

    _loadProviderAvailability();
    _loadProviderStatistics();
    _loadProfilePhoto();
    _loadJobHistory();
    _loadActiveJob();
  }

  Future<void> _loadProfilePhoto() async {
    final String providerId = _providerId;

    if (providerId.isEmpty) {
      return;
    }

    try {
      final DocumentSnapshot snapshot = await _firestore
          .collection('users')
          .doc(providerId)
          .get();

      if (!snapshot.exists) {
        return;
      }

      final Map<String, dynamic> data = snapshot.data() as Map<String, dynamic>;
      final String photoUrl = data['profilePhotoUrl']?.toString() ?? '';

      if (!mounted) {
        return;
      }

      setState(() {
        _profilePhotoUrl = photoUrl;
      });
    } catch (e) {
      debugPrint('Error loading profile photo: $e');
    }
  }

  Future<void> _uploadProfilePhoto() async {
    final String providerId = _providerId;

    if (providerId.isEmpty) {
      _showMessage('Unable to identify provider account.');
      return;
    }

    try {
      final XFile? selectedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (selectedImage == null) {
        return;
      }

      if (mounted) {
        setState(() {
          _isUploadingProfilePhoto = true;
        });
      }

      final Reference storageReference = _storage
          .ref()
          .child('provider_profile_photos')
          .child('$providerId.jpg');

      await storageReference.putData(
        await selectedImage.readAsBytes(),
        SettableMetadata(contentType: 'image/jpeg'),
      );

      final String downloadUrl = await storageReference.getDownloadURL();

      await _firestore.collection('users').doc(providerId).update({
        'profilePhotoUrl': downloadUrl,
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _profilePhotoUrl = downloadUrl;
        _isUploadingProfilePhoto = false;
      });

      _showMessage('Profile photo updated successfully.');
    } catch (e) {
      debugPrint('Profile photo upload error: $e');

      if (!mounted) {
        return;
      }

      setState(() {
        _isUploadingProfilePhoto = false;
      });

      _showMessage('Failed to upload profile photo.');
    }
  }

  Future<void> _loadProviderStatistics() async {
    final String providerId = _providerId;

    if (providerId.isEmpty) {
      if (mounted) {
        setState(() {
          _statisticsError = 'Provider account could not be identified.';
          _isLoadingStats = false;
          _hasLoadedAssignedStatistics = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingStats = true;
        _statisticsError = null;
        _hasLoadedAssignedStatistics = false;
        _hasLoadedDeniedStatistics = false;
      });
    }

    try {
      final QuerySnapshot snapshot = await _firestore
          .collection('assistance_requests')
          .where('providerId', isEqualTo: providerId)
          .get();

      int completed = 0;
      int active = 0;
      double earnings = 0.0;

      const List<String> activeStatuses = [
        'accepted',
        'on_the_way',
        'arrived',
        'in_progress',
      ];

      for (final DocumentSnapshot document in snapshot.docs) {
        final Map<String, dynamic> data =
            document.data() as Map<String, dynamic>;

        final String status = data['status']?.toString() ?? '';

        // Completed jobs
        if (status == 'completed') {
          completed++;

          final String paymentStatus = data['paymentStatus']?.toString() ?? '';

          if (paymentStatus == 'paid') {
            final dynamic amount = data['paidAmount'] ?? data['jobAmount'];

            if (amount is num) {
              earnings += amount.toDouble();
            } else if (amount != null) {
              earnings += double.tryParse(amount.toString()) ?? 0.0;
            }
          }
        }

        // Active jobs
        if (activeStatuses.contains(status)) {
          active++;
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _assignedJobs = snapshot.docs.length;
        _completedJobs = completed;
        _activeJobs = active;
        _totalEarnings = earnings;
        _hasLoadedAssignedStatistics = true;
      });

      // Load denied requests separately so a deniedBy rules/query failure
      // does not hide the statistics for jobs assigned to this provider.
      try {
        final QuerySnapshot deniedSnapshot = await _firestore
            .collection('assistance_requests')
            .where('deniedBy', arrayContains: providerId)
            .get();

        if (!mounted) {
          return;
        }

        setState(() {
          _deniedRequests = deniedSnapshot.docs.length;
          _hasLoadedDeniedStatistics = true;
        });
      } catch (e) {
        debugPrint('Error loading denied provider requests: $e');

        if (!mounted) {
          return;
        }

        setState(() {
          _statisticsError = _profileLoadErrorMessage('Denied requests', e);
          _hasLoadedDeniedStatistics = false;
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoadingStats = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading provider statistics: $e');

      if (!mounted) {
        return;
      }

      setState(() {
        _statisticsError = _profileLoadErrorMessage('Provider statistics', e);
        _hasLoadedAssignedStatistics = false;
        _isLoadingStats = false;
      });
    }
  }

  String _profileLoadErrorMessage(String section, Object error) {
    if (error is FirebaseException) {
      switch (error.code) {
        case 'permission-denied':
          return '$section was blocked by Firestore security rules. '
              'Allow this signed-in provider to read matching assistance requests.';
        case 'unauthenticated':
          return 'Your session has expired. Sign in again to load $section.';
        case 'unavailable':
          return 'Firestore is unavailable. Check your internet connection and retry.';
        case 'failed-precondition':
          return 'Firestore could not complete $section. Check the Firebase query/index configuration.';
        default:
          return '$section failed (${error.code}). '
              '${error.message ?? 'Please retry.'}';
      }
    }

    return '$section failed: $error';
  }

  Future<void> _loadJobHistory() async {
    final String providerId = _providerId;

    if (providerId.isEmpty) {
      if (mounted) {
        setState(() {
          _jobHistoryError = 'Provider account could not be identified.';
          _isLoadingJobHistory = false;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingJobHistory = true;
        _jobHistoryError = null;
      });
    }

    try {
      // ----------------------------------------------------------
      // Get requests accepted by this provider
      // ----------------------------------------------------------

      final QuerySnapshot acceptedSnapshot = await _firestore
          .collection('assistance_requests')
          .where('providerId', isEqualTo: providerId)
          .get();

      // ----------------------------------------------------------
      // Get requests denied by this provider
      // ----------------------------------------------------------

      QuerySnapshot? deniedSnapshot;
      try {
        deniedSnapshot = await _firestore
            .collection('assistance_requests')
            .where('deniedBy', arrayContains: providerId)
            .get();
      } catch (e) {
        debugPrint('Error loading denied job history: $e');
        if (mounted) {
          setState(() {
            _jobHistoryError = _profileLoadErrorMessage(
              'Declined job history',
              e,
            );
          });
        }
      }

      final List<Map<String, dynamic>> history = [];

      // ----------------------------------------------------------
      // Add accepted/provider jobs
      // ----------------------------------------------------------

      for (final QueryDocumentSnapshot document in acceptedSnapshot.docs) {
        final Map<String, dynamic> data =
            document.data() as Map<String, dynamic>;

        final String status = data['status']?.toString() ?? '';

        if (status == 'completed' || status == 'cancelled') {
          history.add({
            'requestId': document.id,
            'type': status,
            'issueType': data['issueType']?.toString() ?? 'Assistance Request',
            'vehicleType': data['vehicleType']?.toString() ?? 'Vehicle',
            'jobAmount': data['jobAmount'],
            'createdAt': data['createdAt'],
            'completedAt': data['completedAt'],
          });
        }
      }

      // ----------------------------------------------------------
      // Add denied requests
      // ----------------------------------------------------------

      for (final QueryDocumentSnapshot document
          in deniedSnapshot?.docs ?? <QueryDocumentSnapshot>[]) {
        final Map<String, dynamic> data =
            document.data() as Map<String, dynamic>;

        history.add({
          'requestId': document.id,
          'type': 'denied',
          'issueType': data['issueType']?.toString() ?? 'Assistance Request',
          'vehicleType': data['vehicleType']?.toString() ?? 'Vehicle',
          'jobAmount': data['jobAmount'],
          'createdAt': data['createdAt'],
          'completedAt': null,
        });
      }

      // ----------------------------------------------------------
      // Sort newest first
      // ----------------------------------------------------------

      history.sort((a, b) {
        DateTime? getDate(Map<String, dynamic> item) {
          final dynamic value = item['completedAt'] ?? item['createdAt'];

          if (value is Timestamp) {
            return value.toDate();
          }

          return null;
        }

        final DateTime? aDate = getDate(a);
        final DateTime? bDate = getDate(b);

        if (aDate == null && bDate == null) {
          return 0;
        }

        if (aDate == null) {
          return 1;
        }

        if (bDate == null) {
          return -1;
        }

        return bDate.compareTo(aDate);
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _jobHistory = history;
        _isLoadingJobHistory = false;
      });
    } catch (e) {
      debugPrint('Error loading job history: $e');

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingJobHistory = false;
        _jobHistoryError = _profileLoadErrorMessage('Job history', e);
      });
    }
  }

  Future<void> _loadActiveJob() async {
    final String providerId = _providerId;

    if (providerId.isEmpty) {
      return;
    }

    if (mounted) {
      setState(() {
        _isLoadingActiveJob = true;
      });
    }

    try {
      const List<String> activeStatuses = [
        'accepted',
        'on_the_way',
        'arrived',
        'in_progress',
      ];

      final QuerySnapshot snapshot = await _firestore
          .collection('assistance_requests')
          .where('providerId', isEqualTo: providerId)
          .get();

      QueryDocumentSnapshot? activeDocument;

      for (final QueryDocumentSnapshot document in snapshot.docs) {
        final Map<String, dynamic> data =
            document.data() as Map<String, dynamic>;

        final String status = data['status']?.toString() ?? '';

        if (activeStatuses.contains(status)) {
          activeDocument = document;
          break;
        }
      }

      if (!mounted) {
        return;
      }

      if (activeDocument == null) {
        setState(() {
          _activeRequestId = null;
          _activeJobData = null;
          _isLoadingActiveJob = false;
        });

        return;
      }

      final Map<String, dynamic> activeData =
          activeDocument.data() as Map<String, dynamic>;

      setState(() {
        _activeRequestId = activeDocument!.id;
        _activeJobData = activeData;
        _isLoadingActiveJob = false;
      });

      debugPrint('Active job loaded: $_activeRequestId');
    } catch (e) {
      debugPrint('Error loading active job: $e');

      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingActiveJob = false;
      });
    }
  }

  void _startActiveJobListener() {
    final String? requestId = _activeRequestId;

    if (requestId == null || requestId.isEmpty) {
      return;
    }

    _firestore
        .collection('assistance_requests')
        .doc(requestId)
        .snapshots()
        .listen(
          (DocumentSnapshot snapshot) {
            if (!snapshot.exists) {
              return;
            }

            final Map<String, dynamic> data =
                snapshot.data() as Map<String, dynamic>;

            final String status = data['status']?.toString() ?? '';

            if (!mounted) {
              return;
            }

            setState(() {
              _activeJobData = data;
            });

            if (status == 'completed') {
              _loadProviderStatistics();
              _loadJobHistory();
            }
          },
          onError: (error) {
            debugPrint('Active job listener error: $error');
          },
        );
  }

  // ============================================================
  // LOAD PROVIDER AVAILABILITY
  // ============================================================

  Future<void> _loadProviderAvailability() async {
    try {
      if (_providerId.isEmpty) {
        return;
      }

      final DocumentSnapshot document = await _firestore
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

      final bool savedOnlineStatus = data['isOnline'] == true;

      Position? savedPosition;

      if (data['latitude'] != null && data['longitude'] != null) {
        savedPosition = Position(
          latitude: (data['latitude'] as num).toDouble(),
          longitude: (data['longitude'] as num).toDouble(),
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

      if (!mounted) {
        return;
      }

      setState(() {
        _isOnline = savedOnlineStatus;
        _currentPosition = savedPosition;
      });

      if (savedOnlineStatus) {
        _startLocationStream();
        _startRequestListener();
      }
    } catch (e) {
      debugPrint('Error loading provider availability: $e');
    }
  }

  // ============================================================
  // LOCATION PERMISSION
  // ============================================================

  Future<bool> _checkLocationPermission() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      if (mounted) {
        _showLocationServiceMessage();
      }

      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied) {
      if (mounted) {
        _showMessage('Location permission is required to go online.');
      }

      return false;
    }

    if (permission == LocationPermission.deniedForever) {
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
      final bool permissionGranted = await _checkLocationPermission();

      if (!permissionGranted) {
        if (mounted) {
          setState(() {
            _isOnline = false;
            _isGettingLocation = false;
          });
        }

        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      _currentPosition = position;

      await _updateProviderLocation(position, isOnline: true);

      if (!mounted) {
        return;
      }

      setState(() {
        _isOnline = true;
        _isGettingLocation = false;
      });

      _startLocationStream();
      _startRequestListener();

      _showMessage('You are now online.');
    } catch (e) {
      debugPrint('Error going online: $e');

      if (!mounted) {
        return;
      }

      setState(() {
        _isOnline = false;
        _isGettingLocation = false;
      });

      _showMessage('Could not get your current location.');
    }
  }

  // ============================================================
  // GO OFFLINE
  // ============================================================

  Future<void> _goOffline() async {
    await _stopLocationTracking();
    await _stopRequestListener();

    try {
      if (_providerId.isNotEmpty) {
        await _firestore.collection('users').doc(_providerId).update({
          'isOnline': false,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      debugPrint('Error going offline: $e');
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isOnline = false;
      _isGettingLocation = false;
    });

    _showMessage('You are now offline.');
  }

  // ============================================================
  // START LOCATION STREAM
  // ============================================================

  void _startLocationStream() {
    _positionSubscription?.cancel();

    const LocationSettings settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: settings).listen(
          (Position position) async {
            if (!_isOnline) {
              return;
            }

            _currentPosition = position;

            if (mounted) {
              setState(() {});
            }

            // Update provider's own user document.
            await _updateProviderLocation(position, isOnline: true);

            // Update the accepted assistance request.
            await _updateAcceptedRequestLocation(position);
          },
          onError: (error) {
            debugPrint('Provider location stream error: $error');
          },
        );
  }

  // ============================================================
  // UPDATE PROVIDER USER LOCATION
  // ============================================================

  Future<void> _updateProviderLocation(
    Position position, {
    required bool isOnline,
  }) async {
    if (_providerId.isEmpty) {
      debugPrint('Provider ID is empty. Cannot update location.');
      return;
    }

    try {
      await _firestore.collection('users').doc(_providerId).update({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'isOnline': isOnline,
        'locationUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating provider location: $e');
    }
  }

  // ============================================================
  // UPDATE ACCEPTED ASSISTANCE REQUEST LOCATION
  // ============================================================

  Future<void> _updateAcceptedRequestLocation(Position position) async {
    final String? requestId = _activeRequestId;

    if (requestId == null || requestId.isEmpty) {
      return;
    }

    try {
      await _firestore.collection('assistance_requests').doc(requestId).update({
        'providerLatitude': position.latitude,
        'providerLongitude': position.longitude,
        'providerLocationUpdatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint(
        'Updated accepted request provider location: '
        '${position.latitude}, '
        '${position.longitude}',
      );
    } catch (e) {
      debugPrint('Error updating accepted request location: $e');
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
  // START REQUEST LISTENER
  // ============================================================

  void _startRequestListener() {
    if (_providerId.isEmpty) {
      return;
    }

    _requestSubscription?.cancel();

    if (mounted) {
      setState(() {
        _isLoadingRequests = true;
      });
    }

    _requestSubscription = _firestore
        .collection('assistance_requests')
        .where('status', whereIn: ['pending', 'searching'])
        .snapshots()
        .listen(
          (QuerySnapshot snapshot) {
            final List<QueryDocumentSnapshot> requests = snapshot.docs.where((
              document,
            ) {
              final Map<String, dynamic> data =
                  document.data() as Map<String, dynamic>;

              final List<dynamic> deniedBy = data['deniedBy'] is List
                  ? List<dynamic>.from(data['deniedBy'] as List)
                  : <dynamic>[];

              return !deniedBy.contains(_providerId);
            }).toList();

            requests.sort((a, b) {
              final Map<String, dynamic> aData =
                  a.data() as Map<String, dynamic>;

              final Map<String, dynamic> bData =
                  b.data() as Map<String, dynamic>;

              final Timestamp? aTime = aData['createdAt'] is Timestamp
                  ? aData['createdAt'] as Timestamp
                  : null;

              final Timestamp? bTime = bData['createdAt'] is Timestamp
                  ? bData['createdAt'] as Timestamp
                  : null;

              if (aTime == null && bTime == null) {
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
            debugPrint('Assistance request listener error: $error');

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

  // ============================================================
  // ACCEPT REQUEST
  // ============================================================

  Future<void> _acceptRequest(QueryDocumentSnapshot requestDocument) async {
    if (_providerId.isEmpty) {
      _showMessage('Provider ID is not available.');
      return;
    }

    final DocumentReference requestReference = _firestore
        .collection('assistance_requests')
        .doc(requestDocument.id);

    try {
      // ==========================================================
      // STEP 1:
      // Get the provider's latest location
      // ==========================================================

      final DocumentSnapshot providerSnapshot = await _firestore
          .collection('users')
          .doc(_providerId)
          .get();

      if (!providerSnapshot.exists) {
        throw Exception('Provider profile could not be found.');
      }

      final Map<String, dynamic>? providerData =
          providerSnapshot.data() as Map<String, dynamic>?;

      if (providerData == null) {
        throw Exception('Provider information could not be loaded.');
      }

      final dynamic latitudeValue = providerData['latitude'];

      final dynamic longitudeValue = providerData['longitude'];

      if (latitudeValue == null || longitudeValue == null) {
        throw Exception(
          'Provider location is not available yet. '
          'Please wait a few seconds and try again.',
        );
      }

      final double providerLatitude = (latitudeValue as num).toDouble();

      final double providerLongitude = (longitudeValue as num).toDouble();

      debugPrint('========================================');

      debugPrint('PROVIDER LOCATION BEFORE ACCEPTING');

      debugPrint('Provider ID: $_providerId');

      debugPrint('Latitude: $providerLatitude');

      debugPrint('Longitude: $providerLongitude');

      debugPrint('========================================');

      // ==========================================================
      // STEP 2:
      // Accept the request
      // ==========================================================

      String requestOwnerId = '';
      String issueType = 'roadside assistance';

      await _firestore.runTransaction((transaction) async {
        final DocumentSnapshot snapshot = await transaction.get(
          requestReference,
        );

        if (!snapshot.exists) {
          throw Exception('This request no longer exists.');
        }

        final Map<String, dynamic> data =
            snapshot.data() as Map<String, dynamic>;
        requestOwnerId = data['userId']?.toString() ?? '';
        issueType = data['issueType']?.toString() ?? 'roadside assistance';

        final String status = data['status']?.toString() ?? 'pending';

        final List<dynamic> deniedBy = data['deniedBy'] is List
            ? List<dynamic>.from(data['deniedBy'] as List)
            : <dynamic>[];

        // --------------------------------------------------------
        // Check whether this provider already denied it.
        // --------------------------------------------------------

        if (deniedBy.contains(_providerId)) {
          throw Exception('You have already denied this request.');
        }

        // --------------------------------------------------------
        // Only pending/searching requests can be accepted.
        // --------------------------------------------------------

        if (status != 'pending' && status != 'searching') {
          throw Exception(
            'This request has already been accepted '
            'by another provider.',
          );
        }

        // --------------------------------------------------------
        // Save provider information and GPS coordinates.
        // --------------------------------------------------------

        transaction.update(requestReference, {
          'status': 'accepted',

          'providerId': _providerId,

          'providerName': _providerName,

          'providerEmail': _email,

          'providerLatitude': providerLatitude,

          'providerLongitude': providerLongitude,

          'providerLocationUpdatedAt': FieldValue.serverTimestamp(),

          'acceptedAt': FieldValue.serverTimestamp(),

          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      final bool driverNotified = await _createRequestDecisionNotification(
        userId: requestOwnerId,
        requestId: requestDocument.id,
        issueType: issueType,
        status: 'accepted',
      );

      // ==========================================================
      // STEP 3:
      // Set this as the provider's active request
      // ==========================================================

      _activeRequestId = requestDocument.id;

      debugPrint('========================================');

      debugPrint('REQUEST ACCEPTED');

      debugPrint('Request ID: $_activeRequestId');

      debugPrint('Provider Latitude: $providerLatitude');

      debugPrint('Provider Longitude: $providerLongitude');

      debugPrint('========================================');

      // ==========================================================
      // STEP 4:
      // Immediately update with the newest GPS position
      // if one is available.
      // ==========================================================

      if (_currentPosition != null) {
        await _updateAcceptedRequestLocation(_currentPosition!);
      }

      // ==========================================================
      // STEP 5:
      // Remove request from the incoming list
      // ==========================================================

      if (mounted) {
        setState(() {
          _incomingRequests.removeWhere(
            (request) => request.id == requestDocument.id,
          );
        });
      }

      // ==========================================================
      // STEP 6:
      // Stop listening for NEW incoming requests.
      //
      // We don't need the old request-list screen anymore
      // because we are going to the navigation screen.
      // ==========================================================

      await _stopRequestListener();

      // ==========================================================
      // STEP 7:
      // Navigate to provider directions page
      // ==========================================================

      if (!mounted) {
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ProviderDirectionsPage(
            requestId: requestDocument.id,
            userData: widget.userData,
          ),
        ),
      );
      if (!driverNotified) {
        _showMessage('Request accepted, but the driver could not be notified.');
      }
    } catch (e) {
      debugPrint('========================================');

      debugPrint('ERROR ACCEPTING REQUEST');

      debugPrint('$e');

      debugPrint('========================================');

      if (!mounted) {
        return;
      }

      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  // ============================================================
  // DENY REQUEST
  // ============================================================

  Future<void> _denyRequest(QueryDocumentSnapshot requestDocument) async {
    if (_providerId.isEmpty) {
      return;
    }

    final DocumentReference requestReference = _firestore
        .collection('assistance_requests')
        .doc(requestDocument.id);
    String requestOwnerId = '';
    String issueType = 'roadside assistance';

    try {
      await _firestore.runTransaction((transaction) async {
        final DocumentSnapshot snapshot = await transaction.get(
          requestReference,
        );

        if (!snapshot.exists) {
          throw Exception('This request no longer exists.');
        }

        final Map<String, dynamic> data =
            snapshot.data() as Map<String, dynamic>;
        requestOwnerId = data['userId']?.toString() ?? '';
        issueType = data['issueType']?.toString() ?? 'roadside assistance';

        final String status = data['status']?.toString() ?? 'pending';

        if (status != 'pending' && status != 'searching') {
          throw Exception('This request is no longer available.');
        }

        final List<dynamic> deniedBy = data['deniedBy'] is List
            ? List<dynamic>.from(data['deniedBy'] as List)
            : <dynamic>[];

        if (!deniedBy.contains(_providerId)) {
          deniedBy.add(_providerId);
        }

        // IMPORTANT:
        // Denying a request must NOT change it
        // to "accepted".
        transaction.update(requestReference, {
          'deniedBy': deniedBy,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      });

      final bool driverNotified = await _createRequestDecisionNotification(
        userId: requestOwnerId,
        requestId: requestDocument.id,
        issueType: issueType,
        status: 'declined',
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _incomingRequests.removeWhere(
          (request) => request.id == requestDocument.id,
        );
      });

      _showMessage(
        driverNotified
            ? 'Request denied.'
            : 'Request denied, but the driver could not be notified.',
      );
    } catch (e) {
      debugPrint('Error denying request: $e');

      if (!mounted) {
        return;
      }

      _showMessage(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<bool> _createRequestDecisionNotification({
    required String userId,
    required String requestId,
    required String issueType,
    required String status,
  }) async {
    if (userId.isEmpty) {
      debugPrint(
        'Request decision notification skipped: request owner ID is missing.',
      );
      return false;
    }

    final bool accepted = status == 'accepted';
    try {
      await _firestore.collection('notifications').add({
        'userId': userId,
        'type': 'assistance_request_update',
        'status': status,
        'requestId': requestId,
        'title': accepted
            ? 'Request accepted'
            : 'Request declined by a provider',
        'message': accepted
            ? 'Your $issueType request has been accepted.'
            : 'A provider declined your $issueType request. '
                  'It may still be available to other providers.',
        'read': false,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return true;
    } on FirebaseException catch (e) {
      debugPrint(
        'Request decision notification error: ${e.code} - ${e.message}',
      );
      return false;
    }
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> _logout() async {
    try {
      await _stopLocationTracking();
      await _stopRequestListener();

      if (_providerId.isNotEmpty) {
        try {
          await _firestore.collection('users').doc(_providerId).update({
            'isOnline': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          debugPrint('Error updating provider offline state: $e');
        }
      }

      _activeRequestId = null;

      await _auth.signOut();

      if (!mounted) {
        return;
      }

      Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
    } catch (e) {
      debugPrint('Logout error: $e');

      if (mounted) {
        _showMessage('Unable to logout.');
      }
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopHeader(),
            Expanded(child: _buildSelectedPage()),
            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TOP HEADER
  // ============================================================

  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _yellowColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(
              Icons.local_shipping_rounded,
              color: _yellowColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RoadRescue',
                  style: TextStyle(
                    color: _yellowColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Roadside Provider',
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
          _buildOnlineToggle(),
        ],
      ),
    );
  }

  // ============================================================
  // ONLINE TOGGLE
  // ============================================================

  Widget _buildOnlineToggle() {
    return GestureDetector(
      onTap: _isGettingLocation
          ? null
          : () {
              if (_isOnline) {
                _goOffline();
              } else {
                _goOnline();
              }
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: _isOnline
              ? Colors.greenAccent.withOpacity(0.12)
              : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _isOnline
                ? Colors.greenAccent.withOpacity(0.35)
                : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isGettingLocation)
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.greenAccent,
                ),
              )
            else
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _isOnline ? Colors.greenAccent : Colors.white38,
                  shape: BoxShape.circle,
                ),
              ),
            const SizedBox(width: 7),
            Text(
              _isOnline ? 'ONLINE' : 'OFFLINE',
              style: TextStyle(
                color: _isOnline ? Colors.greenAccent : Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SELECTED PAGE
  // ============================================================

  Widget _buildSelectedPage() {
    switch (_selectedIndex) {
      case 1:
        return _buildRequestsPage();

      case 2:
        return _buildProfilePage();

      default:
        return _buildDashboardPage();
    }
  }

  // ============================================================
  // DASHBOARD
  // ============================================================

  Widget _buildDashboardPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard(),
          const SizedBox(height: 16),
          _buildStatusCard(),
          const SizedBox(height: 16),
          _buildQuickStats(),
          const SizedBox(height: 16),
          _buildLocationCard(),
          const SizedBox(height: 22),
          _buildActiveJobSection(),
          const SizedBox(height: 16),
          _buildQuickStats(),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Incoming Requests',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedIndex = 1;
                  });
                },
                child: Text(
                  'View All',
                  style: TextStyle(color: _yellowColor, fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _buildDashboardRequests(),
        ],
      ),
    );
  }

  // ============================================================
  // WELCOME CARD
  // ============================================================

  Widget _buildWelcomeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _yellowColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.person_rounded, color: _yellowColor, size: 29),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Welcome back',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  _providerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isOnline
                      ? 'You are available for requests'
                      : 'Go online to receive requests',
                  style: TextStyle(
                    color: _isOnline ? Colors.greenAccent : Colors.white38,
                    fontSize: 11,
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
  // STATUS CARD
  // ============================================================

  Widget _buildStatusCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _isOnline ? Colors.greenAccent.withOpacity(0.07) : _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isOnline
              ? Colors.greenAccent.withOpacity(0.18)
              : Colors.white.withOpacity(0.04),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: _isOnline
                  ? Colors.greenAccent.withOpacity(0.12)
                  : Colors.white.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _isOnline
                  ? Icons.check_circle_rounded
                  : Icons.pause_circle_outline,
              color: _isOnline ? Colors.greenAccent : Colors.white38,
              size: 24,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isOnline ? 'You are Online' : 'You are Offline',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isOnline
                      ? 'Waiting for roadside assistance requests.'
                      : 'Turn on availability to receive requests.',
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveJobSection() {
    if (_isLoadingActiveJob) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              color: Color(0xFFF6E900),
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    if (_activeJobData == null) {
      return const SizedBox.shrink();
    }

    final String issueType =
        _activeJobData!['issueType']?.toString() ?? 'Assistance Request';

    final String vehicleType =
        _activeJobData!['vehicleType']?.toString() ?? 'Vehicle';

    final String userName =
        _activeJobData!['userName']?.toString() ?? 'Vehicle Owner';

    final String status = _activeJobData!['status']?.toString() ?? 'accepted';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _yellowColor.withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: _yellowColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.car_repair_rounded,
                  color: _yellowColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Active Job',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildActiveStatusBadge(status),
            ],
          ),

          const SizedBox(height: 18),

          _buildRequestDetailRow(Icons.build_outlined, 'Issue', issueType),

          const SizedBox(height: 10),

          _buildRequestDetailRow(
            Icons.directions_car_outlined,
            'Vehicle',
            vehicleType,
          ),

          const SizedBox(height: 10),

          _buildRequestDetailRow(Icons.person_outline, 'Customer', userName),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: () {
                if (_activeRequestId == null) {
                  return;
                }

                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => ProviderDirectionsPage(
                      requestId: _activeRequestId!,
                      userData: widget.userData,
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _yellowColor,
                foregroundColor: Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: const Text(
                'View Active Job',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveStatusBadge(String status) {
    String label;

    switch (status) {
      case 'accepted':
        label = 'ACCEPTED';
        break;

      case 'on_the_way':
        label = 'ON THE WAY';
        break;

      case 'arrived':
        label = 'ARRIVED';
        break;

      case 'in_progress':
        label = 'IN PROGRESS';
        break;

      default:
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: _yellowColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: _yellowColor,
          fontSize: 8,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  // ============================================================
  // QUICK STATS
  // ============================================================

  Widget _buildQuickStats() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            icon: Icons.notifications_active_outlined,
            title: 'Requests',
            value: '${_incomingRequests.length}',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _buildStatCard(
            icon: Icons.location_on_outlined,
            title: 'GPS',
            value: _currentPosition != null ? 'Active' : 'Waiting',
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: _yellowColor, size: 23),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
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
  // LOCATION CARD
  // ============================================================

  Widget _buildLocationCard() {
    final bool hasLocation = _currentPosition != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Colors.greenAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current Location',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Your live provider location',
                      style: TextStyle(color: Colors.white38, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _backgroundColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              hasLocation
                  ? '${_currentPosition!.latitude.toStringAsFixed(6)}, '
                        '${_currentPosition!.longitude.toStringAsFixed(6)}'
                  : 'Location not available',
              style: TextStyle(
                color: hasLocation ? Colors.white70 : Colors.white38,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DASHBOARD REQUESTS
  // ============================================================

  Widget _buildDashboardRequests() {
    if (_isLoadingRequests) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: _cardColor,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFF6E900)),
        ),
      );
    }

    if (_incomingRequests.isEmpty) {
      return _buildEmptyRequests();
    }

    final int count = _incomingRequests.length > 2
        ? 2
        : _incomingRequests.length;

    return Column(
      children: List.generate(count, (index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _buildRequestCard(_incomingRequests[index]),
        );
      }),
    );
  }

  // ============================================================
  // REQUESTS PAGE
  // ============================================================

  Widget _buildRequestsPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Assistance Requests',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _isOnline
                ? 'Requests available near you'
                : 'Go online to receive requests',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 20),
          if (!_isOnline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.white54),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'You are offline. Go online to receive new roadside assistance requests.',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (_isLoadingRequests)
            const Center(
              child: CircularProgressIndicator(color: Color(0xFFF6E900)),
            )
          else if (_incomingRequests.isEmpty)
            _buildEmptyRequests()
          else
            Column(
              children: _incomingRequests.map((request) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildRequestCard(request),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY REQUESTS
  // ============================================================

  Widget _buildEmptyRequests() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 45, horizontal: 20),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.04),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_none_rounded,
              color: Colors.white38,
              size: 31,
            ),
          ),
          const SizedBox(height: 15),
          const Text(
            'No Requests Yet',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'New roadside assistance requests will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // REQUEST CARD
  // ============================================================

  Widget _buildRequestCard(QueryDocumentSnapshot requestDocument) {
    final Map<String, dynamic> data =
        requestDocument.data() as Map<String, dynamic>;

    final String userName = data['userName']?.toString() ?? 'Vehicle Owner';

    final String vehicleType = data['vehicleType']?.toString() ?? 'Vehicle';

    final String issueType =
        data['issueType']?.toString() ?? 'Assistance Required';

    final String status = data['status']?.toString() ?? 'pending';

    final double? latitude = data['latitude'] is num
        ? (data['latitude'] as num).toDouble()
        : null;

    final double? longitude = data['longitude'] is num
        ? (data['longitude'] as num).toDouble()
        : null;

    String locationText = 'Location unavailable';

    if (latitude != null && longitude != null) {
      locationText =
          '${latitude.toStringAsFixed(5)}, '
          '${longitude.toStringAsFixed(5)}';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.04)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: _yellowColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _getIssueIcon(issueType),
                  color: _yellowColor,
                  size: 23,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      issueType,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      userName,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.orangeAccent,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          _buildRequestDetailRow(
            Icons.directions_car_outlined,
            'Vehicle',
            vehicleType,
          ),
          const SizedBox(height: 9),
          _buildRequestDetailRow(
            Icons.location_on_outlined,
            'Location',
            locationText,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _denyRequest(requestDocument),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white70,
                    side: const BorderSide(color: Colors.white12),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Deny',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _acceptRequest(requestDocument),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _yellowColor,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Accept',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
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
  // REQUEST DETAIL ROW
  // ============================================================

  Widget _buildRequestDetailRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white38, size: 17),
        const SizedBox(width: 9),
        Text(
          '$title: ',
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // ISSUE ICON
  // ============================================================

  IconData _getIssueIcon(String issue) {
    final String lower = issue.toLowerCase();

    if (lower.contains('tire') || lower.contains('tyre')) {
      return Icons.tire_repair_outlined;
    }

    if (lower.contains('battery')) {
      return Icons.battery_alert_outlined;
    }

    if (lower.contains('fuel')) {
      return Icons.local_gas_station_outlined;
    }

    if (lower.contains('tow')) {
      return Icons.local_shipping_outlined;
    }

    return Icons.build_outlined;
  }
  // ============================================================
  // SAVE PROFILE DETAILS
  // ============================================================

  Future<void> _saveProfileDetails({
    required String name,
    required String workshopLocation,
    required BuildContext dialogContext,
  }) async {
    final String trimmedName = name.trim();
    final String trimmedLocation = workshopLocation.trim();

    if (trimmedName.isEmpty) {
      _showMessage('Provider name is required.');
      return;
    }

    if (trimmedLocation.isEmpty) {
      _showMessage('Workshop location is required.');
      return;
    }

    if (_providerId.isEmpty) {
      _showMessage('Unable to identify provider account.');
      return;
    }

    setState(() {
      _isSavingProfile = true;
    });

    try {
      await _firestore.collection('users').doc(_providerId).update({
        'name': trimmedName,
        'workshopLocation': trimmedLocation,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) {
        return;
      }

      setState(() {
        _profileName = trimmedName;
        _profileWorkshopLocation = trimmedLocation;

        // Update the local userData map as well.
        // This makes the new values available to
        // other pages opened from this page.
        widget.userData['name'] = trimmedName;
        widget.userData['workshopLocation'] = trimmedLocation;
      });

      if (Navigator.canPop(dialogContext)) {
        Navigator.pop(dialogContext);
      }

      _showMessage('Profile updated successfully.');
    } catch (e) {
      debugPrint('Error saving provider profile: $e');

      if (mounted) {
        _showMessage('Failed to update profile. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSavingProfile = false;
        });
      }
    }
  }

  // ============================================================
  // EDIT PROFILE DIALOG
  // ============================================================

  void _showEditProfileDialog() {
    final TextEditingController nameController = TextEditingController(
      text: _profileName,
    );

    final TextEditingController workshopController = TextEditingController(
      text: _profileWorkshopLocation,
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: _cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text(
                'Edit Profile',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ------------------------------------------------
                    // PROVIDER NAME
                    // ------------------------------------------------

                    TextField(
                      controller: nameController,
                      textCapitalization: TextCapitalization.words,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Provider Name',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: Icon(
                          Icons.person_outline,
                          color: _yellowColor,
                        ),
                        filled: true,
                        fillColor: _backgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ------------------------------------------------
                    // WORKSHOP LOCATION
                    // ------------------------------------------------
                    TextField(
                      controller: workshopController,
                      textCapitalization: TextCapitalization.words,
                      maxLines: 2,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Workshop Location',
                        labelStyle: const TextStyle(color: Colors.white70),
                        prefixIcon: Icon(
                          Icons.home_work_outlined,
                          color: _yellowColor,
                        ),
                        filled: true,
                        fillColor: _backgroundColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ------------------------------------------------
                    // EMAIL - READ ONLY
                    // ------------------------------------------------
                    TextField(
                      enabled: false,
                      controller: TextEditingController(text: _email),
                      style: const TextStyle(color: Colors.white38),
                      decoration: InputDecoration(
                        labelText: 'Email',
                        labelStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(
                          Icons.email_outlined,
                          color: Colors.white38,
                        ),
                        filled: true,
                        fillColor: _backgroundColor,
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
                // --------------------------------------------------
                // CANCEL
                // --------------------------------------------------

                TextButton(
                  onPressed: _isSavingProfile
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),

                // --------------------------------------------------
                // SAVE
                // --------------------------------------------------
                ElevatedButton(
                  onPressed: _isSavingProfile
                      ? null
                      : () async {
                          final String name = nameController.text.trim();

                          final String workshopLocation = workshopController
                              .text
                              .trim();

                          if (name.isEmpty) {
                            _showMessage('Please enter the provider name.');
                            return;
                          }

                          if (workshopLocation.isEmpty) {
                            _showMessage('Please enter the workshop location.');
                            return;
                          }

                          setDialogState(() {});

                          await _saveProfileDetails(
                            name: name,
                            workshopLocation: workshopLocation,
                            dialogContext: dialogContext,
                          );

                          if (mounted) {
                            setDialogState(() {});
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _yellowColor,
                    foregroundColor: Colors.black,
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
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Save Changes',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // PROFILE PAGE
  // ============================================================
  Widget _buildProviderStatisticsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _yellowColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.bar_chart_rounded,
                  color: _yellowColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'My Statistics',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (_isLoadingStats)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _yellowColor,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 18),

          if (_statisticsError != null)
            _buildProfileLoadError(
              message: _statisticsError!,
              onRetry: _loadProviderStatistics,
            ),
          if (_hasLoadedAssignedStatistics) ...[
            Row(
              children: [
                Expanded(
                  child: _buildStatisticItem(
                    icon: Icons.check_circle_outline_rounded,
                    title: 'Completed',
                    value: _completedJobs.toString(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatisticItem(
                    icon: Icons.cancel_outlined,
                    title: 'Denied',
                    value: _hasLoadedDeniedStatistics
                        ? _deniedRequests.toString()
                        : '—',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _buildStatisticItem(
                    icon: Icons.directions_car_filled_outlined,
                    title: 'Active',
                    value: _activeJobs.toString(),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildStatisticItem(
                    icon: Icons.payments_outlined,
                    title: 'Earnings',
                    value: 'Rs. ${_totalEarnings.toStringAsFixed(0)}',
                  ),
                ),
              ],
            ),
          ] else if (_isLoadingStats)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileLoadError({
    required String message,
    required VoidCallback onRetry,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            message,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Try again'),
            style: TextButton.styleFrom(
              foregroundColor: _yellowColor,
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _yellowColor.withOpacity(0.10),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: _yellowColor, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfilePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ========================================================
          // TITLE
          // ========================================================

          const Text(
            'Provider Profile',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 5),

          const Text(
            'Manage your provider information',
            style: TextStyle(color: Colors.white54, fontSize: 12),
          ),

          const SizedBox(height: 18),

          // ========================================================
          // PROFILE HEADER CARD
          // ========================================================
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                // --------------------------------------------------
                // PROFILE ICON
                // --------------------------------------------------

                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        color: _yellowColor.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _yellowColor.withOpacity(0.35),
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
                          ? Icon(
                              Icons.person_rounded,
                              color: _yellowColor,
                              size: 44,
                            )
                          : null,
                    ),

                    if (_isUploadingProfilePhoto)
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
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 14),

                // --------------------------------------------------
                // PROVIDER NAME
                // --------------------------------------------------
                Text(
                  _providerName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 5),

                // --------------------------------------------------
                // EMAIL
                // --------------------------------------------------
                Text(
                  _email.isEmpty ? 'Email not available' : _email,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),

                const SizedBox(height: 8),

                GestureDetector(
                  onTap: _isUploadingProfilePhoto ? null : _uploadProfilePhoto,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.camera_alt_outlined,
                        color: _yellowColor,
                        size: 16,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _isUploadingProfilePhoto
                            ? 'Uploading...'
                            : 'Change Photo',
                        style: TextStyle(
                          color: _yellowColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // --------------------------------------------------
                // EDIT PROFILE BUTTON
                // --------------------------------------------------
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
                      backgroundColor: _yellowColor,
                      foregroundColor: Colors.black,
                      disabledBackgroundColor: _yellowColor.withOpacity(0.4),
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

          // ========================================================
          // EMAIL
          // ========================================================
          _buildProviderStatisticsCard(),
          const SizedBox(height: 16),

          _buildJobHistorySection(),
          const SizedBox(height: 22),

          _buildProfileInfoCard(
            icon: Icons.email_outlined,
            title: 'Email',
            value: _email.isEmpty ? 'Not available' : _email,
          ),

          const SizedBox(height: 10),

          // ========================================================
          // WORKSHOP LOCATION
          // ========================================================
          _buildProfileInfoCard(
            icon: Icons.home_work_outlined,
            title: 'Workshop Location',
            value: _workshopLocation,
          ),

          const SizedBox(height: 22),

          // ========================================================
          // PERFORMANCE
          // ========================================================
          const Text(
            'Performance',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 10),

          _buildPerformanceCard(),

          const SizedBox(height: 22),

          // ========================================================
          // LOGOUT
          // ========================================================
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout_rounded),
              label: const Text(
                'Logout',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
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
  // PROFILE INFO CARD
  // ============================================================

  Widget _buildPerformanceCard() {
    final double completionRate = _assignedJobs == 0
        ? 0
        : _completedJobs / _assignedJobs;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: !_hasLoadedAssignedStatistics
          ? _statisticsError != null
                ? _buildProfileLoadError(
                    message: _statisticsError!,
                    onRetry: _loadProviderStatistics,
                  )
                : const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Completion rate',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    Text(
                      '${(completionRate * 100).round()}%',
                      style: TextStyle(
                        color: _yellowColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: completionRate,
                    minHeight: 7,
                    backgroundColor: Colors.white12,
                    valueColor: AlwaysStoppedAnimation<Color>(_yellowColor),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$_completedJobs completed out of $_assignedJobs assigned jobs',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.work_history_outlined,
                      color: Colors.white54,
                      size: 17,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '$_assignedJobs total jobs  •  $_activeJobs active',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                if (_isLoadingStats) ...[
                  const SizedBox(height: 12),
                  const LinearProgressIndicator(
                    minHeight: 2,
                    backgroundColor: Colors.white12,
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildJobHistorySection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _yellowColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.history_rounded,
                  color: _yellowColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Job History',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          if (_isLoadingJobHistory)
            Center(
              child: CircularProgressIndicator(
                color: _yellowColor,
                strokeWidth: 2,
              ),
            )
          else if (_jobHistoryError != null && _jobHistory.isEmpty)
            _buildProfileLoadError(
              message: _jobHistoryError!,
              onRetry: _loadJobHistory,
            )
          else
            Column(
              children: [
                if (_jobHistoryError != null)
                  _buildProfileLoadError(
                    message: _jobHistoryError!,
                    onRetry: _loadJobHistory,
                  ),
                if (_jobHistory.isEmpty)
                  _buildEmptyJobHistory()
                else
                  ..._jobHistory.map(_buildJobHistoryItem),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyJobHistory() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      child: Column(
        children: [
          Icon(Icons.history_rounded, color: Colors.white24, size: 42),
          const SizedBox(height: 10),
          const Text(
            'No job history yet',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Completed, cancelled and declined requests will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildJobHistoryItem(Map<String, dynamic> job) {
    final bool isCompleted = job['type'] == 'completed';
    final bool isCancelled =
        job['type'] == 'cancelled' || job['type'] == 'canceled';
    final Color statusColor = isCompleted
        ? Colors.greenAccent
        : isCancelled
        ? Colors.orangeAccent
        : Colors.redAccent;
    final Color statusBackgroundColor = isCompleted
        ? Colors.green
        : isCancelled
        ? Colors.orange
        : Colors.red;

    final String issueType =
        job['issueType']?.toString() ?? 'Assistance Request';

    final String vehicleType = job['vehicleType']?.toString() ?? 'Vehicle';

    final dynamic amountValue = job['jobAmount'];

    String amountText = '';

    if (amountValue is num) {
      amountText = 'Rs. ${amountValue.toStringAsFixed(0)}';
    } else if (amountValue != null) {
      final double? parsedAmount = double.tryParse(amountValue.toString());

      if (parsedAmount != null) {
        amountText = 'Rs. ${parsedAmount.toStringAsFixed(0)}';
      }
    }

    DateTime? date;

    final dynamic dateValue = job['completedAt'] ?? job['createdAt'];

    if (dateValue is Timestamp) {
      date = dateValue.toDate();
    }

    final String dateText = date == null
        ? 'Date unavailable'
        : '${date.day.toString().padLeft(2, '0')}/'
              '${date.month.toString().padLeft(2, '0')}/'
              '${date.year}';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: statusBackgroundColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isCompleted ? Icons.check_rounded : Icons.close_rounded,
              color: statusColor,
              size: 22,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issueType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  vehicleType,
                  style: const TextStyle(color: Colors.white54, fontSize: 11),
                ),

                const SizedBox(height: 6),

                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: statusBackgroundColor.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isCompleted
                            ? 'Completed'
                            : isCancelled
                            ? 'Cancelled'
                            : 'Denied',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    const SizedBox(width: 8),

                    Text(
                      dateText,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (isCompleted && amountText.isNotEmpty)
            Text(
              amountText,
              style: TextStyle(
                color: _yellowColor,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: _yellowColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: Colors.white38, fontSize: 10),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
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

  Widget _buildBottomNavigation() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: _backgroundColor,
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.04))),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildNavItem(
              index: 0,
              icon: Icons.dashboard_rounded,
              label: 'Home',
            ),
          ),
          Expanded(
            child: _buildNavItem(
              index: 1,
              icon: Icons.notifications_rounded,
              label: 'Requests',
            ),
          ),
          Expanded(
            child: _buildNavItem(
              index: 2,
              icon: Icons.person_rounded,
              label: 'Profile',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // NAV ITEM
  // ============================================================

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required String label,
  }) {
    final bool selected = _selectedIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
        if (index == 2) {
          _loadProviderStatistics();
          _loadJobHistory();
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              decoration: BoxDecoration(
                color: selected
                    ? _yellowColor.withOpacity(0.12)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                icon,
                color: selected ? _yellowColor : Colors.white38,
                size: 22,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: selected ? _yellowColor : Colors.white38,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LOCATION SERVICE MESSAGE
  // ============================================================

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
            'Location Services Disabled',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Please enable location services on your device to go online.',
            style: TextStyle(color: Colors.white70, height: 1.5),
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
  // PERMISSION SETTINGS MESSAGE
  // ============================================================

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
            'Location Permission Required',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Location permission has been permanently denied. Please enable it from your device settings.',
            style: TextStyle(color: Colors.white70, height: 1.5),
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
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF151D21),
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _requestSubscription?.cancel();

    super.dispose();
  }
}
