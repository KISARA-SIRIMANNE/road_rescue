import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../roadside_provider/provider_job_flow_pages.dart';

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

class _AssistanceTrackingPageState extends State<AssistanceTrackingPage> {
  // ================================================================
  // FIRESTORE
  // ================================================================

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ================================================================
  // GOOGLE MAP
  // ================================================================

  GoogleMapController? _mapController;

  // ================================================================
  // LOCATION STREAMS
  // ================================================================

  // Vehicle owner's GPS stream.
  StreamSubscription<Position>? _positionSubscription;

  // Firestore request listener.
  //
  // This listens to:
  // assistance_requests/{requestId}
  //
  // It allows the vehicle owner to receive the roadside
  // provider's location in real time.
  StreamSubscription<DocumentSnapshot>? _requestSubscription;

  // ================================================================
  // VEHICLE OWNER LOCATION
  // ================================================================

  Position? _currentPosition;

  // ================================================================
  // PAGE STATE
  // ================================================================

  bool _isLoading = true;
  bool _isTracking = false;
  bool _isCancelling = false;

  // ================================================================
  // ASSISTANCE REQUEST
  // ================================================================

  String _status = 'pending';
  Map<String, dynamic>? _requestData;

  // ================================================================
  // ROADSIDE PROVIDER LIVE LOCATION
  // ================================================================

  double? _providerLatitude;
  double? _providerLongitude;

  // Distance from vehicle owner to provider.
  double? _currentDistance;

  // Previous distance.
  //
  // Used to determine whether the provider is getting
  // closer or farther.
  double? _previousDistance;

  String _distanceStatus = 'Waiting for roadside assistance...';

  String? _providerName;

  // ================================================================
  // MAP MARKERS
  // ================================================================
  final Set<Marker> _markers = {};

  // ================================================================
  // DEFAULT MAP LOCATION
  // ================================================================

  static const LatLng _defaultLocation = LatLng(6.9271, 79.8612);

  // ================================================================
  // INIT STATE
  // ================================================================

  @override
  void initState() {
    super.initState();

    // Start listening for provider/request changes.
    _startRequestListener();

    // Start vehicle owner's live location tracking.
    _startTracking();
  }

  // ================================================================
  // LISTEN TO ASSISTANCE REQUEST
  // ================================================================

  void _startRequestListener() {
    _requestSubscription = _firestore
        .collection('assistance_requests')
        .doc(widget.requestId)
        .snapshots()
        .listen(
          (DocumentSnapshot snapshot) {
            if (!snapshot.exists) {
              return;
            }

            final Map<String, dynamic> data =
                snapshot.data() as Map<String, dynamic>;

            final String status = data['status']?.toString() ?? 'pending';

            final String? providerName = data['providerName']?.toString();

            final dynamic providerLatitude = data['providerLatitude'];

            final dynamic providerLongitude = data['providerLongitude'];

            if (!mounted) {
              return;
            }

            setState(() {
              _status = status;
              _requestData = data;
              _providerName = providerName;

              if (providerLatitude is num && providerLongitude is num) {
                _providerLatitude = providerLatitude.toDouble();

                _providerLongitude = providerLongitude.toDouble();
              } else {
                _providerLatitude = null;
                _providerLongitude = null;
              }
            });

            _updateProviderMarker();
            _calculateDistance();
          },
          onError: (error) {
            debugPrint('Assistance request listener error: $error');
          },
        );
  }

  // ================================================================
  // START LIVE TRACKING
  // ================================================================

