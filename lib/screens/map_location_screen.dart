import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart'; // Added for Realtime Database
import 'package:firebase_auth/firebase_auth.dart'; // Added to get user ID

class MapLocationScreen extends StatefulWidget {
  final Function(bool isInRange, double distanceToWorkLocation, double workRadius) onLocationUpdate;

  MapLocationScreen({required this.onLocationUpdate});

  @override
  _MapLocationScreenState createState() => _MapLocationScreenState();
}

class _MapLocationScreenState extends State<MapLocationScreen> {
  final MapController _mapController = MapController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _rtdb = FirebaseDatabase.instance.ref(); // Realtime Database reference
  final FirebaseAuth _auth = FirebaseAuth.instance;

  LatLng? _currentPosition;
  LatLng? _workLocation;
  double _workRadius = 100;
  double _distanceToWorkLocation = 0.0;
  bool _isLoading = true;
  StreamSubscription<Position>? _positionStreamSubscription;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _fetchWorkLocationAndRadius();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }

    Position position = await Geolocator.getCurrentPosition();
    _updateCurrentPosition(position);

    _positionStreamSubscription = Geolocator.getPositionStream().listen((position) {
      _updateCurrentPosition(position);
    });
  }

  void _updateCurrentPosition(Position position) {
    setState(() {
      _currentPosition = LatLng(position.latitude, position.longitude);
      _isLoading = false;
    });
    
    // Update location in Realtime Database
    _updateLocationInRealtimeDatabase(position);
    _checkIfInRange();
  }

  void _updateLocationInRealtimeDatabase(Position position) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final locationData = {
      'inRange': _distanceToWorkLocation <= _workRadius,
      'latitude': position.latitude,
      'longitude': position.longitude,
      'timestamp': ServerValue.timestamp,
    };

    _rtdb.child('user_locations').child(userId).set(locationData)
      .then((_) => print('Location updated in Realtime Database'))
      .catchError((error) => print('Failed to update location: $error'));
  }

  Future<void> _fetchWorkLocationAndRadius() async {
    try {
      DocumentSnapshot workLocationSnapshot =
          await _firestore.collection('settings').doc('work_location').get();
      DocumentSnapshot radiusSnapshot =
          await _firestore.collection('settings').doc('work_radius').get();

      if (workLocationSnapshot.exists && radiusSnapshot.exists) {
        setState(() {
          _workLocation = LatLng(
            workLocationSnapshot['latitude'],
            workLocationSnapshot['longitude'],
          );
          _workRadius = radiusSnapshot['radius'].toDouble();
        });
      }
    } catch (e) {
      print('Error fetching location and radius: $e');
    }
  }

  void _checkIfInRange() {
    if (_currentPosition == null || _workLocation == null) return;

    double distance = Geolocator.distanceBetween(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
      _workLocation!.latitude,
      _workLocation!.longitude,
    );

    setState(() {
      _distanceToWorkLocation = distance;
    });

    widget.onLocationUpdate(distance <= _workRadius, _distanceToWorkLocation, _workRadius);
  }

  List<LatLng> _generateWorkAreaPolygon(LatLng center, double radius) {
    List<LatLng> points = [];
    const int numPoints = 36;
    for (int i = 0; i < numPoints; i++) {
      double angle = (2 * pi * i) / numPoints;
      double dx = radius * cos(angle);
      double dy = radius * sin(angle);
      points.add(LatLng(center.latitude + (dy / 111320), center.longitude + (dx / (111320 * cos(center.latitude * pi / 180)))));
    }
    return points;
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _currentPosition ?? LatLng(0, 0),
                        initialZoom: 15.0,
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://{s}.tile.openstreetmap.fr/hot/{z}/{x}/{y}.png',
                          subdomains: ['a', 'b', 'c'],
                        ),
                        MarkerLayer(
                          markers: [
                            if (_currentPosition != null)
                              Marker(
                                point: _currentPosition!,
                                child: Icon(Icons.my_location, color: Colors.blue, size: 30),
                              ),
                            if (_workLocation != null)
                              Marker(
                                point: _workLocation!,
                                child: Icon(Icons.location_pin, color: Colors.red, size: 30),
                              ),
                          ],
                        ),
                        PolygonLayer(
                          polygons: [
                            if (_workLocation != null)
                              Polygon(
                                points: _generateWorkAreaPolygon(_workLocation!, _workRadius),
                                color: Colors.red.withOpacity(0.2),
                                borderColor: Colors.red,
                                borderStrokeWidth: 2,
                              ),
                          ],
                        ),
                      ],
                    ),
                    Positioned(
                      top: 20,
                      left: 20,
                      child: Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.work, color: Colors.blue),
                            SizedBox(width: 10),
                            Text(
                              'Work Location',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        _buildInfoRow(Icons.business, 'Work Location:',
                            _workLocation != null
                                ? 'Lat: ${_workLocation!.latitude}, Lng: ${_workLocation!.longitude}'
                                : 'Not available'),
                        Divider(),
                        _buildInfoRow(Icons.person_pin_circle, 'Your Location:',
                            _currentPosition != null
                                ? 'Lat: ${_currentPosition!.latitude}, Lng: ${_currentPosition!.longitude}'
                                : 'Not available'),
                        Divider(),
                        _buildInfoRow(Icons.location_searching, 'Distance to Work:',
                            '${_distanceToWorkLocation.toStringAsFixed(2)} meters'),
                        _buildInfoRow(Icons.circle, 'Work Radius:', '$_workRadius meters'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue),
        SizedBox(width: 10),
        Expanded(
          child: Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
        ),
        Text(value, style: TextStyle(color: Colors.black87)),
      ],
    );
  }
}