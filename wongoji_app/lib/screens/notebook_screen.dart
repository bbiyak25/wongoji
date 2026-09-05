import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/manuscript.dart';
import '../widgets/document_card.dart';
import 'editor_screen.dart';
import 'trash_screen.dart';

class NotebookHomeScreen extends StatefulWidget {
  const NotebookHomeScreen({Key? key}) : super(key: key);

  @override
  State<NotebookHomeScreen> createState() => _NotebookHomeScreenState();
}

class _NotebookHomeScreenState extends State<NotebookHomeScreen> {
  List<Manuscript> _documents = [];

  @override
  void initState() {
    super.initState();
    _cleanExpiredTrash();
  }

  void _cleanExpiredTrash() {
    final now = DateTime.now();
    _documents.removeWhere((doc) => doc.deletedAt != null && now.difference(doc.deletedAt!).inDays >= 3);
  }

  List<Manuscript> get _activeDocuments => _documents.where((d) => d.deletedAt == null).toList();

  void _openEditor([Manuscript? doc]) async {
    final isNew = doc == null;
    final targetDoc = doc ?? Manuscript(id: DateTime.now().millisecondsSinceEpoch.toString(), lastModified: DateTime.now());

    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => WongojiEditor(initialDocument: targetDoc)));

    if (result != null && result is Manuscript) {
      setState(() {
        if (isNew) {
          if (result.title.isNotEmpty || result.content.isNotEmpty) _documents.insert(0, result);
        } else {
          final index = _documents.indexWhere((d) => d.id == result.id);
          if (index != -1) {
            _documents[index] = result;
            final updatedDoc = _documents.removeAt(index);
            _documents.insert(0, updatedDoc);
          }
        }
      });
    }
  }

  void _moveToTrash(Manuscript doc) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text("원고 삭제", style: GoogleFonts.nanumMyeongjo(fontWeight: FontWeight.bold)),
        content: Text("이 원고를 휴지통으로 이동하시겠습니까?\n휴지통으로 이동한 원고는 3일 후 영구 삭제됩니다.", style: GoogleFonts.nanumMyeongjo(height: 1.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("취소", style: TextStyle(color: Colors.grey))),
          TextButton(
            onPressed: () {
              setState(() => doc.deletedAt = DateTime.now());
              Navigator.pop(ctx);
            },
            child: const Text("삭제", style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeDocs = _activeDocuments;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7), 
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F7),
        elevation: 0,
        title: const Text("Wongoji Studio", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
        actions: [
          Builder(
            builder: (context) => IconButton(icon: const Icon(Icons.menu, color: Colors.black87), onPressed: () => Scaffold.of(context).openEndDrawer()),
          ),
          const SizedBox(width: 16),
        ],
      ),
      endDrawer: _buildSidebarDrawer(context),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("내 원고함", style: GoogleFonts.nanumMyeongjo(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87)),
            const SizedBox(height: 30),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  int columns = constraints.maxWidth > 1200 ? 5 : (constraints.maxWidth > 800 ? 4 : 2);
                  return GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns, crossAxisSpacing: 40, mainAxisSpacing: 40, childAspectRatio: 0.55, 
                    ),
                    itemCount: activeDocs.length + 1, 
                    itemBuilder: (context, index) {
                      if (index == 0) return _buildNewDocumentCard();
                      final doc = activeDocs[index - 1];
                      return DocumentCard(
                        doc: doc,
                        onTap: () => _openEditor(doc),
                        onUpdate: () => setState(() {}), 
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

  Widget _buildSidebarDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(color: Color(0xFFF5F5F7)),
            accountName: Text("Wongoji 작가님", style: GoogleFonts.nanumMyeongjo(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
            accountEmail: Text("로그인이 필요합니다.", style: GoogleFonts.nanumMyeongjo(color: Colors.grey.shade600)),
            currentAccountPicture: CircleAvatar(backgroundColor: Colors.grey.shade300, child: const Icon(Icons.person, color: Colors.white, size: 40)),
          ),
          ListTile(
            leading: Icon(Icons.delete_outline, color: Colors.grey.shade700),
            title: Text("휴지통", style: GoogleFonts.nanumMyeongjo(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
            onTap: () {
              Navigator.pop(context); 
              Navigator.push(context, MaterialPageRoute(builder: (_) => TrashBinScreen(documents: _documents, onUpdate: () => setState(() {}))));
            },
          ),
          const Spacer(),
          Padding(padding: const EdgeInsets.all(20.0), child: Text("Wongoji Studio v0.50", style: TextStyle(color: Colors.grey.shade400, fontSize: 12)))
        ],
      ),
    );
  }

  Widget _buildNewDocumentCard() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1 / 1.414,
              child: GestureDetector(
                onTap: () => _openEditor(),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: Colors.grey.withOpacity(0.4), width: 2, style: BorderStyle.solid),
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
        const SizedBox(height: 16), const SizedBox(height: 24), const SizedBox(height: 4), const SizedBox(height: 16), 
      ],
    );
  }
}