  Future<void> _startTracking() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        _showMessage('Location services are disabled.');

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }

        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('Location permission is required for live tracking.');

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }

        return;
      }

      // ------------------------------------------------------------
      // GET INITIAL POSITION
      // ------------------------------------------------------------

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        _currentPosition = position;
        _isLoading = false;
        _isTracking = true;
      });

      // Add vehicle owner marker.
      _updateMarker(position);

      // Update driver's location in Firestore.
      await _updateFirestoreLocation(position);

      // Calculate distance to provider if available.
      _calculateDistance();

      // Move map camera.
      await _moveCamera(position);

      // ------------------------------------------------------------
      // START CONTINUOUS GPS UPDATES
      // ------------------------------------------------------------

      await _positionSubscription?.cancel();

      const LocationSettings settings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );

      _positionSubscription =
          Geolocator.getPositionStream(locationSettings: settings).listen(
            (Position position) async {
              if (!mounted) return;

              setState(() {
                _currentPosition = position;
              });

              // Update vehicle owner marker.
              _updateMarker(position);

              // Update vehicle owner location in Firestore.
              await _updateFirestoreLocation(position);

              // Recalculate distance to provider.
              _calculateDistance();
            },
            onError: (error) {
              debugPrint('Vehicle owner location stream error: $error');
            },
          );
    } catch (e) {
      debugPrint('Unable to start live location tracking: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _isTracking = false;
      });

      _showMessage('Unable to start live location tracking.');
    }
  }

  // ================================================================
  // UPDATE FIRESTORE VEHICLE OWNER LOCATION
  // ================================================================

  Future<void> _updateFirestoreLocation(Position position) async {
    try {
      await _firestore
          .collection('assistance_requests')
          .doc(widget.requestId)
          .update({
            'latitude': position.latitude,
            'longitude': position.longitude,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Failed to update live location: $e');
    }
  }

  // ================================================================
  // UPDATE VEHICLE OWNER MARKER
  // ================================================================

  void _updateMarker(Position position) {
    final LatLng location = LatLng(position.latitude, position.longitude);

    if (!mounted) {
      return;
    }

    setState(() {
      // Remove only the vehicle owner's old marker.
      //
      // IMPORTANT:
      // Do not clear the complete marker set because the
      // provider marker also exists there.
      _markers.remove(const MarkerId('vehicle_owner'));

      _markers.add(
        Marker(
          markerId: const MarkerId('vehicle_owner'),
          position: location,
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'Live location',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    });
  }

  // ================================================================
  // UPDATE ROADSIDE PROVIDER MARKER
  // ================================================================

  void _updateProviderMarker() {
    if (_providerLatitude == null || _providerLongitude == null) {
      return;
    }

    final LatLng providerLocation = LatLng(
      _providerLatitude!,
      _providerLongitude!,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      // Remove old provider marker.
      _markers.remove(const MarkerId('roadside_provider'));

      // Add new provider marker.
      _markers.add(
        Marker(
          markerId: const MarkerId('roadside_provider'),
          position: providerLocation,
          infoWindow: InfoWindow(
            title: _providerName?.isNotEmpty == true
                ? _providerName!
                : 'Roadside Assistance Provider',
            snippet: 'Live provider location',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    });
  }

  // ================================================================
  // CALCULATE DISTANCE TO PROVIDER
  // ================================================================

  void _calculateDistance() {
    if (_currentPosition == null ||
        _providerLatitude == null ||
        _providerLongitude == null) {
      return;
    }

    final double distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _providerLatitude!,
      _providerLongitude!,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _previousDistance = _currentDistance;
      _currentDistance = distance;

      if (_previousDistance == null) {
        _distanceStatus = 'Provider location received';
      } else if (distance < _previousDistance! - 5) {
        _distanceStatus = 'Provider is getting closer';
      } else if (distance > _previousDistance! + 5) {
        _distanceStatus = 'Provider is getting farther';
      } else {
        _distanceStatus = 'Provider distance is stable';
      }
    });
  }

  // ================================================================
  // FORMAT DISTANCE
  // ================================================================

  String _formatDistance(double? distance) {
    if (distance == null) {
      return '--';
    }

    if (distance < 1000) {
      return '${distance.toStringAsFixed(0)} m';
    }

    return '${(distance / 1000).toStringAsFixed(2)} km';
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

  // ================================================================
  // CANCEL REQUEST
  // ================================================================

  Future<void> _cancelRequest() async {
    if (_isCancelling) return;

    if (!mounted) return;

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
      debugPrint('Error cancelling request: $e');

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
          backgroundColor: const Color(0xFF1A1D20),
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
                  color: Color(0xFFF6E900),
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
        backgroundColor: const Color(0xFF24282D),
      ),
    );
  }

  // ================================================================
  // DISPOSE
  // ================================================================

  @override
  void dispose() {
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
      backgroundColor: const Color(0xFF101214),
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
      color: const Color(0xFF08090A),
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
    LatLng location = _defaultLocation;

    if (_currentPosition != null) {
      location = LatLng(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
    }

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
        color: Colors.black.withOpacity(0.45),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFFF6E900)),
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
          color: const Color(0xFF171C20),
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
              _isTracking ? 'LIVE LOCATION' : 'LOCATION OFF',
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
  // MY LOCATION BUTTON
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
            color: const Color(0xFF171C20),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(
            Icons.my_location_rounded,
            color: Color(0xFFF6E900),
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
        color: Color(0xFF171C20),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(26),
          topRight: Radius.circular(26),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ----------------------------------------------------------
          // HANDLE
          // ----------------------------------------------------------

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

          // ----------------------------------------------------------
          // ASSISTANCE STATUS
          // ----------------------------------------------------------
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFF6E900).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.support_agent,
                  color: Color(0xFFF6E900),
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

          // ----------------------------------------------------------
          // ISSUE
          // ----------------------------------------------------------
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF08090A),
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

          // ----------------------------------------------------------
          // DRIVER LOCATION SHARING
          // ----------------------------------------------------------
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
          // PROVIDER LIVE LOCATION
          // ----------------------------------------------------------
          if (_providerLatitude != null && _providerLongitude != null) ...[
            const SizedBox(height: 14),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF08090A),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(
                          Icons.support_agent,
                          color: Colors.redAccent,
                          size: 21,
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _providerName?.isNotEmpty == true
                                  ? _providerName!
                                  : 'Roadside Assistance Provider',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),

                            const SizedBox(height: 3),

                            const Text(
                              'Live location',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      const Icon(
                        Icons.route_rounded,
                        color: Color(0xFFF6E900),
                        size: 19,
                      ),

                      const SizedBox(width: 8),

                      Text(
                        _formatDistance(_currentDistance),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),

                      const SizedBox(width: 10),

                      Expanded(
                        child: Text(
                          _distanceStatus,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 18),

          if ((_status == 'accepted' || _status == 'in_progress') &&
              _requestData?['providerId']?.toString().isNotEmpty == true) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _openProviderChat,
                icon: const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Chat with provider'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFF6E900),
                  side: const BorderSide(color: Color(0xFF394149)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // ----------------------------------------------------------
          // CANCEL BUTTON
          // ----------------------------------------------------------
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

  void _openProviderChat() {
    final Map<String, dynamic>? requestData = _requestData;
    final String? ownerId = widget.userData['uid']?.toString();
    if (requestData == null || ownerId == null || ownerId.isEmpty) {
      _showMessage('Could not identify your account for chat.');
      return;
    }

    final String providerId = requestData['providerId']?.toString() ?? '';
    if (providerId.isEmpty) {
      _showMessage('The provider is not available for chat yet.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          backgroundColor: const Color(0xFF08090A),
          body: SafeArea(
            child: ProviderChatView(
              requestId: widget.requestId,
              providerId: ownerId,
              providerName: widget.userData['name']?.toString() ?? 'Customer',
              requestData: requestData,
              chatTitle: 'Chat with provider',
              onBack: () => Navigator.pop(context),
              onError: _showMessage,
            ),
          ),
        ),
      ),
    );
  }

  // ================================================================
  // STATUS TEXT
  // ================================================================

  String _getStatusText() {
    switch (_status) {
      case 'pending':
        return 'Searching for a roadside provider...';

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
