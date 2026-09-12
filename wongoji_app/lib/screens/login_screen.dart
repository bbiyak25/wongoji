import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  Future<void> _signInWithGoogleWeb(BuildContext context) async {
    try {
      final GoogleAuthProvider webProvider = GoogleAuthProvider();
      // The AuthWrapper in main.dart listens to this. 
      // The moment this succeeds, it automatically routes the user!
      await FirebaseAuth.instance.signInWithPopup(webProvider);
    } catch (e) {
      debugPrint("Error during Google Sign-In: $e");
    }
  }

  Future<void> _signInAnonymously(BuildContext context) async {
    try {
      // Automatic routing happens here too!
      await FirebaseAuth.instance.signInAnonymously();
    } catch (e) {
      debugPrint("Error during Anonymous Sign-In: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if the global theme is currently dark or light
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(40.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), 
                blurRadius: 20, 
                offset: const Offset(0, 4)
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("원고지", style: GoogleFonts.nanumMyeongjo(fontSize: 40, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 12),
              Text("당신의 이야기를 시작하세요", style: GoogleFonts.nanumMyeongjo(fontSize: 16, color: isDark ? Colors.white54 : Colors.grey.shade600)),
              const SizedBox(height: 48),
              
              // Google Login
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _signInWithGoogleWeb(context),
                  icon: Icon(Icons.login, color: isDark ? Colors.white : Colors.black87),
                  label: Text("Google 계정으로 로그인", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                    side: BorderSide(color: Theme.of(context).dividerColor),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Guest Mode Button
              TextButton(
                onPressed: () => _signInAnonymously(context),
                child: Text("로그인 없이 비회원으로 시작하기", style: TextStyle(color: isDark ? Colors.white30 : Colors.grey.shade500, decoration: TextDecoration.underline)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}