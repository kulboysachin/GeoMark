import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'complete_profile_page.dart';
import 'theme_provider.dart';
import 'attendance_screen.dart';

class AppDrawer extends StatefulWidget {
  final User? user;
  final Function() onLogout;

  AppDrawer({
    required this.user,
    required this.onLogout,
    required Null Function() onUploadProfileImage,
    required Null Function() onToggleTheme,
    required profileImage,
  });

  @override
  _AppDrawerState createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  String _userName = "User"; // Default value

  @override
  void initState() {
    super.initState();
    _fetchUserName(); // Fetch user's name when drawer initializes
  }

  Future<void> _fetchUserName() async {
    if (widget.user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.user!.uid)
          .get();

      if (userDoc.exists && userDoc['name'] != null) {
        setState(() {
          _userName = userDoc['name']; // Set user's name from Firestore
        });
      }
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Drawer(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Section
            Container(
              height: screenHeight * 0.25,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Profile Picture
                  Positioned(
                    top: screenHeight * 0.05,
                    child: GestureDetector(
                      onTap: _pickImage,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 50,
                            backgroundColor: Colors.white,
                            child: CircleAvatar(
                              radius: 48,
                              backgroundImage: _profileImage != null
                                  ? FileImage(_profileImage!)
                                  : AssetImage('assets/default_profile.png') as ImageProvider,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.white,
                              child: Icon(Icons.edit, size: 14, color: Colors.deepPurple),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // User Name and Email
                  Positioned(
                    bottom: screenHeight * 0.02,
                    child: Column(
                      children: [
                        Text(
                          _userName,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          widget.user?.email ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Menu Items
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                children: [
                  // Complete Profile
                  ListTile(
                    leading: Icon(Icons.person, color: Colors.deepPurple),
                    title: Text(
                      'Complete Profile',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => CompleteProfilePage()),
                      ).then((_) => _fetchUserName()); // Refresh name after profile update
                    },
                  ),

                  // Change Profile Picture
                  ListTile(
                    leading: Icon(Icons.camera_alt, color: Colors.deepPurple),
                    title: Text(
                      'Change Profile Picture',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    onTap: _pickImage,
                  ),

                  // Attendance
                  ListTile(
                    leading: Icon(Icons.access_time, color: Colors.deepPurple),
                    title: Text(
                      'Attendance',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => AttendanceScreen()),
                      );
                    },
                  ),

                  // Toggle Theme
                  ListTile(
                    leading: Icon(Icons.brightness_6, color: Colors.deepPurple),
                    title: Text(
                      'Toggle Theme',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    onTap: () {
                      Provider.of<ThemeProvider>(context, listen: false).toggleTheme();
                    },
                  ),

                  // Logout
                  ListTile(
                    leading: Icon(Icons.logout, color: Colors.red),
                    title: Text(
                      'Logout',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.red),
                    ),
                    onTap: widget.onLogout,
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