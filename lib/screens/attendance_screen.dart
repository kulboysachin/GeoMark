import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class AttendanceScreen extends StatefulWidget {
  @override
  _AttendanceScreenState createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isLoggedIn = false;
  String _loginTime = "";
  String _logoutTime = "";
  String _totalHoursWorked = "";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    setState(() => _isLoading = true);
    User? user = _auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    try {
      DocumentSnapshot doc = await _firestore
          .collection('attendance')
          .doc(user.uid)
          .collection('records')
          .doc(today)
          .get();

      if (doc.exists) {
        setState(() {
          _isLoggedIn = doc['logoutTime'] == null;
          _loginTime = doc['loginTime'] ?? "";
          _logoutTime = doc['logoutTime'] ?? "";
          _totalHoursWorked = doc['totalHoursWorked'] ?? "";
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error checking login status: ${e.toString()}')),
      );
    }
  }

  Future<void> _markLogin() async {
    setState(() => _isLoading = true);
    User? user = _auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String currentTime = DateFormat('hh:mm a').format(DateTime.now());

    try {
      await _firestore.collection('attendance').doc(user.uid).collection('records').doc(today).set({
        'userId': user.uid,
        'date': today,
        'loginTime': currentTime,
        'logoutTime': null,
        'totalHoursWorked': null,
      });

      setState(() {
        _isLoggedIn = true;
        _loginTime = currentTime;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking login: ${e.toString()}')),
      );
    }
  }

  Future<void> _markLogout() async {
    setState(() => _isLoading = true);
    User? user = _auth.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String currentTime = DateFormat('hh:mm a').format(DateTime.now());

    try {
      DocumentSnapshot doc = await _firestore.collection('attendance').doc(user.uid).collection('records').doc(today).get();
      if (!doc.exists || doc['loginTime'] == null) {
        setState(() => _isLoading = false);
        return;
      }

      DateTime loginDateTime = DateFormat('hh:mm a').parse(doc['loginTime']);
      DateTime logoutDateTime = DateFormat('hh:mm a').parse(currentTime);
      Duration workedDuration = logoutDateTime.difference(loginDateTime);
      String hoursWorked = "${workedDuration.inHours}h ${workedDuration.inMinutes % 60}m";

      await _firestore.collection('attendance').doc(user.uid).collection('records').doc(today).update({
        'logoutTime': currentTime,
        'totalHoursWorked': hoursWorked,
      });

      setState(() {
        _isLoggedIn = false;
        _logoutTime = currentTime;
        _totalHoursWorked = hoursWorked;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error marking logout: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Attendance Records"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.blue.shade800,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Today's Attendance Card
                Container(
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.2),
                        spreadRadius: 2,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        "Today's Attendance",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Status:",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                _isLoggedIn ? "Logged In" : "Logged Out",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: _isLoggedIn ? Colors.green : Colors.red,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Hours:",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                _totalHoursWorked.isNotEmpty ? _totalHoursWorked : "--",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Divider(),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Login Time:",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                _loginTime.isNotEmpty ? _loginTime : "--:--",
                                style: TextStyle(
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Logout Time:",
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                _logoutTime.isNotEmpty ? _logoutTime : "--:--",
                                style: TextStyle(
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoggedIn ? _markLogout : _markLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isLoggedIn ? Colors.red.shade400 : Colors.green.shade400,
                            padding: EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Text(
                            _isLoggedIn ? "CHECK OUT" : "CHECK IN",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Attendance History
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text(
                        "Attendance History",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: StreamBuilder(
                    stream: _firestore
                        .collection('attendance')
                        .doc(_auth.currentUser?.uid)
                        .collection('records')
                        .orderBy('date', descending: true)
                        .snapshots(),
                    builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(
                          child: Text(
                            "No attendance records found",
                            style: TextStyle(color: Colors.grey),
                          ),
                        );
                      }
                      var records = snapshot.data!.docs;

                      return ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: records.length,
                        itemBuilder: (context, index) {
                          var record = records[index].data() as Map<String, dynamic>;
                          bool isToday = record['date'] == DateFormat('yyyy-MM-dd').format(DateTime.now());
                          
                          return Card(
                            elevation: 2,
                            margin: EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            color: isToday ? Colors.blue.shade50 : Colors.white,
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        record['date'],
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: isToday ? Colors.blue.shade800 : Colors.black,
                                        ),
                                      ),
                                      if (record['totalHoursWorked'] != null)
                                        Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade100,
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            record['totalHoursWorked'],
                                            style: TextStyle(
                                              color: Colors.green.shade800,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Check In",
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            record['loginTime'] ?? "--:--",
                                            style: TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Check Out",
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 12,
                                            ),
                                          ),
                                          Text(
                                            record['logoutTime'] ?? "--:--",
                                            style: TextStyle(
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}