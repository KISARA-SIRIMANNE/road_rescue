import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'assistance_tracking_page.dart';
import '../../services/insurance_company.dart';

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

class _LocationConfirmationPageState extends State<LocationConfirmationPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  GoogleMapController? _mapController;

  StreamSubscription<Position>? _positionSubscription;

  Position? _currentPosition;

  bool _isLoading = true;
  bool _isCreatingRequest = false;

  // Insurance claim details
  bool _isInsuranceClaim = false;

  final TextEditingController _policyNumberController = TextEditingController();

  final TextEditingController _insuranceDescriptionController =
      TextEditingController();
  String? _selectedInsuranceCompanyId;

  bool _isLocationServiceEnabled = true;
  bool _hasLocationPermission = false;

  String? _errorMessage;

  final Set<Marker> _markers = {};

  bool _hasCenteredOnInitialLocation = false;

  @override
  void initState() {
    super.initState();
    _selectedInsuranceCompanyId = widget.userData['_selectedInsuranceCompanyId']
        ?.toString();
    _initializeLocation();
  }

  // ================================================================
  // INITIALIZE LOCATION
  // ================================================================

  Future<void> _initializeLocation() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;

        setState(() {
          _isLocationServiceEnabled = false;
          _isLoading = false;
          _errorMessage = 'Location services are disabled. Please enable GPS.';
        });

        return;
      }

      _isLocationServiceEnabled = true;

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;

        setState(() {
          _hasLocationPermission = false;
          _isLoading = false;
          _errorMessage = 'Location permission is required to continue.';
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

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      if (!mounted) return;

      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });

      _updateUserMarker(position);

      await _centerOnInitialLocation(position);

      _startLocationStream();
    } on TimeoutException {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Location request timed out. '
            'Make sure GPS is enabled and try again.';
      });
    } on LocationServiceDisabledException {
      if (!mounted) return;

      setState(() {
        _isLocationServiceEnabled = false;
        _isLoading = false;
        _errorMessage = 'Location services are disabled. Please enable GPS.';
      });
    } on PermissionDeniedException {
      if (!mounted) return;

      setState(() {
        _hasLocationPermission = false;
        _isLoading = false;
        _errorMessage =
            'Location permission was denied. '
            'Allow it in app settings.';
      });
    } catch (e) {
      debugPrint('Current location error: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Unable to get your current location. '
            'Check GPS and app location permission, then try again.';
      });
    }
  }

  // ================================================================
  // LOCATION STREAM
  // ================================================================

  void _startLocationStream() {
    _positionSubscription?.cancel();

    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen(
          (position) {
            if (!mounted || !_isValidPosition(position)) return;

            setState(() {
              _currentPosition = position;
            });

            _updateUserMarker(position);

            if (!_hasCenteredOnInitialLocation) {
              _centerOnInitialLocation(position);
            }
          },
          onError: (Object error) {
            debugPrint('Location stream error: $error');
          },
        );
  }

  bool _isValidPosition(Position position) {
    return position.latitude.isFinite &&
        position.longitude.isFinite &&
        position.latitude >= -90 &&
        position.latitude <= 90 &&
        position.longitude >= -180 &&
        position.longitude <= 180;
  }

  // ================================================================
  // USER MARKER
  // ================================================================

  void _updateUserMarker(Position position) {
    if (!mounted || !_isValidPosition(position)) return;

    final LatLng location = LatLng(position.latitude, position.longitude);

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

  Future<void> _moveCameraToPosition(Position position) async {
    if (_mapController == null) return;

    final LatLng location = LatLng(position.latitude, position.longitude);

    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: location, zoom: 17),
      ),
    );
  }

  Future<void> _centerOnInitialLocation(Position position) async {
    if (_hasCenteredOnInitialLocation) return;

    _hasCenteredOnInitialLocation = true;

    await _moveCameraToPosition(position);
  }

  // ================================================================
  // MAP CREATED
  // ================================================================

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;

    if (_currentPosition != null) {
      _moveCameraToPosition(_currentPosition!);
    }
  }

  // ================================================================
  // CONFIRM LOCATION
  // ================================================================

  Future<void> _confirmLocation() async {
    // --------------------------------------------------------------
    // 1. Check current location
    // --------------------------------------------------------------

    if (_currentPosition == null) {
      _showMessage('Your current location has not been detected yet.');
      return;
    }

    // Prevent duplicate requests
    if (_isCreatingRequest) return;

    // --------------------------------------------------------------
    // 2. Validate insurance claim fields
    // --------------------------------------------------------------

    if (_isInsuranceClaim) {
      if (insuranceCompanyById(_selectedInsuranceCompanyId) == null) {
        _showMessage('Please select your insurance company.');
        return;
      }

      if (_policyNumberController.text.trim().isEmpty) {
        _showMessage('Please enter your policy number.');
        return;
      }

      if (_insuranceDescriptionController.text.trim().isEmpty) {
        _showMessage('Please describe the insurance claim.');
        return;
      }
    }

    // --------------------------------------------------------------
    // 3. Start loading
    // --------------------------------------------------------------

    if (!mounted) return;

    setState(() {
      _isCreatingRequest = true;
    });

    try {
      // ------------------------------------------------------------
      // 4. Get user ID
      // ------------------------------------------------------------

      final String? userId = widget.userData['uid']?.toString();

      if (userId == null || userId.trim().isEmpty) {
        throw Exception('User ID could not be found.');
      }

      // ------------------------------------------------------------
      // 5. Get user name
      // ------------------------------------------------------------

      final String userName =
          widget.userData['name']?.toString().trim().isNotEmpty == true
          ? widget.userData['name'].toString().trim()
          : 'RoadRescue User';

      // ------------------------------------------------------------
      // 6. Get vehicle type
      // ------------------------------------------------------------

      final String vehicleType =
          widget.userData['vehicleType']?.toString().trim().isNotEmpty == true
          ? widget.userData['vehicleType'].toString().trim()
          : 'Vehicle';

      // ------------------------------------------------------------
      // 7. Get current position
      // ------------------------------------------------------------

      final Position position = _currentPosition!;

      // ------------------------------------------------------------
      // 8. Create assistance request
      // ------------------------------------------------------------

      final DocumentReference<Map<String, dynamic>> requestReference =
          _firestore.collection('assistance_requests').doc();

      await requestReference.set({
        // Request information
        'requestId': requestReference.id,

        // User information
        'userId': userId,
        'userName': userName,
        'vehicleType': vehicleType,

        // Assistance information
        'issueType': widget.issue,
        'status': 'pending',

        // Location information
        'latitude': position.latitude,
        'longitude': position.longitude,
        'accuracy': position.accuracy,

        'locationTimestamp': Timestamp.fromDate(position.timestamp),

        // ----------------------------------------------------------
        // Insurance claim information
        // ----------------------------------------------------------
        'insuranceClaim': _isInsuranceClaim,

        'insuranceCompanyId': _isInsuranceClaim
            ? _selectedInsuranceCompanyId
            : '',
        'insuranceCompany': _isInsuranceClaim
            ? insuranceCompanyById(_selectedInsuranceCompanyId)!.name
            : '',

        'policyNumber': _isInsuranceClaim
            ? _policyNumberController.text.trim()
            : '',

        'insuranceDescription': _isInsuranceClaim
            ? _insuranceDescriptionController.text.trim()
            : '',

        'insuranceStatus': _isInsuranceClaim ? 'pending' : 'not_required',

        // Timestamps
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // ------------------------------------------------------------
      // 9. Create notification for insurance providers
      // ------------------------------------------------------------

      if (_isInsuranceClaim) {
        try {
          final QuerySnapshot<Map<String, dynamic>> insuranceUsers =
              await _firestore
                  .collection('users')
                  .where('role', isEqualTo: 'insurance_provider')
                  .where(
                    'insuranceCompanyId',
                    isEqualTo: _selectedInsuranceCompanyId,
                  )
                  .get();

          if (insuranceUsers.docs.isNotEmpty) {
            final WriteBatch batch = _firestore.batch();

            for (final QueryDocumentSnapshot<Map<String, dynamic>> insuranceUser
                in insuranceUsers.docs) {
              final DocumentReference<Map<String, dynamic>>
              notificationReference = _firestore
                  .collection('notifications')
                  .doc('new_claim_${requestReference.id}_${insuranceUser.id}');

              batch.set(notificationReference, {
                'userId': insuranceUser.id,

                'title': 'New Insurance Claim',

                'message':
                    'A new insurance claim from '
                    '$userName requires verification.',

                'type': 'new_claim',

                'claimId': requestReference.id,

                'requestId': requestReference.id,

                'read': false,

                'isRead': false,

                'createdAt': FieldValue.serverTimestamp(),
              });
            }

            await batch.commit();
          }
        } on FirebaseException catch (e) {
          // Notification failure should NOT
          // cancel the assistance request.

          debugPrint(
            'Insurance notification error: '
            '${e.code} - ${e.message}',
          );
        } catch (e) {
          debugPrint('Unexpected insurance notification error: $e');
        }
      }

      // ------------------------------------------------------------
      // 10. Check mounted
      // ------------------------------------------------------------

      if (!mounted) return;

      // ------------------------------------------------------------
      // 11. Navigate to tracking page
      // ------------------------------------------------------------

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

      debugPrint('Firebase error: ${e.code} - ${e.message}');

      _showMessage(e.message ?? 'Failed to create assistance request.');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isCreatingRequest = false;
      });

      debugPrint('Create assistance request error: $e');

      _showMessage('Something went wrong while creating your request.');
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
    _positionSubscription?.cancel();

    _policyNumberController.dispose();
    _insuranceDescriptionController.dispose();

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

                  if (_isLoading) _buildLoadingOverlay(),

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
    final Position? position = _currentPosition;

    if (position == null) {
      return const ColoredBox(color: Color(0xFF101214));
    }

    final LatLng initialLocation = LatLng(
      position.latitude,
      position.longitude,
    );

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: initialLocation, zoom: 15),
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
        color: Colors.black.withValues(alpha: 0.45),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFFF6E900)),
              SizedBox(height: 16),
              Text(
                'Finding your location...',
                style: TextStyle(color: Colors.white, fontSize: 14),
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
    final bool serviceDisabled = !_isLocationServiceEnabled;

    final bool permissionDenied = !_hasLocationPermission;

    return Positioned.fill(
      child: Container(
        color: const Color(0xFF05090B).withValues(alpha: 0.90),
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
                    color: const Color(0xFFF6E900).withValues(alpha: 0.12),
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
                  _errorMessage ?? 'We need your location to continue.',
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
                      backgroundColor: const Color(0xFFF6E900),
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      serviceDisabled
                          ? 'Enable Location'
                          : permissionDenied
                          ? 'Open Settings'
                          : 'Try Again',
                      style: const TextStyle(fontWeight: FontWeight.bold),
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
              await _moveCameraToPosition(_currentPosition!);
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
  // INSURANCE SECTION
  // ================================================================

  Widget _buildInsuranceSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF11181C),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _isInsuranceClaim
              ? const Color(0xFFF6E900)
              : Colors.white.withValues(alpha: 0.06),
        ),
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
                  color: const Color(0xFFF6E900).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: Color(0xFFF6E900),
                ),
              ),

              const SizedBox(width: 12),

              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Insurance Claim',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Is this request related to an insurance claim?',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ],
                ),
              ),

              Switch(
                value: _isInsuranceClaim,
                activeThumbColor: const Color(0xFFF6E900),
                onChanged: (value) {
                  setState(() {
                    _isInsuranceClaim = value;
                  });
                },
              ),
            ],
          ),

          if (_isInsuranceClaim) ...[
            const SizedBox(height: 18),

            DropdownButtonFormField<String>(
              initialValue: _selectedInsuranceCompanyId,
              isExpanded: true,
              dropdownColor: const Color(0xFF191C20),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Insurance Company',
                labelStyle: TextStyle(color: Colors.white70),
                prefixIcon: Icon(
                  Icons.business_outlined,
                  color: Color(0xFFF6E900),
                ),
              ),
              hint: const Text('Select insurance company'),
              items: insuranceCompanies
                  .map(
                    (company) => DropdownMenuItem(
                      value: company.id,
                      child: Text(company.name),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedInsuranceCompanyId = value;
                });
              },
            ),

            const SizedBox(height: 12),

            _buildInsuranceTextField(
              controller: _policyNumberController,
              label: 'Policy Number',
              hint: 'Enter your policy number',
              icon: Icons.badge_outlined,
            ),

            const SizedBox(height: 12),

            _buildInsuranceTextField(
              controller: _insuranceDescriptionController,
              label: 'Claim Description',
              hint: 'Briefly describe the incident',
              icon: Icons.notes_outlined,
              maxLines: 3,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInsuranceTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(color: Colors.white60, fontSize: 13),
        hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
        prefixIcon: Icon(icon, color: const Color(0xFFF6E900), size: 20),
        filled: true,
        fillColor: const Color(0xFF101214),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
          borderSide: BorderSide(color: Color(0xFFF6E900), width: 1.3),
        ),
      ),
    );
  }

  // ================================================================
  // BOTTOM PANEL
  // ================================================================

  Widget _buildBottomPanel() {
    final bool hasLocation = _currentPosition != null;

    return Flexible(
      fit: FlexFit.loose,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          decoration: const BoxDecoration(
            color: Color(0xFF191C20),
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
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF6E900).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                  borderRadius: BorderRadius.circular(14),
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
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              _buildInsuranceSection(),

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
                  onPressed: hasLocation && !_isCreatingRequest
                      ? _confirmLocation
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFF6E900),
                    disabledBackgroundColor: Colors.white12,
                    foregroundColor: Colors.black,
                    disabledForegroundColor: Colors.white30,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _isCreatingRequest
                      ? const SizedBox(
                          width: 23,
                          height: 23,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.black,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline_rounded, size: 21),
                            SizedBox(width: 9),
                            Text(
                              'Confirm Location',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
}
