import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/notebook_screen.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyBktc-4rempBbYPoAQHPLpA4zM5XPVKtxo",
      authDomain: "wongoji-559ce.firebaseapp.com",
      projectId: "wongoji-559ce",
      storageBucket: "wongoji-559ce.firebasestorage.app",
      messagingSenderId: "1017624062769",
      appId: "1:1017624062769:web:e7f10080121abf16ef1e10",
      measurementId: "G-L3W7F563MP",
    ),
  );

  runApp(const WongojiApp());
}

class WongojiApp extends StatelessWidget {
  const WongojiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      // StreamBuilder listens to Firebase Auth automatically
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // If the snapshot has data, the user is already logged in!
          if (snapshot.hasData) {
            return const NotebookHomeScreen();
          }
          // If there is no data, they are not logged in. Show the login screen.
          return const LoginScreen();
        },
      ),
    );
  }
}