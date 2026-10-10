import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:road_rescue/theme/road_rescue_theme.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../messaging/assistance_chat_page.dart';
import 'driver_job_status_page.dart';
import 'insurance_claim_result_page.dart';

class ProviderTrackingPage extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> userData;
  final String issue;
  final String providerName;

  const ProviderTrackingPage({
    super.key,
    required this.requestId,
    required this.userData,
    required this.issue,
    required this.providerName,
  });

  @override
  State<ProviderTrackingPage> createState() => _ProviderTrackingPageState();
}

class _ProviderTrackingPageState extends State<ProviderTrackingPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // GOOGLE ROUTES API
  // ============================================================

  static const String _routesApiKey = String.fromEnvironment('ROUTES_API_KEY');

  static const String _routesEndpoint =
      'https://routes.googleapis.com/directions/v2:computeRoutes';

  // ============================================================
  // MAP / STREAMS
  // ============================================================

  GoogleMapController? _mapController;

  StreamSubscription<DocumentSnapshot>? _requestSubscription;

  StreamSubscription<Position>? _positionSubscription;

  Position? _currentPosition;

  double? _providerLatitude;
  double? _providerLongitude;

  // ============================================================
  // ROUTE INFORMATION
  // ============================================================

  final Set<Polyline> _polylines = {};

  String _routeEta = 'Calculating...';

  double? _routeDistanceMeters;

  bool _isRouteLoading = false;

  DateTime? _lastRouteRequestTime;

  double? _lastRouteDriverLatitude;
  double? _lastRouteDriverLongitude;

  double? _lastRouteProviderLatitude;
  double? _lastRouteProviderLongitude;

  bool _routeRequestInProgress = false;

  // Minimum distance provider must move before another
  // route request is allowed.
  static const double _routeUpdateDistanceMeters = 150;

  // Minimum time between route API requests.
  static const Duration _routeUpdateInterval = Duration(seconds: 15);

  // ============================================================
  // REQUEST STATE
  // ============================================================

  bool _isLoading = true;

  bool _isCancelling = false;

  bool _hasNavigatedToDriverJobStatus = false;
  bool _hasNavigatedToInsuranceResult = false;

  final Set<Marker> _markers = {};

  static const LatLng _defaultLocation = LatLng(6.9271, 79.8612);

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _startDriverLocationTracking();
    _startRequestListener();

    if (_routesApiKey.isEmpty) {
      debugPrint('WARNING: ROUTES_API_KEY was not provided.');
    }
  }

  // ============================================================
  // DRIVER LOCATION
  // ============================================================

  Future<void> _startDriverLocationTracking() async {
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
        _showMessage('Location permission is required for tracking.');

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }

        return;
      }

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        _currentPosition = position;
        _isLoading = false;
      });

      _updateDriverMarker(position);

      await _updateDriverLocation(position);

      await _requestRouteUpdate(force: true);

      await _moveCameraToDriver();

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

              _updateDriverMarker(position);

              await _updateDriverLocation(position);

              await _requestRouteUpdate();
            },
            onError: (error) {
              debugPrint('Driver location stream error: $error');
            },
          );
    } catch (e) {
      debugPrint('Error starting driver location: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage('Unable to start live location tracking.');
    }
  }

  // ============================================================
  // UPDATE DRIVER LOCATION IN FIRESTORE
  // ============================================================

  Future<void> _updateDriverLocation(Position position) async {
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
      debugPrint('Failed to update driver location: $e');
    }
  }

  // ============================================================
  // FIRESTORE REQUEST LISTENER
  // ============================================================

  void _startRequestListener() {
    _requestSubscription?.cancel();

    _requestSubscription = _firestore
        .collection('assistance_requests')
        .doc(widget.requestId)
        .snapshots()
        .listen(
          (DocumentSnapshot snapshot) async {
            if (!snapshot.exists) {
              return;
            }

            final Map<String, dynamic> data =
                snapshot.data() as Map<String, dynamic>;

            final String status = data['status']?.toString() ?? 'accepted';

            double? providerLatitude;
            double? providerLongitude;

            if (data['providerLatitude'] != null) {
              providerLatitude = (data['providerLatitude'] as num).toDouble();
            }

            if (data['providerLongitude'] != null) {
              providerLongitude = (data['providerLongitude'] as num).toDouble();
            }

            if (!mounted) {
              return;
            }

            final String insuranceStatus =
                data['insuranceStatus']?.toString().toLowerCase() ?? '';
            if (data['insuranceClaim'] == true &&
                (insuranceStatus == 'approved' ||
                    insuranceStatus == 'rejected')) {
              await _navigateToInsuranceResult(data);
              return;
            }

            setState(() {
              _providerLatitude = providerLatitude;
              _providerLongitude = providerLongitude;
            });

            // Update provider marker.
            _updateProviderMarker();

            // Update straight-line distance.

            // ========================================================
            // PROVIDER HAS ARRIVED
            // ========================================================
            //
            // Provider side changes:
            //
            //     status = "arrived"
            //
            // Firestore sends that change to this page immediately.
            // We then move the driver to DriverJobStatusPage.
            // ========================================================

            if (status == 'arrived' && !_hasNavigatedToDriverJobStatus) {
              _hasNavigatedToDriverJobStatus = true;

              debugPrint(
                'Provider has arrived. '
                'Navigating driver to Job Status page.',
              );

              // Stop driver's GPS tracking.
              await _stopTracking();

              // Stop listening to the request because we are
              // leaving this page.
              await _requestSubscription?.cancel();

              _requestSubscription = null;

              if (!mounted) {
                return;
              }

              _navigateToDriverJobStatus(data);

              return;
            }

            // ========================================================
            // UPDATE ROAD ROUTE
            // ========================================================

            await _requestRouteUpdate();
          },
          onError: (error) {
            debugPrint('Request tracking listener error: $error');
          },
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
  // ============================================================
  // NAVIGATE TO DRIVER JOB STATUS
  // ============================================================

  void _navigateToDriverJobStatus(Map<String, dynamic> requestData) {
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => DriverJobStatusPage(
          requestId: widget.requestId,
          userData: widget.userData,
          issue: widget.issue,
        ),
      ),
    );
  }

  // ============================================================
  // ROUTES API
  // ============================================================

  Future<void> _requestRouteUpdate({bool force = false}) async {
    if (_currentPosition == null ||
        _providerLatitude == null ||
        _providerLongitude == null) {
      return;
    }

    if (_routesApiKey.isEmpty) {
      debugPrint('Routes API key is missing.');
      return;
    }

    if (_routeRequestInProgress) {
      return;
    }

    final double driverLat = _currentPosition!.latitude;

    final double driverLng = _currentPosition!.longitude;

    final double providerLat = _providerLatitude!;

    final double providerLng = _providerLongitude!;

    final DateTime now = DateTime.now();

    // ----------------------------------------------------------
    // Check time threshold
    // ----------------------------------------------------------

    if (!force &&
        _lastRouteRequestTime != null &&
        now.difference(_lastRouteRequestTime!) < _routeUpdateInterval) {
      return;
    }

    // ----------------------------------------------------------
    // Check movement threshold
    // ----------------------------------------------------------

    if (!force &&
        _lastRouteDriverLatitude != null &&
        _lastRouteDriverLongitude != null &&
        _lastRouteProviderLatitude != null &&
        _lastRouteProviderLongitude != null) {
      final double driverMovement = Geolocator.distanceBetween(
        _lastRouteDriverLatitude!,
        _lastRouteDriverLongitude!,
        driverLat,
        driverLng,
      );

      final double providerMovement = Geolocator.distanceBetween(
        _lastRouteProviderLatitude!,
        _lastRouteProviderLongitude!,
        providerLat,
        providerLng,
      );

      if (driverMovement < _routeUpdateDistanceMeters &&
          providerMovement < _routeUpdateDistanceMeters) {
        return;
      }
    }

    _routeRequestInProgress = true;

    if (mounted) {
      setState(() {
        _isRouteLoading = true;
      });
    }

    try {
      final HttpClient client = HttpClient();

      try {
        final HttpClientRequest request = await client.postUrl(
          Uri.parse(_routesEndpoint),
        );

        request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');

        request.headers.set('X-Goog-Api-Key', _routesApiKey);

        request.headers.set(
          'X-Goog-FieldMask',
          'routes.duration,routes.distanceMeters,routes.polyline',
        );

        final Map<String, dynamic> body = {
          'origin': {
            'location': {
              'latLng': {'latitude': driverLat, 'longitude': driverLng},
            },
          },
          'destination': {
            'location': {
              'latLng': {'latitude': providerLat, 'longitude': providerLng},
            },
          },
          'travelMode': 'DRIVE',
          'routingPreference': 'TRAFFIC_AWARE',
          'polylineQuality': 'OVERVIEW',
          'polylineEncoding': 'ENCODED_POLYLINE',
        };

        request.write(jsonEncode(body));

        final HttpClientResponse response = await request.close();

        final String responseBody = await response
            .transform(utf8.decoder)
            .join();

        debugPrint('Routes API status: ${response.statusCode}');

        if (response.statusCode != 200) {
          debugPrint('Routes API error: $responseBody');

          return;
        }

        final Map<String, dynamic> json =
            jsonDecode(responseBody) as Map<String, dynamic>;

        final List<dynamic>? routes = json['routes'] as List<dynamic>?;

        if (routes == null || routes.isEmpty) {
          debugPrint('Routes API returned no routes.');
          return;
        }

        final Map<String, dynamic> route = routes.first as Map<String, dynamic>;

        final int distanceMeters =
            (route['distanceMeters'] as num?)?.toInt() ?? 0;

        final String duration = route['duration']?.toString() ?? '0s';

        final Map<String, dynamic> polyline =
            route['polyline'] as Map<String, dynamic>? ?? {};

        final String? encodedPolyline = polyline['encodedPolyline']?.toString();

        if (encodedPolyline == null || encodedPolyline.isEmpty) {
          debugPrint('Routes API returned no polyline.');
          return;
        }

        final List<LatLng> routePoints = _decodePolyline(encodedPolyline);

        if (routePoints.isEmpty) {
          debugPrint('Unable to decode route polyline.');
          return;
        }

        final int durationSeconds = _parseDurationSeconds(duration);

        final String eta = _formatEta(durationSeconds);

        if (!mounted) return;

        setState(() {
          _routeDistanceMeters = distanceMeters.toDouble();

          _routeEta = eta;

          _polylines.clear();

          _polylines.add(
            Polyline(
              polylineId: const PolylineId('provider_route'),
              points: routePoints,
              color: RoadRescueColors.accent,
              width: 6,
              jointType: JointType.round,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
            ),
          );
        });

        _lastRouteRequestTime = now;

        _lastRouteDriverLatitude = driverLat;

        _lastRouteDriverLongitude = driverLng;

        _lastRouteProviderLatitude = providerLat;

        _lastRouteProviderLongitude = providerLng;

        await _fitBothLocations();
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('Routes API request failed: $e');
    } finally {
      _routeRequestInProgress = false;

      if (mounted) {
        setState(() {
          _isRouteLoading = false;
        });
      }
    }
  }

  // ============================================================
  // POLYLINE DECODER
  // ============================================================

  List<LatLng> _decodePolyline(String encoded) {
    final List<LatLng> points = [];

    int index = 0;
    int latitude = 0;
    int longitude = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;

      while (true) {
        if (index >= encoded.length) {
          return points;
        }

        final int byte = encoded.codeUnitAt(index++) - 63;

        result |= (byte & 0x1f) << shift;

        shift += 5;

        if (byte < 0x20) {
          break;
        }
      }

      final int latitudeChange = (result & 1) != 0
          ? ~(result >> 1)
          : (result >> 1);

      latitude += latitudeChange;

      shift = 0;
      result = 0;

      while (true) {
        if (index >= encoded.length) {
          return points;
        }

        final int byte = encoded.codeUnitAt(index++) - 63;

        result |= (byte & 0x1f) << shift;

        shift += 5;

        if (byte < 0x20) {
          break;
        }
      }

      final int longitudeChange = (result & 1) != 0
          ? ~(result >> 1)
          : (result >> 1);

      longitude += longitudeChange;

      points.add(LatLng(latitude / 1e5, longitude / 1e5));
    }

    return points;
  }

  // ============================================================
  // DURATION
  // ============================================================

  int _parseDurationSeconds(String duration) {
    final String value = duration.replaceAll('s', '');

    return double.tryParse(value)?.round() ?? 0;
  }

  String _formatEta(int seconds) {
    if (seconds <= 0) {
      return 'Calculating...';
    }

    final int minutes = (seconds / 60).ceil();

    if (minutes < 1) {
      return '<1 min';
    }

    if (minutes == 1) {
      return '1 min';
    }

    return '$minutes min';
  }

  // ============================================================
  // DRIVER MARKER
  // ============================================================

  void _updateDriverMarker(Position position) {
    final LatLng location = LatLng(position.latitude, position.longitude);

    if (!mounted) return;

    setState(() {
      _markers.removeWhere(
        (marker) => marker.markerId.value == 'vehicle_owner',
      );

      _markers.add(
        Marker(
          markerId: const MarkerId('vehicle_owner'),
          position: location,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: const InfoWindow(
            title: 'Your Location',
            snippet: 'Live location',
          ),
        ),
      );
    });
  }

  // ============================================================
  // PROVIDER MARKER
  // ============================================================

  void _updateProviderMarker() {
    if (_providerLatitude == null || _providerLongitude == null) {
      return;
    }

    final LatLng providerLocation = LatLng(
      _providerLatitude!,
      _providerLongitude!,
    );

    if (!mounted) return;

    setState(() {
      _markers.removeWhere(
        (marker) => marker.markerId.value == 'roadside_provider',
      );

      _markers.add(
        Marker(
          markerId: const MarkerId('roadside_provider'),
          position: providerLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: widget.providerName,
            snippet: 'Roadside assistance provider',
          ),
        ),
      );
    });
  }

  // ============================================================
  // DISTANCE
  // ============================================================

  String _formatRouteDistance() {
    if (_routeDistanceMeters == null) {
      return 'Calculating...';
    }

    if (_routeDistanceMeters! < 1000) {
      return '${_routeDistanceMeters!.round()} m';
    }

    return '${(_routeDistanceMeters! / 1000).toStringAsFixed(1)} km';
  }

  // ============================================================
  // MOVE CAMERA TO DRIVER
  // ============================================================

  Future<void> _moveCameraToDriver() async {
    if (_mapController == null || _currentPosition == null) {
      return;
    }

    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          zoom: 15,
        ),
      ),
    );
  }

  // ============================================================
  // FIT BOTH LOCATIONS
  // ============================================================

  Future<void> _fitBothLocations() async {
    if (_mapController == null ||
        _currentPosition == null ||
        _providerLatitude == null ||
        _providerLongitude == null) {
      return;
    }

    final double minLat = _currentPosition!.latitude < _providerLatitude!
        ? _currentPosition!.latitude
        : _providerLatitude!;

    final double maxLat = _currentPosition!.latitude > _providerLatitude!
        ? _currentPosition!.latitude
        : _providerLatitude!;

    final double minLng = _currentPosition!.longitude < _providerLongitude!
        ? _currentPosition!.longitude
        : _providerLongitude!;

    final double maxLng = _currentPosition!.longitude > _providerLongitude!
        ? _currentPosition!.longitude
        : _providerLongitude!;

    final LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    try {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 100),
      );
    } catch (e) {
      debugPrint('Unable to fit map bounds: $e');
    }
  }

  // ============================================================
  // MAP CREATED
  // ============================================================

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;

    if (_providerLatitude != null &&
        _providerLongitude != null &&
        _currentPosition != null) {
      _fitBothLocations();
    } else if (_currentPosition != null) {
      _moveCameraToDriver();
    }
  }

  // ============================================================
  // CANCEL REQUEST
  // ============================================================

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
      debugPrint('Cancel request error: $e');

      if (!mounted) return;

      setState(() {
        _isCancelling = false;
      });

      _showMessage('Unable to cancel the request.');
    }
  }

  // ============================================================
  // STOP TRACKING
  // ============================================================

  Future<void> _stopTracking() async {
    await _positionSubscription?.cancel();

    _positionSubscription = null;

    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // CANCEL DIALOG
  // ============================================================

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

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: RoadRescueColors.surface,
      ),
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _requestSubscription?.cancel();
    _positionSubscription?.cancel();
    _mapController?.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

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

                  if (_isRouteLoading) _buildRouteLoadingIndicator(),

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

  // ============================================================
  // TOP BAR
  // ============================================================

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
              'Track Provider',
              style: TextStyle(
                color: Colors.white,
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Message provider',
            onPressed: _openProviderChat,
            icon: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: RoadRescueColors.accent,
            ),
          ),
        ],
      ),
    );
  }

  void _openProviderChat() {
    final String driverName =
        widget.userData['name']?.toString().trim().isNotEmpty == true
        ? widget.userData['name'].toString().trim()
        : 'Driver';

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => AssistanceChatPage(
          requestId: widget.requestId,
          currentUserName: driverName,
          otherPartyName: widget.providerName,
          title: 'Chat with provider',
        ),
      ),
    );
  }

  // ============================================================
  // MAP
  // ============================================================

  Widget _buildMap() {
    LatLng location = _defaultLocation;

    if (_currentPosition != null) {
      location = LatLng(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
      );
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(target: location, zoom: 15),
      onMapCreated: _onMapCreated,
      markers: _markers,
      polylines: _polylines,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: true,
      mapToolbarEnabled: false,
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

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

  // ============================================================
  // ROUTE LOADING
  // ============================================================

  Widget _buildRouteLoadingIndicator() {
    return Positioned(
      top: 72,
      right: 18,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: RoadRescueColors.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: RoadRescueColors.accent,
              ),
            ),
            SizedBox(width: 7),
            Text(
              'Updating route',
              style: TextStyle(color: Colors.white70, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // LIVE INDICATOR
  // ============================================================

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
              decoration: const BoxDecoration(
                color: Colors.greenAccent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            const Text(
              'LIVE TRACKING',
              style: TextStyle(
                color: Colors.greenAccent,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MY LOCATION BUTTON
  // ============================================================

  Widget _buildMyLocationButton() {
    return Positioned(
      right: 18,
      bottom: 18,
      child: GestureDetector(
        onTap: _moveCameraToDriver,
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

  // ============================================================
  // BOTTOM PANEL
  // ============================================================

  Widget _buildBottomPanel() {
    final bool providerFound =
        _providerLatitude != null && _providerLongitude != null;

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
                  Icons.local_shipping,
                  color: RoadRescueColors.accent,
                  size: 27,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      providerFound ? widget.providerName : 'Roadside Provider',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      providerFound
                          ? 'Your provider is on the way'
                          : 'Waiting for provider location...',
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

          // ====================================================
          // ETA + DISTANCE
          // ====================================================
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: RoadRescueColors.background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        color: RoadRescueColors.accent,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ETA',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _routeEta,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: RoadRescueColors.background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.near_me_outlined,
                        color: Colors.greenAccent,
                        size: 21,
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'DISTANCE',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatRouteDistance(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: Colors.greenAccent,
                size: 18,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  _routeDistanceMeters != null
                      ? 'Route and provider location are updated in real time.'
                      : 'Calculating the best route to your location...',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ],
          ),

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
}