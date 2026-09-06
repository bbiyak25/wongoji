import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'notebook_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  Future<void> _signInWithGoogleWeb(BuildContext context) async {
    try {
      final GoogleAuthProvider webProvider = GoogleAuthProvider();
      final UserCredential userCredential = await FirebaseAuth.instance.signInWithPopup(webProvider);
      
      if (userCredential.user != null) {
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const NotebookHomeScreen()),
          );
        }
      }
    } catch (e) {
      print("Error during Google Sign-In: $e");
    }
  }

  // --- NEW: Anonymous Guest Login Engine ---
  Future<void> _signInAnonymously(BuildContext context) async {
    try {
      final UserCredential userCredential = await FirebaseAuth.instance.signInAnonymously();
      
      if (userCredential.user != null) {
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const NotebookHomeScreen()),
          );
        }
      }
    } catch (e) {
      print("Error during Anonymous Sign-In: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(40.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("원고지", style: GoogleFonts.nanumMyeongjo(fontSize: 40, fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 12),
              Text("당신의 이야기를 시작하세요", style: GoogleFonts.nanumMyeongjo(fontSize: 16, color: Colors.grey.shade600)),
              const SizedBox(height: 48),
              
              // Google Login
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: () => _signInWithGoogleWeb(context),
                  icon: const Icon(Icons.login),
                  label: const Text("Google 계정으로 로그인", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    side: BorderSide(color: Colors.grey.shade300),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Placeholder for future Naver Login
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Implement Naver Login
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF03C75A), 
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                  child: const Text("네이버 계정으로 로그인", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 16),

              // Placeholder for future Kakao Login
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: Implement Kakao Login
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFEE500), 
                    foregroundColor: Colors.black87,
                    elevation: 0,
                  ),
                  child: const Text("카카오 계정으로 로그인", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 24),
              
              // --- NEW: Guest Mode Button ---
              TextButton(
                onPressed: () => _signInAnonymously(context),
                child: Text("로그인 없이 비회원으로 시작하기", style: TextStyle(color: Colors.grey.shade500, decoration: TextDecoration.underline)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}