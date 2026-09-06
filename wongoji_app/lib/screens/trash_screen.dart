import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/manuscript.dart';

class TrashBinScreen extends StatefulWidget {
  // Keeping these optional parameters so we don't break your NotebookHomeScreen navigation
  final List<dynamic>? documents;
  final Function? onUpdate;
  
  const TrashBinScreen({Key? key, this.documents, this.onUpdate}) : super(key: key);

  @override
  State<TrashBinScreen> createState() => _TrashBinScreenState();
}

class _TrashBinScreenState extends State<TrashBinScreen> {
  final User? user = FirebaseAuth.instance.currentUser;

  // Point directly to the current user's database
  CollectionReference get _manuscriptsRef {
    return FirebaseFirestore.instance
        .collection('users')
        .doc(user?.uid ?? 'guest')
        .collection('manuscripts');
  }

  // 👉 RESTORE: Removes the 'deletedAt' timestamp so it pops back into the main notebook
  Future<void> _restoreDocument(Manuscript doc) async {
    await _manuscriptsRef.doc(doc.id).update({
      'deletedAt': FieldValue.delete(), 
    });
  }

  // 👉 HARD DELETE: Erases the document from the cloud forever
  Future<void> _permanentDelete(String docId) async {
    await _manuscriptsRef.doc(docId).delete();
  }

  // Batch delete to empty the entire trash in one network request
  Future<void> _emptyTrash(List<Manuscript> trashDocs) async {
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in trashDocs) {
      batch.delete(_manuscriptsRef.doc(doc.id));
    }
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text('휴지통', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      // Listen ONLY for documents that have a deletedAt timestamp
      body: StreamBuilder<QuerySnapshot>(
        stream: _manuscriptsRef.where('deletedAt', isNull: false).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.redAccent));
          }

          List<Manuscript> trashDocs = [];
          final now = DateTime.now();

          if (snapshot.hasData) {
            for (var doc in snapshot.data!.docs) {
              final m = Manuscript.fromMap(doc.data() as Map<String, dynamic>, doc.id);
              if (m.deletedAt != null) {
                // Double-check the 3-day expiration client-side
                if (now.difference(m.deletedAt!).inDays >= 3) {
                  _permanentDelete(m.id); // Auto-nuke if the timer expired
                } else {
                  trashDocs.add(m);
                }
              }
            }
          }

          if (trashDocs.isEmpty) {
            return Center(
              child: Text("휴지통이 비어 있습니다.", style: GoogleFonts.nanumMyeongjo(fontSize: 18, color: Colors.grey.shade500)),
            );
          }

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("휴지통", style: GoogleFonts.nanumMyeongjo(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
                    TextButton.icon(
                      onPressed: () => _emptyTrash(trashDocs),
                      icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                      label: Text("휴지통 비우기", style: GoogleFonts.nanumMyeongjo(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    )
                  ],
                ),
                const SizedBox(height: 10),
                Text("휴지통에 있는 항목은 3일 후 영구 삭제됩니다.", style: GoogleFonts.nanumMyeongjo(color: Colors.grey.shade600)),
                const SizedBox(height: 30),
                Expanded(
                  child: ListView.builder(
                    itemCount: trashDocs.length,
                    itemBuilder: (context, index) {
                      final doc = trashDocs[index];
                      // Calculate exactly how many days are left in the 3-day window
                      final daysLeft = 3 - now.difference(doc.deletedAt!).inDays;
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.grey.shade300)
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          title: Text(doc.title.isEmpty ? "제목 없음" : doc.title, style: GoogleFonts.nanumMyeongjo(fontWeight: FontWeight.bold, fontSize: 18)),
                          subtitle: Text("삭제까지 $daysLeft일 남음", style: GoogleFonts.nanumMyeongjo(color: Colors.redAccent, fontSize: 13)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.restore, color: Colors.blueGrey),
                                tooltip: "복원하기",
                                onPressed: () => _restoreDocument(doc),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                                tooltip: "영구 삭제",
                                onPressed: () => _permanentDelete(doc.id),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}