import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart'; 

import 'screens/notebook_screen.dart';
import 'screens/login_screen.dart'; 

// 0: Light, 1: Grey, 2: Deep Ink
final ValueNotifier<int> globalThemeMode = ValueNotifier<int>(0);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const WongojiApp());
}

class WongojiApp extends StatelessWidget {
  const WongojiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: globalThemeMode,
      builder: (context, themeIndex, _) {
        
        ThemeData currentTheme;

        if (themeIndex == 0) {
          // --- ANALOG PAPER (LIGHT) ---
          currentTheme = ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF5F5F7),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFF5F5F7),
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.black87),
            ),
            cardColor: Colors.white,
            dividerColor: Colors.grey.shade300,
          );
        } else if (themeIndex == 1) {
          // --- MIDNIGHT GREY (GREY) ---
          currentTheme = ThemeData(
            brightness: Brightness.light, // Text defaults to dark in grey mode
            scaffoldBackgroundColor: const Color(0xFF5C5C5C),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF9E9E9E),
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.black87),
            ),
            cardColor: const Color(0xFFBDBDBD),
            dividerColor: const Color(0xFF858585),
          );
        } else {
          // --- DEEP INK (DARK) ---
          currentTheme = ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF121212),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF121212),
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.white70),
            ),
            cardColor: const Color(0xFF1E1E1E),
            dividerColor: const Color(0xFF333333),
          );
        }

        return MaterialApp(
          title: '원고지',
          debugShowCheckedModeBanner: false,
          theme: currentTheme, 
          home: const AuthWrapper(), 
        );
      },
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.redAccent)));
        }
        if (snapshot.hasData) {
          return const NotebookHomeScreen();
        }
        return const LoginScreen();
      },
    );
  }
}