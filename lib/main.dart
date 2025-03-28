import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geomark/screens/auth_screen.dart';
import 'package:geomark/screens/home_screen.dart';
import 'package:geomark/screens/theme_provider.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'Attendance System',
      theme: themeProvider.themeData,
      home: AuthWrapper(), // Use AuthWrapper to handle authentication state
      routes: {
        '/auth': (context) => AuthScreen(), // Login screen
        '/home': (context) => HomeScreen(), // Home screen
      },
      debugShowCheckedModeBanner: false,
    );
  }
}

// AuthWrapper to check authentication state
class AuthWrapper extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show a loading indicator while checking authentication state
          return Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        } else if (snapshot.hasData) {
          // User is logged in, redirect to HomeScreen
          return HomeScreen();
        } else {
          // User is not logged in, redirect to AuthScreen
          return AuthScreen();
        }
      },
    );
  }
}