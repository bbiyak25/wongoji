import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // 👉 NEW: Firestore Import
import 'package:google_fonts/google_fonts.dart';
import '../models/manuscript.dart';
import '../widgets/document_card.dart';
import 'editor_screen.dart';
import 'trash_screen.dart';
import 'login_screen.dart';

class NotebookHomeScreen extends StatefulWidget {
  const NotebookHomeScreen({Key? key}) : super(key: key);

  @override
  State<NotebookHomeScreen> createState() => _NotebookHomeScreenState();
}

class _NotebookHomeScreenState extends State<NotebookHomeScreen> {
  // 👉 NEW: Identify the current user (Google or Guest)
  final User? user = FirebaseAuth.instance.currentUser;

  // 👉 NEW: Create a direct pipeline to this specific user's private folder in the database
  CollectionReference get _manuscriptsRef {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user?.uid ?? 'guest') 
        .collection('manuscripts');
  }

  @override
  void initState() {
    super.initState();
    _cleanExpiredTrash();
  }

  // 👉 NEW: Runs a cloud query to permanently delete expired trash files
  Future<void> _cleanExpiredTrash() async {
    final now = DateTime.now();
    final snapshot = await _manuscriptsRef.where('deletedAt', isNull: false).get();
    
    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final deletedAtStr = data['deletedAt'];
      if (deletedAtStr != null) {
        final deletedAt = DateTime.tryParse(deletedAtStr);
        if (deletedAt != null && now.difference(deletedAt).inDays >= 3) {
          await doc.reference.delete(); // Nukes it from the cloud
        }
      }
    }
  }

  // 👉 NEW: Fires a payload to the cloud to save or update
  Future<void> _saveToFirestore(Manuscript doc) async {
    await _manuscriptsRef.doc(doc.id).set(doc.toMap());
  }

  // 👉 NEW: Tags the file as deleted and updates the cloud
  Future<void> _moveToTrash(Manuscript doc) async {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text("원고 삭제", style: GoogleFonts.nanumMyeongjo(fontWeight: FontWeight.bold)),
        content: Text("이 원고를 휴지통으로 이동하시겠습니까?\n휴지통으로 이동한 원고는 3일 후 영구 삭제됩니다.", style: GoogleFonts.nanumMyeongjo(height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("취소", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () async {
              doc.deletedAt = DateTime.now();
              await _saveToFirestore(doc); // Sync to cloud
              if (context.mounted) Navigator.pop(ctx);
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
        if (!hasBase && maxSuffix == 0) {
          result.title = "제목 없음";
        } else {
          result.title = "제목 없음-${maxSuffix == 0 ? 2 : maxSuffix + 1}";
        }
      }
      
      // 👉 NEW: Push the final written document straight into Firestore
      await _saveToFirestore(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 👉 NEW: StreamBuilder wraps the UI to listen for live database changes
    return StreamBuilder<QuerySnapshot>(
      stream: _manuscriptsRef.orderBy('lastModified', descending: true).snapshots(),
      builder: (context, snapshot) {
        
        // Translate incoming JSON maps from the cloud back into our Dart Manuscript models
        List<Manuscript> allDocs = [];
        if (snapshot.hasData) {
          allDocs = snapshot.data!.docs.map((doc) => Manuscript.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
        }
        
        final activeDocs = allDocs.where((d) => d.deletedAt == null).toList();

        return Scaffold(
          backgroundColor: const Color(0xFFF5F5F7), 
          appBar: AppBar(
            title: const Text('원고지', style: TextStyle(color: Colors.black)),
            backgroundColor: Colors.white,
            elevation: 0,
            actions: [
              Builder(
                builder: (context) => IconButton(
                  icon: const Icon(Icons.menu, color: Colors.black87),
                  onPressed: () => Scaffold.of(context).openEndDrawer(),
                ),
              ),
              const SizedBox(width: 16),
            ],
          ),
          endDrawer: _buildSidebarDrawer(context, allDocs),
          body: snapshot.connectionState == ConnectionState.waiting 
            ? const Center(child: CircularProgressIndicator(color: Colors.redAccent))
            : Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("내 원고함", style: GoogleFonts.nanumMyeongjo(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 30),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      int columns = constraints.maxWidth > 1200 ? 3 : (constraints.maxWidth > 800 ? 2 : 1);
                      return GridView.builder(
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns, 
                          crossAxisSpacing: 40, 
                          mainAxisSpacing: 40, 
                          childAspectRatio: 1.414, 
                        ),
                        itemCount: activeDocs.length + 1, 
                        itemBuilder: (context, index) {
                          if (index == 0) return _buildNewDocumentCard(allDocs);
                          final doc = activeDocs[index - 1];
                          return DocumentCard(
                            doc: doc,
                            onTap: () => _openEditor(allDocs, doc),
                            onUpdate: () => _saveToFirestore(doc), // Instantly triggers a cloud update
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
    String emailText = "로그인이 필요합니다.";
    String nameText = "Wongoji 작가님";
    if (user != null) {
      if (user!.isAnonymous) {
        emailText = "게스트로 로그인 되었습니다.";
        nameText = "게스트 작가님";
      } else {
        emailText = user!.email ?? "이메일 없음";
        nameText = user!.displayName ?? "Wongoji 작가님";
      }
    }

    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFFF5F5F7)),
            accountName: Text(nameText, style: GoogleFonts.nanumMyeongjo(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
            accountEmail: Text(emailText, style: GoogleFonts.nanumMyeongjo(color: Colors.grey.shade600)),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.grey.shade300, 
              backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
              child: user?.photoURL == null ? const Icon(Icons.person, color: Colors.white, size: 40) : null,
            ),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.grey.shade700),
            title: Text("휴지통", style: GoogleFonts.nanumMyeongjo(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            onTap: () {
              Navigator.pop(context); 
              Navigator.push(context, MaterialPageRoute(builder: (_) => TrashBinScreen(documents: allDocs, onUpdate: () {})));
            },
          ),
          const Spacer(),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: Text("로그아웃", style: GoogleFonts.nanumMyeongjo(fontSize: 16, color: Colors.redAccent)),
            onTap: () async {
              await FirebaseAuth.instance.signOut();
              if (context.mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
              }
            },
          ),
          Padding(padding: const EdgeInsets.all(20.0), child: Text("Wongoji Studio v0.60", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)))
        ],
      ),
    );
  }

  Widget _buildNewDocumentCard(List<Manuscript> allDocs) {
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
                    color: Colors.white, 
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.withOpacity(0.3), width: 1.5, style: BorderStyle.solid),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text("새 원고", style: GoogleFonts.nanumMyeongjo(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16), 
        const SizedBox(height: 24), 
        const SizedBox(height: 4), 
        const SizedBox(height: 16), 
      ],
    );
  }
}