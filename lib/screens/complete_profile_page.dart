import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class CompleteProfilePage extends StatefulWidget {
  @override
  _CompleteProfilePageState createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _rollNoController = TextEditingController();
  final _departmentController = TextEditingController();
  bool _isProfileComplete = false;
  LatLng? _currentLocation;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchProfileDetails();
    _getCurrentLocation();
  }

  Future<void> _fetchProfileDetails() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    DocumentSnapshot snapshot = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

    if (snapshot.exists) {
      setState(() {
        _nameController.text = snapshot['name'];
        _rollNoController.text = snapshot['rollNo'];
        _departmentController.text = snapshot['department'];
        _isProfileComplete = true;
      });
    }
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
    setState(() {
      _currentLocation = LatLng(position.latitude, position.longitude);
    });
  }

  Future<void> _saveProfile(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'name': _nameController.text,
        'rollNo': _rollNoController.text,
        'department': _departmentController.text,
        'latitude': _currentLocation?.latitude,
        'longitude': _currentLocation?.longitude,
      }, SetOptions(merge: true));

      setState(() {
        _isProfileComplete = true;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated successfully!')),
      );
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save profile: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(
          _isProfileComplete ? 'Profile' : 'Complete Profile',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
        iconTheme: IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileHeader(),
              SizedBox(height: 20),
              _buildTextField(_nameController, 'Name', Icons.person),
              SizedBox(height: 15),
              _buildTextField(_rollNoController, 'Roll No', Icons.numbers),
              SizedBox(height: 15),
              _buildTextField(_departmentController, 'Department', Icons.school),
              SizedBox(height: 20),
              if (_currentLocation != null)
                Center(
                  child: Text(
                    '📍 Current Location: ${_currentLocation!.latitude}, ${_currentLocation!.longitude}',
                    style: TextStyle(fontSize: 14, color: Colors.blueAccent),
                  ),
                ),
              SizedBox(height: 30),
              Center(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : () => _saveProfile(context),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isSaving
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                          _isProfileComplete ? 'Update Profile' : 'Save Profile',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.blueAccent,
            child: Icon(Icons.person, color: Colors.white, size: 50),
          ),
          SizedBox(height: 10),
          Text(
            "Let's complete your profile!",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueAccent),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.blueAccent),
        labelText: label,
        labelStyle: TextStyle(color: Colors.blueAccent),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
      ),
      validator: (value) {
        if (value!.isEmpty) return 'Please enter your $label';
        return null;
      },
    );
  }
}
