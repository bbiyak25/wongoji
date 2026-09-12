import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';

class Achievement {
  final String id;
  final String title;
  final String description;
  final IconData icon;

  const Achievement({required this.id, required this.title, required this.description, required this.icon});
}

const List<Achievement> allAchievements = [
  Achievement(id: 'first_notebook', title: '첫 걸음', description: '첫 원고 작성 완료', icon: Icons.edit_document),
  Achievement(id: '1min_essay', title: '1분 에세이스트', description: '600자 이상의 글 작성', icon: Icons.timer),
  Achievement(id: 'serious_writer', title: '진지한 작가', description: '한 원고에 1시간 이상 몰두', icon: Icons.psychology),
  Achievement(id: 'bye_note', title: '안녕, 내 원고', description: '첫 원고 삭제', icon: Icons.delete_sweep),
  Achievement(id: 'real_publisher', title: '진정한 출판인', description: '첫 PDF 내보내기', icon: Icons.picture_as_pdf),
  Achievement(id: 'insta_viral', title: '너도 알잖아?', description: '첫 인스타그램 공유', icon: Icons.share),
];

class AchievementManager {
  static Future<void> unlock(BuildContext context, String achievementId) async {
    final user = FirebaseAuth.instance.currentUser;
    // 👉 FIX: The guest block is removed! Anonymous users can now earn badges.
    if (user == null) return; 

    // Capture the root overlay synchronously BEFORE the async cloud call.
    final overlay = Overlay.of(context, rootOverlay: true);

    final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
    final doc = await docRef.get();
    
    List<dynamic> unlocked = [];
    if (doc.exists && doc.data() != null) {
      unlocked = doc.data()!['unlockedBadges'] ?? [];
    }

    if (!unlocked.contains(achievementId)) {
      unlocked.add(achievementId);
      await docRef.set({'unlockedBadges': unlocked}, SetOptions(merge: true));
      
      final achievement = allAchievements.firstWhere((a) => a.id == achievementId);
      
      // Pass the surviving overlay directly, bypassing the dead context.
      _showAnimatedToast(overlay, achievement);
    }
  }

  // Accepts OverlayState instead of BuildContext
  static void _showAnimatedToast(OverlayState overlay, Achievement achievement) {
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => _AnimatedToast(
        achievement: achievement,
        onDismissed: () => entry.remove(),
      ),
    );

    overlay.insert(entry); 
  }
}

// A dedicated widget to handle the bouncy entry AND bouncy exit
class _AnimatedToast extends StatefulWidget {
  final Achievement achievement;
  final VoidCallback onDismissed;

  const _AnimatedToast({required this.achievement, required this.onDismissed});

  @override
  State<_AnimatedToast> createState() => _AnimatedToastState();
}

class _AnimatedToastState extends State<_AnimatedToast> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    // Set up the bounce curves for both directions
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(1.2, 0), // Start slightly off-screen to the right
      end: Offset.zero,            // End exactly where it belongs
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,   // Bouncy on the way in
      reverseCurve: Curves.easeInBack, // Bouncy on the way out!
    ));

    // Play the entry animation immediately
    _controller.forward();

    // Wait 3.5 seconds, play the exit animation, then tell the overlay to delete it
    _timer = Timer(const Duration(milliseconds: 3500), () async {
      if (mounted) {
        await _controller.reverse();
        widget.onDismissed();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 👉 NEW: Direct Universal Theme Wiring
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Positioned(
      top: 40,
      right: 40,
      child: Material(
        color: Colors.transparent,
        child: SlideTransition(
          position: _offsetAnimation,
          child: Container(
            width: 320,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Theme.of(context).dividerColor, width: 2),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(isDark ? 0.4 : 0.1), blurRadius: 10, offset: const Offset(0, 5))
              ]
            ),
            child: Row(
              children: [
                Icon(widget.achievement.icon, color: Colors.redAccent, size: 36),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("업적 달성!", style: GoogleFonts.nanumGothic(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(widget.achievement.title, style: GoogleFonts.nanumMyeongjo(color: isDark ? Colors.white : Colors.black87, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}