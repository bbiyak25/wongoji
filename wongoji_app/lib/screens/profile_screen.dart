import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/achievement_manager.dart';

// 👉 We make this map global so your Drawer can look up the image later!
const Map<String, List<Map<String, String>>> wongojiAvatars = {
  '한국의 작가': [
    {'id': 'kr_yundongju', 'name': '윤동주', 'img': 'YDJ.PNG'},
    {'id': 'kr_parkkyungni', 'name': '박경리', 'img': 'PGR.PNG'},
    {'id': 'kr_kimyujeong', 'name': '김유정', 'img': 'KYJ.PNG'},
    {'id': 'kr_baekseok', 'name': '백석', 'img': 'BS.PNG'},
    {'id': 'kr_leesang', 'name': '이상', 'img': 'YS.PNG'},
    {'id': 'kr_hangang', 'name': '한강', 'img': 'HG.PNG'},
    {'id': 'kr_kimsowol', 'name': '김소월', 'img': 'KSW.PNG'},
    {'id': 'kr_parkwanseo', 'name': '박완서', 'img': 'PWS.PNG'},
    {'id': 'kr_leehyoseok', 'name': '이효석', 'img': 'LHS.PNG'},
  ],
  '서양의 작가': [
    {'id': 'en_georgeorwell', 'name': '조지 오웰', 'img': 'JO.PNG'},
    {'id': 'en_hemingway', 'name': '헤밍웨이', 'img': 'EH.PNG'},
    {'id': 'en_kafka', 'name': '카프카', 'img': 'KA.PNG'},
    {'id': 'en_jkrowling', 'name': 'J.K. 롤링', 'img': 'JK.PNG'},
    {'id': 'en_jacklondon', 'name': '잭 런던', 'img': 'JL.PNG'},
    {'id': 'en_austen', 'name': '제인 오스틴', 'img': 'JA.PNG'},
  ],
  '고전명작 작가': [
    {'id': 'cl_tolstoy', 'name': '톨스토이', 'img': 'TS.PNG'},
    {'id': 'cl_shakespeare', 'name': '셰익스피어', 'img': 'SP.PNG'},
    {'id': 'cl_dante', 'name': '단테', 'img': 'DT.PNG'},
  ],
};

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  String? _selectedAvatarId;
  List<String> _unlockedBadges = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentProfile();
  }

  Future<void> _loadCurrentProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (doc.exists && mounted) {
      final data = doc.data()!;
      setState(() {
        _nicknameController.text = data['nickname'] ?? '';
        _selectedAvatarId = data['avatarId'];
        _unlockedBadges = List<String>.from(data['unlockedBadges'] ?? []);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_nicknameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('필명을 입력해주세요.')));
      return;
    }
    if (_selectedAvatarId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('프로필 초상화를 선택해주세요.')));
      return;
    }

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    
    // If the user is logged in, save to Firebase
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'nickname': _nicknameController.text.trim(),
        'avatarId': _selectedAvatarId,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); 
    } else {
      // 👉 FIX: If it is a Guest User, simulate a tiny loading pause so it looks natural
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (mounted) {
      // 👉 FIX: We must return the newly selected data back to the Main Screen!
      Navigator.pop(context, {
        'nickname': _nicknameController.text.trim(),
        'avatarId': _selectedAvatarId,
      });
    }
  }

  Widget _buildAvatarCarousel(String categoryTitle, List<Map<String, String>> authors, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Text(categoryTitle, style: GoogleFonts.nanumMyeongjo(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            itemCount: authors.length,
            itemBuilder: (context, index) {
              final author = authors[index];
              final isSelected = _selectedAvatarId == author['id'];

              return GestureDetector(
                onTap: () => setState(() => _selectedAvatarId = author['id']),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFFDF6E3),
                          border: Border.all(
                            color: isSelected ? const Color(0xFFE57373) : Theme.of(context).dividerColor, 
                            width: isSelected ? 3.0 : 1.0
                          ),
                          boxShadow: isSelected ? [BoxShadow(color: Colors.redAccent.withOpacity(isDark ? 0.4 : 0.2), blurRadius: 8, spreadRadius: 2)] : null,
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/images/${author['img']}',
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Text(
                                  author['name']!.substring(0, 1),
                                  style: GoogleFonts.nanumMyeongjo(fontSize: 24, color: isSelected ? Colors.redAccent : (isDark ? Colors.white54 : Colors.grey.shade500), fontWeight: FontWeight.bold),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        author['name']!,
                        style: GoogleFonts.nanumMyeongjo(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.redAccent : (isDark ? Colors.white70 : Colors.grey.shade600)),
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildAchievements(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Text("나의 업적 (배지)", style: GoogleFonts.nanumMyeongjo(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Wrap(
            spacing: 16,
            runSpacing: 16,
            children: allAchievements.map((achievement) {
              final isUnlocked = _unlockedBadges.contains(achievement.id);
              return Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: isUnlocked 
                      ? (isDark ? const Color(0xFF2C2C2C) : const Color(0xFFFDF6E3)) 
                      : Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isUnlocked ? const Color(0xFFE57373) : Theme.of(context).dividerColor
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isUnlocked ? achievement.icon : Icons.lock, 
                      color: isUnlocked ? Colors.redAccent : (isDark ? Colors.white30 : Colors.grey.shade400), 
                      size: 32
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isUnlocked ? achievement.title : "???",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nanumMyeongjo(
                        fontSize: 12, 
                        fontWeight: FontWeight.bold, 
                        color: isUnlocked ? (isDark ? Colors.white : Colors.black87) : (isDark ? Colors.white54 : Colors.grey.shade500)
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black87), onPressed: () => Navigator.pop(context)),
        title: Text("프로필 편집", style: GoogleFonts.nanumMyeongjo(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold)),
        actions: [
          _isLoading 
            ? const Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.redAccent))
            : TextButton(onPressed: _saveProfile, child: Text("저장", style: GoogleFonts.nanumMyeongjo(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold))),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            Center(
              child: Container(
                width: 400,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor, 
                  borderRadius: BorderRadius.circular(8), 
                  border: Border.all(color: Theme.of(context).dividerColor)
                ),
                child: Column(
                  children: [
                    Text("원고지에서 사용할 필명을 정해주세요.", style: GoogleFonts.nanumMyeongjo(fontSize: 14, color: isDark ? Colors.white54 : Colors.grey.shade600)),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nicknameController,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nanumMyeongjo(fontSize: 24, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: "필명 입력", 
                        hintStyle: TextStyle(color: isDark ? Colors.white30 : Colors.grey.shade400), 
                        focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.redAccent, width: 2)),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).dividerColor)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            ...wongojiAvatars.entries.map((entry) => _buildAvatarCarousel(entry.key, entry.value, isDark)).toList(),
            const SizedBox(height: 20),
            _buildAchievements(isDark),
            const SizedBox(height: 60),
          ],
        ),
      ),
    );
  }
}