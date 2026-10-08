import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'assistance_tracking_page.dart';

class LocationConfirmationPage extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String issue;

  const LocationConfirmationPage({
    super.key,
    required this.userData,
    required this.issue,
  });

  @override
  State<LocationConfirmationPage> createState() =>
      _LocationConfirmationPageState();
}

class _LocationConfirmationPageState
    extends State<LocationConfirmationPage> {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  GoogleMapController? _mapController;

  StreamSubscription<Position>? _positionSubscription;

  Position? _currentPosition;

  bool _isLoading = true;
  bool _isCreatingRequest = false;

  bool _isLocationServiceEnabled = true;
  bool _hasLocationPermission = false;

  String? _errorMessage;

  final Set<Marker> _markers = {};

  static const LatLng _defaultLocation = LatLng(
    6.9271,
    79.8612,
  );

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  // ================================================================
  // INITIALIZE LOCATION
  // ================================================================

  Future<void> _initializeLocation() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bool serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;

        setState(() {
          _isLocationServiceEnabled = false;
          _isLoading = false;
          _errorMessage =
              'Location services are disabled. Please enable GPS.';
        });

        return;
      }

      _isLocationServiceEnabled = true;

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;

        setState(() {
          _hasLocationPermission = false;
          _isLoading = false;
          _errorMessage =
              'Location permission is required to continue.';
        });

        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;

        setState(() {
          _hasLocationPermission = false;
          _isLoading = false;
          _errorMessage =
              'Location permission is permanently denied. '
              'Please enable it from device settings.';
        });

        return;
      }

      _hasLocationPermission = true;

      final Position position =
          await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });

      _updateUserMarker(position);

      await _moveCameraToPosition(position);

      // We only start the local GPS stream here.
      // Firestore tracking starts after the user confirms
      // the assistance request.
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Unable to get your current location.';
      });
    }
  }

  // ================================================================
  // USER MARKER
  // ================================================================

  void _updateUserMarker(Position position) {
    final LatLng location = LatLng(
      position.latitude,
      position.longitude,
    );

    setState(() {
      _markers
        ..clear()
        ..add(
          Marker(
            markerId: const MarkerId('user_location'),
            position: location,
            infoWindow: const InfoWindow(
              title: 'Your Location',
              snippet: 'Current breakdown location',
            ),
          ),
        );
    });
  }

  // ================================================================
  // MAP CAMERA
  // ================================================================

  Future<void> _moveCameraToPosition(
    Position position,
  ) async {
    if (_mapController == null) return;

    final LatLng location = LatLng(
      position.latitude,
      position.longitude,
    );

    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: location,
          zoom: 17,
        ),
      ),
    );
  }

  // ================================================================
  // MAP CREATED
  // ================================================================

  void _onMapCreated(
    GoogleMapController controller,
  ) {
    _mapController = controller;

    if (_currentPosition != null) {
      _moveCameraToPosition(_currentPosition!);
    }
  }

  // ================================================================
  // CONFIRM LOCATION
  // ================================================================

  Future<void> _confirmLocation() async {
    if (_currentPosition == null) {
      _showMessage(
        'Your current location has not been detected yet.',
      );

      return;
    }

    if (_isCreatingRequest) return;

    setState(() {
      _isCreatingRequest = true;
    });

    try {
      final String? userId =
          widget.userData['uid']?.toString();

      if (userId == null || userId.isEmpty) {
        throw Exception(
          'User ID could not be found.',
        );
      }

      final String userName =
          widget.userData['name']?.toString() ??
              'RoadRescue User';

      final String vehicleType =
          widget.userData['vehicleType']?.toString() ??
              'Vehicle';

      final DocumentReference requestReference =
          _firestore
              .collection('assistance_requests')
              .doc();

      await requestReference.set({
        'requestId': requestReference.id,
        'userId': userId,
        'userName': userName,
        'vehicleType': vehicleType,
        'issueType': widget.issue,
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      // Move to the tracking page.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => AssistanceTrackingPage(
            requestId: requestReference.id,
            userData: widget.userData,
            issue: widget.issue,
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      setState(() {
        _isCreatingRequest = false;
      });

      _showMessage(
        e.message ?? 'Failed to create assistance request.',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isCreatingRequest = false;
      });

      _showMessage(
        'Something went wrong while creating your request.',
      );
    }
  }

  // ================================================================
  // SETTINGS
  // ================================================================

  Future<void> _openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  Future<void> _openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  // ================================================================
  // SNACKBAR
  // ================================================================

  void _showMessage(String message) {
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
    _positionSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  // ================================================================
  // BUILD
  // ================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF05090B),
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),

            Expanded(
              child: Stack(
                children: [
                  _buildMap(),

                  if (_isLoading)
                    _buildLoadingOverlay(),

                  if (!_isLoading && _errorMessage != null)
                    _buildLocationError(),

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
      color: const Color(0xFF05090B),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 20,
            ),
          ),
          const Expanded(
            child: Text(
              'Confirm Your Location',
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
  // GOOGLE MAP
  // ================================================================

  Widget _buildMap() {
    LatLng initialLocation = _defaultLocation;

    if (_currentPosition != null) {
      initialLocation = LatLng(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: initialLocation,
        zoom: 15,
      ),
      onMapCreated: _onMapCreated,
      markers: _markers,
      myLocationEnabled: _hasLocationPermission,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: true,
      mapToolbarEnabled: false,
      buildingsEnabled: true,
      indoorViewEnabled: false,
      trafficEnabled: false,
    );
  }

  // ================================================================
  // LOADING
  // ================================================================

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.45),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: Color(0xFFF6E900),
              ),
              SizedBox(height: 16),
              Text(
                'Finding your location...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ================================================================
  // LOCATION ERROR
  // ================================================================

  Widget _buildLocationError() {
    final bool serviceDisabled =
        !_isLocationServiceEnabled;

    final bool permissionDenied =
        !_hasLocationPermission;

    return Positioned.fill(
      child: Container(
        color: const Color(0xFF05090B).withOpacity(0.90),
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF11181C),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6E900)
                        .withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_off_rounded,
                    color: Color(0xFFF6E900),
                    size: 32,
                  ),
                ),

                const SizedBox(height: 18),

                const Text(
                  'Location Required',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  _errorMessage ??
                      'We need your location to continue.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white60,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: serviceDisabled
                        ? _openLocationSettings
                        : permissionDenied
                            ? _openAppSettings
                            : _initializeLocation,
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          const Color(0xFFF6E900),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      serviceDisabled
                          ? 'Enable Location'
                          : permissionDenied
                              ? 'Open Settings'
                              : 'Try Again',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            if (_currentPosition != null) {
              await _moveCameraToPosition(
                _currentPosition!,
              );
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF11181C),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.my_location_rounded,
              color: Color(0xFFF6E900),
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  // ================================================================
  // BOTTOM PANEL
  // ================================================================

  Widget _buildBottomPanel() {
    final bool hasLocation =
        _currentPosition != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        20,
        18,
        20,
        20,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF11181C),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(26),
          topRight: Radius.circular(26),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius:
                    BorderRadius.circular(20),
              ),
            ),
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFF6E900)
                      .withOpacity(0.12),
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: Color(0xFFF6E900),
                  size: 25,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Current Location',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      hasLocation
                          ? 'Location detected'
                          : 'Detecting location...',
                      style: TextStyle(
                        color: hasLocation
                            ? Colors.greenAccent
                            : Colors.white54,
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
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF05090B),
              borderRadius:
                  BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.build_circle_outlined,
                  color: Colors.white54,
                  size: 20,
                ),

                const SizedBox(width: 10),

                const Text(
                  'Issue:',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
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
                    overflow:
                        TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          const Text(
            'Your location will be shared with a roadside assistance provider so they can find you.',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 12,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: hasLocation &&
                      !_isCreatingRequest
                  ? _confirmLocation
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFFF6E900),
                disabledBackgroundColor:
                    Colors.white12,
                foregroundColor: Colors.black,
                disabledForegroundColor:
                    Colors.white30,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(16),
                ),
              ),
              child: _isCreatingRequest
                  ? const SizedBox(
                      width: 23,
                      height: 23,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.black,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 21,
                        ),
                        SizedBox(width: 9),
                        Text(
                          'Confirm Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                FontWeight.bold,
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
}