import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import 'job_status_page.dart';

class ProviderDirectionsPage extends StatefulWidget {
  final String requestId;
  final Map<String, dynamic> userData;

  const ProviderDirectionsPage({
    super.key,
    required this.requestId,
    required this.userData,
  });

  @override
  State<ProviderDirectionsPage> createState() =>
      _ProviderDirectionsPageState();
}

class _ProviderDirectionsPageState
    extends State<ProviderDirectionsPage> {
  // ============================================================
  // FIREBASE
  // ============================================================

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  // ============================================================
  // MAP
  // ============================================================

  GoogleMapController? _mapController;

  final Set<Marker> _markers = {};

  final Set<Polyline> _polylines = {};

  // ============================================================
  // STREAMS
  // ============================================================

  StreamSubscription<Position>?
      _positionSubscription;

  StreamSubscription<DocumentSnapshot>?
      _requestSubscription;

  // ============================================================
  // LOCATIONS
  // ============================================================

  Position? _providerPosition;

  double? _driverLatitude;

  double? _driverLongitude;

  // ============================================================
  // DRIVER DATA
  // ============================================================

  String _driverName = 'Vehicle Owner';

  String _vehicleType = 'Vehicle';

  String _issueType = 'Assistance';

  String _requestStatus = 'accepted';

  // ============================================================
  // ROUTE DATA
  // ============================================================

  double? _routeDistanceKm;

  int? _routeDurationMinutes;

  bool _isCalculatingRoute = false;

  bool _isLoading = true;

  bool _isOpeningDirections = false;

  bool _hasInitialCameraFit = false;

  // ============================================================
  // GOOGLE ROUTES API KEY
  // ============================================================
  //
  // Put your Routes API key here.
  //
  // Example:
  //
  // static const String _routesApiKey =
  //     'AIzaSy........................';
  //
  // ============================================================

  static const String _routesApiKey =
      'PASTE_YOUR_ROUTES_API_KEY_HERE';

  // ============================================================
  // DEFAULT MAP LOCATION
  // ============================================================

  static const LatLng _defaultLocation =
      LatLng(7.2906, 80.6337);

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _startRequestListener();

    _startProviderLocationTracking();
  }

  // ============================================================
  // REQUEST LISTENER
  // ============================================================

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
            snapshot.data()
                as Map<String, dynamic>;

        // --------------------------------------------------------
        // DRIVER LOCATION
        // --------------------------------------------------------

        final dynamic latitude =
            data['latitude'];

        final dynamic longitude =
            data['longitude'];

        if (latitude is num &&
            longitude is num) {
          _driverLatitude =
              latitude.toDouble();

          _driverLongitude =
              longitude.toDouble();
        }

        // --------------------------------------------------------
        // DRIVER INFORMATION
        // --------------------------------------------------------

        _driverName =
            data['userName']?.toString() ??
                'Vehicle Owner';

        _vehicleType =
            data['vehicleType']?.toString() ??
                'Vehicle';

        _issueType =
            data['issueType']?.toString() ??
                'Assistance';

        _requestStatus =
            data['status']?.toString() ??
                'accepted';

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }

        _updateMarkers();

        _calculateRouteIfPossible();
      },
      onError: (error) {
        debugPrint(
          'Request listener error: $error',
        );
      },
    );
  }

  // ============================================================
  // PROVIDER LOCATION TRACKING
  // ============================================================

  Future<void>
      _startProviderLocationTracking() async {
    final bool serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      debugPrint(
        'Location services are disabled.',
      );

      return;
    }

    LocationPermission permission =
        await Geolocator.checkPermission();

    if (permission ==
        LocationPermission.denied) {
      permission =
          await Geolocator.requestPermission();
    }

    if (permission ==
            LocationPermission.denied ||
        permission ==
            LocationPermission.deniedForever) {
      debugPrint(
        'Location permission denied.',
      );

      return;
    }

    try {
      // ----------------------------------------------------------
      // GET CURRENT PROVIDER LOCATION
      // ----------------------------------------------------------

      final Position position =
          await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      _providerPosition = position;

      if (mounted) {
        setState(() {});
      }

      _updateMarkers();

      await _calculateRouteIfPossible();

      // ----------------------------------------------------------
      // CONTINUE TRACKING PROVIDER
      // ----------------------------------------------------------

      const LocationSettings settings =
          LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      );

      _positionSubscription =
          Geolocator.getPositionStream(
        locationSettings: settings,
      ).listen(
        (Position position) async {
          _providerPosition = position;

          if (mounted) {
            setState(() {});
          }

          _updateMarkers();

          await _calculateRouteIfPossible();
        },
        onError: (error) {
          debugPrint(
            'Provider location stream error: $error',
          );
        },
      );
    } catch (e) {
      debugPrint(
        'Error getting provider location: $e',
      );
    }
  }

  // ============================================================
  // UPDATE MAP MARKERS
  // ============================================================

  void _updateMarkers() {
    final Set<Marker> newMarkers = {};

    // ----------------------------------------------------------
    // PROVIDER MARKER
    // ----------------------------------------------------------

    if (_providerPosition != null) {
      newMarkers.add(
        Marker(
          markerId:
              const MarkerId('provider'),
          position: LatLng(
            _providerPosition!.latitude,
            _providerPosition!.longitude,
          ),
          infoWindow:
              const InfoWindow(
            title: 'Your Location',
            snippet:
                'Roadside Assistance Provider',
          ),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueYellow,
          ),
        ),
      );
    }

    // ----------------------------------------------------------
    // DRIVER MARKER
    // ----------------------------------------------------------

    if (_driverLatitude != null &&
        _driverLongitude != null) {
      newMarkers.add(
        Marker(
          markerId:
              const MarkerId('driver'),
          position: LatLng(
            _driverLatitude!,
            _driverLongitude!,
          ),
          infoWindow:
              InfoWindow(
            title: _driverName,
            snippet:
                '$_vehicleType • $_issueType',
          ),
          icon:
              BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueRed,
          ),
        ),
      );
    }

    if (mounted) {
      setState(() {
        _markers
          ..clear()
          ..addAll(newMarkers);
      });
    }

    _fitBothLocations();
  }

  // ============================================================
  // OPEN GOOGLE MAPS DIRECTIONS
  // ============================================================

  Future<void> _openGoogleMapsDirections() async {
    // ----------------------------------------------------------
    // DRIVER LOCATION REQUIRED
    // ----------------------------------------------------------

    if (_driverLatitude == null ||
        _driverLongitude == null) {
      _showMessage(
        'Vehicle owner location is not available yet.',
      );

      return;
    }

    if (_isOpeningDirections) {
      return;
    }

    setState(() {
      _isOpeningDirections = true;
    });

    try {
      final String destination =
          '${_driverLatitude!},'
          '${_driverLongitude!}';

      Uri googleMapsUri;

      // --------------------------------------------------------
      // PROVIDER LOCATION AVAILABLE
      // --------------------------------------------------------

      if (_providerPosition != null) {
        final String origin =
            '${_providerPosition!.latitude},'
            '${_providerPosition!.longitude}';

        googleMapsUri = Uri.https(
          'www.google.com',
          '/maps/dir/',
          {
            'api': '1',
            'origin': origin,
            'destination': destination,
            'travelmode': 'driving',
          },
        );
      }

      // --------------------------------------------------------
      // PROVIDER LOCATION NOT AVAILABLE
      // --------------------------------------------------------

      else {
        googleMapsUri = Uri.https(
          'www.google.com',
          '/maps/dir/',
          {
            'api': '1',
            'destination': destination,
            'travelmode': 'driving',
          },
        );
      }

      debugPrint(
        'Opening Google Maps:',
      );

      debugPrint(
        googleMapsUri.toString(),
      );

      final bool canLaunch =
          await canLaunchUrl(
        googleMapsUri,
      );

      if (!canLaunch) {
        throw Exception(
          'Google Maps could not be opened.',
        );
      }

      await launchUrl(
        googleMapsUri,
        mode:
            LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint(
        'Error opening Google Maps: $e',
      );

      if (mounted) {
        _showMessage(
          'Could not open Google Maps.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isOpeningDirections = false;
        });
      }
    }
  }

  // ============================================================
  // OPEN JOB STATUS PAGE
  // ============================================================

  void _openJobStatusPage() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) =>
            JobStatusPage(
          requestId: widget.requestId,
          userData: widget.userData,
        ),
      ),
    );
  }

  // ============================================================
  // CALCULATE ROUTE IF POSSIBLE
  // ============================================================

  Future<void>
      _calculateRouteIfPossible() async {
    if (_providerPosition == null ||
        _driverLatitude == null ||
        _driverLongitude == null) {
      return;
    }

    if (_routesApiKey ==
        'PASTE_YOUR_ROUTES_API_KEY_HERE') {
      debugPrint(
        'Routes API key has not been configured.',
      );

      return;
    }

    if (_isCalculatingRoute) {
      return;
    }

    await _calculateRoute();
  }

  // ============================================================
  // GOOGLE ROUTES API
  // ============================================================

  Future<void> _calculateRoute() async {
    if (_providerPosition == null ||
        _driverLatitude == null ||
        _driverLongitude == null) {
      return;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _isCalculatingRoute = true;
    });

    try {
      final HttpClient client =
          HttpClient();

      final Uri uri = Uri.parse(
        'https://routes.googleapis.com/'
        'directions/v2:computeRoutes',
      );

      final HttpClientRequest request =
          await client.postUrl(uri);

      // ----------------------------------------------------------
      // HEADERS
      // ----------------------------------------------------------

      request.headers.set(
        'Content-Type',
        'application/json',
      );

      request.headers.set(
        'X-Goog-Api-Key',
        _routesApiKey,
      );

      request.headers.set(
        'X-Goog-FieldMask',
        'routes.duration,'
        'routes.distanceMeters,'
        'routes.polyline',
      );

      // ----------------------------------------------------------
      // REQUEST BODY
      // ----------------------------------------------------------

      final Map<String, dynamic> body = {
        'origin': {
          'location': {
            'latLng': {
              'latitude':
                  _providerPosition!.latitude,
              'longitude':
                  _providerPosition!.longitude,
            },
          },
        },
        'destination': {
          'location': {
            'latLng': {
              'latitude':
                  _driverLatitude!,
              'longitude':
                  _driverLongitude!,
            },
          },
        },
        'travelMode': 'DRIVE',
        'routingPreference':
            'TRAFFIC_AWARE',
        'polylineQuality':
            'OVERVIEW',
        'polylineEncoding':
            'ENCODED_POLYLINE',
      };

      request.write(
        jsonEncode(body),
      );

      // ----------------------------------------------------------
      // RESPONSE
      // ----------------------------------------------------------

      final HttpClientResponse response =
          await request.close();

      final String responseBody =
          await response
              .transform(utf8.decoder)
              .join();

      client.close();

      debugPrint(
        'Routes API status: '
        '${response.statusCode}',
      );

      if (response.statusCode != 200) {
        debugPrint(
          'Routes API error: $responseBody',
        );

        return;
      }

      final Map<String, dynamic> result =
          jsonDecode(responseBody)
              as Map<String, dynamic>;

      final List<dynamic>? routes =
          result['routes']
              as List<dynamic>?;

      if (routes == null ||
          routes.isEmpty) {
        debugPrint(
          'Routes API returned no routes.',
        );

        return;
      }

      final Map<String, dynamic> route =
          routes.first
              as Map<String, dynamic>;

      // ----------------------------------------------------------
      // DISTANCE
      // ----------------------------------------------------------

      final dynamic distanceValue =
          route['distanceMeters'];

      if (distanceValue is num) {
        _routeDistanceKm =
            distanceValue.toDouble() /
                1000;
      }

      // ----------------------------------------------------------
      // DURATION
      // ----------------------------------------------------------

      final String duration =
          route['duration']
                  ?.toString() ??
              '';

      final RegExp durationRegex =
          RegExp(
        r'(\d+(?:\.\d+)?)s',
      );

      final Match? durationMatch =
          durationRegex.firstMatch(
        duration,
      );

      if (durationMatch != null) {
        final double seconds =
            double.parse(
          durationMatch.group(1)!,
        );

        _routeDurationMinutes =
            (seconds / 60).ceil();
      }

      // ----------------------------------------------------------
      // POLYLINE
      // ----------------------------------------------------------

      final Map<String, dynamic>?
          polylineData =
          route['polyline']
              as Map<String, dynamic>?;

      final String? encodedPolyline =
          polylineData?[
                  'encodedPolyline']
              ?.toString();

      if (encodedPolyline != null &&
          encodedPolyline.isNotEmpty) {
        final List<LatLng> points =
            _decodePolyline(
          encodedPolyline,
        );

        if (mounted) {
          setState(() {
            _polylines.clear();

            _polylines.add(
              Polyline(
                polylineId:
                    const PolylineId(
                  'provider_to_driver_route',
                ),
                points: points,
                color:
                    const Color(0xFFF6E900),
                width: 6,
                jointType:
                    JointType.round,
                startCap:
                    Cap.roundCap,
                endCap:
                    Cap.roundCap,
              ),
            );
          });
        }
      }

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      debugPrint(
        'Error calculating route: $e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCalculatingRoute = false;
        });
      }
    }
  }

  // ============================================================
  // DECODE GOOGLE POLYLINE
  // ============================================================

  List<LatLng> _decodePolyline(
    String encoded,
  ) {
    final List<LatLng> points = [];

    int index = 0;

    int latitude = 0;

    int longitude = 0;

    while (index < encoded.length) {
      int shift = 0;

      int result = 0;

      int byte;

      do {
        byte =
            encoded.codeUnitAt(index++) -
                63;

        result |=
            (byte & 0x1f) << shift;

        shift += 5;
      } while (byte >= 0x20);

      final int latitudeChange =
          (result & 1) != 0
              ? ~(result >> 1)
              : (result >> 1);

      latitude += latitudeChange;

      shift = 0;

      result = 0;

      do {
        byte =
            encoded.codeUnitAt(index++) -
                63;

        result |=
            (byte & 0x1f) << shift;

        shift += 5;
      } while (byte >= 0x20);

      final int longitudeChange =
          (result & 1) != 0
              ? ~(result >> 1)
              : (result >> 1);

      longitude += longitudeChange;

      points.add(
        LatLng(
          latitude / 100000.0,
          longitude / 100000.0,
        ),
      );
    }

    return points;
  }

  // ============================================================
  // FIT CAMERA TO BOTH LOCATIONS
  // ============================================================

  Future<void> _fitBothLocations() async {
    if (_mapController == null ||
        _providerPosition == null ||
        _driverLatitude == null ||
        _driverLongitude == null) {
      return;
    }

    if (_hasInitialCameraFit) {
      return;
    }

    final double minLatitude =
        _providerPosition!.latitude <
                _driverLatitude!
            ? _providerPosition!.latitude
            : _driverLatitude!;

    final double maxLatitude =
        _providerPosition!.latitude >
                _driverLatitude!
            ? _providerPosition!.latitude
            : _driverLatitude!;

    final double minLongitude =
        _providerPosition!.longitude <
                _driverLongitude!
            ? _providerPosition!.longitude
            : _driverLongitude!;

    final double maxLongitude =
        _providerPosition!.longitude >
                _driverLongitude!
            ? _providerPosition!.longitude
            : _driverLongitude!;

    try {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(
              minLatitude,
              minLongitude,
            ),
            northeast: LatLng(
              maxLatitude,
              maxLongitude,
            ),
          ),
          80,
        ),
      );

      _hasInitialCameraFit = true;
    } catch (e) {
      debugPrint(
        'Error fitting map: $e',
      );
    }
  }

  // ============================================================
  // MAP CREATED
  // ============================================================

  void _onMapCreated(
    GoogleMapController controller,
  ) {
    _mapController = controller;

    _fitBothLocations();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFF05090B),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition:
                        const CameraPosition(
                      target:
                          _defaultLocation,
                      zoom: 8,
                    ),
                    onMapCreated:
                        _onMapCreated,
                    markers: _markers,
                    polylines: _polylines,
                    myLocationEnabled:
                        true,
                    myLocationButtonEnabled:
                        false,
                    zoomControlsEnabled:
                        false,
                    compassEnabled: true,
                    mapToolbarEnabled: false,
                  ),

                  Positioned(
                    top: 16,
                    left: 16,
                    child:
                        _buildLiveBadge(),
                  ),

                  Positioned(
                    right: 16,
                    bottom: 16,
                    child:
                        _buildLocationButton(),
                  ),
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
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.fromLTRB(
        16,
        16,
        16,
        16,
      ),
      color:
          const Color(0xFF05090B),
      child: Row(
        children: [
          IconButton(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),

          const SizedBox(width: 4),

          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Get Directions',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Navigate to the vehicle owner',
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
    );
  }

  // ============================================================
  // LIVE BADGE
  // ============================================================

  Widget _buildLiveBadge() {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 9,
      ),
      decoration: BoxDecoration(
        color:
            const Color(0xFF111719),
        borderRadius:
            BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration:
                const BoxDecoration(
              color:
                  Colors.greenAccent,
              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(width: 7),

          const Text(
            'LIVE NAVIGATION',
            style: TextStyle(
              color:
                  Colors.greenAccent,
              fontSize: 10,
              fontWeight:
                  FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // LOCATION BUTTON
  // ============================================================

  Widget _buildLocationButton() {
    return GestureDetector(
      onTap: () {
        if (_providerPosition ==
            null) {
          return;
        }

        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(
              _providerPosition!.latitude,
              _providerPosition!.longitude,
            ),
            15,
          ),
        );
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color:
              const Color(0xFF101719),
          borderRadius:
              BorderRadius.circular(16),
        ),
        child: const Icon(
          Icons.my_location_rounded,
          color:
              Color(0xFFF6E900),
          size: 23,
        ),
      ),
    );
  }

  // ============================================================
  // BOTTOM PANEL
  // ============================================================

  Widget _buildBottomPanel() {
    final bool canGetDirections =
        _driverLatitude != null &&
        _driverLongitude != null;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.fromLTRB(
        20,
        18,
        20,
        20,
      ),
      decoration: const BoxDecoration(
        color:
            Color(0xFF151A1E),
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // ======================================================
          // DRIVER INFORMATION
          // ======================================================

          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color:
                      const Color(0xFFF6E900)
                          .withOpacity(0.12),
                  borderRadius:
                      BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons
                      .directions_car_filled_rounded,
                  color:
                      Color(0xFFF6E900),
                  size: 24,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      _driverName,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 3),

                    Text(
                      '$_vehicleType • $_issueType',
                      style:
                          const TextStyle(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // ======================================================
          // ETA + DISTANCE
          // ======================================================

          Row(
            children: [
              Expanded(
                child:
                    _buildInfoCard(
                  icon:
                      Icons.timer_outlined,
                  title: 'ETA',
                  value:
                      _routeDurationMinutes !=
                              null
                          ? '${_routeDurationMinutes!} min'
                          : 'Calculating...',
                ),
              ),

              const SizedBox(width: 10),

              Expanded(
                child:
                    _buildInfoCard(
                  icon:
                      Icons.route_outlined,
                  title: 'DISTANCE',
                  value:
                      _routeDistanceKm !=
                              null
                          ? '${_routeDistanceKm!.toStringAsFixed(1)} km'
                          : 'Calculating...',
                ),
              ),
            ],
          ),

          const SizedBox(height: 13),

          // ======================================================
          // STATUS
          // ======================================================

          Row(
            children: [
              const Icon(
                Icons.navigation_rounded,
                color:
                    Colors.greenAccent,
                size: 17,
              ),

              const SizedBox(width: 8),

              Expanded(
                child: Text(
                  _isCalculatingRoute
                      ? 'Calculating the best route to the driver...'
                      : _routeDistanceKm !=
                                  null
                          ? 'Follow the highlighted route to the driver.'
                          : canGetDirections
                              ? 'Driver location is ready.'
                              : 'Waiting for location data...',
                  style:
                      const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          // ======================================================
          // GET DIRECTIONS BUTTON
          // ======================================================

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed:
                  canGetDirections &&
                          !_isOpeningDirections
                      ? _openGoogleMapsDirections
                      : null,

              icon: _isOpeningDirections
                  ? const SizedBox(
                      width: 19,
                      height: 19,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(
                      Icons
                          .directions_rounded,
                      size: 23,
                    ),

              label: Text(
                _isOpeningDirections
                    ? 'Opening Google Maps...'
                    : 'Get Directions',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    const Color(0xFFF6E900),
                foregroundColor:
                    Colors.black,
                disabledBackgroundColor:
                    Colors.white10,
                disabledForegroundColor:
                    Colors.white30,
                elevation: 0,
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

          const SizedBox(height: 10),

          // ======================================================
          // JOB STATUS BUTTON
          // ======================================================

          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed:
                  _openJobStatusPage,

              icon: const Icon(
                Icons.assignment_rounded,
                size: 22,
              ),

              label: const Text(
                'Job Status',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),

              style:
                  OutlinedButton.styleFrom(
                foregroundColor:
                    Colors.white,
                side:
                    const BorderSide(
                  color: Colors.white24,
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

          const SizedBox(height: 10),

          // ======================================================
          // BACK BUTTON
          // ======================================================

          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style:
                  OutlinedButton.styleFrom(
                foregroundColor:
                    Colors.white,
                side:
                    const BorderSide(
                  color: Colors.white24,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
              ),
              child: const Text(
                'Back',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFO CARD
  // ============================================================

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            const Color(0xFF05090B),
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color:
                const Color(0xFFF6E900),
            size: 22,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style:
                      const TextStyle(
                    color: Colors.white38,
                    fontSize: 9,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  value,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight:
                        FontWeight.bold,
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
  // SHOW MESSAGE
  // ============================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
        behavior:
            SnackBarBehavior.floating,
        backgroundColor:
            const Color(0xFF151D21),
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

    _mapController = null;

    super.dispose();
  }
}