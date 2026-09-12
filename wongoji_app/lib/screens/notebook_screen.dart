import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/manuscript.dart';
import '../widgets/document_card.dart';
import 'editor_screen.dart';
import 'trash_screen.dart';
import 'profile_screen.dart';
import '../utils/achievement_manager.dart';
import '../main.dart'; // To access globalThemeMode

class NotebookHomeScreen extends StatefulWidget {
  const NotebookHomeScreen({Key? key}) : super(key: key);

  @override
  State<NotebookHomeScreen> createState() => _NotebookHomeScreenState();
}

class _NotebookHomeScreenState extends State<NotebookHomeScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _cleanExpiredTrash();
  }

  Future<void> _cleanExpiredTrash() async {
    if (currentUser == null) return;
    
    final ref = FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).collection('manuscripts');
    final snap = await ref.get(); 
    
    final now = DateTime.now();
    for (var doc in snap.docs) {
      final data = doc.data();
      final deletedAtStr = data['deletedAt'];
      if (deletedAtStr != null) {
        final deletedAt = DateTime.tryParse(deletedAtStr);
        if (deletedAt != null && now.difference(deletedAt).inDays >= 3) {
          await ref.doc(doc.id).delete();
        }
      }
    }
  }

  Future<void> _saveToFirebase(Manuscript doc) async {
    if (currentUser == null) return;
    final ref = FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).collection('manuscripts');
    await ref.doc(doc.id).set(doc.toMap());
  }

  Future<void> _moveToTrash(Manuscript doc) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text("원고 삭제", style: GoogleFonts.nanumMyeongjo(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        content: Text("이 원고를 휴지통으로 이동하시겠습니까?\n휴지통으로 이동한 원고는 3일 후 영구 삭제됩니다.", style: GoogleFonts.nanumMyeongjo(height: 1.5, color: isDark ? Colors.white70 : Colors.black87)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("취소", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              doc.deletedAt = DateTime.now();
              await _saveToFirebase(doc); 
              if (context.mounted) {
                AchievementManager.unlock(context, 'bye_note'); 
                Navigator.pop(ctx);
              }
            },
            child: const Text("삭제", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      )
    );
  }

  void _openEditor(List<Manuscript> currentDocs, [Manuscript? doc]) async {
    final targetDoc = doc ?? Manuscript(id: DateTime.now().millisecondsSinceEpoch.toString(), lastModified: DateTime.now());
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => WongojiEditor(initialDocument: targetDoc)));

    if (result != null && result is Manuscript) {
      if (result.title.trim().isEmpty) {
        int maxSuffix = 0;
        bool hasBase = false;
        for (var d in currentDocs) {
          if (d.id == result.id) continue;
          if (d.title == "제목 없음") {
            hasBase = true;
          } else if (d.title.startsWith("제목 없음-")) {
            final match = RegExp(r'제목 없음-(\d+)').firstMatch(d.title);
            if (match != null) {
              int val = int.parse(match.group(1)!);
              if (val > maxSuffix) maxSuffix = val;
            }
          }
        }
        result.title = (!hasBase && maxSuffix == 0) ? "제목 없음" : "제목 없음-${maxSuffix == 0 ? 2 : maxSuffix + 1}";
      }
      await _saveToFirebase(result);
    }
  }
  
  Future<void> _signOut() async {
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (currentUser == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final manuscriptsRef = FirebaseFirestore.instance.collection('users').doc(currentUser!.uid).collection('manuscripts');

    return StreamBuilder<QuerySnapshot>(
      stream: manuscriptsRef.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
           return Scaffold(
             appBar: AppBar(title: Text('원고지', style: TextStyle(color: isDark ? Colors.white : Colors.black))),
             body: const Center(child: CircularProgressIndicator(color: Colors.redAccent))
           );
        }

        List<Manuscript> allDocs = [];
        if (snapshot.hasData) {
          for (var doc in snapshot.data!.docs) {
            allDocs.add(Manuscript.fromMap(doc.data() as Map<String, dynamic>, doc.id));
          }
        }
        
        allDocs.sort((a, b) => b.lastModified.compareTo(a.lastModified));
        final activeDocs = allDocs.where((d) => d.deletedAt == null).toList();

        return Scaffold(
          appBar: AppBar(
            title: Text('원고지', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
            actions: [
              Builder(
                builder: (context) => IconButton(
                  icon: Icon(Icons.menu, color: isDark ? Colors.white : Colors.black87),
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
          endDrawer: _buildSidebarDrawer(context, allDocs),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("내 원고함", style: GoogleFonts.nanumMyeongjo(fontSize: 28, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                const SizedBox(height: 30),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      int columns = constraints.maxWidth > 1200 ? 3 : (constraints.maxWidth > 800 ? 2 : 1);
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns, crossAxisSpacing: 40, mainAxisSpacing: 40, childAspectRatio: 1.414, 
                        ),
                        itemCount: activeDocs.length + 1, 
                        itemBuilder: (context, index) {
                          if (index == 0) return _buildNewDocumentCard(allDocs, isDark);
                          final doc = activeDocs[index - 1];
                          return DocumentCard(
                            doc: doc,
                            onTap: () => _openEditor(allDocs, doc),
                            onUpdate: () => _saveToFirebase(doc), 
                            onDelete: () => _moveToTrash(doc),
                            isTrashMode: false,
                          );
                        },
                      );
                    }
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildSidebarDrawer(BuildContext context, List<Manuscript> allDocs) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    String displayName = currentUser?.isAnonymous == true ? "비회원 작가님" : (currentUser?.displayName ?? "Wongoji 작가님");
    String email = currentUser?.isAnonymous == true ? "임시 게스트 계정" : (currentUser?.email ?? "연동된 이메일 없음");
    String avatarInitial = displayName.isNotEmpty ? displayName.substring(0, 1) : "W";

    return Drawer(
      backgroundColor: Theme.of(context).cardColor,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor),
            accountName: Text(displayName, style: GoogleFonts.nanumMyeongjo(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 20)),
            accountEmail: Text(email, style: GoogleFonts.nanumGothic(color: Colors.grey.shade500, fontSize: 12)),
            currentAccountPicture: CircleAvatar(
              backgroundColor: isDark ? const Color(0xFF2C2C2C) : const Color(0xFFFDF6E3), 
              child: Text(avatarInitial, style: GoogleFonts.nanumMyeongjo(fontSize: 32, color: Colors.redAccent, fontWeight: FontWeight.bold)),
            ),
          ),
          ListTile(
            leading: Icon(Icons.person_outline, color: isDark ? Colors.white70 : Colors.grey.shade700),
            title: Text("프로필 편집", style: GoogleFonts.nanumMyeongjo(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: isDark ? Colors.white70 : Colors.grey.shade700),
            title: Text("휴지통", style: GoogleFonts.nanumMyeongjo(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            onTap: () {
              Navigator.pop(context); 
              Navigator.push(context, MaterialPageRoute(builder: (_) => TrashBinScreen(documents: allDocs, onUpdate: () {})));
            },
          ),
          const Divider(),
          
          // NEW: The 3-Step Theme Cycler
          ValueListenableBuilder<int>(
            valueListenable: globalThemeMode,
            builder: (context, themeIndex, _) {
              IconData themeIcon = Icons.light_mode;
              String themeName = "라이트 모드";
              
              if (themeIndex == 1) {
                themeIcon = Icons.monochrome_photos;
                themeName = "그레이 모드";
              } else if (themeIndex == 2) {
                themeIcon = Icons.dark_mode;
                themeName = "다크 모드";
              }

              return ListTile(
                leading: Icon(themeIcon, color: isDark ? Colors.white70 : Colors.grey.shade700),
                title: Text(themeName, style: GoogleFonts.nanumMyeongjo(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                onTap: () {
                  globalThemeMode.value = (globalThemeMode.value + 1) % 3;
                },
              );
            },
          ),
          const Spacer(),
          
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: Text("로그아웃", style: GoogleFonts.nanumMyeongjo(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.redAccent)),
            onTap: () {
              Navigator.pop(context);
              _signOut();
            },
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 20.0, top: 10.0), 
            child: Text("Wongoji Studio Web", style: TextStyle(color: Colors.grey.shade500, fontSize: 12))
          )
        ],
      ),
    );
  }

  Widget _buildNewDocumentCard(List<Manuscript> allDocs, bool isDark) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1.414, 
              child: GestureDetector(
                onTap: () => _openEditor(allDocs),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor, 
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Theme.of(context).dividerColor, width: 1.5),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 48, color: isDark ? Colors.white30 : Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text("새 원고", style: GoogleFonts.nanumMyeongjo(fontSize: 16, color: isDark ? Colors.white54 : Colors.grey.shade600, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 56), 
      ],
    );
  }
}