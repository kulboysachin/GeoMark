import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
// ignore: unused_import
import 'package:geolocator/geolocator.dart';
import 'face_capture_screen.dart';
import 'app_drawer.dart';
import 'map_location_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final DatabaseReference _database = FirebaseDatabase.instance.ref();

  bool _isInRange = false;
  String _attendanceStatus = 'Absent';
  bool _hasMarkedAttendance = false;
  String _dailyAttendanceKey = '';
  StreamSubscription<DatabaseEvent>? _attendanceSubscription;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _initializeDailyAttendanceKey();
    _listenForRealtimeUpdates();
  }

  @override
  void dispose() {
    _attendanceSubscription?.cancel();
    super.dispose();
  }

  void _initializeDailyAttendanceKey() {
    final now = DateTime.now();
    _dailyAttendanceKey = '${now.year}-${now.month}-${now.day}';
  }

  void _listenForRealtimeUpdates() {
    User? user = _auth.currentUser;
    if (user == null) return;

    _attendanceSubscription = _database
        .child('attendance')
        .child(_dailyAttendanceKey)
        .child(user.uid)
        .onValue
        .listen((DatabaseEvent event) {
      if (event.snapshot.exists) {
        final data = event.snapshot.value as Map<dynamic, dynamic>;
        setState(() {
          _attendanceStatus = data['status'] ?? 'Absent';
          _hasMarkedAttendance = _attendanceStatus == 'Present';
        });
      } else {
        setState(() {
          _attendanceStatus = 'Absent';
          _hasMarkedAttendance = false;
        });
      }
    });
  }

  void _onLocationUpdate(
    bool isInRange,
    double distanceToWorkLocation,
    double workRadius,
  ) {
    setState(() {
      _isInRange = isInRange;
      if (!_isInRange) {
        _updateAttendanceStatus('Absent');
      }
    });
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    await Future.delayed(Duration(seconds: 1));

    _initializeDailyAttendanceKey();
    _listenForRealtimeUpdates();

    setState(() => _isRefreshing = false);

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Data refreshed successfully!')));
  }

  void _markAttendanceWithPhoto() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FaceCaptureScreen(
          onPictureTaken: (bool isCaptured) {
            if (isCaptured) {
              _markAttendance();
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Failed to capture image!')),
              );
            }
          },
        ),
      ),
    );
  }

  Future<void> _markAttendance() async {
    if (!_isInRange || _hasMarkedAttendance) return;

    User? user = _auth.currentUser;
    if (user == null) return;

    await _database
        .child('attendance')
        .child(_dailyAttendanceKey)
        .child(user.uid)
        .set({
      'userId': user.uid,
      'timestamp': DateTime.now().toString(),
      'status': 'Present',
    });

    setState(() {
      _hasMarkedAttendance = true;
      _attendanceStatus = 'Present';
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Attendance marked successfully!')));
  }

  Future<void> _updateAttendanceStatus(String status) async {
    User? user = _auth.currentUser;
    if (user == null) return;

    await _database
        .child('attendance')
        .child(_dailyAttendanceKey)
        .child(user.uid)
        .update({'status': status});

    setState(() {
      _attendanceStatus = status;
      if (status == 'Absent') _hasMarkedAttendance = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: AppDrawer(
        user: _auth.currentUser,
        onUploadProfileImage: () {},
        onToggleTheme: () {},
        onLogout: () async {
          await _auth.signOut();
          Navigator.of(context).pushReplacementNamed('/');
        },
        profileImage: null,
      ),
      appBar: AppBar(
        title: Text('Attendance System'),
        actions: [
          IconButton(
            icon: _isRefreshing
                ? CircularProgressIndicator(color: Colors.white)
                : Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _refreshData,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blue.shade50, Colors.white],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  MapLocationScreen(onLocationUpdate: _onLocationUpdate),
                  if (_isRefreshing) Center(child: CircularProgressIndicator()),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 10,
                    offset: Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _attendanceStatus == 'Present'
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _attendanceStatus == 'Present'
                              ? Icons.check_circle
                              : Icons.error,
                          color: _attendanceStatus == 'Present'
                              ? Colors.green
                              : Colors.red,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Status: $_attendanceStatus',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _attendanceStatus == 'Present'
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  if (_isInRange && !_hasMarkedAttendance)
                    ElevatedButton.icon(
                      icon: Icon(Icons.camera_alt),
                      label: Text('Mark Attendance with Photo'),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.blue,
                        padding:
                            EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _markAttendanceWithPhoto,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
