import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:road_rescue/theme/road_rescue_theme.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'insurance_claim_result_page.dart';
import 'provider_tracking_page.dart';

class AssistanceTrackingPage extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> userData;
  final String issue;

  const AssistanceTrackingPage({
    super.key,
    required this.requestId,
    required this.userData,
    required this.issue,
  });

  @override
  State<AssistanceTrackingPage> createState() => _AssistanceTrackingPageState();
}

class _AssistanceTrackingPageState extends State<AssistanceTrackingPage>
    with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  GoogleMapController? _mapController;

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _requestSubscription;

  Position? _currentPosition;

  bool _isLoading = true;
  bool _isTracking = false;
  bool _isCancelling = false;
  bool _hasNavigatedToProviderTracking = false;
  bool _hasNavigatedToInsuranceResult = false;

  // ================================================================
  // ASSISTANCE REQUEST
  // ================================================================
  bool _isWritingLocation = false;
  bool _locationWriteFailed = false;
  Position? _queuedPosition;

  String _status = 'pending';

  // Roadside provider's latest location.
  double? _providerLatitude;
  double? _providerLongitude;
  String? _providerName;

  String _distanceStatus = 'Waiting for provider location';

  // ================================================================
  // MAP MARKERS
  // ================================================================
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    _listenToRequestStatus();
    _startTracking();
  }

  void _navigateToProviderTracking(Map<String, dynamic> requestData) {
    if (!mounted) return;

    final String providerName =
        requestData['providerName']?.toString() ?? 'Roadside Provider';

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => ProviderTrackingPage(
          requestId: widget.requestId,
          userData: widget.userData,
          issue: widget.issue,
          providerName: providerName,
        ),
      ),
    );
  }

  Future<void> _navigateToInsuranceResult(
    Map<String, dynamic> requestData,
  ) async {
    if (!mounted || _hasNavigatedToInsuranceResult) return;
    _hasNavigatedToInsuranceResult = true;

    await _stopTracking();
    await _requestSubscription?.cancel();
    _requestSubscription = null;
    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (context) => InsuranceClaimResultPage(
          requestData: {'id': widget.requestId, ...requestData},
          userData: widget.userData,
          issue: widget.issue,
        ),
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _positionSubscription?.cancel();
      _positionSubscription = null;
    } else if (state == AppLifecycleState.resumed &&
        mounted &&
        _status != 'cancelled' &&
        _status != 'completed') {
      _startTracking();
    }
  }

  Future<void> _startTracking() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;

        _showMessage('Location services are disabled.');

        setState(() {
          _isLoading = false;
        });

        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;

        _showMessage('Location permission is required for live tracking.');

        setState(() {
          _isLoading = false;
        });

        return;
      }

      // Get initial position.
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      if (!_isValidPosition(position)) {
        throw StateError('Invalid GPS coordinates received.');
      }

      if (!mounted) return;

      setState(() {
        _currentPosition = position;
        _isLoading = false;
        _isTracking = true;
      });

      _updateMarker(position);

      await _updateFirestoreLocation(position);

      await _moveCamera(position);

      // Start continuous GPS updates.
      _positionSubscription?.cancel();

      const LocationSettings settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );

      _positionSubscription =
          Geolocator.getPositionStream(locationSettings: settings).listen(
            (Position position) {
              if (!mounted || !_isValidPosition(position)) return;

              setState(() {
                _currentPosition = position;
              });

              _updateMarker(position);
              _moveCamera(position);
              _queueFirestoreLocationUpdate(position);
            },
            onError: (Object error) {
              debugPrint('Live location stream error: $error');
              if (mounted) {
                _showMessage(
                  'Live location updates are temporarily unavailable.',
                );
              }
            },
          );
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isTracking = false;
      });
      _showMessage('Location request timed out. Check GPS and try again.');
    } on LocationServiceDisabledException {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isTracking = false;
      });
      _showMessage('Location services are disabled. Please enable GPS.');
    } on PermissionDeniedException {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isTracking = false;
      });
      _showMessage('Location permission is required for live tracking.');
    } catch (e) {
      debugPrint('Live location startup error: $e');
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isTracking = false;
      });

      _showMessage('Unable to start live location tracking.');
    }
  }

  bool _isValidPosition(Position position) {
    return position.latitude.isFinite &&
        position.longitude.isFinite &&
        position.latitude >= -90 &&
        position.latitude <= 90 &&
        position.longitude >= -180 &&
        position.longitude <= 180;
  }

  void _queueFirestoreLocationUpdate(Position position) {
    _queuedPosition = position;
    if (_isWritingLocation) return;
    _flushFirestoreLocationUpdate();
  }

  Future<void> _flushFirestoreLocationUpdate() async {
    final position = _queuedPosition;
    if (position == null || _isWritingLocation) return;

    _queuedPosition = null;
    _isWritingLocation = true;
    try {
      await _updateFirestoreLocation(position);
    } finally {
      _isWritingLocation = false;
      if (_queuedPosition != null && mounted) {
        _flushFirestoreLocationUpdate();
      }
    }
  }

  // ================================================================
  // UPDATE FIRESTORE LOCATION
  // ================================================================

  Future<void> _updateFirestoreLocation(Position position) async {
    if (!_isValidPosition(position)) return;

    try {
      await _firestore
          .collection('assistance_requests')
          .doc(widget.requestId)
          .update({
            'userId': widget.userData['uid']?.toString(),
            'latitude': position.latitude,
            'longitude': position.longitude,
            'accuracy': position.accuracy,
            'locationTimestamp': Timestamp.fromDate(position.timestamp),
            'updatedAt': FieldValue.serverTimestamp(),
          });
      _locationWriteFailed = false;
    } catch (e) {
      debugPrint('Failed to update live location: $e');
      if (mounted && !_locationWriteFailed) {
        _locationWriteFailed = true;
        _showMessage(
          'Location was detected, but could not be shared with the provider.',
        );
      }
    }
  }

  // ================================================================
  // UPDATE MAP MARKER
  // ================================================================

  void _updateMarker(Position position) {
    if (!mounted || !_isValidPosition(position)) return;

    setState(() {
      _markers.removeWhere(
        (marker) => marker.markerId.value == 'vehicle_owner',
      );
      _markers.add(
        Marker(
          markerId: const MarkerId('vehicle_owner'),
          position: LatLng(position.latitude, position.longitude),
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'Live location',
          ),
        ),
      );
    });

    _calculateDistance();
  }

  void _updateProviderMarker() {
    if (!mounted || _providerLatitude == null || _providerLongitude == null) {
      return;
    }

    setState(() {
      _markers.removeWhere(
        (marker) => marker.markerId.value == 'roadside_provider',
      );
      _markers.add(
        Marker(
          markerId: const MarkerId('roadside_provider'),
          position: LatLng(_providerLatitude!, _providerLongitude!),
          infoWindow: InfoWindow(
            title: _providerName ?? 'Roadside Provider',
            snippet: 'Provider live location',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueYellow,
          ),
        ),
      );
    });

    _calculateDistance();
  }

  // ================================================================
  // MOVE CAMERA
  // ================================================================

  Future<void> _moveCamera(Position position) async {
    if (_mapController == null) return;

    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(position.latitude, position.longitude),
          zoom: 17,
        ),
      ),
    );
  }

  // ================================================================
  // MAP CREATED
  // ================================================================

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;

    if (_currentPosition != null) {
      _moveCamera(_currentPosition!);
    }
  }

  void _listenToRequestStatus() {
    _requestSubscription = _firestore
        .collection('assistance_requests')
        .doc(widget.requestId)
        .snapshots()
        .listen(
          (snapshot) async {
            final data = snapshot.data();
            final status = data?['status']?.toString();

            if (!snapshot.exists ||
                data == null ||
                status == null ||
                status.isEmpty) {
              return;
            }
            if (!mounted) return;

            final latitude = data['providerLatitude'];
            final longitude = data['providerLongitude'];

            setState(() {
              _status = status;
              _providerName = data['providerName']?.toString();

              if (latitude is num && longitude is num) {
                _providerLatitude = latitude.toDouble();
                _providerLongitude = longitude.toDouble();
              } else {
                _providerLatitude = null;
                _providerLongitude = null;
              }
            });

            final String insuranceStatus =
                data['insuranceStatus']?.toString().toLowerCase() ?? '';
            if (data['insuranceClaim'] == true &&
                (insuranceStatus == 'approved' ||
                    insuranceStatus == 'rejected')) {
              await _navigateToInsuranceResult(data);
              return;
            }

            if (_providerLatitude != null && _providerLongitude != null) {
              _updateProviderMarker();
            } else {
              _calculateDistance();
            }

            if (status == 'cancelled' || status == 'completed') {
              await _stopTracking();
            } else if (status == 'accepted' &&
                !_hasNavigatedToProviderTracking) {
              _hasNavigatedToProviderTracking = true;
              await _stopTracking();
              if (mounted) _navigateToProviderTracking(data);
            }
          },
          onError: (Object error) {
            debugPrint('Request status listener error: $error');
          },
        );
  }

  void _calculateDistance() {
    final currentPosition = _currentPosition;
    final providerLatitude = _providerLatitude;
    final providerLongitude = _providerLongitude;

    if (currentPosition == null ||
        providerLatitude == null ||
        providerLongitude == null) {
      if (mounted) {
        setState(() {
          _distanceStatus = 'Waiting for provider location';
        });
      }
      return;
    }

    final double distanceMeters = Geolocator.distanceBetween(
      currentPosition.latitude,
      currentPosition.longitude,
      providerLatitude,
      providerLongitude,
    );

    if (!mounted) return;

    setState(() {
      _distanceStatus = distanceMeters < 1000
          ? '${distanceMeters.round()} m away'
          : '${(distanceMeters / 1000).toStringAsFixed(1)} km away';
    });
  }

  // ================================================================
  // CANCEL REQUEST
  // ================================================================

  Future<void> _cancelRequest() async {
    if (_isCancelling) return;

    setState(() {
      _isCancelling = true;
    });

    try {
      await _firestore
          .collection('assistance_requests')
          .doc(widget.requestId)
          .update({
            'status': 'cancelled',
            'updatedAt': FieldValue.serverTimestamp(),
          });

      await _stopTracking();

      if (!mounted) return;

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isCancelling = false;
      });

      _showMessage('Unable to cancel the request.');
    }
  }

  // ================================================================
  // STOP TRACKING
  // ================================================================

  Future<void> _stopTracking() async {
    await _positionSubscription?.cancel();

    _positionSubscription = null;

    if (mounted) {
      setState(() {
        _isTracking = false;
      });
    }
  }

  // ================================================================
  // CONFIRM CANCEL
  // ================================================================

  Future<void> _showCancelDialog() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: RoadRescueColors.surface,
          title: const Text(
            'Cancel Request?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to cancel your roadside assistance request?',
            style: TextStyle(color: Colors.white70, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('No', style: TextStyle(color: Colors.white70)),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text(
                'Cancel Request',
                style: TextStyle(
                  color: RoadRescueColors.accent,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await _cancelRequest();
    }
  }

  // ================================================================
  // SNACKBAR
  // ================================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF151D21),
      ),
    );
  }

  // ================================================================
  // DISPOSE
  // ================================================================

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _positionSubscription?.cancel();
    _requestSubscription?.cancel();
    _mapController?.dispose();

    super.dispose();
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: RoadRescueColors.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),

            Expanded(
              child: Stack(
                children: [
                  _buildMap(),

                  if (_isLoading) _buildLoading(),

                  _buildLiveIndicator(),

                  _buildMyLocationButton(),
                ],
              ),
            ),

            _buildBottomPanel(),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // TOP BAR
  // ================================================================

  Widget _buildTopBar() {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      color: RoadRescueColors.background,
      child: Row(
        children: [
          IconButton(
            onPressed: _showCancelDialog,
            icon: const Icon(Icons.close, color: Colors.white),
          ),

          const Expanded(
            child: Text(
              'Roadside Assistance',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // MAP
  // ================================================================

  Widget _buildMap() {
    final position = _currentPosition;
    if (position == null) {
      return const ColoredBox(color: Color(0xFF101214));
    }

    final location = LatLng(position.latitude, position.longitude);

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: location, zoom: 17),
      onMapCreated: _onMapCreated,
      markers: _markers,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: true,
      mapToolbarEnabled: false,
    );
  }

  // ================================================================
  // LOADING
  // ================================================================

  Widget _buildLoading() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.45),
        child: const Center(
          child: CircularProgressIndicator(color: RoadRescueColors.accent),
        ),
      ),
    );
  }

  // ================================================================
  // LIVE INDICATOR
  // ================================================================

  Widget _buildLiveIndicator() {
    return Positioned(
      top: 18,
      left: 18,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: RoadRescueColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: _isTracking ? Colors.greenAccent : Colors.white38,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              _isTracking
                  ? (_providerLatitude == null
                        ? 'Waiting for provider'
                        : _distanceStatus)
                  : 'LOCATION OFF',
              style: TextStyle(
                color: _isTracking ? Colors.greenAccent : Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ================================================================
  // MY LOCATION
  // ================================================================

  Widget _buildMyLocationButton() {
    return Positioned(
      right: 18,
      bottom: 18,
      child: GestureDetector(
        onTap: () {
          if (_currentPosition != null) {
            _moveCamera(_currentPosition!);
          }
        },
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: RoadRescueColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.my_location_rounded,
            color: RoadRescueColors.accent,
          ),
        ),
      ),
    );
  }

  // ================================================================
  // BOTTOM PANEL
  // ================================================================

  Widget _buildBottomPanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: const BoxDecoration(
        color: RoadRescueColors.surface,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(26),
          topRight: Radius.circular(26),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: RoadRescueColors.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.support_agent,
                  color: RoadRescueColors.accent,
                  size: 27,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Assistance Requested',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getStatusText(),
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: RoadRescueColors.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.build_circle_outlined,
                  color: Colors.white54,
                  size: 21,
                ),

                const SizedBox(width: 10),

                const Text(
                  'Issue:',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),

                const SizedBox(width: 6),

                Expanded(
                  child: Text(
                    widget.issue,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          const Row(
            children: [
              Icon(
                Icons.location_on_outlined,
                color: Colors.greenAccent,
                size: 18,
              ),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  'Your live location is being shared with RoadRescue.',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ],
          ),

          // ----------------------------------------------------------
          // CANCEL BUTTON
          // ----------------------------------------------------------
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton(
              onPressed: _isCancelling ? null : _showCancelDialog,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isCancelling
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Cancel Request',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ================================================================
  // STATUS TEXT
  // ================================================================

  String _getStatusText() {
    switch (_status) {
      case 'pending':
      case 'searching':
        return 'Searching for a roadside provider...';

      case 'accepted':
        return _providerName?.isNotEmpty == true
            ? '${_providerName!} has accepted your request.'
            : 'A roadside provider has accepted your request.';

      case 'on_the_way':
        return _providerName?.isNotEmpty == true
            ? '${_providerName!} is on the way.'
            : 'Your roadside provider is on the way.';

      case 'arrived':
        return 'Your roadside provider has arrived.';

      case 'in_progress':
        return 'Roadside assistance is in progress.';

      case 'completed':
        return 'Roadside assistance has been completed.';

      case 'cancelled':
        return 'This assistance request was cancelled.';

      default:
        return _status;
    }
  }
}